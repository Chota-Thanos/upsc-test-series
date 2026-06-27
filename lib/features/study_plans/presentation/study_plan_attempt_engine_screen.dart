import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/study_plan_service.dart';
import '../models/study_plan_models.dart';
import 'study_plan_result_screen.dart';


class StudyPlanAttemptEngineScreen extends StatefulWidget {
  final int attemptId;
  final int planItemId;
  const StudyPlanAttemptEngineScreen({super.key, required this.attemptId, required this.planItemId});

  @override
  State<StudyPlanAttemptEngineScreen> createState() => _StudyPlanAttemptEngineScreenState();
}

class _StudyPlanAttemptEngineScreenState extends State<StudyPlanAttemptEngineScreen> {
  late StudyPlanService _service;
  bool _loading = true;
  String? _error;
  String? _statusMessage;

  StudyPlanAttemptPaper? _paper;
  int _activeIndex = 0;
  int _remainingSeconds = 0;
  Timer? _timer;

  // Local state copy of responses
  final Map<int, Map<String, dynamic>> _responses = {};

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = StudyPlanService(apiClient: apiClient);
    _loadPaper();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadPaper() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final paper = await _service.getStudyPlanAttemptPaper(widget.attemptId);
      
      // If result already submitted, exit and go back
      if (paper.status != "in_progress" && paper.result != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Test already submitted. Score: ${paper.result!['score']}/${paper.result!['max_score']}"), backgroundColor: AppColors.emerald),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Populate local responses map
      for (final q in paper.questions) {
        _responses[q.id] = {
          'selectedAnswer': q.response?.selectedAnswer,
          'status': q.response?.status ?? 'not_visited',
          'marked': q.response?.isMarkedForReview ?? false,
        };
      }

      setState(() {
        _paper = paper;
        _remainingSeconds = _calculateRemainingSeconds(paper.expiresAt);
        _loading = false;
      });

      _startTimer();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
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
      const SnackBar(content: Text("Time expired! Submitting study plan test..."), backgroundColor: AppColors.berry),
    );
    try {
      await _service.submitStudyPlanAttempt(widget.attemptId);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  String _formattedTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}";
  }

  // Key selector
  String _optionKey(dynamic option, int index) {
    if (option is Map) {
      final key = option['id'] ?? option['key'] ?? option['value'] ?? option['label'];
      if (key != null) return key.toString();
    }
    return String.fromCharCode(65 + index);
  }

  // Text selector
  String _optionText(dynamic option, int index) {
    if (option is Map) {
      final text = option['text'] ?? option['label'] ?? option['value'] ?? option['statement'];
      if (text != null) return text.toString();
    }
    if (option != null) return option.toString();
    return "Option ${String.fromCharCode(65 + index)}";
  }

  // Save Response
  Future<void> _saveResponse({
    required StudyPlanQuestion question,
    required dynamic selectedAnswer,
    required String status,
    required bool marked,
  }) async {
    final qid = question.id;
    setState(() {
      _responses[qid] = {
        'selectedAnswer': selectedAnswer,
        'status': status,
        'marked': marked,
      };
      _statusMessage = "Saving selection...";
    });

    try {
      await _service.saveStudyPlanResponse(
        attemptId: widget.attemptId,
        questionId: qid,
        selectedAnswer: selectedAnswer,
        status: status,
        isMarkedForReview: marked,
      );
      setState(() {
        _statusMessage = null;
      });
    } catch (_) {
      setState(() {
        _statusMessage = "Autosave failed. Check internet.";
      });
    }
  }

  // Submit test
  Future<void> _submitAttempt() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Submit Test", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
          content: const Text("Submit this study plan test? Your weekly progress will sync on submission."),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("SUBMIT TEST", style: TextStyle(color: AppColors.civic)),
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
      final resultId = await _service.submitStudyPlanAttempt(widget.attemptId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mock test submitted successfully!"), backgroundColor: AppColors.emerald),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => StudyPlanResultScreen(resultId: resultId)),
        );
      }
    } catch (e) {
      setState(() {
        _error = "Submission failed: $e";
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

    final paper = _paper!;
    final activeQ = paper.questions[_activeIndex];
    final activeQResp = _responses[activeQ.id] ?? {};

    final totalQ = paper.questions.length;
    final answeredQ = _responses.values.where((r) => r['status'] == 'answered').length;
    final reviewQ = _responses.values.where((r) => r['marked'] == true).length;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(
          paper.testTemplate.title,
          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(8)),
            child: Text(
              _formattedTime(_remainingSeconds),
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
            ),
          )
        ],
      ),
      endDrawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.8,
        child: _buildPaletteDrawer(totalQ),
      ),
      body: Column(
        children: [
          if (_statusMessage != null)
            Container(
              color: AppColors.civic.withOpacity(0.08),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Center(
                child: Text(_statusMessage!, style: const TextStyle(fontSize: 10, color: AppColors.civic, fontWeight: FontWeight.bold)),
              ),
            ),

          // Overview Stats Panel
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCompactStatBadge("${_activeIndex + 1}/$totalQ", "Question", Colors.grey[200]!, AppColors.ink),
                _buildCompactStatBadge(answeredQ.toString(), "Done", AppColors.emerald.withOpacity(0.1), AppColors.emerald),
                _buildCompactStatBadge(reviewQ.toString(), "Review", AppColors.saffron.withOpacity(0.1), AppColors.saffron),
                Builder(
                  builder: (context) => InkWell(
                    onTap: () => Scaffold.of(context).openEndDrawer(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.civic.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.grid_view_rounded, size: 14, color: AppColors.civic),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Canvas
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          "QUESTION ${_activeIndex + 1}",
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted),
                        ),
                        const Spacer(),
                        Text(
                          "+${activeQ.marks} Marks",
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.civic),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.line),
                    const SizedBox(height: 12),

                    MarkdownBody(
                      data: activeQ.questionStatement,
                      styleSheet: MarkdownStyleSheet(
                        p: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.45),
                      ),
                    ),

                    if (activeQ.supplementaryStatement != null && activeQ.supplementaryStatement!.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: MarkdownBody(
                          data: activeQ.supplementaryStatement!,
                          styleSheet: MarkdownStyleSheet(
                            p: GoogleFonts.inter(fontSize: 13, color: AppColors.muted, height: 1.4, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Options Grid
                    _buildOptionsGrid(activeQ, activeQResp),
                  ],
                ),
              ),
            ),
          ),

          // Actions
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        side: const BorderSide(color: AppColors.line),
                      ),
                      onPressed: _activeIndex > 0
                          ? () {
                              setState(() {
                                _activeIndex--;
                              });
                            }
                          : null,
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.ink),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppColors.line),
                      ),
                      onPressed: () {
                        _saveResponse(
                          question: activeQ,
                          selectedAnswer: null,
                          status: 'skipped',
                          marked: false,
                        );
                      },
                      child: Text("SKIP", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.ink)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppColors.line),
                      ),
                      onPressed: () {
                        final currentMarked = activeQResp['marked'] as bool? ?? false;
                        _saveResponse(
                          question: activeQ,
                          selectedAnswer: activeQResp['selectedAnswer'],
                          status: activeQResp['status'] ?? 'not_visited',
                          marked: !currentMarked,
                        );
                      },
                      child: Icon(
                        activeQResp['marked'] == true ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 14,
                        color: AppColors.saffron,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _activeIndex < totalQ - 1
                      ? () {
                          setState(() {
                            _activeIndex++;
                          });
                        }
                      : _submitAttempt,
                  child: Text(_activeIndex == totalQ - 1 ? "SUBMIT" : "NEXT"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatBadge(String count, String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Text(count, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: text)),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: text.withOpacity(0.8))),
        ],
      ),
    );
  }

  Widget _buildOptionsGrid(StudyPlanQuestion question, Map<String, dynamic> activeResp) {
    final options = question.options;
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
              color: isSelected ? AppColors.civic.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.civic : AppColors.line,
                width: isSelected ? 2 : 1.5,
              ),
            ),
            child: Row(
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
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : AppColors.ink),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _optionText(option, index),
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaletteDrawer(int totalQ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DrawerHeader(
          decoration: const BoxDecoration(color: AppColors.ink),
          child: Center(
            child: Text(
              "Questions Palette",
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemCount: totalQ,
            itemBuilder: (context, index) {
              final q = _paper!.questions[index];
              final resp = _responses[q.id] ?? {};
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
              }

              return InkWell(
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _activeIndex = index;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(color: bg, border: Border.all(color: border, width: 1.5), borderRadius: BorderRadius.circular(8)),
                  child: Center(
                    child: Text((index + 1).toString(), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: text)),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitAttempt();
            },
            child: const Text("SUBMIT TEST"),
          ),
        ),
      ],
    );
  }
}
