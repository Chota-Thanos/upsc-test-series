import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/study_plan_service.dart';
import '../models/study_plan_models.dart';
import 'study_plan_attempt_engine_screen.dart';
import 'live_class_screen.dart';

const List<String> _testItemTypes = ['prelims_test', 'csat_test', 'mains_test'];
const List<String> _privilegedHostRoles = ['admin', 'moderator', 'content_editor'];
const List<String> _monthNames = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

class StudyPlanDetailScreen extends StatefulWidget {
  final int planId;
  const StudyPlanDetailScreen({super.key, required this.planId});

  @override
  State<StudyPlanDetailScreen> createState() => _StudyPlanDetailScreenState();
}

class _StudyPlanDetailScreenState extends State<StudyPlanDetailScreen> {
  late StudyPlanService _service;
  late ApiClient _apiClient;
  bool _loading = true;
  bool _processing = false;
  String? _error;
  StudyPlanDetail? _plan;
  bool _descriptionExpanded = false;
  final Set<int> _expandedWeeks = {};
  bool _weeksInitialized = false;

  @override
  void initState() {
    super.initState();
    _apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = StudyPlanService(apiClient: _apiClient);
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final plan = await _service.getStudyPlan(widget.planId);
      setState(() {
        _plan = plan;
        _loading = false;
      });
      _initExpandedWeeks(plan);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  /// Auto-expand only the first week that isn't fully complete (the "current"
  /// week), matching a guided-path presentation -- past weeks collapse to a
  /// checkmark, future weeks stay collapsed and dim until access allows.
  void _initExpandedWeeks(StudyPlanDetail plan) {
    if (_weeksInitialized) return;
    final weeksMap = _groupByWeeks(plan.items);
    final sortedWeeks = weeksMap.keys.toList()..sort();
    if (sortedWeeks.isEmpty) {
      _weeksInitialized = true;
      return;
    }
    int currentWeek = sortedWeeks.first;
    for (final w in sortedWeeks) {
      final items = weeksMap[w]!;
      final allDone = items.isNotEmpty && items.every((i) => i.progress?.status == 'completed');
      currentWeek = w;
      if (!allDone) break;
    }
    setState(() {
      _expandedWeeks.add(currentWeek);
      _weeksInitialized = true;
    });
  }

  Future<void> _enroll() async {
    setState(() => _processing = true);
    try {
      await _service.enrollInStudyPlan(widget.planId);
      final fresh = await _service.getStudyPlan(widget.planId);
      setState(() => _plan = fresh);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Study plan unlocked successfully!"), backgroundColor: AppColors.emerald),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Enrollment failed: $e")));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _launchWebPurchase() async {
    if (_plan == null) return;
    final url = Uri.parse("${ApiConstants.webAppUrl}/study-plans/${_plan!.summary.slug}");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  Future<void> _updateProgress(StudyPlanItem item, String status) async {
    setState(() => _processing = true);
    try {
      await _service.updateItemProgress(item.id, status);
      final fresh = await _service.getStudyPlan(widget.planId);
      setState(() => _plan = fresh);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Progress update failed: $e")));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _startTest(StudyPlanItem item) async {
    if (item.testTemplateId == null) return;
    setState(() => _processing = true);
    try {
      final attemptId = await _service.startTestAttempt(item.testTemplateId!, item.id);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudyPlanAttemptEngineScreen(attemptId: attemptId, planItemId: item.id),
          ),
        );
        _loadDetails();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not start test attempt: $e")));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _openResourceUrl(String url) async {
    final uri = Uri.tryParse(url);
    final messenger = ScaffoldMessenger.of(context);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(const SnackBar(content: Text("Could not open this link.")));
    }
  }

  Future<void> _joinLiveClass(int liveClassId, String title) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LiveClassScreen(liveClassId: liveClassId, title: title)),
    );
    _loadDetails();
  }

  Future<void> _startAndJoinLiveClass(int liveClassId, String title) async {
    setState(() => _processing = true);
    try {
      await _service.startLiveClass(liveClassId);
      if (mounted) await _joinLiveClass(liveClassId, title);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not start class: $e")));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  bool get _isPrivilegedHost => _privilegedHostRoles.contains(_apiClient.user?['role'] as String?);

  int? get _currentUserId {
    final raw = _apiClient.user?['id'];
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  Map<int, List<StudyPlanItem>> _groupByWeeks(List<StudyPlanItem> items) {
    final Map<int, List<StudyPlanItem>> weeks = {};
    for (final item in items) {
      weeks.putIfAbsent(item.weekNo, () => []).add(item);
    }
    return weeks;
  }

  IconData _itemIcon(String type) {
    if (type == 'reading') return Icons.menu_book_rounded;
    if (type == 'revision') return Icons.history_rounded;
    if (type == 'live_lecture') return Icons.video_call_rounded;
    return Icons.play_circle_outline_rounded;
  }

  String _formatPrice(int amountMinor, String currency) {
    final double amount = amountMinor / 100;
    if (amount == 0) return "Free";
    final symbol = currency == 'INR' ? '₹' : '\$';
    return "$symbol${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}";
  }

  String _formatScheduledTime(String isoString) {
    final dt = DateTime.tryParse(isoString)?.toLocal();
    if (dt == null) return 'Scheduled';
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${_monthNames[dt.month]} ${dt.day}, $hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _plan == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.civic)),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.berry, size: 44),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadDetails, child: const Text("RETRY")),
              ],
            ),
          ),
        ),
      );
    }

    final plan = _plan!;
    final weeksMap = _groupByWeeks(plan.items);
    final sortedWeeks = weeksMap.keys.toList()..sort();

    final completed = plan.progressSummary?['completed_items'] ?? 0;
    final total = plan.progressSummary?['total_items'] ?? plan.items.length;
    final progress = total > 0 ? (completed / total * 100).round() : 0;
    final priceStr = _formatPrice(plan.summary.priceAmountMinor, plan.summary.currency);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(
          "Study Schedule",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.line, height: 1),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.ink, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_processing)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.summary.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      height: 1.2,
                    ),
                  ),
                  if (plan.summary.subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      plan.summary.subtitle!,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.muted, height: 1.4),
                    ),
                  ],
                  if (plan.reviewsSummary.totalReviews > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          final filled = i < plan.reviewsSummary.averageRating.round();
                          return Icon(filled ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.saffron, size: 15);
                        }),
                        const SizedBox(width: 6),
                        Text(
                          "${plan.reviewsSummary.averageRating.toStringAsFixed(1)} (${plan.reviewsSummary.totalReviews} reviews)",
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ],
                  _buildDescription(plan.summary.description),
                  const SizedBox(height: 16),
                  if (!plan.hasAccess)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.innerCardDecoration,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "PLAN UNLOCK FEE",
                                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.muted),
                              ),
                              Text(
                                priceStr,
                                style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: _processing ? null : (plan.summary.priceAmountMinor > 0 ? _launchWebPurchase : _enroll),
                            child: Text(
                              plan.summary.priceAmountMinor > 0 ? "BUY ON WEB" : "UNLOCK NOW",
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Your Progress", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.muted)),
                        Text("$progress%", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.civic)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        minHeight: 8,
                        backgroundColor: AppColors.paper,
                        valueColor: const AlwaysStoppedAnimation(AppColors.civic),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "$completed of $total items done",
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.bold),
                    ),
                  ]
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Text(
                "Course Schedule",
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                children: [
                  for (int i = 0; i < sortedWeeks.length; i++)
                    _buildWeekNode(
                      sortedWeeks[i],
                      weeksMap[sortedWeeks[i]]!,
                      plan,
                      isLast: i == sortedWeeks.length - 1,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescription(String? description) {
    if (description == null || description.trim().isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: _descriptionExpanded ? 4000 : 90),
            child: ClipRect(
              child: Html(
                data: description,
                style: {
                  "body": Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: FontSize(12.5),
                    color: AppColors.muted,
                    lineHeight: const LineHeight(1.5),
                  ),
                  "p": Style(margin: Margins.only(bottom: 8)),
                  "ul": Style(margin: Margins.only(bottom: 8, left: 4)),
                  "li": Style(margin: Margins.only(bottom: 4)),
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => setState(() => _descriptionExpanded = !_descriptionExpanded),
          child: Text(
            _descriptionExpanded ? "Show less" : "Read more",
            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.civic),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekNode(int week, List<StudyPlanItem> items, StudyPlanDetail plan, {required bool isLast}) {
    final allDone = items.isNotEmpty && items.every((i) => i.progress?.status == 'completed');
    final isExpanded = _expandedWeeks.contains(week);
    final locked = !plan.hasAccess && !items.any((i) => i.isPreview);
    final weekTitle = plan.weekTitle(week);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _buildWeekStatusCircle(done: allDone, locked: locked, isCurrent: isExpanded && !allDone),
              if (!isLast) Expanded(child: Container(width: 2, color: AppColors.line, margin: const EdgeInsets.symmetric(vertical: 2))),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 8 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => setState(() {
                      if (isExpanded) {
                        _expandedWeeks.remove(week);
                      } else {
                        _expandedWeeks.add(week);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "WEEK $week${allDone ? ' · COMPLETE' : (locked ? ' · LOCKED' : '')}",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: allDone ? AppColors.emerald : (locked ? AppColors.muted : AppColors.civic),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            weekTitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: locked ? AppColors.muted : AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 8),
                    ...items.map((item) => _buildDayRow(item, plan.hasAccess)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStatusCircle({required bool done, required bool locked, required bool isCurrent}) {
    if (done) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(color: AppColors.emerald, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 15),
      );
    }
    if (isCurrent) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.civic,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.civic.withOpacity(0.25), blurRadius: 0, spreadRadius: 4)],
        ),
        child: Center(
          child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
        ),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(color: AppColors.paper, shape: BoxShape.circle, border: Border.all(color: AppColors.line, width: 2)),
      child: locked ? const Icon(Icons.lock_outline_rounded, size: 11, color: AppColors.muted) : null,
    );
  }

  Widget _buildDayRow(StudyPlanItem item, bool planHasAccess) {
    final done = item.progress?.status == 'completed';
    final locked = !planHasAccess && !item.isPreview;
    final isTest = _testItemTypes.contains(item.itemType);
    final isLive = item.itemType == 'live_lecture';
    final resourceUrl = item.lectureUrl ?? item.resourceUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              done ? Icons.check_circle_rounded : (locked ? Icons.lock_outline_rounded : _itemIcon(item.itemType)),
              color: done ? AppColors.emerald : (locked ? AppColors.muted : AppColors.civic),
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "DAY ${item.dayNo} · ${item.itemType.replaceAll('_', ' ').toUpperCase()}",
                  style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.6),
                ),
                const SizedBox(height: 2),
                Text(
                  item.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.muted,
                    color: done ? AppColors.muted : (locked ? AppColors.muted : AppColors.ink),
                  ),
                ),
                if (item.description != null && item.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.description!,
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted, height: 1.3),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (item.estimatedMinutes != null)
                      _metaChip(Icons.timer_outlined, "${item.estimatedMinutes} mins"),
                    if (item.isPreview && !planHasAccess)
                      Text(
                        "FREE PREVIEW",
                        style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.civic, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                      ),
                    if (isLive && item.liveClass != null) _buildLiveClassStatusText(item.liveClass!),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (locked)
            const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.lock_outline_rounded, color: AppColors.muted, size: 16))
          else if (isLive && item.liveClass != null)
            _buildLiveClassAction(item.liveClass!, item.title)
          else if (isTest)
            _actionButton(done ? "RETAKE" : "ATTEMPT", filled: true, onTap: _processing ? null : () => _startTest(item))
          else if (resourceUrl != null)
            _actionButton("OPEN", filled: false, onTap: () => _openResourceUrl(resourceUrl))
          else if (!done)
            _actionButton("MARK DONE", filled: false, onTap: _processing ? null : () => _updateProgress(item, 'completed'))
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.muted, size: 12),
        const SizedBox(width: 3),
        Text(text, style: GoogleFonts.inter(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _actionButton(String label, {required bool filled, required VoidCallback? onTap}) {
    return SizedBox(
      height: 30,
      child: filled
          ? ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
              onPressed: onTap,
              child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                side: const BorderSide(color: AppColors.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
              onPressed: onTap,
              child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.civic, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
            ),
    );
  }

  bool _canHostLiveClass(StudyPlanLiveClassSummary liveClass) {
    return _isPrivilegedHost || (_currentUserId != null && _currentUserId == liveClass.hostUserId);
  }

  Widget _buildLiveClassStatusText(StudyPlanLiveClassSummary liveClass) {
    if (liveClass.isLive) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.berry, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text("LIVE NOW", style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.berry)),
        ],
      );
    }
    if (liveClass.hasEnded) {
      return Text("Session ended", style: GoogleFonts.inter(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w600));
    }
    return _metaChip(Icons.schedule_rounded, "Starts ${_formatScheduledTime(liveClass.scheduledStart)}");
  }

  Widget _buildLiveClassAction(StudyPlanLiveClassSummary liveClass, String title) {
    final canHost = _canHostLiveClass(liveClass);

    if (liveClass.hasEnded) {
      return const SizedBox.shrink();
    }

    if (liveClass.isLive) {
      return _actionButton(
        canHost ? "RESUME" : "JOIN LIVE",
        filled: true,
        onTap: _processing ? null : () => _joinLiveClass(liveClass.id, title),
      );
    }

    if (canHost) {
      return _actionButton(
        "START",
        filled: false,
        onTap: _processing ? null : () => _startAndJoinLiveClass(liveClass.id, title),
      );
    }

    return const SizedBox.shrink();
  }
}
