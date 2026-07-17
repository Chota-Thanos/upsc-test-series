import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/assessment_service.dart';
import 'category_detail_screen.dart';

class CategoryPerformanceDetailScreen extends StatefulWidget {
  final int taxonomyNodeId;
  final String? initialTitle;
  final String contentType;

  const CategoryPerformanceDetailScreen({
    super.key,
    required this.taxonomyNodeId,
    required this.contentType,
    this.initialTitle,
  });

  @override
  State<CategoryPerformanceDetailScreen> createState() => _CategoryPerformanceDetailScreenState();
}

class _CategoryPerformanceDetailScreenState extends State<CategoryPerformanceDetailScreen> {
  late AssessmentService _service;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = AssessmentService(apiClient: apiClient);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _service.getCategoryPerformance(widget.taxonomyNodeId);
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  // ─── Small parsing / formatting helpers ────────────────────────────────

  num _num(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _text(dynamic value, [String fallback = '']) {
    final raw = value?.toString();
    if (raw == null || raw.trim().isEmpty) return fallback;
    return raw;
  }

  List<Map<String, dynamic>> _list(String key) {
    final raw = _data?[key];
    if (raw is! List) return [];
    return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  double _pct(dynamic value) {
    final n = _num(value).toDouble();
    return n <= 1 ? n : n / 100;
  }

  String _formatPercent(dynamic value) => "${(_pct(value) * 100).round()}%";

  /// score_percent is already percent-scale (not 0..1) and can go negative
  /// once negative marking outweighs correct answers — accuracy alone can't
  /// express that, which is why this (not accuracy) drives ranking/color here.
  double _scorePercent(dynamic value) => _num(value).toDouble();

  String _formatScorePercent(dynamic value) {
    final rounded = _scorePercent(value).round();
    return rounded > 0 ? "+$rounded%" : "$rounded%";
  }

  Color _scorePercentColor(dynamic value, {bool hasData = true}) {
    if (!hasData) return AppColors.muted;
    final pct = _scorePercent(value);
    if (pct >= 60) return AppColors.emerald;
    if (pct >= 40) return AppColors.saffron;
    return AppColors.berry;
  }

  Color _outcomeColor(String outcome) {
    if (outcome == 'correct') return AppColors.emerald;
    if (outcome == 'incorrect') return AppColors.berry;
    return AppColors.muted;
  }

  IconData _outcomeIcon(String outcome) {
    if (outcome == 'correct') return Icons.check_circle_rounded;
    if (outcome == 'incorrect') return Icons.cancel_rounded;
    return Icons.radio_button_unchecked_rounded;
  }

  String _levelLabel(String nodeType) {
    switch (nodeType) {
      case 'subject':
        return 'Subject';
      case 'source_bucket':
        return 'Book';
      case 'topic':
        return 'Chapter';
      case 'subtopic':
        return 'Topic';
      default:
        return nodeType.isEmpty ? 'Category' : nodeType.replaceAll('_', ' ');
    }
  }

  IconData _levelIcon(String nodeType) {
    switch (nodeType) {
      case 'subject':
        return Icons.local_library_rounded;
      case 'source_bucket':
        return Icons.menu_book_rounded;
      case 'topic':
        return Icons.bookmark_rounded;
      case 'subtopic':
        return Icons.label_rounded;
      default:
        return Icons.folder_open_rounded;
    }
  }

  List<Map<String, dynamic>> _filteredQuestions() {
    final questions = _list('questions');
    if (_filter == 'all') return questions;
    return questions.where((q) => _text(q['outcome'], 'unattempted') == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.civic)),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Category Performance")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.berry, size: 44),
                const SizedBox(height: 14),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _load, child: const Text("RETRY")),
              ],
            ),
          ),
        ),
      );
    }

    final data = _data ?? {};
    final category = Map<String, dynamic>.from((data['category'] as Map?) ?? {});
    final summary = Map<String, dynamic>.from((data['summary'] as Map?) ?? {});
    final questions = _filteredQuestions();
    final attempts = _list('attempts');
    final children = _list('children');
    final title = _text(category['name'], widget.initialTitle ?? 'Category');
    final nodeType = _text(category['node_type'], 'category');

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Category Performance",
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 16),
            ),
            Text(
              _levelLabel(nodeType).toUpperCase(),
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.muted, fontSize: 10, letterSpacing: 0.6),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.civic,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _buildHero(title, nodeType, summary),
            const SizedBox(height: 18),
            _buildOutcomeSplit(summary),
            const SizedBox(height: 18),
            _buildSubcategoriesSection(children),
            const SizedBox(height: 18),
            _buildAttemptHistory(attempts),
            const SizedBox(height: 18),
            _buildImprovementTip(summary),
            const SizedBox(height: 24),
            _buildQuestionRecordHeader(summary),
            const SizedBox(height: 12),
            if (questions.isEmpty)
              _buildEmptyQuestions()
            else
              ...questions.map(_buildQuestionCard),
          ],
        ),
      ),
    );
  }

  // ─── Section: Hero ──────────────────────────────────────────────────────

  Widget _buildHero(String title, String nodeType, Map<String, dynamic> summary) {
    final accuracy = _pct(summary['accuracy']);
    final scorePercent = _scorePercent(summary['score_percent']);
    final hasData = _num(summary['total_questions']) > 0;

    return Container(
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
          Row(
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
                    Icon(_levelIcon(nodeType), size: 13, color: Colors.white.withOpacity(0.85)),
                    const SizedBox(width: 6),
                    Text(
                      _levelLabel(nodeType).toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15),
          ),
          const SizedBox(height: 6),
          Text(
            "Every question tagged anywhere inside this ${_levelLabel(nodeType).toLowerCase()}, rolled up into one view.",
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.65), height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _heroMetric(hasData ? _formatScorePercent(scorePercent) : "--", "Score %")),
              _heroDivider(),
              Expanded(child: _heroMetric(hasData ? _formatPercent(accuracy) : "--", "Accuracy")),
              _heroDivider(),
              Expanded(child: _heroMetric(_num(summary['total_questions']).toInt().toString(), "Questions")),
              _heroDivider(),
              Expanded(child: _heroMetric(_num(summary['attempts']).toInt().toString(), "Attempts")),
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
        ],
      ),
    );
  }

  Widget _heroDivider() => Container(width: 1, height: 34, color: Colors.white.withOpacity(0.12));

  Widget _heroMetric(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 3),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.55), letterSpacing: 0.4),
        ),
      ],
    );
  }

  // ─── Section: Outcome split ─────────────────────────────────────────────

  Widget _buildOutcomeSplit(Map<String, dynamic> summary) {
    final total = _num(summary['total_questions']).toDouble();
    final correct = _num(summary['correct_count']).toDouble();
    final incorrect = _num(summary['incorrect_count']).toDouble();
    final skipped = _num(summary['unattempted_count']).toDouble();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle("Outcome Split", "How every attempted question resolved.")),
              const Icon(Icons.donut_large_rounded, color: AppColors.civic, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 12,
              child: Row(
                children: total == 0
                    ? [Expanded(child: Container(color: AppColors.line))]
                    : [
                        if (correct > 0) Expanded(flex: correct.round(), child: Container(color: AppColors.emerald)),
                        if (incorrect > 0) Expanded(flex: incorrect.round(), child: Container(color: AppColors.berry)),
                        if (skipped > 0) Expanded(flex: skipped.round(), child: Container(color: AppColors.muted.withOpacity(0.4))),
                      ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _outcomeTile("Correct", correct.toInt(), AppColors.emerald, Icons.check_circle_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _outcomeTile("Incorrect", incorrect.toInt(), AppColors.berry, Icons.cancel_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _outcomeTile("Skipped", skipped.toInt(), AppColors.muted, Icons.remove_circle_outline_rounded)),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.line),
          const SizedBox(height: 10),
          Text(
            "Accuracy = Correct ÷ (Correct + Incorrect). Skipped questions don't count against you.",
            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _outcomeTile(String label, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 6),
          Text(value.toString(), style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w700, color: color.withOpacity(0.85), letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }

  // ─── Section: Subcategories (strong / weak / unattempted) ──────────────

  Widget _buildSubcategoriesSection(List<Map<String, dynamic>> children) {
    if (children.isEmpty) return const SizedBox.shrink();

    final attempted = children.where((c) {
      final summary = Map<String, dynamic>.from((c['summary'] as Map?) ?? {});
      return _num(summary['total_questions']).toInt() > 0;
    }).toList();

    final unattempted = children.where((c) {
      final summary = Map<String, dynamic>.from((c['summary'] as Map?) ?? {});
      return _num(summary['total_questions']).toInt() == 0;
    }).toList()
      ..sort((a, b) => _text(a['name']).toLowerCase().compareTo(_text(b['name']).toLowerCase()));

    attempted.sort((a, b) {
      final sumA = Map<String, dynamic>.from((a['summary'] as Map?) ?? {});
      final sumB = Map<String, dynamic>.from((b['summary'] as Map?) ?? {});
      final scoreB = _scorePercent(sumB['score_percent']);
      final scoreA = _scorePercent(sumA['score_percent']);
      if (scoreB != scoreA) return scoreB.compareTo(scoreA);
      return _num(sumB['total_questions']).compareTo(_num(sumA['total_questions']));
    });

    final strong = attempted.where((c) {
      final summary = Map<String, dynamic>.from((c['summary'] as Map?) ?? {});
      return _scorePercent(summary['score_percent']) >= 60;
    }).toList();

    final weak = attempted.where((c) {
      final summary = Map<String, dynamic>.from((c['summary'] as Map?) ?? {});
      return _scorePercent(summary['score_percent']) < 60;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Subcategory Performance", "Drill into any level for its own performance page."),
          const SizedBox(height: 18),
          _buildSubcategoryGroup(
            "Strong areas",
            "Accuracy ≥ 70%",
            strong,
            AppColors.emerald,
            Icons.check_circle_outline_rounded,
          ),
          if (strong.isNotEmpty && weak.isNotEmpty) const SizedBox(height: 22),
          _buildSubcategoryGroup(
            "Needs improvement",
            "Accuracy < 70%",
            weak,
            AppColors.berry,
            Icons.warning_amber_rounded,
          ),
          if ((strong.isNotEmpty || weak.isNotEmpty) && unattempted.isNotEmpty) const SizedBox(height: 22),
          _buildSubcategoryGroup(
            "Not attempted yet",
            "${unattempted.length} node${unattempted.length == 1 ? '' : 's'} with no recorded attempts",
            unattempted,
            AppColors.muted,
            Icons.hourglass_empty_rounded,
            isUnattemptedGroup: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSubcategoryGroup(
    String title,
    String subtitle,
    List<Map<String, dynamic>> items,
    Color headerColor,
    IconData icon, {
    bool isUnattemptedGroup = false,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: headerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: headerColor, size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: headerColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                items.length.toString(),
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: headerColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((child) => _subcategoryCard(child, headerColor, dimmed: isUnattemptedGroup)),
      ],
    );
  }

  Widget _subcategoryCard(Map<String, dynamic> child, Color accentColor, {bool dimmed = false}) {
    final childSummary = Map<String, dynamic>.from((child['summary'] as Map?) ?? {});
    final scorePercent = _scorePercent(childSummary['score_percent']);
    final totalQs = _num(childSummary['total_questions']).toInt();
    final hasData = totalQs > 0;
    final color = dimmed ? AppColors.muted : _scorePercentColor(scorePercent, hasData: hasData);
    final nodeType = _text(child['node_type']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryDetailScreen(
                nodeId: child['id'],
                nodeName: _text(child['name']),
                contentType: widget.contentType,
                initialTabIndex: 1,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: dimmed ? AppColors.paper.withOpacity(0.6) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: dimmed ? AppColors.line : color.withOpacity(0.18)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _text(child['name']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                          ),
                        ),
                        if (nodeType.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.paper,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Text(
                              _levelLabel(nodeType).toUpperCase(),
                              style: GoogleFonts.inter(fontSize: 7.5, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.3),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      hasData ? "$totalQs question${totalQs != 1 ? 's' : ''} attempted" : "No attempts recorded yet",
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppColors.muted),
                    ),
                    if (hasData) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          value: (scorePercent / 100).clamp(0.0, 1.0),
                          backgroundColor: AppColors.line.withOpacity(0.5),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (hasData)
                Text(
                  _formatScorePercent(scorePercent),
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: color),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: AppColors.muted.withOpacity(0.6), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Section: Attempt history ───────────────────────────────────────────

  Widget _buildAttemptHistory(List<Map<String, dynamic>> attempts) {
    final shown = attempts.take(12).toList();
    int bestIdx = -1;
    double bestScore = double.negativeInfinity;
    for (var i = 0; i < shown.length; i++) {
      final score = _scorePercent(shown[i]['score_percent']);
      if (score > bestScore) {
        bestScore = score;
        bestIdx = i;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Attempt History", "This category's marks percentage inside each submitted test."),
          const SizedBox(height: 16),
          if (shown.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.paper.withOpacity(0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  "No attempts recorded for this category yet.",
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            ...shown.asMap().entries.map((entry) {
              final idx = entry.key;
              final attempt = entry.value;
              final scorePercent = _scorePercent(attempt['score_percent']);
              final color = _scorePercentColor(scorePercent);
              final isBest = idx == bestIdx;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isBest) ...[
                          const Icon(Icons.emoji_events_rounded, color: AppColors.saffron, size: 13),
                          const SizedBox(width: 5),
                        ],
                        Expanded(
                          child: Text(
                            _text(attempt['test_title'], 'Test'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
                          ),
                        ),
                        Text(_formatScorePercent(scorePercent), style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value: (scorePercent / 100).clamp(0.0, 1.0),
                        backgroundColor: AppColors.line.withOpacity(0.45),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── Section: Improvement tip ────────────────────────────────────────────

  Widget _buildImprovementTip(Map<String, dynamic> summary) {
    final avgTime = _num(summary['avg_time_seconds']).round();
    final incorrect = _num(summary['incorrect_count']).toInt();
    final skipped = _num(summary['unattempted_count']).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.civic.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.civic.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_rounded, color: AppColors.civic, size: 16),
              const SizedBox(width: 8),
              Text(
                "IMPROVEMENT FOCUS",
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.civic, letterSpacing: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Average time: ${avgTime}s per question.",
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.5),
          ),
          if (incorrect + skipped > 0)
            Text(
              "Re-attempt the $incorrect incorrect and $skipped skipped question${(incorrect + skipped) == 1 ? '' : 's'} here before moving to a harder set.",
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.5),
            )
          else
            Text(
              "Every attempted question here was answered correctly — nice work.",
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.5),
            ),
        ],
      ),
    );
  }

  // ─── Section: Question record ────────────────────────────────────────────

  Widget _buildQuestionRecordHeader(Map<String, dynamic> summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Question Record", "Every question attempted in this category at any level."),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('all', "All (${_num(summary['total_questions']).toInt()})", AppColors.civic),
              _filterChip('correct', "Correct (${_num(summary['correct_count']).toInt()})", AppColors.emerald),
              _filterChip('incorrect', "Incorrect (${_num(summary['incorrect_count']).toInt()})", AppColors.berry),
              _filterChip('unattempted', "Skipped (${_num(summary['unattempted_count']).toInt()})", AppColors.muted),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String value, String label, Color color) {
    final active = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: active,
        onSelected: (_) => setState(() => _filter = value),
        label: Text(label),
        selectedColor: color.withOpacity(0.14),
        backgroundColor: Colors.white,
        labelStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: active ? color : AppColors.muted,
        ),
        side: BorderSide(color: active ? color.withOpacity(0.45) : AppColors.line),
      ),
    );
  }

  Widget _buildEmptyQuestions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, color: AppColors.muted, size: 34),
          const SizedBox(height: 10),
          Text("No questions match this filter.", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question) {
    final outcome = _text(question['outcome'], 'unattempted');
    final color = _outcomeColor(outcome);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 3), top: const BorderSide(color: AppColors.line), right: const BorderSide(color: AppColors.line), bottom: const BorderSide(color: AppColors.line)),
        boxShadow: const [
          BoxShadow(color: Color(0x060F172A), offset: Offset(0, 3), blurRadius: 8),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_outcomeIcon(outcome), color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _text(question['test_title'], 'Test'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.muted),
                ),
              ),
              Text(
                outcome.toUpperCase(),
                style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _text(question['question_statement'], 'Question'),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.35),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniPill("${_num(question['score']).toStringAsFixed(1)} marks", AppColors.civic),
              _miniPill("${_num(question['time_spent_seconds']).toInt()}s", AppColors.saffron),
              if (_text(question['topic_name']).isNotEmpty) _miniPill(_text(question['topic_name']), AppColors.brand),
              if (_text(question['subtopic_name']).isNotEmpty) _miniPill(_text(question['subtopic_name']), AppColors.muted),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Shared bits ──────────────────────────────────────────────────────

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppColors.muted),
        ),
      ],
    );
  }

  Widget _miniPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
