import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../mentors/models/mentor_models.dart';
import '../../mentors/presentation/mentorship_video_call_screen.dart';
import '../data/mentor_workspace_service.dart';
import '../models/mentor_workspace_models.dart';

/// Mentor-side detail view for a single student request. Counterpart to the
/// web `/mentor/workspace` request panel: triage (accept/reject/complete),
/// offer slots, chat, agenda negotiation, copy evaluation, and the entry
/// point into the 1:1 Agora video room.
class MentorRequestDetailScreen extends StatefulWidget {
  final MentorRequest request;

  const MentorRequestDetailScreen({super.key, required this.request});

  @override
  State<MentorRequestDetailScreen> createState() =>
      _MentorRequestDetailScreenState();
}

class _MentorRequestDetailScreenState extends State<MentorRequestDetailScreen> {
  late MentorWorkspaceService _service;
  late MentorRequest _request;
  int? _myUserId;

  bool _loading = false;
  List<MentorshipMessage> _messages = [];
  List<MentorshipAgenda> _agendas = [];
  List<MentorSlot> _mySlots = [];
  final Set<int> _selectedOffers = {};

  final _messageController = TextEditingController();
  final _messageScroll = ScrollController();
  bool _sendingMessage = false;

  final _agendaTitleController = TextEditingController();
  bool _proposingAgenda = false;

  bool _busyTriage = false;

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = MentorWorkspaceService(apiClient: apiClient);
    _myUserId = int.tryParse(apiClient.user?['id']?.toString() ?? '');
    _request = widget.request;
    _refresh();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageScroll.dispose();
    _agendaTitleController.dispose();
    super.dispose();
  }

  int get _requestId => _request.id;

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final requests = await _service.getIncomingRequests();
      final updated = requests.firstWhere(
        (r) => r.id == _request.id,
        orElse: () => _request,
      );
      final messages = await _service.getMessages(_requestId);
      final agendas = await _service.getAgendas(_requestId);

      List<MentorSlot> slots = [];
      if (updated.status == 'accepted' &&
          updated.paymentStatus == 'paid' &&
          updated.scheduledSlotId == null &&
          _myUserId != null) {
        slots = await _service.getMySlots(_myUserId!);
      }

      if (!mounted) return;
      setState(() {
        _request = updated;
        _messages = messages;
        _agendas = agendas;
        _mySlots = slots;
      });
      _scrollMessagesToBottom();
    } catch (e) {
      _toast("Failed to refresh: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollMessagesToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messageScroll.hasClients) {
        _messageScroll.jumpTo(_messageScroll.position.maxScrollExtent);
      }
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _triage(String status) async {
    setState(() => _busyTriage = true);
    try {
      await _service.setRequestStatus(_requestId, status);
      _toast("Request marked as $status");
      await _refresh();
    } catch (e) {
      _toast("Failed: $e");
    } finally {
      if (mounted) setState(() => _busyTriage = false);
    }
  }

  Future<void> _startCallNow() async {
    try {
      final session = await _service.startSessionNow(_requestId);
      final sessionId = int.tryParse(session['id']?.toString() ?? '');
      if (sessionId != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MentorshipVideoCallScreen(sessionId: sessionId),
          ),
        );
      }
    } catch (e) {
      _toast("Failed to start session: $e");
    }
  }

  Future<void> _offerSlots() async {
    if (_selectedOffers.isEmpty) return;
    try {
      await _service.offerSlots(_requestId, _selectedOffers.toList());
      _toast("Slots offered to student");
      _selectedOffers.clear();
      await _refresh();
    } catch (e) {
      _toast("Offering slots failed: $e");
    }
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();
    if (body.isEmpty) return;
    setState(() => _sendingMessage = true);
    try {
      await _service.sendMessage(_requestId, body);
      _messageController.clear();
      final messages = await _service.getMessages(_requestId);
      if (mounted) setState(() => _messages = messages);
      _scrollMessagesToBottom();
    } catch (e) {
      _toast("Failed to send: $e");
    } finally {
      if (mounted) setState(() => _sendingMessage = false);
    }
  }

  Future<void> _proposeAgenda() async {
    final title = _agendaTitleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _proposingAgenda = true);
    try {
      await _service.proposeAgenda(_requestId, title, null);
      _agendaTitleController.clear();
      final agendas = await _service.getAgendas(_requestId);
      if (mounted) setState(() => _agendas = agendas);
    } catch (e) {
      _toast("Failed to propose: $e");
    } finally {
      if (mounted) setState(() => _proposingAgenda = false);
    }
  }

  Future<void> _agendaAction(Future<void> Function() action) async {
    try {
      await action();
      final agendas = await _service.getAgendas(_requestId);
      if (mounted) setState(() => _agendas = agendas);
    } catch (e) {
      _toast("Failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(_request.learnerLabel,
            style: AppTypography.title.copyWith(fontSize: 16)),
        actions: [
          IconButton(
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.refresh_rounded, color: AppColors.muted),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _statusHeaderCard(),
            const SizedBox(height: 16),
            if (_request.hasCopyToEvaluate) ...[
              _evaluationCard(),
              const SizedBox(height: 16),
            ],
            _offerSlotsCard(),
            _agendaCard(),
            const SizedBox(height: 16),
            _chatCard(),
          ],
        ),
      ),
    );
  }

  Widget _statusHeaderCard() {
    final status = _request.status;
    Color chipColor;
    switch (status) {
      case 'accepted':
        chipColor = AppColors.emerald;
        break;
      case 'completed':
        chipColor = AppColors.civic;
        break;
      case 'rejected':
      case 'cancelled':
      case 'expired':
        chipColor = AppColors.berry;
        break;
      default:
        chipColor = AppColors.saffron;
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_request.learnerLabel,
                        style: AppTypography.cardTitle.copyWith(fontSize: 18)),
                    const SizedBox(height: 2),
                    Text(_request.learnerEmail ?? "No email",
                        style: AppTypography.caption),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: chipColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status.toUpperCase(),
                    style: AppTypography.eyebrowSmall.copyWith(color: chipColor)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _pill(
                  _request.preferredMode == 'video'
                      ? "Video call"
                      : "Chat triage",
                  AppColors.civic),
              const SizedBox(width: 8),
              _pill(
                  _request.paymentStatus == 'paid' ? "Paid" : "Payment pending",
                  _request.paymentStatus == 'paid'
                      ? AppColors.emerald
                      : AppColors.muted),
            ],
          ),
          if (_request.note != null && _request.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("STUDENT MESSAGE",
                      style: AppTypography.eyebrowSmall
                          .copyWith(color: AppColors.muted)),
                  const SizedBox(height: 4),
                  Text(_request.note!, style: AppTypography.body),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _triageActions(),
        ],
      ),
    );
  }

  Widget _triageActions() {
    if (_busyTriage) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_request.status == 'requested') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _triage('accepted'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.civic,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Accept"),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _triage('rejected'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.berry,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Reject"),
            ),
          ),
        ],
      );
    }
    if (_request.status == 'accepted') {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startCallNow,
              icon: const Icon(Icons.videocam_rounded, size: 20),
              label: const Text("Start Instant Video Room"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _triage('completed'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.emerald,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Mark as Completed"),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _offerSlotsCard() {
    final show = _request.status == 'accepted' &&
        _request.paymentStatus == 'paid' &&
        _request.scheduledSlotId == null;
    if (!show) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Offer Scheduling Slots",
                style: AppTypography.cardTitle.copyWith(fontSize: 15)),
            const SizedBox(height: 4),
            Text("Select slots to offer this student. They can book one.",
                style: AppTypography.caption),
            const SizedBox(height: 12),
            if (_mySlots.isEmpty)
              Text(
                  "Create slots in the Availability tab first to offer them.",
                  style:
                      AppTypography.caption.copyWith(color: AppColors.berry))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _mySlots.map((slot) {
                  final selected = _selectedOffers.contains(slot.id);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedOffers.remove(slot.id);
                      } else {
                        _selectedOffers.add(slot.id);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.civic : Colors.white,
                        border: Border.all(
                            color: selected
                                ? AppColors.civic
                                : AppColors.line),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _formatSlotLabel(slot.startsAt),
                        style: AppTypography.caption.copyWith(
                          color:
                              selected ? Colors.white : AppColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            if (_selectedOffers.isNotEmpty) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _offerSlots,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text("Send Offers (${_selectedOffers.length})"),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _agendaCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Session Agendas",
              style: AppTypography.cardTitle.copyWith(fontSize: 15)),
          const SizedBox(height: 4),
          Text("Propose discussion points before the session.",
              style: AppTypography.caption),
          const SizedBox(height: 12),
          if (_agendas.isEmpty)
            Text("No agendas yet.", style: AppTypography.caption)
          else
            ..._agendas.map(_agendaTile),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _agendaTitleController,
                  decoration: InputDecoration(
                    hintText: "New agenda point...",
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _proposingAgenda ? null : _proposeAgenda,
                style: IconButton.styleFrom(backgroundColor: AppColors.civic),
                icon: _proposingAgenda
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _agendaTile(MentorshipAgenda agenda) {
    final mine = agenda.createdBy == _myUserId;
    Widget? action;
    if (agenda.status == 'proposed' && !mine) {
      action = TextButton(
        onPressed: () => _agendaAction(() => _service.agreeAgenda(agenda.id)),
        child: const Text("Agree"),
      );
    } else if (agenda.status == 'agreed') {
      action = TextButton(
        onPressed: () =>
            _agendaAction(() => _service.proposeSolveAgenda(agenda.id)),
        child: const Text("Mark solved"),
      );
    } else if (agenda.status == 'solved_proposed' && !mine) {
      action = TextButton(
        onPressed: () =>
            _agendaAction(() => _service.confirmSolveAgenda(agenda.id)),
        child: const Text("Confirm solved"),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(agenda.title,
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(agenda.status.replaceAll('_', ' '),
                    style: AppTypography.eyebrowSmall
                        .copyWith(color: AppColors.muted)),
              ],
            ),
          ),
          if (action != null) action,
          if (mine && agenda.status == 'proposed')
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.berry),
              onPressed: () =>
                  _agendaAction(() => _service.deleteAgenda(agenda.id)),
            ),
        ],
      ),
    );
  }

  Widget _chatCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Chat with Student",
              style: AppTypography.cardTitle.copyWith(fontSize: 15)),
          const SizedBox(height: 12),
          Container(
            height: 260,
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _messages.isEmpty
                ? Center(
                    child: Text("No messages yet.",
                        style: AppTypography.caption))
                : ListView.builder(
                    controller: _messageScroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      final mine = m.senderId == _myUserId;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          constraints: const BoxConstraints(maxWidth: 260),
                          decoration: BoxDecoration(
                            color: mine ? AppColors.civic : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.body,
                                  style: AppTypography.body.copyWith(
                                      color: mine
                                          ? Colors.white
                                          : AppColors.ink)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: "Type a message...",
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sendingMessage ? null : _sendMessage,
                style: IconButton.styleFrom(backgroundColor: AppColors.civic),
                icon: _sendingMessage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _evaluationCard() {
    return _EvaluationForm(
      request: _request,
      service: _service,
      onSubmitted: _refresh,
    );
  }

  // --- small UI helpers ---

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: AppTypography.eyebrowSmall.copyWith(color: color)),
    );
  }

  String _formatSlotLabel(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return "${dt.day}/${dt.month} $h:$m";
  }
}

/// Evaluation form kept as a small stateful child so its text controllers are
/// isolated from the parent's frequent refreshes.
class _EvaluationForm extends StatefulWidget {
  final MentorRequest request;
  final MentorWorkspaceService service;
  final Future<void> Function() onSubmitted;

  const _EvaluationForm({
    required this.request,
    required this.service,
    required this.onSubmitted,
  });

  @override
  State<_EvaluationForm> createState() => _EvaluationFormState();
}

class _EvaluationFormState extends State<_EvaluationForm> {
  late TextEditingController _score;
  late TextEditingController _maxScore;
  late TextEditingController _feedback;
  late TextEditingController _strengths;
  late TextEditingController _weaknesses;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final r = widget.request;
    final custom = r.customEvaluation;
    _score = TextEditingController(
        text: (r.evaluationScore ?? custom?['score'])?.toString() ?? "7");
    _maxScore = TextEditingController(
        text:
            (r.evaluationMaxScore ?? custom?['max_score'])?.toString() ?? "10");
    _feedback = TextEditingController(
        text: r.evaluationFeedback ?? custom?['feedback']?.toString() ?? "");
    final strengths = r.evaluationStrengths.isNotEmpty
        ? r.evaluationStrengths
        : (custom?['strengths'] is List
            ? List<String>.from(custom!['strengths'] as List)
            : <String>[]);
    final weaknesses = r.evaluationWeaknesses.isNotEmpty
        ? r.evaluationWeaknesses
        : (custom?['weaknesses'] is List
            ? List<String>.from(custom!['weaknesses'] as List)
            : <String>[]);
    _strengths = TextEditingController(text: strengths.join(", "));
    _weaknesses = TextEditingController(text: weaknesses.join(", "));
  }

  @override
  void dispose() {
    _score.dispose();
    _maxScore.dispose();
    _feedback.dispose();
    _strengths.dispose();
    _weaknesses.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final score = double.tryParse(_score.text.trim());
    final maxScore = double.tryParse(_maxScore.text.trim());
    if (score == null || maxScore == null || maxScore <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enter valid score and max score")));
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.service.submitEvaluation(
        requestId: widget.request.id,
        mainsAnswerAttemptId: widget.request.mainsAnswerAttemptId,
        score: score,
        maxScore: maxScore,
        feedback: _feedback.text,
        strengths: _strengths.text
            .split(",")
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        weaknesses: _weaknesses.text
            .split(",")
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Evaluation saved")));
      }
      await widget.onSubmitted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grading_rounded,
                  color: AppColors.civic, size: 20),
              const SizedBox(width: 8),
              Text("Copy Evaluation",
                  style: AppTypography.cardTitle.copyWith(fontSize: 15)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            r.mainsAnswerAttemptId != null
                ? "Linked to a platform Mains attempt."
                : "Student uploaded a copy directly.",
            style: AppTypography.caption,
          ),
          if (r.attemptQuestionStatement != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(r.attemptQuestionStatement!,
                  style: AppTypography.caption),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _score,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Score",
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _maxScore,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Max Score",
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _feedback,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: "Feedback",
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _strengths,
            decoration: InputDecoration(
              labelText: "Strengths (comma separated)",
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weaknesses,
            decoration: InputDecoration(
              labelText: "Weaknesses (comma separated)",
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.civic,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text("Save Evaluation"),
            ),
          ),
        ],
      ),
    );
  }
}
