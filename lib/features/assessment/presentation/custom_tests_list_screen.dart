import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/tour/app_tour_service.dart';
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

  // Tour
  final GlobalKey _tourCreateTileKey = GlobalKey();
  bool _tourChecked = false;

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
        _tests = (data as dynamic) ?? <AssessmentTestTemplate>[];
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
    final bool confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              "Delete Custom Test",
              style: AppTypography.cardTitle.copyWith(fontSize: 16),
            ),
            content: const Text(
              "Are you sure you want to delete this custom test template?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  "Cancel",
                  style: AppTypography.button.copyWith(color: AppColors.muted),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  "Delete",
                  style: AppTypography.button.copyWith(color: AppColors.berry),
                ),
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
          style: AppTypography.cardTitle.copyWith(fontSize: 16),
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
            child: Text(
              "Cancel",
              style: AppTypography.button.copyWith(color: AppColors.muted),
            ),
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
                final testType = widget.contentType == 'mains'
                    ? 'mains_test'
                    : 'sectional_test';

                final templateId = await _service.createUserCustomTest(
                  title: title,
                  description: descController.text.trim(),
                  examId: 1,
                  contentType: widget.contentType == 'aptitude'
                      ? 'aptitude'
                      : (widget.contentType == 'mains' ? 'mains' : 'gk'),
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
            child: Text(
              "Create",
              style: AppTypography.button.copyWith(color: AppColors.civic),
            ),
          ),
        ],
      ),
    );
  }

  void _startTour(BuildContext ctx) {
    ShowCaseWidget.of(ctx).startShowCase([_tourCreateTileKey]);
  }

  Future<void> _maybeAutoStartTour(BuildContext ctx) async {
    if (await AppTourService.shouldShowTour(AppTourService.listScreenKey)) {
      await AppTourService.markTourSeen(AppTourService.listScreenKey);
      if (mounted) _startTour(ctx);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (ctx) {
        if (!_tourChecked) {
          _tourChecked = true;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _maybeAutoStartTour(ctx),
          );
        }
        return _buildScaffold(ctx);
      },
    );
  }

  Widget _buildScaffold(BuildContext ctx) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(
          "My Custom Tests",
          style: AppTypography.title.copyWith(fontSize: 18),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.map_outlined,
              color: AppColors.civic,
              size: 20,
            ),
            tooltip: "App Tour",
            onPressed: () => _startTour(ctx),
          ),
        ],
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
                style: AppTypography.body.copyWith(
                  color: AppColors.berry,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Showcase(
              key: _tourCreateTileKey,
              title: "Build Custom Tests",
              description:
                  "Tap here to create a personalised practice test — choose the name, pick topics from the syllabus, and set how many questions to include.",
              targetBorderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.civic.withOpacity(0.1),
                    child: const Icon(
                      Icons.add_task_rounded,
                      color: AppColors.civic,
                    ),
                  ),
                  title: Text(
                    "Create custom test template",
                    style: AppTypography.cardTitle.copyWith(fontSize: 14),
                  ),
                  subtitle: Text(
                    "Build a test template with name and description",
                    style: AppTypography.caption.copyWith(fontSize: 11),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.muted,
                  ),
                  onTap: _showCreateTestDialog,
                ),
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.civic),
                  )
                : ((_tests as dynamic) == null || _tests.isEmpty)
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
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: AppColors.muted,
            ),
            const SizedBox(height: 16),
            Text(
              "No Custom Tests Created",
              style: AppTypography.title.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              "Create a tailored practice exam by combining specific syllabus categories and question counts.",
              style: AppTypography.body.copyWith(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CustomTestCreateScreen(contentType: widget.contentType),
                  ),
                );
                _fetchCustomTests();
              },
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text("Build Test"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.civic,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
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
        : test.title.toLowerCase().contains("csat") ||
              test.title.toLowerCase().contains("aptitude")
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
    final bool isCompleted =
        test.latestAttemptStatus == "submitted" ||
        test.latestAttemptStatus == "completed";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "$typeLabel Test",
                      style: AppTypography.eyebrowSmall.copyWith(
                        fontSize: 10,
                        color: badgeText,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.emerald.withOpacity(0.1)
                          : hasAttempt
                          ? AppColors.saffron.withOpacity(0.1)
                          : AppColors.muted.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isCompleted
                          ? "COMPLETED"
                          : hasAttempt
                          ? "IN PROGRESS"
                          : "NOT STARTED",
                      style: AppTypography.eyebrowSmall.copyWith(
                        color: isCompleted
                            ? AppColors.emerald
                            : hasAttempt
                            ? AppColors.saffron
                            : AppColors.muted,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                test.title,
                style: AppTypography.title.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildStatBadge(
                    Icons.layers_outlined,
                    "${test.questionCount ?? 0} Qs",
                  ),
                  const SizedBox(width: 12),
                  _buildStatBadge(
                    Icons.timer_outlined,
                    "${test.durationMinutes} Min",
                  ),
                  const SizedBox(width: 12),
                  _buildStatBadge(
                    Icons.emoji_events_outlined,
                    "${test.totalMarks.round()} Marks",
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: AppColors.line, height: 1),
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
                                    backgroundColor: AppColors.surface,
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
                            style: AppTypography.button.copyWith(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.civic,
                            side: const BorderSide(color: AppColors.civic),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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
                                if (isCompleted &&
                                    test.latestResultId != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ResultReviewScreen(
                                        resultId: test.latestResultId!,
                                      ),
                                    ),
                                  );
                                } else if (hasAttempt &&
                                    test.latestAttemptId != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AttemptEngineScreen(
                                        attemptId: test.latestAttemptId!,
                                      ),
                                    ),
                                  ).then((_) => _fetchCustomTests());
                                } else {
                                  _handleStartAttempt(test.id);
                                }
                              },
                        icon: _startingId == test.id
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                isCompleted
                                    ? Icons.emoji_events_outlined
                                    : hasAttempt
                                    ? Icons.play_arrow_rounded
                                    : Icons.rocket_launch_outlined,
                                size: 16,
                              ),
                        label: Text(
                          isCompleted
                              ? "Result"
                              : hasAttempt
                              ? "Resume"
                              : "Start",
                          style: AppTypography.button.copyWith(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.ink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
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
                      onPressed: _deletingId == test.id
                          ? null
                          : () => _handleDeleteTest(test.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.berry,
                        side: BorderSide(color: AppColors.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: _deletingId == test.id
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.berry,
                              ),
                            )
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
            style: AppTypography.caption.copyWith(
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
