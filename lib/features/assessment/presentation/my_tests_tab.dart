import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/assessment_service.dart';
import '../models/assessment_models.dart';
import 'result_review_screen.dart';
import 'attempt_engine_screen.dart';
import 'custom_test_detail_screen.dart';
import 'self_test_builder_tab.dart';

class MyTestsTab extends StatefulWidget {
  final String? contentType;
  final bool onlyInProgress;
  const MyTestsTab({super.key, this.contentType, this.onlyInProgress = false});

  @override
  State<MyTestsTab> createState() => _MyTestsTabState();
}

class _MyTestsTabState extends State<MyTestsTab> {
  late AssessmentService _service;
  bool _loading = true;
  String? _error;
  List<StudentAttemptSummary> _attempts = [];
  List<AssessmentTestTemplate> _customTests = [];

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = AssessmentService(apiClient: apiClient);
    _loadAttempts();
  }

  Future<void> _loadAttempts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final isMains = widget.contentType == 'mains';
      final attempts = await _service.getMyAssessmentAttempts(
        contentType: isMains ? null : widget.contentType,
      );
      final templates = await _service.getUserCustomTests();

      setState(() {
        var filteredAttempts = isMains
            ? attempts.where((a) => a.testTemplate.testType == 'mains_test').toList()
            : attempts;
        if (widget.onlyInProgress) {
          filteredAttempts = filteredAttempts
              .where((a) => a.status != 'completed' && a.status != 'submitted')
              .toList();
        }
        _attempts = filteredAttempts;

        _customTests = templates.where((t) {
          if (isMains) {
            return t.testType == 'mains_test';
          } else {
            if (widget.contentType == 'aptitude') {
              return t.examLevelId == 1;
            } else {
              return t.examLevelId == 7;
            }
          }
        }).toList();

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
      return const Center(child: CircularProgressIndicator(color: AppColors.civic));
    }
    
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.berry, size: 48),
              const SizedBox(height: 16),
              Text(
                "Could not load your tests",
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
                onPressed: _loadAttempts,
                child: const Text("RETRY"),
              ),
            ],
          ),
        ),
      );
    }

    final bool isEmpty = _customTests.isEmpty && _attempts.isEmpty;

    return RefreshIndicator(
      onRefresh: _loadAttempts,
      color: AppColors.civic,
      child: isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.quiz_outlined, color: AppColors.muted, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        "No tests found",
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "You haven't compiled or started any tests yet.",
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_customTests.isNotEmpty) ...[
                  Text(
                    "My Custom Tests",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._customTests.map((test) {
                    final bool hasAttempt = test.latestAttemptStatus != null;
                    final bool isCompleted = test.latestAttemptStatus == "submitted" || test.latestAttemptStatus == "completed";

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.line),
                        boxShadow: const [
                          BoxShadow(color: Color(0x05000000), blurRadius: 8, offset: Offset(0, 2))
                        ],
                      ),
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
                                    InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CustomTestDetailScreen(
                                              testTemplateId: test.id,
                                              contentType: widget.contentType,
                                            ),
                                          ),
                                        ).then((_) => _loadAttempts());
                                      },
                                      child: Text(
                                        test.title,
                                        style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.ink),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${test.questionCount ?? 0} Questions • ${test.totalMarks.round()} Marks",
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isCompleted ? AppColors.emerald.withOpacity(0.1) :
                                         hasAttempt ? AppColors.saffron.withOpacity(0.1) :
                                         AppColors.muted.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
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
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CustomTestDetailScreen(
                                        testTemplateId: test.id,
                                        contentType: widget.contentType,
                                      ),
                                    ),
                                  ).then((_) => _loadAttempts());
                                },
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                                child: Text(
                                  "View Details →",
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.muted),
                                ),
                              ),
                              Row(
                                children: [
                                  if (!hasAttempt) ...[
                                    TextButton(
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
                                        ).then((_) => _loadAttempts());
                                      },
                                      child: Text(
                                        "Add Qs",
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.civic),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.civic,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      if (isCompleted && test.latestResultId != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => ResultReviewScreen(resultId: test.latestResultId!)),
                                        );
                                      } else if (hasAttempt && test.latestAttemptId != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => AttemptEngineScreen(attemptId: test.latestAttemptId!)),
                                        ).then((_) => _loadAttempts());
                                      } else {
                                        _service.startAttempt(test.id).then((attemptId) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => AttemptEngineScreen(attemptId: attemptId)),
                                          ).then((_) => _loadAttempts());
                                        });
                                      }
                                    },
                                    child: Text(
                                      isCompleted ? "Result" : hasAttempt ? "Resume" : "Start",
                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ],
                if (_attempts.isNotEmpty) ...[
                  Text(
                    "Attempt History",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._attempts.map((attempt) {
                    final result = attempt.result;
                    final hasReport = result != null;
                    final test = attempt.testTemplate;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.line),
                        boxShadow: const [
                          BoxShadow(color: Color(0x05000000), blurRadius: 8, offset: Offset(0, 2))
                        ],
                      ),
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
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.ink),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Attempted on ${attempt.startedAt.split('T')[0]}",
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (attempt.status == 'completed' || attempt.status == 'submitted')
                                      ? AppColors.emerald.withOpacity(0.1)
                                      : AppColors.saffron.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  attempt.status.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: (attempt.status == 'completed' || attempt.status == 'submitted')
                                        ? AppColors.emerald
                                        : AppColors.saffron,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (hasReport)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Score: ${result.score.toStringAsFixed(1)}",
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600, color: AppColors.civic, fontSize: 14),
                                ),
                                Text(
                                  "Accuracy: ${(result.accuracy * 100).round()}%",
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600, color: AppColors.brand, fontSize: 14),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.civic),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                if (attempt.status == 'completed' || attempt.status == 'submitted') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ResultReviewScreen(resultId: result!.id)),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => AttemptEngineScreen(attemptId: attempt.id)),
                                  ).then((_) => _loadAttempts());
                                }
                              },
                              child: Text(
                                (attempt.status == 'completed' || attempt.status == 'submitted') ? "View Detailed Report" : "Resume Test",
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.civic),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
    );
  }
}
