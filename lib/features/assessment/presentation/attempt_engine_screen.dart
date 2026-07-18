import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:file_picker/file_picker.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/tour/app_tour_service.dart';
import '../../../../core/utils/image_compressor.dart';
import '../data/assessment_service.dart';
import '../models/assessment_models.dart';
import 'result_review_screen.dart';

class AttemptEngineScreen extends StatefulWidget {
  final int attemptId;
  const AttemptEngineScreen({super.key, required this.attemptId});

  @override
  State<AttemptEngineScreen> createState() => _AttemptEngineScreenState();
}

class _AttemptEngineScreenState extends State<AttemptEngineScreen> {
  late AssessmentService _service;
  late ApiClient _apiClient;
  bool _loading = true;
  String? _error;
  String? _statusMessage;

  AttemptPaper? _paper;
  int _activeIndex = 0;
  int _remainingSeconds = 0;
  Timer? _timer;

  // Local state copy of responses for instant UI updating
  // Key: question_version_id, Value: Map of values
  final Map<int, Map<String, dynamic>> _responses = {};

  // Tour
  final GlobalKey _tourStatsPanelKey = GlobalKey();
  final GlobalKey _tourNextBtnKey = GlobalKey();
  bool _tourChecked = false;

  // Subjective answering states
  final TextEditingController _subjectiveController = TextEditingController();
  final TextEditingController _fileUrlController = TextEditingController();
  bool _submittingSubjective = false;
  Map<int, dynamic> _mainsAnswers = {}; // cached mains responses

  @override
  void initState() {
    super.initState();
    _apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = AssessmentService(apiClient: _apiClient);
    _loadPaper();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subjectiveController.dispose();
    _fileUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadPaper() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final paper = await _service.getAttemptPaper(widget.attemptId);

      // If result already exists, skip attempt engine and go directly to results
      if (paper.result != null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResultReviewScreen(resultId: paper.result!.id),
            ),
          );
        }
        return;
      }

      // Populate local responses map
      for (final q in paper.questions) {
        _responses[q.questionVersion.id] = {
          'selectedAnswer': q.response?.selectedAnswer,
          'status': q.response?.status ?? 'not_visited',
          'marked': q.response?.isMarkedForReview ?? false,
        };
      }

      // Fetch subjective answers
      final mainsAnswersList = await _service.getMainsSubjectiveAnswers(
        widget.attemptId,
      );
      final Map<int, dynamic> answersMap = {};
      for (var ans in mainsAnswersList) {
        if (ans['question_version_id'] != null) {
          answersMap[int.parse(ans['question_version_id'].toString())] = ans;
        }
      }

      setState(() {
        _paper = paper;
        _mainsAnswers = answersMap;
        _remainingSeconds = _calculateRemainingSeconds(paper.expiresAt);
        _loading = false;
      });

      _syncSubjectiveInputs();
      _startTimer();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _syncSubjectiveInputs() {
    if (_paper == null || _paper!.questions.isEmpty) return;
    final activeQ = _paper!.questions[_activeIndex];
    final ans = _mainsAnswers[activeQ.questionVersion.id];

    _subjectiveController.text = ans?['student_answer_text']?.toString() ?? '';
    _fileUrlController.text = ans?['answer_file_url']?.toString() ?? '';
  }

  int _calculateRemainingSeconds(String? expiresAt) {
    if (expiresAt == null) return 0;
    final expires = DateTime.tryParse(expiresAt);
    if (expires == null) return 0;
    final diff = expires.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        _autoSubmit();
      }
    });
  }

  Future<void> _autoSubmit() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Time expired! Submitting your answers automatically..."),
        backgroundColor: AppColors.berry,
      ),
    );
    try {
      final resultId = await _service.submitAttempt(
        widget.attemptId,
        0,
        _paper!.testTemplate.durationMinutes,
      );
      if (_apiClient.isGuestMode) {
        await _apiClient.setPendingGuestClaim(widget.attemptId);
      }
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultReviewScreen(resultId: resultId),
          ),
        );
      }
    } catch (_) {
      // Fail-safe exit on submission error
      if (mounted) Navigator.pop(context);
    }
  }

  String _formattedTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}";
  }

  // Local helper to select option key
  String _optionKey(dynamic option, int index) {
    if (option is Map) {
      final key =
          option['id'] ?? option['key'] ?? option['value'] ?? option['label'];
      if (key != null) return key.toString();
    }
    return String.fromCharCode(65 + index);
  }

  // Local helper to extract text
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

  // Save selection
  Future<void> _saveResponse({
    required TestQuestionItem question,
    required dynamic selectedAnswer,
    required String status,
    required bool marked,
  }) async {
    final qid = question.questionVersion.id;
    setState(() {
      _responses[qid] = {
        'selectedAnswer': selectedAnswer,
        'status': status,
        'marked': marked,
      };
      _statusMessage = "Saving response...";
    });

    try {
      await _service.saveResponse(
        attemptId: widget.attemptId,
        questionVersionId: qid,
        selectedAnswer: selectedAnswer,
        status: status,
        isMarkedForReview: marked,
      );
      setState(() {
        _statusMessage = null;
      });
    } catch (_) {
      setState(() {
        _statusMessage = "Autosave failed. Check connection.";
      });
    }
  }

  // Perform OCR Scan using Gemini
  Future<void> _performOcrScan() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _submittingSubjective = true;
      _statusMessage = "Compressing and analyzing answer copy...";
    });

    try {
      final List<String> imagesBase64 = [];
      for (final file in result.files) {
        List<int> rawBytes;
        if (file.bytes != null) {
          rawBytes = file.bytes!;
        } else if (file.path != null && !kIsWeb) {
          rawBytes = await io.File(file.path!).readAsBytes();
        } else {
          continue;
        }

        // Compress image using ImageCompressor in isolate
        final compressedBytes = await ImageCompressor.compressImage(
          Uint8List.fromList(rawBytes),
        );
        final base64String = base64Encode(compressedBytes);
        imagesBase64.add("data:image/jpeg;base64,$base64String");
      }

      if (imagesBase64.isNotEmpty) {
        setState(() {
          _statusMessage = "Analyzing answer copy with Gemini...";
        });
        final extractedText = await _service.performOcr(imagesBase64);
        setState(() {
          final currentText = _subjectiveController.text.trim();
          _subjectiveController.text =
              currentText +
              (currentText.isNotEmpty ? "\n\n" : "") +
              extractedText;
          _statusMessage = "OCR scan completed successfully!";
        });
      } else {
        setState(() {
          _statusMessage = "No valid images selected.";
        });
      }
    } catch (e) {
      debugPrint("OCR failed: $e");
      setState(() {
        _statusMessage = "OCR processing failed.";
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("OCR processing failed: $e")));
    } finally {
      setState(() {
        _submittingSubjective = false;
      });
    }
  }

  // Pick copy file and simulate upload
  Future<void> _pickAndUploadCopy() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _submittingSubjective = true;
      _statusMessage = "Uploading file copy...";
    });

    try {
      final file = result.files.first;
      // NOTE: Replace with actual file upload service when storage is configured
      final copyData = <String, String>{'url': file.name};

      setState(() {
        _fileUrlController.text = copyData['url'] ?? '';
        _statusMessage = "Copy file selected: ${file.name}";
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
    } finally {
      setState(() {
        _submittingSubjective = false;
      });
    }
  }

  // Submit subjective answers
  Future<void> _submitMainsAnswer(TestQuestionItem question) async {
    final qid = question.questionVersion.id;
    final draftText = _subjectiveController.text.trim();
    final fileUrl = _fileUrlController.text.trim();

    if (draftText.isEmpty && fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Write an answer or enter a file copy URL first."),
        ),
      );
      return;
    }

    setState(() {
      _submittingSubjective = true;
      _statusMessage = "Submitting subjective response...";
    });

    try {
      final ans = await _service.submitMainsAnswer(
        attemptId: widget.attemptId,
        questionVersionId: qid,
        answerText: draftText.isNotEmpty ? draftText : null,
        answerFileUrl: fileUrl.isNotEmpty ? fileUrl : null,
      );

      setState(() {
        _mainsAnswers[qid] = ans;
        _responses[qid] = {
          'selectedAnswer': null,
          'status': 'answered',
          'marked': false,
        };
        _statusMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Mains answer locked successfully!"),
          backgroundColor: AppColors.emerald,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not save subjective answer: $e")),
      );
      setState(() {
        _statusMessage = null;
      });
    } finally {
      setState(() {
        _submittingSubjective = false;
      });
    }
  }

  // Submit whole attempt
  Future<void> _submitAttempt() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            "Submit Exam",
            style: AppTypography.cardTitle.copyWith(fontSize: 16),
          ),
          content: const Text(
            "Are you sure you want to finish and submit the test? You cannot edit answers after submission.",
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("CANCEL"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "SUBMIT TEST",
                style: TextStyle(color: AppColors.civic),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _timer?.cancel();
      final resultId = await _service.submitAttempt(
        widget.attemptId,
        _remainingSeconds,
        _paper!.testTemplate.durationMinutes,
      );
      if (_apiClient.isGuestMode) {
        await _apiClient.setPendingGuestClaim(widget.attemptId);
      }
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultReviewScreen(resultId: resultId),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error =
            "Submission failed: ${e.toString().replaceFirst('Exception: ', '')}";
        _loading = false;
      });
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _paper == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.civic)),
      );
    }

    // Error state — show friendly message with retry
    if (_paper == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            "Test",
            style: AppTypography.sectionHeader.copyWith(fontSize: 14),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.berry,
                ),
                const SizedBox(height: 12),
                Text(
                  "Failed to load the test paper.",
                  style: AppTypography.title.copyWith(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  _error ??
                      "An unknown error occurred. Please check your connection and try again.",
                  style: AppTypography.body.copyWith(fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _loadPaper,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("Retry"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final paper = _paper!;

    // Safety guard: if questions list is empty (shouldn't happen but be safe)
    if (paper.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            paper.testTemplate.title,
            style: AppTypography.sectionHeader.copyWith(fontSize: 14),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Text(
            "No questions found in this test.",
            style: AppTypography.body.copyWith(fontSize: 14),
          ),
        ),
      );
    }

    final activeQ =
        paper.questions[_activeIndex.clamp(0, paper.questions.length - 1)];
    final activeQResp = _responses[activeQ.questionVersion.id] ?? {};
    final isSubjective =
        activeQ.questionFormat.questionFamily == 'mains_subjective';
    final hasMainsAns = _mainsAnswers[activeQ.questionVersion.id] != null;

    // Summary values
    final totalQ = paper.questions.length;
    final answeredQ = _responses.values
        .where((r) => r['status'] == 'answered')
        .length;
    final reviewQ = _responses.values.where((r) => r['marked'] == true).length;
    final skippedQ = _responses.values
        .where((r) => r['status'] == 'skipped')
        .length;
    final unvisitedQ = totalQ - answeredQ - reviewQ - skippedQ;

    return ShowCaseWidget(
      builder: (ctx) {
        if (!_tourChecked) {
          _tourChecked = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            if (await AppTourService.shouldShowTour(
              AppTourService.attemptScreenKey,
            )) {
              await AppTourService.markTourSeen(
                AppTourService.attemptScreenKey,
              );
              if (mounted)
                ShowCaseWidget.of(
                  ctx,
                ).startShowCase([_tourStatsPanelKey, _tourNextBtnKey]);
            }
          });
        }
        return _buildAttemptScaffold(
          ctx,
          paper,
          activeQ,
          activeQResp,
          isSubjective,
          hasMainsAns,
          totalQ,
          answeredQ,
          reviewQ,
          skippedQ,
          unvisitedQ,
        );
      },
    );
  }

  Widget _buildAttemptScaffold(
    BuildContext ctx,
    AttemptPaper paper,
    TestQuestionItem activeQ,
    Map<String, dynamic> activeQResp,
    bool isSubjective,
    bool hasMainsAns,
    int totalQ,
    int answeredQ,
    int reviewQ,
    int skippedQ,
    int unvisitedQ,
  ) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1.5,
        title: Text(
          paper.testTemplate.title,
          style: AppTypography.sectionHeader.copyWith(fontSize: 14),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  color: AppColors.paper,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _formattedTime(_remainingSeconds),
                  style: AppTypography.eyebrowSmall.copyWith(
                    color: Colors.white,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            bottomLeft: Radius.circular(24),
          ),
        ),
        child: _buildPaletteDrawer(totalQ),
      ),
      body: Column(
        children: [
          // Saving Indicator Bar
          if (_statusMessage != null)
            Container(
              color: AppColors.civic.withOpacity(0.08),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Center(
                child: Text(
                  _statusMessage!,
                  style: AppTypography.eyebrowSmall.copyWith(
                    color: AppColors.civic,
                    fontSize: 10,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),

          // Overview Stats Panel
          Showcase(
            key: _tourStatsPanelKey,
            title: "Track Your Progress",
            description:
                "See how many questions you've answered, marked for review, or skipped. Tap 'Grid' to jump to any question.",
            targetBorderRadius: BorderRadius.zero,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCompactStatBadge(
                    "${_activeIndex + 1}/$totalQ",
                    "Question",
                    Colors.grey[200]!,
                    AppColors.ink,
                  ),
                  _buildCompactStatBadge(
                    answeredQ.toString(),
                    "Done",
                    AppColors.emerald.withOpacity(0.1),
                    AppColors.emerald,
                  ),
                  _buildCompactStatBadge(
                    reviewQ.toString(),
                    "Review",
                    AppColors.saffron.withOpacity(0.1),
                    AppColors.saffron,
                  ),
                  Builder(
                    builder: (context) => InkWell(
                      onTap: () => Scaffold.of(context).openEndDrawer(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.civic.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.grid_view_rounded,
                              size: 14,
                              color: AppColors.civic,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Grid",
                              style: AppTypography.eyebrowLarge.copyWith(
                                fontSize: 11,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Question Workspace
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Question specs row
                    Row(
                      children: [
                        Text(
                          "QUESTION ${_activeIndex + 1}",
                          style: AppTypography.eyebrowLarge.copyWith(
                            fontSize: 11,
                            color: AppColors.muted,
                            letterSpacing: 0,
                          ),
                        ),
                        if (activeQ.questionVersion.createdByUserId !=
                            null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 10,
                                  color: Colors.amber[800],
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  "Your Question",
                                  style: AppTypography.eyebrowSmall.copyWith(
                                    color: Colors.amber[800],
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          "+${activeQ.marks} Marks",
                          style: AppTypography.eyebrowLarge.copyWith(
                            fontSize: 10,
                            letterSpacing: 0,
                          ),
                        ),
                        if (activeQ.negativeMarks > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            "-${activeQ.negativeMarks} Neg",
                            style: AppTypography.eyebrowLarge.copyWith(
                              fontSize: 10,
                              color: AppColors.berry,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.line),
                    const SizedBox(height: 12),

                    // Question statement rendered via markdown (since it supports HTML tags inside)
                    MarkdownBody(
                      data: activeQ.questionVersion.questionStatement,
                      styleSheet: MarkdownStyleSheet(
                        p: AppTypography.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          height: 1.45,
                        ),
                      ),
                    ),

                    if (activeQ.questionVersion.supplementaryStatement !=
                            null &&
                        activeQ.questionVersion.supplementaryStatement!
                            .trim()
                            .isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: MarkdownBody(
                          data: activeQ.questionVersion.supplementaryStatement!,
                          styleSheet: MarkdownStyleSheet(
                            p: AppTypography.body.copyWith(
                              fontSize: 13,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (activeQ.questionVersion.questionPrompt != null &&
                        activeQ.questionVersion.questionPrompt!
                            .trim()
                            .isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.civic.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.civic.withOpacity(0.1),
                          ),
                        ),
                        child: Text(
                          activeQ.questionVersion.questionPrompt!,
                          style: AppTypography.body.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.civic,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Options block (MCQ vs Subjective input)
                    if (isSubjective)
                      _buildSubjectiveWorkspace(activeQ, hasMainsAns)
                    else
                      _buildOptionsGrid(activeQ, activeQResp),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Back button
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        side: const BorderSide(color: AppColors.line),
                      ),
                      onPressed: _activeIndex > 0
                          ? () {
                              setState(() {
                                _activeIndex--;
                              });
                              _syncSubjectiveInputs();
                            }
                          : null,
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 14,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Skip button
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: AppColors.line),
                      ),
                      onPressed: () {
                        if (isSubjective) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Lock & Submit your subjective answer, or use Next to proceed.",
                              ),
                            ),
                          );
                        } else {
                          _saveResponse(
                            question: activeQ,
                            selectedAnswer: null,
                            status: 'skipped',
                            marked: false,
                          );
                        }
                      },
                      child: Text(
                        "SKIP",
                        style: AppTypography.button.copyWith(
                          fontSize: 11,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Review toggle
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: AppColors.line),
                      ),
                      onPressed: () {
                        final currentMarked =
                            activeQResp['marked'] as bool? ?? false;
                        _saveResponse(
                          question: activeQ,
                          selectedAnswer: activeQResp['selectedAnswer'],
                          status: activeQResp['status'] ?? 'not_visited',
                          marked: !currentMarked,
                        );
                      },
                      child: Row(
                        children: [
                          Icon(
                            activeQResp['marked'] == true
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 14,
                            color: AppColors.saffron,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "REVIEW",
                            style: AppTypography.button.copyWith(
                              fontSize: 11,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Next / Submit Button
                Showcase(
                  key: _tourNextBtnKey,
                  title: "Submit When Ready",
                  description:
                      "Tap 'Next' to move through questions. On the last question this becomes 'Submit' — tap it to finish and see your results.",
                  targetBorderRadius: BorderRadius.circular(12),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _activeIndex < totalQ - 1
                        ? () {
                            setState(() {
                              _activeIndex++;
                            });
                            _syncSubjectiveInputs();
                          }
                        : _submitAttempt,
                    child: Row(
                      children: [
                        Text(_activeIndex == totalQ - 1 ? "SUBMIT" : "NEXT"),
                        const SizedBox(width: 4),
                        Icon(
                          _activeIndex == totalQ - 1
                              ? Icons.send_rounded
                              : Icons.arrow_forward_ios_rounded,
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatBadge(
    String count,
    String label,
    Color bg,
    Color text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            count,
            style: AppTypography.eyebrowLarge.copyWith(
              fontSize: 11,
              color: text,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.eyebrowSmall.copyWith(
              color: text.withOpacity(0.8),
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsGrid(
    TestQuestionItem question,
    Map<String, dynamic> activeResp,
  ) {
    final options = question.questionVersion.options;
    final selectedKey = activeResp['selectedAnswer']?.toString();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final option = options[index];
        final key = _optionKey(option, index);
        final isSelected = selectedKey == key;

        return InkWell(
          onTap: () {
            _saveResponse(
              question: question,
              selectedAnswer: key,
              status: 'answered',
              marked: activeResp['marked'] as bool? ?? false,
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.civic.withOpacity(0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.civic : AppColors.line,
                width: isSelected ? 2 : 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 28,
                  width: 28,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.civic : AppColors.paper,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      key,
                      style: AppTypography.eyebrowLarge.copyWith(
                        fontSize: 11,
                        color: isSelected ? Colors.white : AppColors.ink,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: MarkdownBody(
                      data: _optionText(option, index),
                      styleSheet: MarkdownStyleSheet(
                        p: AppTypography.body.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubjectiveWorkspace(TestQuestionItem question, bool isLocked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Editor label
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("WRITE ANSWER", style: AppTypography.eyebrowSmall),
            if (!isLocked)
              InkWell(
                onTap: _submittingSubjective ? null : _performOcrScan,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      size: 14,
                      color: AppColors.civic,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "OCR SCAN SHEET",
                      style: AppTypography.eyebrowSmall.copyWith(
                        color: AppColors.civic,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _subjectiveController,
          maxLines: 8,
          readOnly: isLocked,
          decoration: const InputDecoration(
            hintText:
                "Structure your answer here. Provide arguments and headings...",
          ),
          onChanged: (_) {
            setState(() {}); // trigger rebuild for word count
          },
        ),
        const SizedBox(height: 6),
        Text(
          "Word Count: ${_subjectiveController.text.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).length} words",
          style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 16),

        // Copy Upload URL field
        Text(
          "OR ATTACH SCAN COPY (PDF/IMAGE)",
          style: AppTypography.eyebrowSmall,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _fileUrlController,
                readOnly: isLocked,
                decoration: const InputDecoration(
                  hintText: "Enter scan document URL...",
                ),
              ),
            ),
            if (!isLocked) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.line, width: 1.5),
                ),
                onPressed: _submittingSubjective ? null : _pickAndUploadCopy,
                child: const Icon(
                  Icons.file_upload_outlined,
                  color: AppColors.civic,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),

        if (!isLocked)
          ElevatedButton(
            onPressed: _submittingSubjective
                ? null
                : () => _submitMainsAnswer(question),
            child: _submittingSubjective
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text("LOCK & SUBMIT ANSWER"),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.emerald.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.emerald.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.emerald,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "This response sheet is locked and submitted for mentor review.",
                    style: AppTypography.body.copyWith(
                      color: AppColors.emerald,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_fileUrlController.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                // Link opening mockup
              },
              child: const Text("Open Submitted Document Copy"),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildPaletteDrawer(int totalQ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DrawerHeader(
          decoration: const BoxDecoration(color: AppColors.ink),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Questions Directory",
                style: AppTypography.title.copyWith(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Jump directly to any section",
                style: AppTypography.caption.copyWith(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: totalQ,
            itemBuilder: (context, index) {
              final q = _paper!.questions[index];
              final resp = _responses[q.questionVersion.id] ?? {};
              final isMarked = resp['marked'] == true;
              final isCurrent = index == _activeIndex;
              final status = resp['status'];

              Color bg = Colors.white;
              Color border = AppColors.line;
              Color text = AppColors.ink;

              if (isCurrent) {
                bg = AppColors.ink;
                border = AppColors.ink;
                text = Colors.white;
              } else if (isMarked) {
                bg = AppColors.saffron.withOpacity(0.08);
                border = AppColors.saffron;
                text = AppColors.saffron;
              } else if (status == 'answered') {
                bg = AppColors.emerald.withOpacity(0.08);
                border = AppColors.emerald;
                text = AppColors.emerald;
              } else if (status == 'skipped') {
                bg = AppColors.paper;
                border = AppColors.line;
                text = AppColors.muted;
              }

              return InkWell(
                onTap: () {
                  Navigator.pop(context); // close drawer
                  setState(() {
                    _activeIndex = index;
                  });
                  _syncSubjectiveInputs();
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: bg,
                    border: Border.all(color: border, width: isCurrent ? 2 : 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      (index + 1).toString(),
                      style: AppTypography.cardTitle.copyWith(
                        fontSize: 13,
                        color: text,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Status Legend inside Drawer
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(color: AppColors.line),
              const SizedBox(height: 10),
              Text(
                "LEGEND STATUS",
                style: AppTypography.eyebrowSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendDot(AppColors.emerald, "Answered"),
                  _buildLegendDot(AppColors.saffron, "Review"),
                  _buildLegendDot(AppColors.muted, "Skipped"),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _submitAttempt();
                },
                child: const Text("FINISH TEST"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          height: 10,
          width: 10,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
