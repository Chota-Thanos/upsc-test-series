import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/study_plan_service.dart';
import 'study_plan_list_screen.dart';

enum _SPResultTab { summary, questions, topics, time }

enum _SPQuestionFilter { all, correct, incorrect, unattempted }

class StudyPlanResultScreen extends StatefulWidget {
  final int resultId;
  const StudyPlanResultScreen({super.key, required this.resultId});

  @override
  State<StudyPlanResultScreen> createState() => _StudyPlanResultScreenState();
}

class _StudyPlanResultScreenState extends State<StudyPlanResultScreen> {
  late StudyPlanService _service;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _review;

  _SPResultTab _activeTab = _SPResultTab.summary;
  _SPQuestionFilter _qFilter = _SPQuestionFilter.all;

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = StudyPlanService(apiClient: apiClient);
    _loadResult();
  }

  Future<void> _loadResult() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getStudyPlanResultReview(widget.resultId);
      setState(() {
        _review = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _optionKey(dynamic option, int index) {
    if (option is Map) {
      final key =
          option['id'] ?? option['key'] ?? option['value'] ?? option['label'];
      if (key != null) return key.toString();
    }
    return String.fromCharCode(65 + index);
  }

  String _optionText(dynamic option, int index) {
    if (option is Map) {
      final text =
          option['text'] ??
          option['label'] ??
          option['value'] ??
          option['statement'];
      if (text != null) return text.toString();
    }
    if (option != null) return option.toString();
    return "Option ${String.fromCharCode(65 + index)}";
  }

  String? _selectedKey(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      final k = value['id'] ?? value['key'] ?? value['value'] ?? value['label'];
      return k?.toString();
    }
    return value.toString();
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
        appBar: AppBar(title: const Text("Error")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.berry,
                  size: 44,
                ),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadResult,
                  child: const Text("RETRY"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final review = _review!;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(
          "Study Plan Result",
          style: AppTypography.title.copyWith(fontSize: 18),
        ),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.ink,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _tabChip(
                    _SPResultTab.summary,
                    Icons.emoji_events_rounded,
                    "Summary",
                  ),
                  const SizedBox(width: 8),
                  _tabChip(
                    _SPResultTab.questions,
                    Icons.checklist_rounded,
                    "Questions (${(review['questions'] as List? ?? []).length})",
                  ),
                  const SizedBox(width: 8),
                  _tabChip(
                    _SPResultTab.topics,
                    Icons.track_changes_rounded,
                    "Topics",
                  ),
                  const SizedBox(width: 8),
                  _tabChip(
                    _SPResultTab.time,
                    Icons.timer_outlined,
                    "Time Analysis",
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadResult,
              color: AppColors.civic,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: _buildContent(review),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(_SPResultTab tab, IconData icon, String label) {
    final isActive = _activeTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.ink : AppColors.line,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : AppColors.muted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.button.copyWith(
                fontSize: 12,
                color: isActive ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> review) {
    switch (_activeTab) {
      case _SPResultTab.summary:
        return _buildSummary(review);
      case _SPResultTab.questions:
        return _buildQuestions(review);
      case _SPResultTab.topics:
        return _buildTopics(review);
      case _SPResultTab.time:
        return _buildTime(review);
    }
  }

  // ─── Summary ──────────────────────────────────────────────────────────────

  Widget _buildSummary(Map<String, dynamic> review) {
    final score = double.tryParse(review['score']?.toString() ?? '0') ?? 0;
    final maxScore =
        double.tryParse(review['max_score']?.toString() ?? '0') ?? 0;
    final accuracy =
        double.tryParse(review['accuracy']?.toString() ?? '0') ?? 0;
    final correctCount = review['correct_count'] as int? ?? 0;
    final incorrectCount = review['incorrect_count'] as int? ?? 0;
    final unattemptedCount = review['unattempted_count'] as int? ?? 0;
    final negativeMarks =
        double.tryParse(review['negative_marks']?.toString() ?? '0') ?? 0;
    final pct = maxScore > 0 ? (score / maxScore * 100).clamp(0.0, 100.0) : 0.0;

    final testTemplate = review['test_template'] as Map<String, dynamic>? ?? {};
    final testTitle = testTemplate['title']?.toString() ?? 'Study Plan Test';
    final testType = testTemplate['test_type']?.toString() ?? '';

    final topicBreakdowns = (review['topic_breakdowns'] as List? ?? [])
        .map((t) => t as Map<String, dynamic>)
        .toList();
    final weakTopics = topicBreakdowns.where((t) {
      final acc = double.tryParse(t['accuracy']?.toString() ?? '0') ?? 0;
      return acc < 0.6;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Score card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.cardDecoration,
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 500;
                  if (isNarrow) {
                    return Column(
                      children: [
                        _SPScoreGauge(percentage: pct),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            _statBox(
                              "🎯",
                              "Score",
                              "${score.toStringAsFixed(1)}/$maxScore",
                            ),
                            _statBox(
                              "📊",
                              "Accuracy",
                              "${(accuracy <= 1 ? accuracy * 100 : accuracy).round()}%",
                            ),
                            _statBox("✅", "Correct", "$correctCount"),
                            _statBox("❌", "Incorrect", "$incorrectCount"),
                            _statBox("⬜", "Skipped", "$unattemptedCount"),
                            _statBox(
                              "⚠️",
                              "Negative",
                              "-${negativeMarks.toStringAsFixed(2)}",
                            ),
                          ],
                        ),
                      ],
                    );
                  } else {
                    return Row(
                      children: [
                        _SPScoreGauge(percentage: pct),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _statBox(
                                "🎯",
                                "Score",
                                "${score.toStringAsFixed(1)}/$maxScore",
                              ),
                              _statBox(
                                "📊",
                                "Accuracy",
                                "${(accuracy <= 1 ? accuracy * 100 : accuracy).round()}%",
                              ),
                              _statBox("✅", "Correct", "$correctCount"),
                              _statBox("❌", "Incorrect", "$incorrectCount"),
                              _statBox("⬜", "Skipped", "$unattemptedCount"),
                              _statBox(
                                "⚠️",
                                "Negative",
                                "-${negativeMarks.toStringAsFixed(2)}",
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Test title badge
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.civic.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                testType.replaceAll('_', ' ').toUpperCase(),
                style: AppTypography.eyebrowSmall.copyWith(
                  color: AppColors.civic,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                testTitle,
                style: AppTypography.cardTitle.copyWith(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (weakTopics.isNotEmpty) ...[
          Text(
            "Priority Revision Areas",
            style: AppTypography.sectionHeader.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 12),
          ...weakTopics.take(4).map((t) {
            final name =
                t['taxonomy_name']?.toString() ??
                t['question_nature_name']?.toString() ??
                'General';
            final acc = double.tryParse(t['accuracy']?.toString() ?? '0') ?? 0;
            final total = t['total_questions'] as int? ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.berry.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.berry.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Text("🔴", style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: AppTypography.cardTitle.copyWith(fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${(acc <= 1 ? acc * 100 : acc).round()}% accuracy · $total questions",
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
        ],

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () =>
                    setState(() => _activeTab = _SPResultTab.questions),
                child: const Text("REVIEW QUESTIONS"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StudyPlanListScreen(),
                    ),
                  );
                },
                child: const Text("STUDY PLANS"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statBox(String emoji, String label, String value) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.statValue),
          Text(
            label,
            style: AppTypography.eyebrowSmall.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Questions ─────────────────────────────────────────────────────────────

  Widget _buildQuestions(Map<String, dynamic> review) {
    final questions = (review['questions'] as List? ?? [])
        .map((q) => q as Map<String, dynamic>)
        .toList();
    final correctCount = review['correct_count'] as int? ?? 0;
    final incorrectCount = review['incorrect_count'] as int? ?? 0;
    final unattemptedCount = review['unattempted_count'] as int? ?? 0;

    final filtered = questions.where((q) {
      final outcome = q['score_item']?['outcome'] as String?;
      switch (_qFilter) {
        case _SPQuestionFilter.all:
          return true;
        case _SPQuestionFilter.correct:
          return outcome == 'correct';
        case _SPQuestionFilter.incorrect:
          return outcome == 'incorrect';
        case _SPQuestionFilter.unattempted:
          return outcome == null || outcome == 'unattempted';
      }
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip(_SPQuestionFilter.all, "All (${questions.length})"),
              const SizedBox(width: 8),
              _filterChip(
                _SPQuestionFilter.correct,
                "Correct ($correctCount)",
                color: AppColors.emerald,
              ),
              const SizedBox(width: 8),
              _filterChip(
                _SPQuestionFilter.incorrect,
                "Incorrect ($incorrectCount)",
                color: AppColors.berry,
              ),
              const SizedBox(width: 8),
              _filterChip(
                _SPQuestionFilter.unattempted,
                "Skipped ($unattemptedCount)",
                color: AppColors.muted,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        ...questions.asMap().entries.map((entry) {
          final idx = entry.key;
          final q = entry.value;
          final outcome = q['score_item']?['outcome'] as String?;
          final show =
              _qFilter == _SPQuestionFilter.all ||
              (_qFilter == _SPQuestionFilter.correct && outcome == 'correct') ||
              (_qFilter == _SPQuestionFilter.incorrect &&
                  outcome == 'incorrect') ||
              (_qFilter == _SPQuestionFilter.unattempted &&
                  (outcome == null || outcome == 'unattempted'));
          if (!show) return const SizedBox.shrink();
          return _buildQuestionCard(q, idx);
        }),
      ],
    );
  }

  Widget _filterChip(
    _SPQuestionFilter filter,
    String label, {
    Color? color,
  }) {
    final chipColor = color ?? AppColors.ink;
    final isActive = _qFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _qFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? chipColor :Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? chipColor :AppColors.line,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.button.copyWith(
            fontSize: 12,
            color: isActive ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> q, int index) {
    final outcome = q['score_item']?['outcome'] as String? ?? 'unattempted';
    final userSelected = _selectedKey(
      q['score_item']?['selected_answer'] ?? q['response']?['selected_answer'],
    );
    final correctAns = _selectedKey(
      q['score_item']?['correct_answer'] ?? q['correct_answer'],
    );
    final timeSpent =
        (q['score_item']?['time_spent_seconds'] as num?)?.toInt() ??
        (q['response']?['time_spent_seconds'] as num?)?.toInt() ??
        0;
    final score = q['score_item']?['score'];
    final statement = q['question_statement']?.toString() ?? '';
    final explanation = q['explanation']?.toString();
    final options = q['options'] as List? ?? [];
    final prompt = q['question_prompt']?.toString();
    final supplementary = q['supplementary_statement']?.toString();

    Color outcomeColor;
    String outcomeLabel;
    switch (outcome) {
      case 'correct':
        outcomeColor = AppColors.emerald;
        outcomeLabel = "✓ Correct";
        break;
      case 'incorrect':
        outcomeColor = AppColors.berry;
        outcomeLabel = "✗ Incorrect";
        break;
      default:
        outcomeColor = AppColors.muted;
        outcomeLabel = "— Unattempted";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: outcomeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: outcomeColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    outcomeLabel,
                    style: AppTypography.eyebrowSmall.copyWith(
                      fontSize: 10,
                      color: outcomeColor,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Q${index + 1}",
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (timeSpent > 0) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.timer_outlined,
                    size: 12,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    "${timeSpent}s",
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const Spacer(),
                if (score != null)
                  Text(
                    "${double.tryParse(score.toString())?.toStringAsFixed(2) ?? score} pts",
                    style: AppTypography.eyebrowLarge.copyWith(
                      fontSize: 11,
                      color: AppColors.ink,
                      letterSpacing: 0,
                    ),
                  ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MarkdownBody(
                  data: statement,
                  styleSheet: MarkdownStyleSheet(
                    p: AppTypography.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      height: 1.45,
                    ),
                  ),
                ),
                if (supplementary != null &&
                    supplementary.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      supplementary,
                      style: AppTypography.body.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                if (prompt != null && prompt.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    prompt,
                    style: AppTypography.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Options
                ...options.asMap().entries.map((e) {
                  final key = _optionKey(e.value, e.key);
                  final text = _optionText(e.value, e.key);
                  final isSelected = userSelected == key;
                  final isCorrect = correctAns == key;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? AppColors.emerald.withOpacity(0.05)
                          : isSelected
                          ? AppColors.berry.withOpacity(0.05)
                          : Colors.white,
                      border: Border.all(
                        color: isCorrect
                            ? AppColors.emerald
                            : isSelected
                            ? AppColors.berry
                            : AppColors.line,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 24,
                          width: 24,
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? AppColors.emerald
                                : isSelected
                                ? AppColors.berry
                                : AppColors.paper,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              key,
                              style: AppTypography.eyebrowSmall.copyWith(
                                fontSize: 10,
                                color: (isCorrect || isSelected)
                                    ? Colors.white
                                    : AppColors.ink,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 3.0),
                            child: Text(
                              text,
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                        if (isCorrect)
                          const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Icon(
                              Icons.check_rounded,
                              color: AppColors.emerald,
                              size: 16,
                            ),
                          )
                        else if (isSelected)
                          const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Icon(
                              Icons.close_rounded,
                              color: AppColors.berry,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  );
                }),

                if (explanation != null && explanation.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.civic.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.civic.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 14,
                              color: AppColors.civic,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "EXPLANATION",
                              style: AppTypography.eyebrowSmall.copyWith(
                                color: AppColors.civic,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        MarkdownBody(
                          data: explanation,
                          styleSheet: MarkdownStyleSheet(
                            p: AppTypography.body.copyWith(height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Topics ────────────────────────────────────────────────────────────────

  Widget _buildTopics(Map<String, dynamic> review) {
    final breakdowns =
        (review['topic_breakdowns'] as List? ?? [])
            .map((t) => t as Map<String, dynamic>)
            .toList()
          ..sort((a, b) {
            final aAcc = double.tryParse(a['accuracy']?.toString() ?? '0') ?? 0;
            final bAcc = double.tryParse(b['accuracy']?.toString() ?? '0') ?? 0;
            return aAcc.compareTo(bAcc);
          });

    if (breakdowns.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            "No topic breakdowns available.",
            style: AppTypography.body,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Topic Performance Heatmap",
          style: AppTypography.sectionHeader.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          "Sorted weakest to strongest",
          style: AppTypography.caption.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...breakdowns.map((t) {
          final name =
              t['taxonomy_name']?.toString() ??
              t['question_nature_name']?.toString() ??
              'General';
          final acc = double.tryParse(t['accuracy']?.toString() ?? '0') ?? 0;
          final pct = (acc <= 1 ? acc * 100 : acc).clamp(0.0, 100.0);
          final correct = t['correct_count'] as int? ?? 0;
          final total = t['total_questions'] as int? ?? 0;
          final avgTime =
              double.tryParse(t['avg_time_seconds']?.toString() ?? '0') ?? 0;
          final barColor = pct < 50
              ? AppColors.berry
              : (pct < 70 ? AppColors.saffron : AppColors.emerald);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: AppTypography.cardTitle.copyWith(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: barColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "${pct.round()}% Acc",
                        style: AppTypography.eyebrowLarge.copyWith(
                          fontSize: 11,
                          color: barColor,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 6,
                    backgroundColor: AppColors.line,
                    valueColor: AlwaysStoppedAnimation(barColor),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "$correct/$total Correct  ·  Avg ${avgTime.round()}s/question",
                  style: AppTypography.caption,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ─── Time ──────────────────────────────────────────────────────────────────

  Widget _buildTime(Map<String, dynamic> review) {
    final questions = (review['questions'] as List? ?? [])
        .map((q) => q as Map<String, dynamic>)
        .toList();
    final durationMinutes =
        (review['test_template']?['duration_minutes'] as int?) ?? 60;

    final totalTime = questions.fold<int>(0, (sum, q) {
      return sum +
          ((q['score_item']?['time_spent_seconds'] as num?)?.toInt() ??
              (q['response']?['time_spent_seconds'] as num?)?.toInt() ??
              0);
    });
    final avgTime = questions.isNotEmpty ? totalTime / questions.length : 0;
    final maxTime = questions
        .map((q) {
          return (q['score_item']?['time_spent_seconds'] as num?)?.toInt() ??
              (q['response']?['time_spent_seconds'] as num?)?.toInt() ??
              0;
        })
        .fold<int>(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Time Analysis",
          style: AppTypography.sectionHeader.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _timeCard(
                "Duration",
                "$durationMinutes min",
                Icons.timer_outlined,
                AppColors.civic,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _timeCard(
                "Spent",
                "${(totalTime / 60).toStringAsFixed(1)} min",
                Icons.timer,
                AppColors.saffron,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _timeCard(
                "Avg/Q",
                "${avgTime.toStringAsFixed(0)}s",
                Icons.speed_rounded,
                AppColors.brand,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          "Per-Question Time",
          style: AppTypography.sectionHeader.copyWith(fontSize: 13),
        ),
        const SizedBox(height: 12),
        ...questions.asMap().entries.map((entry) {
          final idx = entry.key;
          final q = entry.value;
          final timeSpent =
              (q['score_item']?['time_spent_seconds'] as num?)?.toInt() ??
              (q['response']?['time_spent_seconds'] as num?)?.toInt() ??
              0;
          final outcome = q['score_item']?['outcome'] as String?;
          final barPct = maxTime > 0
              ? (timeSpent / maxTime).clamp(0.0, 1.0)
              : 0.0;
          Color barColor = AppColors.muted;
          if (outcome == 'correct') barColor = AppColors.emerald;
          if (outcome == 'incorrect') barColor = AppColors.berry;

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    "Q${idx + 1}",
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.line.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: barPct,
                        child: Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: barColor.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 32,
                  child: Text(
                    "${timeSpent}s",
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _timeCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: AppTypography.statValue.copyWith(fontSize: 14)),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Score Gauge ─────────────────────────────────────────────────────────────

class _SPScoreGauge extends StatelessWidget {
  final double percentage;
  const _SPScoreGauge({required this.percentage});

  @override
  Widget build(BuildContext context) {
    final color = percentage >= 70
        ? AppColors.emerald
        : percentage >= 40
        ? AppColors.saffron
        : AppColors.berry;
    return SizedBox(
      height: 100,
      width: 100,
      child: CustomPaint(
        painter: _SPGaugePainter(
          percentage: percentage.clamp(0.0, 100.0),
          color: color,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "${percentage.round()}%",
                style: AppTypography.statValue.copyWith(fontSize: 20),
              ),
              Text(
                "score",
                style: AppTypography.caption.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SPGaugePainter extends CustomPainter {
  final double percentage;
  final Color color;
  _SPGaugePainter({required this.percentage, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 14) / 2;
    final trackPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;
    canvas.drawCircle(center, radius, trackPaint);
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * (percentage / 100),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_SPGaugePainter old) =>
      old.percentage != percentage || old.color != color;
}
