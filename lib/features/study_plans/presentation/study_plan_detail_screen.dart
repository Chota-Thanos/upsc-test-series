import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/study_plan_service.dart';
import '../models/study_plan_models.dart';
import 'study_plan_attempt_engine_screen.dart';

class StudyPlanDetailScreen extends StatefulWidget {
  final int planId;
  const StudyPlanDetailScreen({super.key, required this.planId});

  @override
  State<StudyPlanDetailScreen> createState() => _StudyPlanDetailScreenState();
}

class _StudyPlanDetailScreenState extends State<StudyPlanDetailScreen> {
  late StudyPlanService _service;
  bool _loading = true;
  bool _processing = false;
  String? _error;
  StudyPlanDetail? _plan;

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = StudyPlanService(apiClient: apiClient);
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
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _enroll() async {
    setState(() {
      _processing = true;
    });

    try {
      await _service.enrollInStudyPlan(widget.planId);
      final fresh = await _service.getStudyPlan(widget.planId);
      setState(() {
        _plan = fresh;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Study plan unlocked successfully!"), backgroundColor: AppColors.emerald),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Enrollment failed: $e")),
      );
    } finally {
      setState(() {
        _processing = false;
      });
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
    setState(() {
      _processing = true;
    });

    try {
      await _service.updateItemProgress(item.id, status);
      final fresh = await _service.getStudyPlan(widget.planId);
      setState(() {
        _plan = fresh;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Progress update failed: $e")),
      );
    } finally {
      setState(() {
        _processing = false;
      });
    }
  }

  Future<void> _startTest(StudyPlanItem item) async {
    if (item.testTemplateId == null) return;
    setState(() {
      _processing = true;
    });

    try {
      final attemptId = await _service.startTestAttempt(item.testTemplateId!, item.id);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudyPlanAttemptEngineScreen(attemptId: attemptId, planItemId: item.id),
          ),
        ).then((_) => _loadDetails()); // refresh on return
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not start test attempt: $e")),
      );
    } finally {
      setState(() {
        _processing = false;
      });
    }
  }

  // Group items helper
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

    // Progress stats
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
            // Course header details (premium card floating on background)
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
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  
                  // Unlock widget panel
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
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AppColors.muted,
                                ),
                              ),
                              Text(
                                priceStr,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _processing
                                ? null
                                : (plan.summary.priceAmountMinor > 0 ? _launchWebPurchase : _enroll),
                            child: Text(
                              plan.summary.priceAmountMinor > 0 ? "BUY ON WEB" : "UNLOCK NOW",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // Progress bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Your Progress",
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.muted),
                        ),
                        Text(
                          "$progress%",
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.civic),
                        ),
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

            // Weeks curriculum list
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Text(
                "Course Schedule",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: sortedWeeks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, wIdx) {
                final week = sortedWeeks[wIdx];
                final items = weeksMap[week]!;
                return _buildWeekSection(week, items, plan.hasAccess);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekSection(int week, List<StudyPlanItem> items, bool planHasAccess) {
    return Container(
      decoration: AppTheme.cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: week == 1,
        shape: const Border(),
        collapsedShape: const Border(),
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
        title: Text(
          "Week $week",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 15),
        ),
        subtitle: Text(
          "${items.length} tasks scheduled",
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500),
        ),
        children: [
          const Divider(color: AppColors.line, height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(color: AppColors.line, height: 1),
            itemBuilder: (context, idx) {
              final item = items[idx];
              final done = item.progress?.status == 'completed';
              final locked = !planHasAccess && !item.isPreview;
              final isTest = ['prelims_test', 'csat_test', 'mains_test'].contains(item.itemType);
              final resourceUrl = item.lectureUrl ?? item.resourceUrl;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status icon
                    Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(
                        color: done ? AppColors.emerald.withOpacity(0.08) : (locked ? AppColors.paper : AppColors.civic.withOpacity(0.08)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        done ? Icons.check_circle_outline_rounded : _itemIcon(item.itemType),
                        size: 16,
                        color: done ? AppColors.emerald : (locked ? Colors.grey : AppColors.civic),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Content details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "DAY ${item.dayNo} • ${item.itemType.replaceAll('_', ' ').toUpperCase()}",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.civic,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: locked ? AppColors.muted : AppColors.ink,
                            ),
                          ),
                          if (item.description != null && item.description!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.description!,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: AppColors.muted,
                                height: 1.35,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (item.estimatedMinutes != null) ...[
                                const Icon(Icons.timer_outlined, color: AppColors.muted, size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  "${item.estimatedMinutes} Mins",
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (item.isPreview && !planHasAccess) ...[
                                const SizedBox(width: 12),
                                const Icon(Icons.play_circle_fill_rounded, color: AppColors.civic, size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  "Free Preview",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: AppColors.civic,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ]
                            ],
                          )
                        ],
                      ),
                    ),

                    // Actions Button
                    const SizedBox(width: 8),
                    if (locked)
                      const Icon(Icons.lock_outline_rounded, color: Colors.grey, size: 18)
                    else if (isTest)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _processing ? null : () => _startTest(item),
                        child: Text(
                          done ? "RETAKE" : "ATTEMPT",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      )
                    else if (resourceUrl != null)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          side: const BorderSide(color: AppColors.line),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          // Mock open external link
                        },
                        child: Text(
                          "OPEN",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.civic,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      )
                    else if (!done)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          side: const BorderSide(color: AppColors.line),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _processing ? null : () => _updateProgress(item, 'completed'),
                        child: Text(
                          "MARK DONE",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.ink,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      )
                    else
                      const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 20),
                  ],
                ),
              );
            },
          )
        ],
      ),
    );
  }
}
