import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/assessment_service.dart';
import '../models/assessment_models.dart';
import 'attempt_engine_screen.dart';
import 'ai_based_parsing_screen.dart';

class TestDetailScreen extends StatefulWidget {
  final int testTemplateId;
  const TestDetailScreen({super.key, required this.testTemplateId});

  @override
  State<TestDetailScreen> createState() => _TestDetailScreenState();
}

class _TestDetailScreenState extends State<TestDetailScreen> {
  late AssessmentService _service;
  bool _loading = true;
  bool _starting = false;
  String? _error;
  AssessmentTestTemplate? _test;

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = AssessmentService(apiClient: apiClient);
    _loadTestDetails();
  }

  Future<void> _loadTestDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tests = await _service.getAssessmentTests(status: "published");
      final test = tests.firstWhere((t) => t.id == widget.testTemplateId);
      setState(() {
        _test = test;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _startAttempt() async {
    setState(() {
      _starting = true;
      _error = null;
    });

    try {
      final attemptId = await _service.startAttempt(widget.testTemplateId);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AttemptEngineScreen(attemptId: attemptId),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error =
            "Could not start attempt: ${e.toString().replaceFirst('Exception: ', '')}";
        _starting = false;
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

    if (_error != null && _test == null) {
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
                  onPressed: _loadTestDetails,
                  child: const Text("RETRY"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final test = _test!;
    final type = test.testType.replaceAll('_', ' ').toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(
          "Exam Overview",
          style: AppTypography.title.copyWith(fontSize: 18),
        ),
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.ink,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.civic.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      type,
                      style: AppTypography.eyebrowSmall.copyWith(
                        color: AppColors.civic,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    test.title,
                    style: AppTypography.title.copyWith(fontSize: 20),
                  ),
                  if (test.description != null &&
                      test.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(test.description!, style: AppTypography.body),
                  ],
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.line),
                  const SizedBox(height: 14),

                  // Metadata Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoColumn(
                        "DURATION",
                        "${test.durationMinutes} Mins",
                      ),
                      _buildInfoColumn(
                        "TOTAL MARKS",
                        test.totalMarks.toStringAsFixed(0),
                      ),
                      if (test.questionCount != null)
                        _buildInfoColumn(
                          "QUESTIONS",
                          test.questionCount.toString(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Instructions Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Standard Exam Instructions",
                    style: AppTypography.sectionHeader.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  _buildInstructionItem(
                    Icons.check_circle_outline_rounded,
                    "Each question carries equal marks. Negative marks apply for wrong answers as per the test settings.",
                  ),
                  _buildInstructionItem(
                    Icons.cloud_upload_outlined,
                    "Your progress is autosaved to the cloud. You can resume the attempt from any device if disconnected.",
                  ),
                  _buildInstructionItem(
                    Icons.lock_clock_outlined,
                    "The attempt cannot be paused once started. The exam will automatically submit when the timer expires.",
                  ),
                  _buildInstructionItem(
                    Icons.security_update_warning_rounded,
                    "Do not refresh, press back, or minimize the app during active test taking to prevent premature submission.",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            if (_error != null) ...[
              Text(
                _error!,
                style: AppTypography.body.copyWith(
                  color: AppColors.berry,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],

            // Action Launch button
            ElevatedButton(
              onPressed: _starting ? null : _startAttempt,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _starting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text("START TEST ATTEMPT"),
            ),

            if (test.createdByUserId != null &&
                Provider.of<ApiClient>(context, listen: false).user?['id'] ==
                    test.createdByUserId) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AiBasedParsingScreen(
                        testTemplateId: test.id,
                        contentType: test.testType == 'mains_test'
                            ? 'mains'
                            : (test.testType.contains('aptitude') ||
                                      test.testType.contains('csat')
                                  ? 'aptitude'
                                  : 'gk'),
                      ),
                    ),
                  ).then((_) => _loadTestDetails());
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: const BorderSide(color: AppColors.civic, width: 1.5),
                  foregroundColor: AppColors.civic,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.psychology_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "ADD QUESTIONS WITH AI",
                      style: AppTypography.button.copyWith(
                        color: AppColors.civic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: AppTypography.statValue.copyWith(fontSize: 16)),
      ],
    );
  }

  Widget _buildInstructionItem(IconData icon, String instruction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.civic, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              instruction,
              style: AppTypography.body.copyWith(
                fontSize: 13,
                height: 1.45,
                color: AppColors.ink.withOpacity(0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
