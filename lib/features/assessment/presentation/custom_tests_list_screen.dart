import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/assessment_service.dart';
import '../models/assessment_models.dart';
import 'attempt_engine_screen.dart';
import 'custom_test_create_screen.dart';
import 'custom_test_detail_screen.dart';
import 'self_test_builder_tab.dart';
import 'result_review_screen.dart';

class CustomTestsListScreen extends StatefulWidget {
  final String? contentType;
  const CustomTestsListScreen({super.key, this.contentType});

  @override
  State<CustomTestsListScreen> createState() => _CustomTestsListScreenState();
}

class _CustomTestsListScreenState extends State<CustomTestsListScreen> {
  late AssessmentService _service;
  bool _loading = true;
  String? _error;
  List<AssessmentTestTemplate> _tests = [];
  int? _deletingId;
  int? _startingId;

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = AssessmentService(apiClient: apiClient);
    _fetchCustomTests();
  }

  Future<void> _fetchCustomTests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getUserCustomTests();
      setState(() {
        _tests = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load custom tests: $e";
        _loading = false;
      });
    }
  }

  Future<void> _handleStartAttempt(int templateId) async {
    setState(() {
      _startingId = templateId;
      _error = null;
    });
    try {
      final attemptId = await _service.startAttempt(templateId);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AttemptEngineScreen(attemptId: attemptId),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = "Failed to start test attempt: $e";
        _startingId = null;
      });
    }
  }

  Future<void> _handleDeleteTest(int templateId) async {
    final bool confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              "Delete Custom Test",
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
            content: const Text("Are you sure you want to delete this custom test template?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text("Cancel", style: GoogleFonts.inter(color: AppColors.muted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text("Delete", style: GoogleFonts.inter(color: AppColors.berry, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() {
      _deletingId = templateId;
      _error = null;
    });

    try {
      await _service.deleteTestTemplate(templateId);
      setState(() {
        _tests.removeWhere((t) => t.id == templateId);
      });
    } catch (e) {
      setState(() {
        _error = "Failed to delete test template: $e";
      });
    } finally {
      setState(() {
        _deletingId = null;
      });
    }
  }

  void _showCreateTestDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Create Custom Test",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: "Test Title (e.g. Modern History Mock)",
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                hintText: "Description (Optional)",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.inter(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(context);

              setState(() {
                _loading = true;
              });

              try {
                int examLevelId = 7;
                String testType = 'sectional_test';
                if (widget.contentType == 'aptitude') {
                  examLevelId = 1;
                } else if (widget.contentType == 'mains') {
                  examLevelId = 3;
                  testType = 'mains_test';
                }

                final templateId = await _service.createUserCustomTest(
                  title: title,
                  description: descController.text.trim(),
                  examId: 1,
                  examLevelId: examLevelId,
                  testType: testType,
                  questionIds: [],
                );

                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CustomTestDetailScreen(
                        testTemplateId: templateId,
                        contentType: widget.contentType,
                      ),
                    ),
                  ).then((_) => _fetchCustomTests());
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to create test: $e")),
                  );
                }
              } finally {
                _fetchCustomTests();
              }
            },
            child: Text("Create", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.civic)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(
          "My Custom Tests",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppColors.berry.withOpacity(0.1),
              child: Text(
                _error!,
                style: GoogleFonts.inter(
                  color: AppColors.berry,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.civic.withOpacity(0.1),
                  child: const Icon(Icons.add_task_rounded, color: AppColors.civic),
                ),
                title: Text(
                  "Create custom test template",
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: Text(
                  "Build a test template with name and description",
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
                onTap: _showCreateTestDialog,
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.civic))
                : _tests.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tests.length,
                        itemBuilder: (context, index) {
                          final test = _tests[index];
                          return _buildTestCard(test);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTestDialog,
        backgroundColor: AppColors.civic,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_outlined, size: 64, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(
              "No Custom Tests Created",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Create a tailored practice exam by combining specific syllabus categories and question counts.",
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CustomTestCreateScreen(
                      contentType: widget.contentType,
                    ),
                  ),
                );
                _fetchCustomTests();
              },
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text("Build Test"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.civic,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCard(AssessmentTestTemplate test) {
    final bool isMains = test.testType == "mains_test";
    final String typeLabel = isMains
        ? "Mains"
        : test.title.toLowerCase().contains("csat") || test.title.toLowerCase().contains("aptitude")
            ? "CSAT"
            : "GS";

    final Color badgeBg = typeLabel == "Mains"
        ? AppColors.berry.withOpacity(0.08)
        : typeLabel == "CSAT"
            ? AppColors.saffron.withOpacity(0.08)
            : AppColors.civic.withOpacity(0.08);

    final Color badgeText = typeLabel == "Mains"
        ? AppColors.berry
        : typeLabel == "CSAT"
            ? AppColors.saffron
            : AppColors.civic;

    final bool hasAttempt = test.latestAttemptStatus != null;
    final bool isCompleted = test.latestAttemptStatus == "submitted" || test.latestAttemptStatus == "completed";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomTestDetailScreen(
                testTemplateId: test.id,
                contentType: widget.contentType,
              ),
            ),
          ).then((_) => _fetchCustomTests());
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "$typeLabel Test",
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeText,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted ? AppColors.emerald.withOpacity(0.1) :
                             hasAttempt ? AppColors.saffron.withOpacity(0.1) :
                             AppColors.muted.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isCompleted ? "COMPLETED" : hasAttempt ? "IN PROGRESS" : "NOT STARTED",
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? AppColors.emerald : hasAttempt ? AppColors.saffron : AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                test.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildStatBadge(Icons.layers_outlined, "${test.questionCount ?? 0} Qs"),
                  const SizedBox(width: 12),
                  _buildStatBadge(Icons.timer_outlined, "${test.durationMinutes} Min"),
                  const SizedBox(width: 12),
                  _buildStatBadge(Icons.emoji_events_outlined, "${test.totalMarks.round()} Marks"),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.line, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!hasAttempt) ...[
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: OutlinedButton.icon(
                          onPressed: () {
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
                            ).then((_) => _fetchCustomTests());
                          },
                          icon: const Icon(Icons.add_circle_outline, size: 16),
                          label: Text(
                            "Add Qs",
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.civic,
                            side: const BorderSide(color: AppColors.civic),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: ElevatedButton.icon(
                        onPressed: _startingId == test.id
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
                                  ).then((_) => _fetchCustomTests());
                                } else {
                                  _handleStartAttempt(test.id);
                                }
                              },
                        icon: _startingId == test.id
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(
                                isCompleted ? Icons.emoji_events_outlined :
                                hasAttempt ? Icons.play_arrow_rounded : Icons.rocket_launch_outlined,
                                size: 16,
                              ),
                        label: Text(
                          isCompleted ? "Result" : hasAttempt ? "Resume" : "Start",
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.ink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 38,
                    width: 44,
                    child: OutlinedButton(
                      onPressed: _deletingId == test.id ? null : () => _handleDeleteTest(test.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.berry,
                        side: const BorderSide(color: AppColors.line),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.zero,
                      ),
                      child: _deletingId == test.id
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.berry))
                          : const Icon(Icons.delete_outline_rounded, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.muted),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.ink.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
