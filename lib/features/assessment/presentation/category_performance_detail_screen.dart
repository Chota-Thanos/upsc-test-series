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

  String _formatPercent(dynamic value) {
    final n = _num(value).toDouble();
    return "${(n <= 1 ? n * 100 : n).round()}%";
  }

  Color _accuracyColor(dynamic value) {
    final n = _num(value).toDouble();
    final pct = n <= 1 ? n : n / 100;
    if (pct >= 0.7) return AppColors.emerald;
    if (pct >= 0.4) return AppColors.saffron;
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

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Category Performance",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 16),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.civic,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHero(title, category, summary),
            const SizedBox(height: 16),
            _buildOutcomeBars(summary),
            const SizedBox(height: 18),
            _buildAttemptBars(attempts),
            const SizedBox(height: 18),
            _buildSubcategoriesSection(children),
            const SizedBox(height: 18),
            _buildQuestionFilters(summary),
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

  Widget _cardTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.muted,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildHero(String title, Map<String, dynamic> category, Map<String, dynamic> summary) {
    final accuracy = _num(summary['accuracy']).toDouble();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.civic.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.civic.withOpacity(0.18)),
                ),
                child: const Icon(Icons.auto_graph_rounded, color: AppColors.civic, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _text(category['node_type'], 'category').replaceAll('_', ' ').toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _heroMetric("Accuracy", _formatPercent(accuracy))),
              Container(width: 1, height: 42, color: AppColors.line),
              Expanded(child: _heroMetric("Score", _num(summary['score']).toDouble().toStringAsFixed(1))),
              Container(width: 1, height: 42, color: AppColors.line),
              Expanded(child: _heroMetric("Questions", _num(summary['total_questions']).toInt().toString())),
              Container(width: 1, height: 42, color: AppColors.line),
              Expanded(child: _heroMetric("Attempts", _num(summary['attempts']).toInt().toString())),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: accuracy.clamp(0.0, 1.0).toDouble(),
              backgroundColor: AppColors.line.withOpacity(0.4),
              valueColor: AlwaysStoppedAnimation<Color>(_accuracyColor(accuracy)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildOutcomeBars(Map<String, dynamic> summary) {
    final total = _num(summary['total_questions']).toDouble();
    final correct = _num(summary['correct_count']).toDouble();
    final incorrect = _num(summary['incorrect_count']).toDouble();
    final skipped = _num(summary['unattempted_count']).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle("Outcome Split"),
          const SizedBox(height: 12),
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
                        if (skipped > 0) Expanded(flex: skipped.round(), child: Container(color: AppColors.muted.withOpacity(0.45))),
                      ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _legend("Correct", correct.toInt(), AppColors.emerald),
              _legend("Incorrect", incorrect.toInt(), AppColors.berry),
              _legend("Skipped", skipped.toInt(), AppColors.muted),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.line, height: 1),
          const SizedBox(height: 10),
          Text(
            "* Accuracy is calculated as: (Correct / (Correct + Incorrect)) * 100%. Skipped (unattempted) questions are excluded from the calculation.",
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text("$value $label", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildAttemptBars(List<Map<String, dynamic>> attempts) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle("Attempt History"),
          const SizedBox(height: 4),
          Text("Each bar is this category's accuracy inside one submitted test.", style: GoogleFonts.inter(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),
          if (attempts.isEmpty)
            Text("No attempts found for this category.", style: GoogleFonts.inter(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w500))
          else
            ...attempts.take(12).map((attempt) {
              final accuracy = _num(attempt['accuracy']).toDouble();
              final color = _accuracyColor(accuracy);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _text(attempt['test_title'], 'Test'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink),
                          ),
                        ),
                        Text(_formatPercent(accuracy), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value: accuracy.clamp(0.0, 1.0).toDouble(),
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

  Widget _buildSubcategoriesSection(List<Map<String, dynamic>> children) {
    if (children.isEmpty) return const SizedBox.shrink();

    // Separate children by performance
    final attempted = children.where((c) {
      final summary = Map<String, dynamic>.from((c['summary'] as Map?) ?? {});
      return _num(summary['total_questions']).toInt() > 0;
    }).toList();

    if (attempted.isEmpty) return const SizedBox.shrink();

    // Sort attempted by accuracy descending
    attempted.sort((a, b) {
      final sumA = Map<String, dynamic>.from((a['summary'] as Map?) ?? {});
      final sumB = Map<String, dynamic>.from((b['summary'] as Map?) ?? {});
      final accA = _num(sumA['accuracy']).toDouble();
      final accB = _num(sumB['accuracy']).toDouble();
      if (accB != accA) {
        return accB.compareTo(accA);
      }
      final qA = _num(sumA['total_questions']).toInt();
      final qB = _num(sumB['total_questions']).toInt();
      return qB.compareTo(qA);
    });

    final strong = attempted.where((c) {
      final summary = Map<String, dynamic>.from((c['summary'] as Map?) ?? {});
      return _num(summary['accuracy']).toDouble() >= 0.7;
    }).toList();

    final weak = attempted.where((c) {
      final summary = Map<String, dynamic>.from((c['summary'] as Map?) ?? {});
      return _num(summary['accuracy']).toDouble() < 0.7;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle("Subcategory Performance"),
          const SizedBox(height: 4),
          Text(
            "Drill down to review performance across nested topics.",
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          _buildSubcategoryGroup("Strong Areas (Accuracy \u2265 70%)", strong, AppColors.emerald, Icons.check_circle_outline_rounded),
          if (strong.isNotEmpty && weak.isNotEmpty) const SizedBox(height: 20),
          _buildSubcategoryGroup("Weak Areas / Needs Improvement (Accuracy < 70%)", weak, AppColors.berry, Icons.warning_amber_rounded),
        ],
      ),
    );
  }

  Widget _buildSubcategoryGroup(String title, List<Map<String, dynamic>> items, Color headerColor, IconData icon) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: headerColor, size: 16),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 20, color: AppColors.line),
          itemBuilder: (context, index) {
            final child = items[index];
            final childSummary = Map<String, dynamic>.from((child['summary'] as Map?) ?? {});
            final accuracy = _num(childSummary['accuracy']).toDouble();
            final totalQs = _num(childSummary['total_questions']).toInt();
            final color = _accuracyColor(accuracy);

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryDetailScreen(
                      nodeId: child['id'],
                      nodeName: child['name'],
                      contentType: widget.contentType,
                    ),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _text(child['name']),
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "$totalQs question${totalQs != 1 ? 's' : ''} attempted",
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatPercent(accuracy),
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      value: accuracy.clamp(0.0, 1.0).toDouble(),
                      backgroundColor: AppColors.line.withOpacity(0.4),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
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

  Widget _buildQuestionFilters(Map<String, dynamic> summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Attempted Questions"),
        const SizedBox(height: 4),
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
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration,
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
