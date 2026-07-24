import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/mentor_service.dart';
import '../models/mentor_models.dart';
import 'mentorship_video_call_screen.dart';

/// Full detail view for a single mentorship request: lifecycle tracker,
/// pre-payment agenda negotiation + chat, payment, slot booking, and the
/// entry point into the 1:1 video call. This is the native-app counterpart
/// to the web app's /dashboard/mentorship detail panel -- previously mobile
/// had no way to do any of this and had to hand off to the website.
class MentorshipRequestDetailScreen extends StatefulWidget {
  final Map<String, dynamic> initialRequest;

  const MentorshipRequestDetailScreen({super.key, required this.initialRequest});

  @override
  State<MentorshipRequestDetailScreen> createState() =>
      _MentorshipRequestDetailScreenState();
}

class _MentorshipRequestDetailScreenState
    extends State<MentorshipRequestDetailScreen> {
  late MentorService _service;
  late Map<String, dynamic> _request;
  int? _myUserId;

  bool _loading = false;
  List<MentorshipAgenda> _agendas = [];
  List<MentorshipMessage> _messages = [];
  List<Map<String, dynamic>> _slots = [];
  int? _selectedSlotId;

  bool _submittingPayment = false;
  bool _bookingSlot = false;
  bool _sendingMessage = false;
  bool _proposingAgenda = false;

  final _messageController = TextEditingController();
  final _agendaTitleController = TextEditingController();
  final _agendaDescController = TextEditingController();
  final _messageScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = MentorService(apiClient: apiClient);
    _myUserId = int.tryParse(apiClient.user?['id']?.toString() ?? '');
    _request = widget.initialRequest;
    _refresh();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _agendaTitleController.dispose();
    _agendaDescController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  int get _requestId => int.tryParse(_request['id']?.toString() ?? '') ?? 0;
  String get _status => _request['status']?.toString() ?? 'requested';
  String get _paymentStatus =>
      _request['payment_status']?.toString() ?? 'pending';
  int? get _scheduledSlotId =>
      int.tryParse(_request['scheduled_slot_id']?.toString() ?? '');
  int? get _sessionId =>
      int.tryParse(_request['session_id']?.toString() ?? '');
  int? get _mentorId => int.tryParse(_request['mentor_id']?.toString() ?? '');

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final requests = await _service.getMyRequests();
      final updated = requests.firstWhere(
        (r) => r['id']?.toString() == _request['id']?.toString(),
        orElse: () => _request,
      );
      final agendas = await _service.getAgendas(_requestId);
      final messages = await _service.getMessages(_requestId);

      List<Map<String, dynamic>> slots = [];
      if (updated['payment_status'] == 'paid' &&
          updated['scheduled_slot_id'] == null &&
          _mentorId != null) {
        slots = await _service.getMentorSlots(_mentorId!);
      }

      if (!mounted) return;
      setState(() {
        _request = updated;
        _agendas = agendas;
        _messages = messages;
        _slots = slots;
      });
      _scrollMessagesToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to refresh: $e")));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollMessagesToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messageScrollController.hasClients) return;
      _messageScrollController.jumpTo(
        _messageScrollController.position.maxScrollExtent,
      );
    });
  }

  bool get _hasUnagreedAgendas =>
      _agendas.any((a) => a.status == 'proposed');

  bool get _isClosed =>
      ['completed', 'rejected', 'cancelled', 'expired'].contains(_status);

  // --- Actions ---

  Future<void> _handlePay() async {
    setState(() => _submittingPayment = true);
    try {
      final order = await _service.createPaymentOrder(_requestId);
      final simulated = order['simulated'] == true;

      if (simulated) {
        await _service.verifyPayment(
          requestId: _requestId,
          orderId: order['order_id'] as String,
          paymentId: 'sim_pay_${DateTime.now().millisecondsSinceEpoch}',
          signature: 'simulated_signature',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Payment successful!")),
          );
        }
        await _refresh();
      } else if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text("Complete Payment on Web"),
            content: const Text(
              "Real payment is configured for this platform. Please complete this payment from your web dashboard for now -- in-app checkout is coming soon.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Payment failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _submittingPayment = false);
    }
  }

  Future<void> _handleBookSlot() async {
    if (_selectedSlotId == null) return;
    setState(() => _bookingSlot = true);
    try {
      await _service.bookSlot(_requestId, _selectedSlotId!);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Booking failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _bookingSlot = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingMessage = true);
    _messageController.clear();
    try {
      await _service.sendMessage(_requestId, text);
      final messages = await _service.getMessages(_requestId);
      if (!mounted) return;
      setState(() => _messages = messages);
      _scrollMessagesToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to send message: $e")));
      }
    } finally {
      if (mounted) setState(() => _sendingMessage = false);
    }
  }

  Future<void> _proposeAgenda() async {
    final title = _agendaTitleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _proposingAgenda = true);
    try {
      await _service.proposeAgenda(
        _requestId,
        title,
        _agendaDescController.text,
      );
      _agendaTitleController.clear();
      _agendaDescController.clear();
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to propose agenda: $e")));
      }
    } finally {
      if (mounted) setState(() => _proposingAgenda = false);
    }
  }

  Future<void> _agreeAgenda(int agendaId) async {
    try {
      await _service.agreeToAgenda(agendaId);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed: $e")));
      }
    }
  }

  Future<void> _confirmSolveAgenda(int agendaId) async {
    try {
      await _service.confirmSolveAgenda(agendaId);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed: $e")));
      }
    }
  }

  Future<void> _deleteAgenda(int agendaId) async {
    try {
      await _service.deleteAgenda(agendaId);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed: $e")));
      }
    }
  }

  void _openVideoCall() {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MentorshipVideoCallScreen(sessionId: sessionId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mentorName = _request['mentor_name']?.toString() ?? 'Mentor';

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(mentorName, style: AppTypography.title.copyWith(fontSize: 16)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.line, height: 1),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTracker(),
            const SizedBox(height: 16),
            _buildActionPanel(),
            const SizedBox(height: 16),
            _buildAgendaPanel(),
            const SizedBox(height: 16),
            _buildChatPanel(),
          ],
        ),
      ),
    );
  }

  // --- Lifecycle tracker -- mirrors buildMentorshipSteps() on web ---

  Widget _buildTracker() {
    if (['rejected', 'cancelled', 'expired'].contains(_status)) {
      final labels = {
        'rejected': 'This mentorship request was rejected.',
        'cancelled': 'This mentorship request was cancelled.',
        'expired': 'This mentorship request expired before it could be scheduled.',
      };
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.berry.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: AppColors.berry, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                labels[_status] ?? 'This mentorship request is closed.',
                style: AppTypography.caption.copyWith(color: AppColors.berry),
              ),
            ),
          ],
        ),
      );
    }

    final hasAgendas = _agendas.isNotEmpty;
    final agendasAgreedDone = !hasAgendas || !_hasUnagreedAgendas;
    final hasCopy =
        _request['mains_answer_attempt_id'] != null ||
        (_request['meta'] is Map && (_request['meta'] as Map)['student_copy'] != null);
    final isEvaluated = _request['mains_answer_attempt_id'] != null
        ? _request['evaluation_status'] == 'evaluated'
        : (_request['meta'] is Map && (_request['meta'] as Map)['evaluation'] != null);
    final isAccepted = _status == 'accepted' || _status == 'completed';
    final isPaid = _paymentStatus == 'paid';
    final isScheduled = _scheduledSlotId != null || _sessionId != null;
    final isCompleted = _status == 'completed';

    final rows = <_TrackerRow>[
      _TrackerRow.simple('Requested', true),
      _TrackerRow.simple('Agenda Agreed', agendasAgreedDone),
      _TrackerRow.simple('Paid', isPaid),
      if (hasCopy)
        _TrackerRow.phase(
          label: 'Copy Evaluation',
          color: AppColors.civic,
          done: isEvaluated,
          statusText: isEvaluated
              ? 'Evaluated'
              : isAccepted
              ? 'In checking'
              : 'Awaiting acceptance',
          substeps: [
            _TrackerSubStep('Copy submitted', true, false),
            _TrackerSubStep('Copy received', isAccepted, !isAccepted),
            _TrackerSubStep('In checking process', isEvaluated, isAccepted && !isEvaluated),
            _TrackerSubStep('Copy evaluated', isEvaluated, false),
          ],
        ),
      _TrackerRow.phase(
        label: 'Mentorship',
        color: AppColors.saffron,
        done: isCompleted,
        statusText: isCompleted
            ? 'Completed'
            : isScheduled
            ? 'Scheduled'
            : isPaid
            ? 'Awaiting scheduling'
            : 'Not started',
        substeps: [
          _TrackerSubStep('Requested', isPaid, !isPaid),
          _TrackerSubStep('Scheduled', isScheduled, isPaid && !isScheduled),
          _TrackerSubStep('In process', isCompleted, isScheduled && !isCompleted),
          _TrackerSubStep('Completed', isCompleted, false),
        ],
      ),
    ];

    final firstNotDone = rows.firstWhere(
      (r) => !r.done,
      orElse: () => rows.last,
    );
    if (!firstNotDone.done) firstNotDone.current = true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) _buildTrackerRow(rows[i], i == rows.length - 1),
        ],
      ),
    );
  }

  Widget _buildTrackerRow(_TrackerRow row, bool isLast) {
    final color = row.color ?? AppColors.civic;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 6,
                  color: Colors.transparent,
                ),
                Container(
                  height: 26,
                  width: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: row.done
                        ? AppColors.emerald
                        : row.current
                        ? color
                        : Colors.white,
                    border: Border.all(
                      color: row.done
                          ? AppColors.emerald
                          : row.kind == _RowKind.phase
                          ? color
                          : (row.current ? AppColors.civic : AppColors.line),
                      width: 2,
                    ),
                  ),
                  child: row.done
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: row.done ? AppColors.emerald : AppColors.line,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        row.label,
                        style: AppTypography.cardTitle.copyWith(
                          fontSize: 13.5,
                          color: row.kind == _RowKind.phase && (row.done || row.current)
                              ? color
                              : (row.done || row.current ? AppColors.ink : AppColors.muted),
                        ),
                      ),
                      if (row.kind == _RowKind.phase)
                        Text(
                          row.statusText ?? '',
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                    ],
                  ),
                  if (row.kind == _RowKind.phase) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final sub in row.substeps!)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 13,
                                    height: 13,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: sub.done ? AppColors.emerald : Colors.white,
                                      border: Border.all(
                                        color: sub.done
                                            ? AppColors.emerald
                                            : sub.current
                                            ? color
                                            : AppColors.line,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    sub.label,
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: (sub.done || sub.current) ? AppColors.ink : AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Action panel: pay / book slot / join call ---

  Widget _buildActionPanel() {
    if (_status == 'accepted' && _paymentStatus == 'pending') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Pay & Book Session", style: AppTypography.cardTitle),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: (_submittingPayment || _hasUnagreedAgendas)
                  ? null
                  : _handlePay,
              icon: const Icon(Icons.credit_card_rounded, size: 16),
              label: Text(
                _submittingPayment ? "Processing..." : "Pay ₹1,000 & Book",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.civic,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_hasUnagreedAgendas) ...[
              const SizedBox(height: 6),
              Text(
                "Agreement on all proposed agendas required before payment.",
                style: AppTypography.caption.copyWith(
                  color: AppColors.berry,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (_paymentStatus == 'paid' && _scheduledSlotId == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Book a Slot", style: AppTypography.cardTitle),
            const SizedBox(height: 10),
            if (_slots.isEmpty)
              Text(
                "No slots offered yet. The mentor will offer availability soon.",
                style: AppTypography.caption,
              )
            else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _selectedSlotId,
                    hint: const Text("Select a slot"),
                    items: _slots
                        .map(
                          (s) => DropdownMenuItem<int>(
                            value: int.tryParse(s['id'].toString()),
                            child: Text(
                              DateTime.tryParse(s['starts_at']?.toString() ?? '')
                                      ?.toLocal()
                                      .toString() ??
                                  s['starts_at'].toString(),
                              style: AppTypography.caption,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedSlotId = val),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: (_bookingSlot || _selectedSlotId == null)
                    ? null
                    : _handleBookSlot,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.civic,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(_bookingSlot ? "Booking..." : "Confirm Slot"),
              ),
            ],
          ],
        ),
      );
    }

    if (_scheduledSlotId != null && _sessionId != null) {
      return ElevatedButton.icon(
        onPressed: _openVideoCall,
        icon: const Icon(Icons.videocam_rounded),
        label: const Text("Join Call Room"),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emerald,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // --- Agendas ---

  Widget _buildAgendaPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Agendas (${_agendas.length})", style: AppTypography.cardTitle),
          const SizedBox(height: 10),
          if (_agendas.isEmpty)
            Text("No agendas proposed yet.", style: AppTypography.caption),
          ..._agendas.map(_buildAgendaTile),
          if (!_isClosed) ...[
            const SizedBox(height: 12),
            Divider(color: AppColors.line),
            const SizedBox(height: 8),
            TextField(
              controller: _agendaTitleController,
              style: AppTypography.body,
              decoration: InputDecoration(
                hintText: "Agenda title...",
                filled: true,
                fillColor: AppColors.paper,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _agendaDescController,
              maxLines: 2,
              style: AppTypography.body,
              decoration: InputDecoration(
                hintText: "Description (optional)...",
                filled: true,
                fillColor: AppColors.paper,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _proposingAgenda ? null : _proposeAgenda,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(_proposingAgenda ? "Proposing..." : "Propose Agenda"),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAgendaTile(MentorshipAgenda agenda) {
    final isMine = agenda.createdBy == _myUserId;
    final statusColors = {
      'proposed': AppColors.saffron,
      'agreed': AppColors.civic,
      'solved_proposed': AppColors.civic,
      'solved': AppColors.emerald,
    };
    final color = statusColors[agenda.status] ?? AppColors.muted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  agenda.title,
                  style: AppTypography.cardTitle.copyWith(fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  agenda.status.replaceAll('_', ' '),
                  style: AppTypography.eyebrowSmall.copyWith(
                    color: color,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          if (agenda.description?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(agenda.description!, style: AppTypography.caption),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (agenda.status == 'proposed' && !isMine)
                TextButton(
                  onPressed: () => _agreeAgenda(agenda.id),
                  child: const Text("Agree"),
                ),
              if (agenda.status == 'solved_proposed' && !isMine)
                TextButton(
                  onPressed: () => _confirmSolveAgenda(agenda.id),
                  child: const Text("Confirm Solved"),
                ),
              if (agenda.status == 'proposed' && isMine)
                TextButton(
                  onPressed: () => _deleteAgenda(agenda.id),
                  style: TextButton.styleFrom(foregroundColor: AppColors.berry),
                  child: const Text("Delete"),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Chat ---

  Widget _buildChatPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Chat with Mentor", style: AppTypography.cardTitle),
          const SizedBox(height: 10),
          SizedBox(
            height: 260,
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      "No messages yet. Send a message to start coordinating.",
                      style: AppTypography.caption,
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    controller: _messageScrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _buildMessageBubble(_messages[index]),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: AppTypography.body,
                  decoration: InputDecoration(
                    hintText: "Type a message...",
                    filled: true,
                    fillColor: AppColors.paper,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  textInputAction: TextInputAction.send,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sendingMessage ? null : _sendMessage,
                icon: const Icon(Icons.send_rounded),
                color: AppColors.civic,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MentorshipMessage message) {
    final isMe = message.senderId == _myUserId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            isMe ? "You" : message.senderUsername,
            style: AppTypography.caption.copyWith(fontSize: 9.5),
          ),
          const SizedBox(height: 2),
          Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMe ? AppColors.civic : AppColors.paper,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              message.body,
              style: AppTypography.body.copyWith(
                fontSize: 12.5,
                color: isMe ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _RowKind { simple, phase }

class _TrackerSubStep {
  final String label;
  final bool done;
  final bool current;
  _TrackerSubStep(this.label, this.done, this.current);
}

class _TrackerRow {
  final _RowKind kind;
  final String label;
  final bool done;
  final Color? color;
  final String? statusText;
  final List<_TrackerSubStep>? substeps;
  bool current;

  _TrackerRow.simple(this.label, this.done)
    : kind = _RowKind.simple,
      color = null,
      statusText = null,
      substeps = null,
      current = false;

  _TrackerRow.phase({
    required this.label,
    required this.color,
    required this.done,
    required this.statusText,
    required this.substeps,
  }) : kind = _RowKind.phase,
       current = false;
}
