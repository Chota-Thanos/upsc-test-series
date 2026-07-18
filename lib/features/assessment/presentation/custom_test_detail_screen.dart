import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/assessment_service.dart';
import '../models/assessment_models.dart';
import 'attempt_engine_screen.dart';
import 'result_review_screen.dart';
import 'self_test_builder_tab.dart';

class CustomTestDetailScreen extends StatefulWidget {
  final int testTemplateId;
  final String? contentType;

  const CustomTestDetailScreen({
    super.key,
    required this.testTemplateId,
    this.contentType,
  });

  @override
  State<CustomTestDetailScreen> createState() => _CustomTestDetailScreenState();
}

class _CustomTestDetailScreenState extends State<CustomTestDetailScreen> {
  late AssessmentService _service;
  bool _loading = true;
  String? _error;
  AssessmentTestTemplate? _template;
  Map<String, dynamic>? _paperDetails;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = AssessmentService(apiClient: apiClient);
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final template = await _service.getTestTemplate(widget.testTemplateId);
      final paper = await _service.getAssessmentTestPaper(widget.testTemplateId);
      setState(() {
        _template = template;
        _paperDetails = paper;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load test details: $e";
        _loading = false;
      });
    }
  }

  Future<void> _handleStartAttempt() async {
    if (_template == null) return;
    setState(() {
      _actionLoading = true;
    });
    try {
      final attemptId = await _service.startAttempt(_template!.id);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AttemptEngineScreen(attemptId: attemptId),
          ),
        ).then((_) => _fetchDetails());
      }
    } catch (e) {
      setState(() {
        _error = "Failed to start test attempt: $e";
      });
    } finally {
      setState(() {
        _actionLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.civic)),
      );
    }

    if (_error != null && _template == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Test Details")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.berry, size: 48),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _fetchDetails, child: const Text("Retry")),
              ],
            ),
          ),
        ),
      );
    }

    final test = _template!;
    final bool hasAttempt = test.latestAttemptStatus != null;
    final bool isCompleted = test.latestAttemptStatus == "submitted" || test.latestAttemptStatus == "completed";

    // Extract categories count
    final List<dynamic> sections = _paperDetails?['sections'] ?? [];
    final List<dynamic> questions = sections.isNotEmpty ? (sections[0]['questions'] ?? []) : [];

    // Group by taxonomy labels
    final Map<String, int> categoryBreakdown = {};
    for (var q in questions) {
      final tax = q['taxonomy'] ?? {};
      final String subject = tax['subject_name'] ?? 'General';
      categoryBreakdown[subject] = (categoryBreakdown[subject] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text("Test Detailed View", style: AppTypography.title.copyWith(fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(test.title, style: AppTypography.title.copyWith(fontSize: 20)),
                  if (test.description != null && test.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(test.description!, style: AppTypography.body.copyWith(fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem("Questions", "${test.questionCount ?? questions.length}"),
                      _buildSummaryItem("Total Marks", "${test.totalMarks.round()}"),
                      _buildSummaryItem("Duration", "${test.durationMinutes} min"),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Category breakdown
            Text(
              "Category Breakdown",
              style: AppTypography.sectionHeader.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 12),
            if (categoryBreakdown.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  "No categories added yet. Click 'Add Questions' below to add topics.",
                  style: AppTypography.body.copyWith(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: categoryBreakdown.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
                  itemBuilder: (context, idx) {
                    final key = categoryBreakdown.keys.elementAt(idx);
                    final val = categoryBreakdown[key];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              key,
                              style: AppTypography.cardTitle.copyWith(fontSize: 13),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.civic.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "$val Questions",
                              style: AppTypography.eyebrowLarge.copyWith(fontSize: 11, letterSpacing: 0),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),

            // Question list
            Text(
              "Questions List (${test.questionCount ?? questions.length})",
              style: AppTypography.sectionHeader.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 12),
            if (questions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.help_outline, color: AppColors.muted, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      "This test template is empty.",
                      style: AppTypography.cardTitle.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Add questions from the syllabus categories to start attempting.",
                      style: AppTypography.caption,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: questions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final q = questions[idx];
                  final String qText = q['question_text'] ?? '';
                  final String cleanText = qText.replaceAll(RegExp(r'<[^>]*>'), '');
                  final String difficulty = q['difficulty'] ?? 'Medium';
                  final double marks = double.tryParse(q['marks']?.toString() ?? '1') ?? 1.0;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Question ${idx + 1}",
                              style: AppTypography.caption.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.paper,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "$difficulty • ${marks.round()} Marks",
                                style: AppTypography.eyebrowSmall.copyWith(color: AppColors.ink.withOpacity(0.6), letterSpacing: 0),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cleanText,
                          style: AppTypography.body.copyWith(fontSize: 13, color: AppColors.ink, height: 1.4),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 80), // spacer for bottom action bar
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.line)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -4))
          ],
        ),
        child: Row(
          children: [
            if (!hasAttempt) ...[
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Navigate to self test builder tab in "Direct Add" mode!
                      // For simplicity, we can navigate to a container or tab selector,
                      // or open a screen that filters SelfTestBuilderTab with a parameter testTemplateId.
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(
                              title: const Text("Select Category to Add"),
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.ink,
                              elevation: 0,
                            ),
                            body: SelfTestBuilderTab(
                              testTemplateId: test.id,
                              contentType: widget.contentType,
                            ),
                          ),
                        ),
                      ).then((_) => _fetchDetails());
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text("Add Questions"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.civic,
                      side: const BorderSide(color: AppColors.civic),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _actionLoading || (questions.isEmpty && !hasAttempt)
                      ? null
                      : () {
                          if (isCompleted && test.latestResultId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ResultReviewScreen(resultId: test.latestResultId!),
                              ),
                            );
                          } else if (hasAttempt && test.latestAttemptId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AttemptEngineScreen(attemptId: test.latestAttemptId!),
                              ),
                            ).then((_) => _fetchDetails());
                          } else {
                            _handleStartAttempt();
                          }
                        },
                  icon: _actionLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(
                          isCompleted ? Icons.emoji_events_outlined :
                          hasAttempt ? Icons.play_arrow_rounded : Icons.rocket_launch_outlined,
                          size: 18,
                        ),
                  label: Text(
                    isCompleted ? "View Result" :
                    hasAttempt ? "Resume Test" : "Start Test",
                    style: AppTypography.button.copyWith(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.civic,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTypography.statValue.copyWith(fontSize: 16, color: AppColors.civic)),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}
