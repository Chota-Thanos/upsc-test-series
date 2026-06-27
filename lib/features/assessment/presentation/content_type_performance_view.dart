import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/assessment_service.dart';
import '../models/assessment_models.dart';
import 'my_tests_tab.dart';

/// Shows performance for a specific content type with 2 sub-tabs:
/// - Summary: performance dashboard for this content type
/// - My Tests: filtered attempt history for this content type
class ContentTypePerformanceView extends StatefulWidget {
  final String contentType; // 'gk' | 'aptitude' | 'mains'
  const ContentTypePerformanceView({
    super.key,
    required this.contentType,
  });

  @override
  State<ContentTypePerformanceView> createState() =>
      _ContentTypePerformanceViewState();
}

class _ContentTypePerformanceViewState extends State<ContentTypePerformanceView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-tab bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.civic,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.civic,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle:
                GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle:
                GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: const [
              Tab(text: 'Summary'),
              Tab(text: 'My Tests'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Summary tab — shows filtered performance dashboard
              _ContentTypeSummaryTab(contentType: widget.contentType),
              // My Tests tab — filtered by contentType
              MyTestsTab(contentType: widget.contentType),
            ],
          ),
        ),
      ],
    );
  }
}

/// Summary tab: loads and shows dashboard data for the specific content type
class _ContentTypeSummaryTab extends StatefulWidget {
  final String contentType;
  const _ContentTypeSummaryTab({required this.contentType});

  @override
  State<_ContentTypeSummaryTab> createState() => _ContentTypeSummaryTabState();
}

class _ContentTypeSummaryTabState extends State<_ContentTypeSummaryTab> {
  late AssessmentService _service;
  bool _loading = true;
  String? _error;
  AssessmentDashboardResponse? _dashboardResponse;
  List<StudentAttemptSummary> _attempts = [];

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = AssessmentService(apiClient: apiClient);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dashboard = await _service.getAssessmentDashboard();
      final attempts = await _service.getMyAssessmentAttempts(
        contentType: widget.contentType == 'mains' ? null : widget.contentType,
      );
      setState(() {
        _dashboardResponse = dashboard;
        _attempts = widget.contentType == 'mains'
            ? attempts
                .where((a) => a.testTemplate.testType == 'mains_test')
                .toList()
            : attempts;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.civic));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.berry, size: 40),
            const SizedBox(height: 12),
            Text(_error!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return _SummaryContent(
      dashboard: _dashboardResponse!,
      contentType: widget.contentType,
      attempts: _attempts,
    );
  }
}

class _SummaryContent extends StatelessWidget {
  final AssessmentDashboardResponse dashboard;
  final String contentType;
  final List<StudentAttemptSummary> attempts;

  const _SummaryContent({
    required this.dashboard,
    required this.contentType,
    required this.attempts,
  });

  @override
  Widget build(BuildContext context) {
    final isMains = contentType == 'mains';
    final db = isMains
        ? dashboard.mains
        : (contentType == 'gk' ? dashboard.gk : dashboard.aptitude);

    final completedAttempts =
        attempts.where((a) => a.status == 'completed').length;

    // Key metrics — use typed locals to avoid repeated cast confusion
    final List<_MetricItem> metrics;
    if (isMains) {
      final mainsDb = dashboard.mains;
      metrics = [
        _MetricItem(
            label: 'Total Attempts',
            value: mainsDb.attemptsCount.toString(),
            color: AppColors.civic),
        _MetricItem(
            label: 'Avg Score',
            value: mainsDb.avgScore.toStringAsFixed(1),
            color: AppColors.brand),
        _MetricItem(
            label: 'Completed',
            value: completedAttempts.toString(),
            color: AppColors.emerald),
      ];
    } else {
      final objDb =
          contentType == 'gk' ? dashboard.gk : dashboard.aptitude;
      metrics = [
        _MetricItem(
            label: 'Attempts',
            value: objDb.attemptsCount.toString(),
            color: AppColors.civic),
        _MetricItem(
            label: 'Avg Accuracy',
            value: '${(objDb.avgAccuracy * 100).round()}%',
            color: AppColors.emerald),
        _MetricItem(
            label: 'Avg Score',
            value: objDb.avgScore.toStringAsFixed(1),
            color: AppColors.brand),
      ];
    }


    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stats grid
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Performance Overview',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink),
              ),
              const SizedBox(height: 16),
              Row(
                children: metrics
                    .map((m) => Expanded(
                          child: Column(
                            children: [
                              Text(
                                m.value,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: m.color),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m.label,
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.muted),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.civic.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.civic.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.insights_rounded,
                  color: AppColors.civic, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'View detailed analysis, topic heatmaps and syllabus coverage in the Analytics tab.',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.ink),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Recent attempts
        if (attempts.isNotEmpty) ...[
          Text(
            'Recent Attempts',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink),
          ),
          const SizedBox(height: 12),
          ...attempts.take(5).map((attempt) {
            final result = attempt.result;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attempt.testTemplate.title,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          attempt.startedAt.split('T')[0],
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  if (result != null)
                    Text(
                      isMains
                          ? result.score.toStringAsFixed(1)
                          : '${(result.accuracy * 100).round()}%',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.civic),
                    ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _MetricItem {
  final String label;
  final String value;
  final Color color;
  const _MetricItem(
      {required this.label, required this.value, required this.color});
}
