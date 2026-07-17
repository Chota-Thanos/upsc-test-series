import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/tour/app_tour_service.dart';
import '../data/assessment_service.dart';
import '../models/assessment_models.dart';
import 'category_performance_detail_screen.dart';
import 'result_review_screen.dart';
import 'custom_test_create_screen.dart';
import 'ai_based_parsing_screen.dart';
import 'category_detail_screen.dart';
import 'attempt_engine_screen.dart';
import 'my_tests_tab.dart';

class AssessmentDashboardScreen extends StatefulWidget {
  const AssessmentDashboardScreen({super.key});

  @override
  State<AssessmentDashboardScreen> createState() =>
      _AssessmentDashboardScreenState();
}

class _AssessmentDashboardScreenState extends State<AssessmentDashboardScreen> {
  late AssessmentService _service;
  late ApiClient _apiClient;
  bool _loading = true;
  String? _error;
  AssessmentDashboardResponse? _dashboardResponse;
  List<StudentAttemptSummary> _gkAttempts = [];
  List<StudentAttemptSummary> _aptitudeAttempts = [];
  List<StudentAttemptSummary> _mainsAttempts = [];

  List<Map<String, dynamic>> _rawTaxonomyNodes = [];
  List<Map<String, dynamic>> _rawStudentTopicMetrics = [];
  int? _selectedExamId;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Tour
  final GlobalKey _tourTitleKey = GlobalKey();
  bool _tourChecked = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = AssessmentService(apiClient: _apiClient);
    // Guests get a sign-in prompt instead of fetching (these endpoints require
    // a real account, and a 401 here would otherwise silently drop guest mode).
    if (_apiClient.isGuestMode) {
      _loading = false;
    } else {
      _loadData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dashboardResponse = await _service.getAssessmentDashboard();
      final gkAttempts = await _service.getMyAssessmentAttempts(
        contentType: 'gk',
      );
      final aptitudeAttempts = await _service.getMyAssessmentAttempts(
        contentType: 'aptitude',
      );
      final allAttempts = await _service.getMyAssessmentAttempts();

      final exams = await _service.getAssessmentExams();
      List<Map<String, dynamic>> nodes = [];
      List<Map<String, dynamic>> metrics = [];
      int? examId;
      if (exams.isNotEmpty) {
        examId = exams.first.id;
        nodes = await _service.getTaxonomyNodes(examId);
        metrics = await _service.getStudentTopicMetrics();
      }

      setState(() {
        _dashboardResponse = dashboardResponse;
        _gkAttempts = gkAttempts;
        _aptitudeAttempts = aptitudeAttempts;
        _mainsAttempts = allAttempts.where((a) {
          return a.testTemplate.testType == 'mains_test';
        }).toList();
        _selectedExamId = examId;
        _rawTaxonomyNodes = nodes;
        _rawStudentTopicMetrics = metrics;
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
    if (_apiClient.isGuestMode) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        color: AppColors.civic.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(child: Text("📊", style: TextStyle(fontSize: 26))),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Your scorecard is waiting",
                      style: Theme.of(context).textTheme.displayMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Sign in to see your full attempt history, topic-wise accuracy trends, and weak-area heatmap — all saved to your account.",
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => _apiClient.setGuestMode(false),
                      child: const Text("SIGN IN / CREATE ACCOUNT"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.civic)),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.berry,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  "Could not load dashboard",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text("RETRY"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final res = _dashboardResponse!;

    return ShowCaseWidget(
      builder: (ctx) {
        if (!_tourChecked) {
          _tourChecked = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            final show = await AppTourService.shouldShowTour(AppTourService.dashboardScreenKey);
            if (show && mounted) {
              await AppTourService.markTourSeen(AppTourService.dashboardScreenKey);
              if (mounted && ctx.mounted) ShowCaseWidget.of(ctx).startShowCase([_tourTitleKey]);
            }
          });
        }
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: AppColors.paper,
            appBar: AppBar(
              backgroundColor: AppColors.paper,
              elevation: 0,
              title: Showcase(
                key: _tourTitleKey,
                title: "Your Performance Dashboard",
                description: "See your accuracy, score trends, and topic-wise breakdown across all your tests. Switch between GK, CSAT, and Mains tabs.",
                targetBorderRadius: BorderRadius.circular(8),
                child: Text(
                  "Performance",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              actions: const [],
              bottom: const TabBar(
                labelColor: AppColors.civic,
                unselectedLabelColor: AppColors.muted,
                indicatorColor: AppColors.civic,
                tabs: [
                  Tab(text: "GK"),
                  Tab(text: "CSAT"),
                  Tab(text: "Mains"),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildNestedTabWrapper('gk', _buildDashboardTab(res.gk, _gkAttempts, 'gk')),
                _buildNestedTabWrapper('aptitude', _buildDashboardTab(res.aptitude, _aptitudeAttempts, 'aptitude')),
                _buildNestedTabWrapper('mains', _buildMainsDashboardTab(res.mains)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNestedTabWrapper(String contentType, Widget dashboardWidget) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: TabBar(
              labelColor: AppColors.civic,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.civic,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(text: "Summary"),
                Tab(text: "My Results"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                dashboardWidget,
                MyTestsTab(contentType: contentType),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveAttemptsSection(List<StudentAttemptSummary> activeAttempts) {
    if (activeAttempts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "In-Progress Attempts",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        ...activeAttempts.map((attempt) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF7ED), Color(0xFFFFFBEB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: const Color(0xFFFED7AA), width: 1.5),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.timer_outlined,
                    color: Color(0xFFF97316),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attempt.testTemplate.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Started on ${attempt.startedAt.split('T').first}. You left this test in between.",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AttemptEngineScreen(attemptId: attempt.id),
                      ),
                    );
                    _loadData(); // reload on return
                  },
                  child: Text(
                    "RESUME",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildDashboardTab(
    AssessmentDashboard db,
    List<StudentAttemptSummary> attempts,
    String contentType,
  ) {
    final results = attempts
        .map((a) => a.result)
        .whereType<AssessmentResult>()
        .toList();
    final roots = _buildTree(contentType);
    final insights = _topicInsightsFromRoots(roots);
    final weakInsights = _weakInsights(insights);
    final strongInsights = _strongInsights(insights, weakInsights);
    final displayAttempts = db.attemptsCount > 0
        ? db.attemptsCount
        : results.length;
    final displayAccuracy = db.attemptsCount > 0 || results.isEmpty
        ? db.avgAccuracy
        : results.map((r) => r.accuracy).reduce((a, b) => a + b) /
              results.length;
    final displayCorrect = db.totalCorrect > 0 || results.isEmpty
        ? db.totalCorrect
        : results.fold<int>(0, (sum, r) => sum + r.correctCount);
    final displayIncorrect = db.attemptsCount > 0 || results.isEmpty
        ? db.totalIncorrect
        : results.fold<int>(0, (sum, r) => sum + r.incorrectCount);

    final totalQuestionsAttempted = displayCorrect + displayIncorrect;

    final attemptedNodes = insights.length;
    final totalNodes = _countTreeNodes(roots);
    // Sum of root-level (subject) score/maxScore — roots already carry the
    // fully rolled-up subtree totals, so this is the true overall marks
    // percentage across everything attempted, not an average-of-averages.
    final overallScore = roots.fold<double>(0, (sum, r) => sum + r.score);
    final overallMaxScore = roots.fold<double>(0, (sum, r) => sum + r.maxScore);
    final overallScorePercent = overallMaxScore > 0 ? (overallScore / overallMaxScore) * 100 : 0.0;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.civic,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildActiveAttemptsSection(attempts.where((a) => a.status == 'in_progress').toList()),
            _buildDashboardHero(
              contentType: contentType,
              attempts: displayAttempts,
              accuracy: displayAccuracy,
              scorePercent: overallScorePercent,
              weakCount: weakInsights.length,
              strongCount: strongInsights.length,
              attemptedNodes: attemptedNodes,
              totalNodes: totalNodes,
              totalQuestionsAttempted: totalQuestionsAttempted,
            ),
            const SizedBox(height: 20),
            // The category table students actually asked for: every subject
            // down to every topic, ranked by marks percentage, grouped by
            // level, click any row for its own detailed performance page.
            // Kept high on the page — this is the primary way in, not a
            // buried afterthought.
            _buildSectionHeader(
              "Category Performance",
              subtitle:
                  "$attemptedNodes of $totalNodes nodes have attempt data, grouped by level. Tap any row to open its page.",
            ),
            _buildCategoryPerformanceSections(insights, contentType),
            const SizedBox(height: 20),
            if (db.trend.isNotEmpty) ...[
              _buildSectionHeader("Score Trend"),
              _buildObjectiveTrendChart(db),
              const SizedBox(height: 24),
            ],
            _buildInsightSection(
              title: "Priority Revision",
              subtitle: "Lowest marks-percentage nodes from the full syllabus tree",
              insights: weakInsights,
              emptyMessage:
                  "No weak subject, topic, or subtopic identified yet.",
              accent: AppColors.berry,
              icon: Icons.priority_high_rounded,
              contentType: contentType,
            ),
            const SizedBox(height: 20),
            _buildInsightSection(
              title: "Strong Areas",
              subtitle: "High-confidence nodes kept separate from weak areas",
              insights: strongInsights,
              emptyMessage: "Complete more tests to confirm strong areas.",
              accent: AppColors.emerald,
              icon: Icons.verified_rounded,
              contentType: contentType,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMainsDashboardTab(MainsDashboard db) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.civic,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildActiveAttemptsSection(_mainsAttempts.where((a) => a.status == 'in_progress').toList()),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildMetricCard(
                  title: "Total Attempts",
                  value: db.attemptsCount.toString(),
                  icon: Icons.history_edu_rounded,
                  color: AppColors.civic,
                ),
                _buildMetricCard(
                  title: "Avg Score",
                  value: db.avgScore.toStringAsFixed(1),
                  icon: Icons.emoji_events_rounded,
                  color: AppColors.saffron,
                ),
                _buildMetricCard(
                  title: "Highest Score",
                  value: db.maxScore.toStringAsFixed(1),
                  icon: Icons.workspace_premium_rounded,
                  color: AppColors.emerald,
                ),
                _buildMetricCard(
                  title: "Evaluated",
                  value: db.evaluatedCount.toString(),
                  icon: Icons.fact_check_rounded,
                  color: AppColors.brand,
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (db.trend.isNotEmpty) ...[
              _buildSectionHeader("Score Trend"),
              Builder(
                builder: (context) {
                  // Group trend points by unique day (e.g. 2026-06-15)
                  final Map<String, List<TrendPoint>> groupedPoints = {};
                  for (var pt in db.trend) {
                    final datePart = pt.resultDate.split('T')[0];
                    groupedPoints.putIfAbsent(datePart, () => []).add(pt);
                  }

                  final List<TrendPoint> aggregatedTrend = [];
                  final sortedKeys = groupedPoints.keys.toList()..sort();
                  for (var key in sortedKeys) {
                    final pts = groupedPoints[key]!;
                    final double totalScore = pts.map((p) => p.avgScore).reduce((a, b) => a + b);
                    final double totalAccuracy = pts.map((p) => p.avgAccuracy).reduce((a, b) => a + b);
                    final int totalAttempts = pts.fold<int>(0, (sum, p) => sum + (p.attempts > 0 ? p.attempts : 1));

                    aggregatedTrend.add(
                      TrendPoint(
                        resultDate: pts.first.resultDate,
                        avgScore: totalScore / pts.length,
                        avgAccuracy: totalAccuracy / pts.length,
                        attempts: totalAttempts,
                      ),
                    );
                  }

                  return Container(
                    height: 220,
                    padding: const EdgeInsets.only(right: 20, top: 16, bottom: 8),
                    decoration: AppTheme.cardDecoration,
                    child: LineChart(
                      LineChartData(
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            tooltipBgColor: AppColors.ink.withOpacity(0.9),
                            tooltipRoundedRadius: 8,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final trendPt = aggregatedTrend[spot.x.toInt()];
                                final dateStr = _formatTrendDate(trendPt.resultDate);
                                return LineTooltipItem(
                                  "$dateStr\nAvg Score: ${spot.y.toStringAsFixed(1)}\nAttempts: ${trendPt.attempts}",
                                  GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        gridData: const FlGridData(show: false),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1.0,
                              getTitlesWidget: (val, meta) {
                                // Prevent repeated labels at fractional values
                                if ((val - val.toInt()).abs() > 0.01) {
                                  return const SizedBox();
                                }
                                int idx = val.toInt();
                                if (idx >= 0 && idx < aggregatedTrend.length) {
                                  final total = aggregatedTrend.length;
                                  bool showLabel = false;
                                  if (total <= 6) {
                                    showLabel = true;
                                  } else if (total <= 12) {
                                    showLabel = (idx % 2 == 0 || idx == total - 1);
                                  } else {
                                    showLabel = (idx % 3 == 0 || idx == total - 1);
                                  }
                                  if (!showLabel) return const SizedBox();

                                  final dateStr = _formatTrendDate(aggregatedTrend[idx].resultDate);
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      dateStr,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                              reservedSize: 22,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              getTitlesWidget: (val, meta) {
                                return Text(
                                  val.toInt().toString(),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.muted,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: (aggregatedTrend.length - 1).toDouble(),
                        minY: aggregatedTrend.map((e) => e.avgScore).reduce((a, b) => a < b ? a : b) < 0
                            ? (aggregatedTrend.map((e) => e.avgScore).reduce((a, b) => a < b ? a : b) - 2).toDouble()
                            : 0.0,
                        maxY: aggregatedTrend.map((e) => e.avgScore).reduce((a, b) => a > b ? a : b) + 5,
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(
                              aggregatedTrend.length,
                              (index) => FlSpot(
                                index.toDouble(),
                                aggregatedTrend[index].avgScore,
                              ),
                            ),
                            isCurved: true,
                            color: AppColors.civic,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.civic.withOpacity(0.08),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              ),
              const SizedBox(height: 24),
            ],

            _buildMainsCategoryTrendSection(db.categoryTrends),
            const SizedBox(height: 24),

            _buildMainsMistakeSection(db.consistentMistakes),
            const SizedBox(height: 24),

            _buildSectionHeader("Weak Topics Summary"),
            if (db.weakTopics.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: AppTheme.cardDecoration,
                child: Center(
                  child: Text(
                    "Awesome! No weak topics identified yet.",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: db.weakTopics.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final topic = db.weakTopics[index];
                  final String name =
                      topic.taxonomyName ??
                      topic.questionNature ??
                      'General Focus';
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: AppTheme.cardDecoration,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${topic.questionCount} Questions evaluated",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "Avg Score: ${topic.avgScore.toStringAsFixed(1)}",
                              style: GoogleFonts.inter(
                                color: AppColors.saffron,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMainsCategoryTrendSection(List<MainsCategoryTrend> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          "Category Marks Trend",
          subtitle:
              "Scores grouped by Mains paper, subject area, theme, topic, and subtopic.",
        ),
        if (categories.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: AppTheme.cardDecoration,
            child: Text(
              "Category trend appears after evaluated answers are mapped to syllabus categories.",
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: min(categories.length, 8),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final category = categories[index];
              final ratio = _mainsScoreRatio(
                category.avgScore,
                category.avgMaxScore,
                category.avgScoreRatio,
              );
              final latestRatio = _mainsScoreRatio(
                category.latestScore,
                category.latestMaxScore,
                0,
              );
              final color = _mainsScoreColor(ratio);
              final recentTrend = category.trend.length > 6
                  ? category.trend.sublist(category.trend.length - 6)
                  : category.trend;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.categoryName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "${_nodeTypeLabel(category.nodeType)} • ${category.attempts} answer${category.attempts == 1 ? '' : 's'}",
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "${(ratio * 100).round()}%",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMainsScoreTile(
                            "Average",
                            "${category.avgScore.toStringAsFixed(1)} / ${_displayMaxScore(category.avgMaxScore)}",
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMainsScoreTile(
                            "Latest",
                            "${category.latestScore.toStringAsFixed(1)} / ${_displayMaxScore(category.latestMaxScore)}",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (recentTrend.isEmpty)
                      Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Text(
                          "No dated trend yet",
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 62,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: recentTrend.map((point) {
                            final pointRatio = _mainsScoreRatio(
                              point.avgScore,
                              category.avgMaxScore,
                              0,
                            );
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: FractionallySizedBox(
                                          heightFactor: max(0.08, pointRatio),
                                          widthFactor: 1,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: _mainsScoreColor(
                                                pointRatio,
                                              ),
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                    top: Radius.circular(5),
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTrendDate(point.resultDate),
                                      maxLines: 1,
                                      overflow: TextOverflow.clip,
                                      style: GoogleFonts.inter(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: latestRatio,
                        backgroundColor: AppColors.line.withOpacity(0.45),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _mainsScoreColor(latestRatio),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMainsMistakeSection(List<MainsMistake> mistakes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          "Consistent Mistakes",
          subtitle:
              "Repeated evaluator weakness notes across evaluated answers.",
        ),
        if (mistakes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: AppTheme.cardDecoration,
            child: Text(
              "Recurring mistakes appear after at least two evaluated answers share the same weakness.",
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: min(mistakes.length, 8),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final mistake = mistakes[index];
              final ratio = _mainsScoreRatio(
                mistake.avgScore,
                mistake.avgMaxScore,
                mistake.avgScoreRatio,
              );
              final categoryChips = mistake.categories.take(3).toList();

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.berry.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            "${index + 1}",
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: AppColors.berry,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mistake.mistake,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Seen ${mistake.occurrenceCount} times in ${mistake.answerCount} answers",
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 6,
                              value: ratio,
                              backgroundColor: AppColors.line.withOpacity(0.45),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _mainsScoreColor(ratio),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "${mistake.avgScore.toStringAsFixed(1)} avg",
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    if (categoryChips.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: categoryChips.map((name) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.paper,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.muted,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMainsScoreTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: AppColors.muted,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAttemptsList(List<StudentAttemptSummary> attempts) {
    if (attempts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        decoration: AppTheme.cardDecoration,
        child: Column(
          children: [
            const Icon(Icons.quiz_outlined, color: AppColors.muted, size: 36),
            const SizedBox(height: 8),
            Text(
              "You haven't attempted any tests yet.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: attempts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final attempt = attempts[index];
        final result = attempt.result;
        final hasReport = result != null;
        final test = attempt.testTemplate;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          test.title,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Attempted on ${attempt.startedAt.split('T')[0]} • Status: ${attempt.status.toUpperCase()}",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (hasReport)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.civic.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "${result.score}/${result.maxScore}",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              color: AppColors.civic,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            "${(result.accuracy * 100).round()}% Acc",
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.saffron.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "No Report",
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.saffron,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              if (hasReport) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.line, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ResultReviewScreen(resultId: result.id),
                        ),
                      );
                    },
                    child: Text(
                      "REVIEW RESULT SHEET",
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: AppColors.ink,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x030F172A),
            offset: Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppColors.muted,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
            letterSpacing: 1.0,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.muted,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  String _formatPercent(double value) => "${(value * 100).round()}%";

  /// Formats an already-percent-scale value (e.g. scorePercent, which can be
  /// negative once negative marking outweighs correct answers) with an
  /// explicit sign, unlike _formatPercent which expects a 0..1 ratio.
  String _formatScorePercent(double value) {
    final rounded = value.round();
    return rounded > 0 ? "+$rounded%" : "$rounded%";
  }

  Color _scorePercentColor(double value, {bool hasData = true}) {
    if (!hasData) return AppColors.muted;
    if (value >= 60) return AppColors.emerald;
    if (value >= 40) return AppColors.saffron;
    return AppColors.berry;
  }

  void _openCategoryPerformance(int taxonomyNodeId, String title, String contentType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryDetailScreen(
          nodeId: taxonomyNodeId,
          nodeName: title,
          contentType: contentType,
          initialTabIndex: 1,
        ),
      ),
    );
  }

  String _sectionLabel(String contentType) {
    if (contentType == 'aptitude') return "CSAT";
    if (contentType == 'mains') return "Mains";
    return "GK";
  }

  String _nodeTypeLabel(String nodeType) {
    if (nodeType == 'source_bucket') return 'Source';
    if (nodeType.isEmpty) return 'Topic';
    return nodeType.replaceAll('_', ' ');
  }

  String _displayMaxScore(double value) {
    final score = value > 0 ? value : 15.0;
    return score.toStringAsFixed(score.truncateToDouble() == score ? 0 : 1);
  }

  double _mainsScoreRatio(double score, double maxScore, double ratio) {
    if (ratio > 0) {
      final normalized = ratio > 1 ? ratio / 100 : ratio;
      return normalized.clamp(0.0, 1.0).toDouble();
    }
    final denominator = maxScore > 0 ? maxScore : 15.0;
    return (score / denominator).clamp(0.0, 1.0).toDouble();
  }

  Color _mainsScoreColor(double ratio) {
    if (ratio >= 0.55) return AppColors.emerald;
    if (ratio >= 0.40) return AppColors.saffron;
    return AppColors.berry;
  }

  int _countTreeNodes(List<_PerformanceTreeNode> nodes) {
    var count = 0;
    for (final node in nodes) {
      count = count + 1 + _countTreeNodes(node.children);
    }
    return count;
  }

  List<_TopicInsight> _topicInsightsFromRoots(
    List<_PerformanceTreeNode> roots,
  ) {
    final insights = <_TopicInsight>[];

    void visit(_PerformanceTreeNode node, int depth) {
      if (node.totalQuestions > 0) {
        insights.add(
          _TopicInsight(
            id: node.id,
            name: node.name,
            nodeType: node.nodeType,
            depth: depth,
            totalQuestions: node.totalQuestions,
            correctCount: node.correctCount,
            incorrectCount: node.incorrectCount,
            unattemptedCount: node.unattemptedCount,
            accuracy: node.accuracy,
            scorePercent: node.scorePercent,
          ),
        );
      }
      for (final child in node.children) {
        visit(child, depth + 1);
      }
    }

    for (final root in roots) {
      visit(root, 0);
    }
    return insights;
  }

  List<_TopicInsight> _weakInsights(List<_TopicInsight> insights) {
    // Ranked by marks percentage (score / maxScore * 100), not raw accuracy —
    // negative marking means a node with 50% accuracy can still net a
    // negative score, which accuracy alone can't surface.
    final weak =
        insights
            .where((item) => item.attemptedQuestions > 0 && item.scorePercent < 40)
            .toList()
          ..sort((a, b) {
            final scoreCompare = a.scorePercent.compareTo(b.scorePercent);
            if (scoreCompare != 0) return scoreCompare;
            return b.totalQuestions.compareTo(a.totalQuestions);
          });
    return _dedupeInsights(weak).take(6).toList();
  }

  List<_TopicInsight> _strongInsights(
    List<_TopicInsight> insights,
    List<_TopicInsight> weak,
  ) {
    final weakKeys = weak.map((item) => item.identityKey).toSet();
    final strong =
        insights
            .where(
              (item) =>
                  item.attemptedQuestions > 0 &&
                  item.scorePercent >= 60 &&
                  !weakKeys.contains(item.identityKey),
            )
            .toList()
          ..sort((a, b) {
            final scoreCompare = b.scorePercent.compareTo(a.scorePercent);
            if (scoreCompare != 0) return scoreCompare;
            return b.totalQuestions.compareTo(a.totalQuestions);
          });
    return _dedupeInsights(strong).take(6).toList();
  }

  List<_TopicInsight> _dedupeInsights(List<_TopicInsight> insights) {
    final seen = <String>{};
    final result = <_TopicInsight>[];
    for (final item in insights) {
      if (seen.add(item.identityKey)) result.add(item);
    }
    return result;
  }

  Widget _buildDashboardHero({
    required String contentType,
    required int attempts,
    required double accuracy,
    required double scorePercent,
    required int weakCount,
    required int strongCount,
    required int attemptedNodes,
    required int totalNodes,
    required int totalQuestionsAttempted,
  }) {
    final coverage = totalNodes == 0
        ? 0.0
        : (attemptedNodes / totalNodes).clamp(0.0, 1.0);
    final hasData = totalQuestionsAttempted > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x2A0F172A), offset: Offset(0, 10), blurRadius: 26),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.radar_rounded, size: 13, color: Colors.white.withOpacity(0.85)),
                const SizedBox(width: 6),
                Text(
                  _sectionLabel(contentType).toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.9), letterSpacing: 0.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "${_sectionLabel(contentType)} Performance",
            style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            "Every attempted subject, book, chapter, and topic rolled into one view.",
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.65), height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildHeroMetric("Score %", hasData ? _formatScorePercent(scorePercent) : "--")),
              Container(width: 1, height: 34, color: Colors.white.withOpacity(0.12)),
              Expanded(child: _buildHeroMetric("Accuracy", hasData ? _formatPercent(accuracy) : "--")),
              Container(width: 1, height: 34, color: Colors.white.withOpacity(0.12)),
              Expanded(child: _buildHeroMetric("Attempts", attempts.toString())),
              Container(width: 1, height: 34, color: Colors.white.withOpacity(0.12)),
              Expanded(child: _buildHeroMetric("Qs Attempted", totalQuestionsAttempted.toString())),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: hasData ? (scorePercent / 100).clamp(0.0, 1.0) : 0,
              backgroundColor: Colors.white.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(hasData ? _scorePercentColor(scorePercent) : Colors.white24),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroChip("$weakCount weak", AppColors.berry),
              _buildHeroChip("$strongCount strong", AppColors.emerald),
              _buildHeroChip("${(coverage * 100).round()}% syllabus mapped", AppColors.brand),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.55),
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTrendDate(String rawDate) {
    if (rawDate.isEmpty) return '';
    final datePart = rawDate.split('T')[0];
    final parts = datePart.split('-');
    if (parts.length == 3) {
      final month = parts[1];
      final day = parts[2];
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final mIdx = int.tryParse(month);
      if (mIdx != null && mIdx >= 1 && mIdx <= 12) {
        return "$day ${months[mIdx - 1]}";
      }
      return "$day/$month";
    }
    return rawDate;
  }

  Widget _buildObjectiveTrendChart(AssessmentDashboard db) {
    // Group trend points by unique day (e.g. 2026-06-15)
    final Map<String, List<TrendPoint>> groupedPoints = {};
    for (var pt in db.trend) {
      final datePart = pt.resultDate.split('T')[0];
      groupedPoints.putIfAbsent(datePart, () => []).add(pt);
    }

    final List<TrendPoint> aggregatedTrend = [];
    final sortedKeys = groupedPoints.keys.toList()..sort();
    for (var key in sortedKeys) {
      final pts = groupedPoints[key]!;
      final double totalScore = pts.map((p) => p.avgScore).reduce((a, b) => a + b);
      final double totalAccuracy = pts.map((p) => p.avgAccuracy).reduce((a, b) => a + b);
      final int totalAttempts = pts.fold<int>(0, (sum, p) => sum + (p.attempts > 0 ? p.attempts : 1));

      aggregatedTrend.add(
        TrendPoint(
          resultDate: pts.first.resultDate,
          avgScore: totalScore / pts.length,
          avgAccuracy: totalAccuracy / pts.length,
          attempts: totalAttempts,
        ),
      );
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.only(right: 20, top: 16, bottom: 8),
      decoration: AppTheme.cardDecoration,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: AppColors.ink.withOpacity(0.9),
              tooltipRoundedRadius: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final trendPt = aggregatedTrend[spot.x.toInt()];
                  final dateStr = _formatTrendDate(trendPt.resultDate);
                  return LineTooltipItem(
                    "$dateStr\nAvg Score: ${spot.y.toStringAsFixed(1)}\nAccuracy: ${_formatPercent(trendPt.avgAccuracy)}\nAttempts: ${trendPt.attempts}",
                    GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: AppColors.line.withOpacity(0.4), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1.0,
                getTitlesWidget: (val, meta) {
                  // Prevent repeated labels at fractional values
                  if ((val - val.toInt()).abs() > 0.01) {
                    return const SizedBox();
                  }
                  final idx = val.toInt();
                  if (idx >= 0 && idx < aggregatedTrend.length) {
                    final total = aggregatedTrend.length;
                    bool showLabel = false;
                    if (total <= 6) {
                      showLabel = true;
                    } else if (total <= 12) {
                      showLabel = (idx % 2 == 0 || idx == total - 1);
                    } else {
                      showLabel = (idx % 3 == 0 || idx == total - 1);
                    }
                    if (!showLabel) return const SizedBox();

                    final dateStr = _formatTrendDate(aggregatedTrend[idx].resultDate);
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.muted,
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
                reservedSize: 22,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (val, meta) {
                  return Text(
                    val.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.muted,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (aggregatedTrend.length - 1).toDouble(),
          minY: aggregatedTrend.map((e) => e.avgScore).reduce((a, b) => a < b ? a : b) < 0
              ? (aggregatedTrend.map((e) => e.avgScore).reduce((a, b) => a < b ? a : b) - 2).toDouble()
              : 0.0,
          maxY: aggregatedTrend.map((e) => e.avgScore).reduce((a, b) => a > b ? a : b) + 5,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                aggregatedTrend.length,
                (index) => FlSpot(index.toDouble(), aggregatedTrend[index].avgScore),
              ),
              isCurved: true,
              color: AppColors.civic,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                      radius: 4,
                      color: Colors.white,
                      strokeWidth: 2.5,
                      strokeColor: AppColors.civic,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.civic.withOpacity(0.25),
                    AppColors.civic.withOpacity(0.01),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightSection({
    required String title,
    required String subtitle,
    required List<_TopicInsight> insights,
    required String emptyMessage,
    required Color accent,
    required IconData icon,
    required String contentType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title, subtitle: subtitle),
        if (insights.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            decoration: AppTheme.cardDecoration,
            child: Row(
              children: [
                Icon(icon, color: AppColors.muted, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    emptyMessage,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: insights.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _buildInsightCard(insights[index], accent, index + 1, contentType),
          ),
      ],
    );
  }

  Widget _buildInsightCard(_TopicInsight insight, Color accent, int rank, String contentType) {
    final barValue = (insight.scorePercent / 100).clamp(0.0, 1.0).toDouble();
    final color = _scorePercentColor(insight.scorePercent);
    return InkWell(
      onTap: () => _openCategoryPerformance(insight.id, insight.name, contentType),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.22), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x030F172A),
              offset: Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withOpacity(0.16)),
              ),
              child: Text(
                rank.toString(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          insight.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildTypeBadge(insight.typeLabel),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: barValue,
                      backgroundColor: AppColors.line.withOpacity(0.45),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${insight.correctCount}/${insight.totalQuestions} correct, ${_formatPercent(insight.accuracy)} accuracy, ${insight.unattemptedCount} skipped",
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatScorePercent(insight.scorePercent),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: accent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
        ),
      ),
    );
  }

  List<_PerformanceTreeNode> _buildTree(String contentType) {
    final Map<int, _PerformanceTreeNode> nodeMap = {};
    for (var nodeJson in _rawTaxonomyNodes) {
      final int id = int.tryParse(nodeJson['id']?.toString() ?? '') ?? 0;
      final String name = nodeJson['name'] as String? ?? '';
      final String nodeType = nodeJson['node_type'] as String? ?? '';
      final int? parentId = nodeJson['parent_id'] != null
          ? int.tryParse(nodeJson['parent_id'].toString())
          : null;
      final String? nodeContentType = nodeJson['content_type'] as String?;

      if (id != 0) {
        nodeMap[id] = _PerformanceTreeNode(
          id: id,
          name: name,
          nodeType: nodeType,
          parentId: parentId,
          contentType: nodeContentType,
        );
      }
    }

    for (var metricJson in _rawStudentTopicMetrics) {
      final int? nodeId = metricJson['taxonomy_node_id'] != null
          ? int.tryParse(metricJson['taxonomy_node_id'].toString())
          : null;
      if (nodeId != null && nodeMap.containsKey(nodeId)) {
        final node = nodeMap[nodeId]!;
        node.ownAttemptCount =
            node.ownAttemptCount +
            (int.tryParse(metricJson['attempt_count']?.toString() ?? '') ?? 0);
        node.ownCorrectCount =
            node.ownCorrectCount +
            (int.tryParse(metricJson['correct_count']?.toString() ?? '') ?? 0);
        node.ownIncorrectCount =
            node.ownIncorrectCount +
            (int.tryParse(metricJson['incorrect_count']?.toString() ?? '') ??
                0);
        node.ownUnattemptedCount =
            node.ownUnattemptedCount +
            (int.tryParse(metricJson['unattempted_count']?.toString() ?? '') ??
                0);
        node.ownTotalQuestions =
            node.ownTotalQuestions +
            (int.tryParse(metricJson['question_count']?.toString() ?? '') ?? 0);
        node.ownScore =
            node.ownScore +
            (double.tryParse(metricJson['total_score']?.toString() ?? '') ?? 0);
        node.ownMaxScore =
            node.ownMaxScore +
            (double.tryParse(metricJson['total_max_score']?.toString() ?? '') ?? 0);
      }
    }

    final List<_PerformanceTreeNode> rootNodes = [];
    for (var node in nodeMap.values) {
      if (node.parentId != null && nodeMap.containsKey(node.parentId)) {
        nodeMap[node.parentId]!.children.add(node);
      } else {
        rootNodes.add(node);
      }
    }

    for (var root in rootNodes) {
      root.calculateCumulativeMetrics();
    }

    final filteredRoots = rootNodes
        .where((node) => node.containsContentType(contentType) && node.totalQuestions > 0)
        .toList();

    void sortNodeAndChildren(_PerformanceTreeNode node) {
      node.children.retainWhere(
        (child) => child.containsContentType(contentType) && child.totalQuestions > 0,
      );
      node.children.sort((a, b) {
        if (a.totalQuestions > 0 && b.totalQuestions == 0) return -1;
        if (a.totalQuestions == 0 && b.totalQuestions > 0) return 1;
        if (a.totalQuestions > 0 && b.totalQuestions > 0) {
          final scoreCompare = a.scorePercent.compareTo(b.scorePercent);
          if (scoreCompare != 0) return scoreCompare;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      for (var child in node.children) {
        sortNodeAndChildren(child);
      }
    }

    filteredRoots.sort((a, b) {
      if (a.totalQuestions > 0 && b.totalQuestions == 0) return -1;
      if (a.totalQuestions == 0 && b.totalQuestions > 0) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    for (var root in filteredRoots) {
      sortNodeAndChildren(root);
    }

    return filteredRoots;
  }



  /// Level-grouped sections (Subjects / Books / Chapters / Subtopics), each a
  /// flat weakest-first list — replaces an earlier nested expandable tree,
  /// which tested poorly: tapping a leaf row did nothing without noticing a
  /// tiny trailing icon, and nesting made a person's own weak subject harder
  /// to spot than a plain per-level ranking does.
  Widget _buildCategoryPerformanceSections(List<_TopicInsight> insights, String contentType) {
    if (insights.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: AppTheme.cardDecoration,
        child: Center(
          child: Text(
            "No performance data available for this section yet.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final query = _searchQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? insights
        : insights.where((i) => i.name.toLowerCase().contains(query)).toList();

    const sectionOrder = ['subject', 'source_bucket', 'topic', 'subtopic'];
    const sectionLabels = {
      'subject': 'Subjects',
      'source_bucket': 'Books',
      'topic': 'Chapters',
      'subtopic': 'Subtopics',
    };
    final groups = {for (final key in sectionOrder) key: <_TopicInsight>[]};
    for (final insight in filtered) {
      (groups[insight.nodeType] ?? groups['subtopic']!).add(insight);
    }
    for (final list in groups.values) {
      list.sort((a, b) {
        final cmp = a.scorePercent.compareTo(b.scorePercent);
        if (cmp != 0) return cmp;
        return b.totalQuestions.compareTo(a.totalQuestions);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line, width: 1.5),
          ),
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: "Search subject, book, chapter, or topic...",
              hintStyle: GoogleFonts.inter(
                color: AppColors.muted.withOpacity(0.6),
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.muted,
                size: 18,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        color: AppColors.muted,
                        size: 16,
                      ),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.paper.withOpacity(0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                "No categories match \"${_searchQuery.trim()}\".",
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600),
              ),
            ),
          )
        else
          for (final key in sectionOrder)
            if (groups[key]!.isNotEmpty) ...[
              _buildCategoryGroupSection(sectionLabels[key]!, groups[key]!, contentType),
              const SizedBox(height: 18),
            ],
      ],
    );
  }

  Widget _buildCategoryGroupSection(String label, List<_TopicInsight> items, String contentType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.8),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(999)),
              child: Text(
                items.length.toString(),
                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((insight) => _buildCategoryRow(insight, contentType)),
      ],
    );
  }

  Widget _buildCategoryRow(_TopicInsight insight, String contentType) {
    final hasData = insight.attemptedQuestions > 0;
    final color = _scorePercentColor(insight.scorePercent, hasData: hasData);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _openCategoryPerformance(insight.id, insight.name, contentType),
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${insight.totalQuestions} question${insight.totalQuestions == 1 ? '' : 's'}",
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                hasData ? _formatScorePercent(insight.scorePercent) : "--",
                style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: color),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, size: 17, color: AppColors.muted.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }

}

class _PerformanceTreeNode {
  final int id;
  final String name;
  final String nodeType;
  final int? parentId;
  final String? contentType;

  int ownAttemptCount = 0;
  int ownCorrectCount = 0;
  int ownIncorrectCount = 0;
  int ownUnattemptedCount = 0;
  int ownTotalQuestions = 0;
  double ownScore = 0;
  double ownMaxScore = 0;

  int attemptCount = 0;
  int correctCount = 0;
  int incorrectCount = 0;
  int unattemptedCount = 0;
  int totalQuestions = 0;
  double score = 0;
  double maxScore = 0;

  final List<_PerformanceTreeNode> children = [];

  _PerformanceTreeNode({
    required this.id,
    required this.name,
    required this.nodeType,
    this.parentId,
    this.contentType,
  });

  int get attemptedQuestions => correctCount + incorrectCount;

  double get accuracy {
    if (attemptedQuestions == 0) return 0.0;
    return correctCount / attemptedQuestions;
  }

  /// score / maxScore * 100 — the primary ranking/display metric. Unlike
  /// accuracy (a correct-vs-incorrect ratio), this reflects negative marking
  /// and so can go below 0 once wrong answers outweigh right ones.
  double get scorePercent {
    if (maxScore <= 0) return 0.0;
    return (score / maxScore) * 100;
  }

  bool matchesSearch(String query) {
    if (query.isEmpty) return true;
    final lowerQuery = query.toLowerCase();
    if (name.toLowerCase().contains(lowerQuery)) return true;
    return children.any((c) => c.matchesSearch(query));
  }

  bool containsContentType(String contentType) {
    if (this.contentType == contentType) return true;
    return children.any((child) => child.containsContentType(contentType));
  }

  void calculateCumulativeMetrics() {
    attemptCount = ownAttemptCount;
    correctCount = ownCorrectCount;
    incorrectCount = ownIncorrectCount;
    unattemptedCount = ownUnattemptedCount;
    totalQuestions = ownTotalQuestions;
    score = ownScore;
    maxScore = ownMaxScore;

    for (var child in children) {
      child.calculateCumulativeMetrics();
      attemptCount = attemptCount + child.attemptCount;
      correctCount = correctCount + child.correctCount;
      incorrectCount = incorrectCount + child.incorrectCount;
      unattemptedCount = unattemptedCount + child.unattemptedCount;
      totalQuestions = totalQuestions + child.totalQuestions;
      score = score + child.score;
      maxScore = maxScore + child.maxScore;
    }
  }
}

class _TopicInsight {
  final int id;
  final String name;
  final String nodeType;
  final int depth;
  final int totalQuestions;
  final int correctCount;
  final int incorrectCount;
  final int unattemptedCount;
  final double accuracy;
  /// score / maxScore * 100 — can be negative once negative marking outweighs
  /// correct answers. This is the primary ranking metric for weak/strong/
  /// extremes, since accuracy alone can't express that.
  final double scorePercent;

  const _TopicInsight({
    required this.id,
    required this.name,
    required this.nodeType,
    required this.depth,
    required this.totalQuestions,
    required this.correctCount,
    required this.incorrectCount,
    required this.unattemptedCount,
    required this.accuracy,
    required this.scorePercent,
  });

  int get attemptedQuestions => correctCount + incorrectCount;

  String get typeLabel {
    if (nodeType == 'source_bucket') return 'Source';
    if (nodeType.isEmpty) return 'Topic';
    return nodeType.replaceAll('_', ' ');
  }

  String get identityKey =>
      "${nodeType.toLowerCase()}::${name.trim().toLowerCase()}";
}
