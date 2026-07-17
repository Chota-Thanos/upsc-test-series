import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/tour/app_tour_service.dart';
import '../../../../core/utils/constants.dart';
import '../data/assessment_service.dart';
import '../models/assessment_models.dart';
import '../../home/presentation/navigation_home.dart';

enum _ResultTab { summary, questions, topics, time }

enum _QuestionFilter { all, correct, incorrect, unattempted }

class ResultReviewScreen extends StatefulWidget {
  final int resultId;
  const ResultReviewScreen({super.key, required this.resultId});

  @override
  State<ResultReviewScreen> createState() => _ResultReviewScreenState();
}

class _ResultReviewScreenState extends State<ResultReviewScreen>
    with SingleTickerProviderStateMixin {
  late AssessmentService _service;
  late ApiClient _apiClient;
  bool _loading = true;
  String? _error;
  ResultReview? _review;
  List<Map<String, dynamic>> _rawTaxonomyNodes = [];
  final Set<int> _expandedTopicNodes = {};
  final Set<int> _bookmarkedQuestionIds = {};
  final Map<int, GlobalKey> _questionKeys = {};

  // Manual evaluation form state
  int? _editingAnswerId;
  final TextEditingController _manualScoreController = TextEditingController();
  final TextEditingController _manualMaxScoreController = TextEditingController();
  final TextEditingController _manualFeedbackController = TextEditingController();
  final TextEditingController _manualCheckedCopyUrlController = TextEditingController();
  final TextEditingController _manualStrengthsController = TextEditingController();
  final TextEditingController _manualWeaknessesController = TextEditingController();
  bool _isSavingManual = false;
  final Set<int> _evaluatingQuestionIds = {};

  _ResultTab _activeTab = _ResultTab.summary;
  _QuestionFilter _qFilter = _QuestionFilter.all;

  // Tour
  final GlobalKey _tourTabBarKey = GlobalKey();
  bool _tourChecked = false;

  void _jumpToQuestion(int index) {
    setState(() {
      _activeTab = _ResultTab.questions;
      _qFilter = _QuestionFilter.all;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _questionKeys[index];
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _toggleBookmark(int questionId, int questionVersionId) async {
    final isBookmarked = _bookmarkedQuestionIds.contains(questionId);
    setState(() {
      if (isBookmarked) {
        _bookmarkedQuestionIds.remove(questionId);
      } else {
        _bookmarkedQuestionIds.add(questionId);
      }
    });

    try {
      if (isBookmarked) {
        await _service.removeBookmark(questionId);
      } else {
        await _service.addBookmark(questionId, questionVersionId);
      }
    } catch (e) {
      setState(() {
        if (isBookmarked) {
          _bookmarkedQuestionIds.add(questionId);
        } else {
          _bookmarkedQuestionIds.remove(questionId);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update bookmark: $e")),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = AssessmentService(apiClient: _apiClient);
    // Guests hit a sign-in wall here instead of fetching (the backend keeps
    // results private to real accounts) — see the guest branch in build().
    if (_apiClient.isGuestMode) {
      _loading = false;
    } else {
      _loadResult();
    }
  }

  @override
  void dispose() {
    _manualScoreController.dispose();
    _manualMaxScoreController.dispose();
    _manualFeedbackController.dispose();
    _manualCheckedCopyUrlController.dispose();
    _manualStrengthsController.dispose();
    _manualWeaknessesController.dispose();
    super.dispose();
  }

  Future<void> _loadResult() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final review = await _service.getResultReview(widget.resultId);
      List<Map<String, dynamic>> nodes = [];
      try {
        if (review.testTemplate.testType == 'mains_test') {
          nodes = await _service.getMainsTaxonomyNodes(review.testTemplate.examId);
        } else {
          nodes = await _service.getTaxonomyNodes(review.testTemplate.examId);
        }
      } catch (e) {
        debugPrint("Error loading taxonomy in review: $e");
      }

      final bookmarksList = await _service.getBookmarks();
      final bookmarkedIds = bookmarksList
          .map((b) => int.tryParse((b as Map<String, dynamic>)['question_id']?.toString() ?? '') ?? 0)
          .where((id) => id != 0)
          .toSet();

      setState(() {
        _review = review;
        _rawTaxonomyNodes = nodes;
        _bookmarkedQuestionIds.addAll(bookmarkedIds);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  bool _checkCanEvaluate(ResultReview review) {
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    final user = apiClient.user;
    if (user == null) return false;
    final userRole = user['role']?.toString() ?? '';
    final userId = user['id'];

    return ['admin', 'moderator', 'evaluator', 'mentor'].contains(userRole) ||
        (userId != null && review.attempt.userId == int.tryParse(userId.toString()));
  }

  void _startManualEvaluation(TestQuestionItem question) {
    final response = question.response;
    if (response == null) return;
    setState(() {
      _editingAnswerId = response.id;
      _manualScoreController.text = response.score != null ? response.score!.toStringAsFixed(1) : "";
      _manualMaxScoreController.text = response.maxScore != null ? response.maxScore!.toStringAsFixed(0) : question.marks.toStringAsFixed(0);
      _manualFeedbackController.text = response.feedback ?? "";
      _manualCheckedCopyUrlController.text = response.checkedCopyUrl ?? "";
      _manualStrengthsController.text = response.strengths != null ? response.strengths!.join("\n") : "";
      _manualWeaknessesController.text = response.weaknesses != null ? response.weaknesses!.join("\n") : "";
    });
  }

  void _cancelManualEvaluation() {
    setState(() {
      _editingAnswerId = null;
    });
  }

  Future<void> _handleSaveManualEvaluation() async {
    if (_editingAnswerId == null) return;
    final score = double.tryParse(_manualScoreController.text.trim());
    final maxScore = double.tryParse(_manualMaxScoreController.text.trim()) ?? 10.0;

    if (score == null || score < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid non-negative score.")),
      );
      return;
    }
    if (score > maxScore) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Score cannot exceed maximum marks ($maxScore).")),
      );
      return;
    }

    setState(() {
      _isSavingManual = true;
    });

    try {
      final strengths = _manualStrengthsController.text
          .split("\n")
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final weaknesses = _manualWeaknessesController.text
          .split("\n")
          .map((w) => w.trim())
          .where((w) => w.isNotEmpty)
          .toList();

      await _service.submitManualEvaluation(
        mainsAnswerId: _editingAnswerId!,
        score: score,
        maxScore: maxScore,
        feedback: _manualFeedbackController.text.trim().isNotEmpty ? _manualFeedbackController.text.trim() : null,
        checkedCopyUrl: _manualCheckedCopyUrlController.text.trim().isNotEmpty ? _manualCheckedCopyUrlController.text.trim() : null,
        strengths: strengths,
        weaknesses: weaknesses,
      );

      setState(() {
        _editingAnswerId = null;
      });
      await _loadResult();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save evaluation: $e")),
      );
    } finally {
      setState(() {
        _isSavingManual = false;
      });
    }
  }

  Future<void> _triggerAiEvaluation(int mainsAnswerId, int questionId) async {
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    final canAiEvaluate = apiClient.hasEntitlement('assessment.ai_evaluation') ||
        apiClient.hasEntitlement('assessment.premium_tests');
    if (!canAiEvaluate) {
      _showAiEvaluationPaywall();
      return;
    }

    setState(() {
      _evaluatingQuestionIds.add(questionId);
    });

    try {
      await _service.triggerMainsAiEvaluation(mainsAnswerId);
      await _loadResult();
    } catch (e) {
      if (e is ApiException && e.code == 'ai_evaluation_requires_premium') {
        _showAiEvaluationPaywall();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("AI Evaluation failed: $e")),
        );
      }
    } finally {
      setState(() {
        _evaluatingQuestionIds.remove(questionId);
      });
    }
  }

  void _showAiEvaluationPaywall() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: Colors.indigo),
              const SizedBox(width: 10),
              Text(
                "Premium Feature",
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: Text(
            "AI-based answer evaluation requires an Assessment Premium subscription. Test creation and taking stays free — this only gates AI review of your answers.",
            style: GoogleFonts.inter(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                final url = Uri.parse("${ApiConstants.webAppUrl}/pricing");
                if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                  debugPrint("Could not launch $url");
                }
              },
              child: Text(
                "View Plans",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  String _optionKey(dynamic option, int index) {
    if (option is Map) {
      final key = option['id'] ?? option['key'] ?? option['value'] ?? option['label'];
      if (key != null) return key.toString();
    }
    return String.fromCharCode(65 + index);
  }

  String _optionText(dynamic option, int index) {
    if (option is Map) {
      final text = option['text'] ?? option['label'] ?? option['value'] ?? option['statement'];
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

  List<TestQuestionItem> _filteredQuestions(List<TestQuestionItem> all) {
    return all.where((q) {
      final outcome = q.scoreItem?['outcome'] as String?;
      switch (_qFilter) {
        case _QuestionFilter.all:
          return true;
        case _QuestionFilter.correct:
          return outcome == 'correct';
        case _QuestionFilter.incorrect:
          return outcome == 'incorrect';
        case _QuestionFilter.unattempted:
          return outcome == null || outcome == 'unattempted';
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_apiClient.isGuestMode) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        color: AppColors.civic.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(child: Text("🎉", style: TextStyle(fontSize: 26))),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Your result is ready",
                      style: Theme.of(context).textTheme.displayMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Create a free account (takes 10 seconds) to unlock your score, topic-wise breakdown, and full answer review — and save it to your dashboard for good.",
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => _apiClient.setGuestMode(false),
                      child: const Text("SIGN IN / CREATE ACCOUNT"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

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
                const Icon(Icons.error_outline_rounded, color: AppColors.berry, size: 44),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadResult, child: const Text("RETRY")),
              ],
            ),
          ),
        ),
      );
    }

    final review = _review!;
    final result = review.result;

    return ShowCaseWidget(
      builder: (ctx) {
        if (!_tourChecked) {
          _tourChecked = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            if (await AppTourService.shouldShowTour(AppTourService.resultScreenKey)) {
              await AppTourService.markTourSeen(AppTourService.resultScreenKey);
              if (mounted) ShowCaseWidget.of(ctx).startShowCase([_tourTabBarKey]);
            }
          });
        }
        return Scaffold(
          backgroundColor: AppColors.paper,
          appBar: AppBar(
            title: Text(
              "Performance Review",
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 18),
            ),
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.ink, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Column(
            children: [
              // Tab Bar
              Showcase(
                key: _tourTabBarKey,
                title: "Explore Your Results",
                description: "Switch between Summary, Questions, Topics, and Time Analysis tabs to understand exactly how you performed and where to focus next.",
                targetBorderRadius: BorderRadius.zero,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTabChip(_ResultTab.summary, Icons.emoji_events_rounded, "Summary"),
                        const SizedBox(width: 8),
                        _buildTabChip(_ResultTab.questions, Icons.checklist_rounded, "Questions (${review.questions.length})"),
                        const SizedBox(width: 8),
                        _buildTabChip(_ResultTab.topics, Icons.track_changes_rounded, "Topics"),
                        const SizedBox(width: 8),
                        _buildTabChip(_ResultTab.time, Icons.timer_outlined, "Time Analysis"),
                      ],
                    ),
                  ),
                ),
              ),

              // Tab Content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadResult,
                  color: AppColors.civic,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: _buildTabContent(review, result),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabChip(_ResultTab tab, IconData icon, String label) {
    final isActive = _activeTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.ink : AppColors.line,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isActive ? Colors.white : AppColors.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(ResultReview review, AssessmentResult result) {
    switch (_activeTab) {
      case _ResultTab.summary:
        return _buildSummaryTab(review, result);
      case _ResultTab.questions:
        return _buildQuestionsTab(review);
      case _ResultTab.topics:
        return _buildTopicsTab(review);
      case _ResultTab.time:
        return _buildTimeTab(review);
    }
  }

  // ─── Tab: Summary ──────────────────
  Widget _buildSummaryTab(ResultReview review, AssessmentResult result) {
    final pct = result.maxScore > 0 ? (result.score / result.maxScore * 100).clamp(0.0, 100.0) : 0.0;
    // Rolled up through the full taxonomy tree (same rollup as the Topics tab) so a
    // uniformly weak subject/chapter surfaces here too, not just individually-tagged topics.
    final weakTopics = _flattenTopicNodes(_buildTopicsTree(review))
        .where((n) => n.attemptedQuestions > 0 && n.accuracy < 0.6)
        .toList()
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));

    final bool mainsPendingEvaluation = review.questions.any(
      (q) =>
          q.questionFormat.questionFamily == 'mains_subjective' &&
          q.response != null &&
          q.response!.evaluationStatus != 'evaluated',
    );

    if (mainsPendingEvaluation) {
      final mainsAttempted = review.questions.where((q) => q.response != null).toList();
      final mainsEvaluated = mainsAttempted.where((q) => q.response!.evaluationStatus == 'evaluated').toList();
      final mainsPending = mainsAttempted.where((q) => q.response!.evaluationStatus != 'evaluated').toList();
      final canEvaluate = _checkCanEvaluate(review);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Gradient Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEEF2FF), Color(0xFFF5F7FF), Color(0xFFEEF2FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE0E7FF), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.civic,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text("✍️", style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Mains Evaluation Pending",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Your subjective answer sheets are successfully registered. You can evaluate them using our AI UPSC Examiner, or submit manual grading scores and upload checked copies.",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.muted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.civic.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.civic.withOpacity(0.2)),
                            ),
                            child: Text(
                              "${mainsEvaluated.length} / ${mainsAttempted.length} Evaluated",
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.civic,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.saffron.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.saffron.withOpacity(0.2)),
                            ),
                            child: Text(
                              "${mainsPending.length} Awaiting Evaluation",
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.saffron,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Mains Answer Copies & Grading Checklist",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: review.questions.length,
            separatorBuilder: (_, __) => const Divider(color: AppColors.line, height: 24),
            itemBuilder: (context, idx) {
              final q = review.questions[idx];
              final response = q.response;
              final status = response?.evaluationStatus;
              final isEvaluating = _evaluatingQuestionIds.contains(q.id) || status == 'ai_evaluating';

              Widget badge;
              if (response == null) {
                badge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "Unattempted",
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.muted),
                  ),
                );
              } else if (status == 'evaluated') {
                badge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
                  ),
                  child: Text(
                    "Score: ${response.score?.toStringAsFixed(1) ?? '?'}/${response.maxScore?.toStringAsFixed(0) ?? q.marks.toStringAsFixed(0)}",
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.emerald),
                  ),
                );
              } else if (isEvaluating) {
                badge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.civic.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.civic.withOpacity(0.3)),
                  ),
                  child: Text(
                    "AI Evaluating...",
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.civic),
                  ),
                );
              } else {
                badge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.saffron.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.saffron.withOpacity(0.3)),
                  ),
                  child: Text(
                    "Pending Evaluation",
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.saffron),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "Q${idx + 1}",
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted),
                      ),
                      if (q.questionVersion.createdByUserId != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber.withOpacity(0.3)),
                          ),
                          child: Text(
                            "Your Question",
                            style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.amber[800]),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      badge,
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    q.questionVersion.questionStatement,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      height: 1.35,
                    ),
                  ),
                  if (response != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (canEvaluate) ...[
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              side: const BorderSide(color: AppColors.line),
                            ),
                            onPressed: () {
                              _jumpToQuestion(idx);
                              _startManualEvaluation(q);
                            },
                            child: Text(
                              status == 'evaluated' ? "EDIT MARKS" : "MANUAL MARKS",
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.ink),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onPressed: isEvaluating ? null : () => _triggerAiEvaluation(response.id, q.id),
                          icon: isEvaluating
                              ? const SizedBox(
                                  height: 10,
                                  width: 10,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5),
                                )
                              : const Icon(Icons.auto_awesome_rounded, size: 12),
                          label: Text(
                            status == 'evaluated' ? "RE-EVALUATE" : "AI EVALUATE",
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Score Card with Gauge + Stats
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x15000000),
                offset: Offset(0, 8),
                blurRadius: 24,
              )
            ],
          ),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 500;
                  if (isNarrow) {
                    return Column(
                      children: [
                        // Score Gauge
                        _ScoreGauge(percentage: pct),
                        const SizedBox(height: 24),
                        // Stat Grid
                        SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: [
                              _buildStatBox("🎯", "Score", "${result.score.toStringAsFixed(1)}/${result.maxScore.toStringAsFixed(0)}"),
                              _buildStatBox("📊", "Accuracy", "${(result.accuracy * 100).round()}%"),
                              _buildStatBox("✅", "Correct", result.correctCount.toString()),
                              _buildStatBox("❌", "Incorrect", result.incorrectCount.toString()),
                              _buildStatBox("⬜", "Skipped", result.unattemptedCount.toString()),
                              _buildStatBox("⚠️", "Negative", "-${result.negativeMarks.toStringAsFixed(2)}"),
                            ],
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(width: 12),
                        // Score Gauge
                        _ScoreGauge(percentage: pct),
                        const SizedBox(width: 32),
                        // Stat Grid
                        Expanded(
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _buildStatBox("🎯", "Score", "${result.score.toStringAsFixed(1)}/${result.maxScore.toStringAsFixed(0)}"),
                              _buildStatBox("📊", "Accuracy", "${(result.accuracy * 100).round()}%"),
                              _buildStatBox("✅", "Correct", result.correctCount.toString()),
                              _buildStatBox("❌", "Incorrect", result.incorrectCount.toString()),
                              _buildStatBox("⬜", "Skipped", result.unattemptedCount.toString()),
                              _buildStatBox("⚠️", "Negative", "-${result.negativeMarks.toStringAsFixed(2)}"),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
              // Cutoff banner
              if (result.cutoffStatus != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: result.cutoffStatus == 'cleared'
                        ? AppColors.emerald.withOpacity(0.2)
                        : AppColors.berry.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: result.cutoffStatus == 'cleared'
                          ? AppColors.emerald.withOpacity(0.5)
                          : AppColors.berry.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(result.cutoffStatus == 'cleared' ? "🎉" : "📈", style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 12),
                      Text(
                        result.cutoffStatus == 'cleared' ? "Cutoff Cleared!" : "Just below cutoff",
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Percentile
              if (result.percentileSnapshot != null) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.leaderboard_rounded, size: 14, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      "Percentile: ${result.percentileSnapshot!.round()}%ile",
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Test title chip
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.civic.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                review.testTemplate.testType.replaceAll('_', ' ').toUpperCase(),
                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.civic),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                review.testTemplate.title,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Weak Topics summary
        if (weakTopics.isNotEmpty) ...[
          Text("Priority Revision Areas", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...weakTopics.take(4).map((t) => _buildWeakTopicCard(t)),
          const SizedBox(height: 20),
        ],

        // Questions Status Grid
        Text("Questions Status & Bookmarks", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text(
          "Tap a cell to review, or tap bookmark to toggle.",
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.0,
          ),
          itemCount: review.questions.length,
          itemBuilder: (context, idx) {
            final q = review.questions[idx];
            final outcome = q.scoreItem?['outcome'] as String? ?? 'unattempted';
            final isBookmarked = _bookmarkedQuestionIds.contains(q.questionVersion.questionId);

            Color cellBg;
            Color borderCol;
            Color textCol;

            switch (outcome) {
              case 'correct':
                cellBg = AppColors.emerald.withOpacity(0.06);
                borderCol = AppColors.emerald.withOpacity(0.3);
                textCol = AppColors.emerald;
                break;
              case 'incorrect':
                cellBg = AppColors.berry.withOpacity(0.06);
                borderCol = AppColors.berry.withOpacity(0.3);
                textCol = AppColors.berry;
                break;
              default:
                cellBg = AppColors.muted.withOpacity(0.06);
                borderCol = AppColors.muted.withOpacity(0.2);
                textCol = AppColors.muted;
            }

            return InkWell(
              onTap: () => _jumpToQuestion(idx),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: cellBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderCol, width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Q${idx + 1}",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textCol,
                      ),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () => _toggleBookmark(q.questionVersion.questionId, q.questionVersion.id),
                      child: Icon(
                        isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        color: isBookmarked ? AppColors.saffron : AppColors.muted,
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // Quick action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => setState(() => _activeTab = _ResultTab.questions),
                child: const Text("REVIEW QUESTIONS"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const NavigationHome()),
                    (route) => false,
                  );
                },
                child: const Text("TRY AGAIN"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatBox(String emoji, String label, String value) {
    return Container(
      width: 102,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildWeakTopicCard(_TopicPerformanceTreeNode node) {
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
                Row(
                  children: [
                    Flexible(
                      child: Text(node.name, style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const SizedBox(width: 6),
                    _buildTopicLevelBadge(_topicNodeTypeLabel(node.nodeType)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "${(node.accuracy * 100).round()}% accuracy · ${node.totalQuestions} question${node.totalQuestions == 1 ? '' : 's'}",
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Revise this before your next test.",
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab: Questions ──────────────────────────────────────────────────────

  Widget _buildQuestionsTab(ResultReview review) {
    final filtered = _filteredQuestions(review.questions);
    final result = review.result;

    // Group by passage
    final passageGroups = <String, List<TestQuestionItem>>{};
    final standalone = <TestQuestionItem>[];
    final ordered = <dynamic>[];
    final seen = <String>{};

    for (final q in filtered) {
      final passageKey = q.passage?['id']?.toString();
      if (passageKey != null && q.passage != null) {
        passageGroups.putIfAbsent(passageKey, () => []).add(q);
        if (!seen.contains(passageKey)) {
          seen.add(passageKey);
          ordered.add({'type': 'passage', 'key': passageKey});
        }
      } else {
        standalone.add(q);
        ordered.add({'type': 'solo', 'q': q});
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(_QuestionFilter.all, "All (${review.questions.length})"),
              const SizedBox(width: 8),
              _buildFilterChip(_QuestionFilter.correct, "Correct (${result.correctCount})", color: AppColors.emerald),
              const SizedBox(width: 8),
              _buildFilterChip(_QuestionFilter.incorrect, "Incorrect (${result.incorrectCount})", color: AppColors.berry),
              const SizedBox(width: 8),
              _buildFilterChip(_QuestionFilter.unattempted, "Skipped (${result.unattemptedCount})", color: AppColors.muted),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Question cards
        ...review.questions.asMap().entries.map((entry) {
          final idx = entry.key;
          final q = entry.value;

          // Check if filtered out
          final outcome = q.scoreItem?['outcome'] as String?;
          final show = _qFilter == _QuestionFilter.all ||
              (_qFilter == _QuestionFilter.correct && outcome == 'correct') ||
              (_qFilter == _QuestionFilter.incorrect && outcome == 'incorrect') ||
              (_qFilter == _QuestionFilter.unattempted && (outcome == null || outcome == 'unattempted'));

          if (!show) return const SizedBox.shrink();

          return _buildQuestionCard(q, idx);
        }),
      ],
    );
  }

  Widget _buildFilterChip(_QuestionFilter filter, String label, {Color color = AppColors.ink}) {
    final isActive = _qFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _qFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? color : AppColors.line, width: 1.5),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(TestQuestionItem item, int index) {
    final q = item.questionVersion;
    final outcome = item.scoreItem?['outcome'] as String? ?? 'unattempted';
    final userSelected = _selectedKey(item.scoreItem?['selected_answer'] ?? item.response?.selectedAnswer);
    final correctAns = _selectedKey(item.scoreItem?['correct_answer'] ?? q.correctAnswer);
    final timeSpent = (item.scoreItem?['time_spent_seconds'] as num?)?.toInt() ??
        item.response?.timeSpentSeconds ?? 0;
    final score = item.scoreItem?['score'];

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

    _questionKeys.putIfAbsent(index, () => GlobalKey());
    return Container(
      key: _questionKeys[index],
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Passage header if applicable
          if (item.passage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Text(
                "PASSAGE-BASED QUESTION",
                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.5),
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.passage!['title'] != null)
                    Text(item.passage!['title'].toString(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  Text(
                    item.passage!['body']?.toString() ?? item.passage!['content']?.toString() ?? '',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted, height: 1.5),
                  ),
                ],
              ),
            ),
          ],

          // Question header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: item.passage != null
                  ? BorderRadius.zero
                  : const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: outcomeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: outcomeColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    outcomeLabel,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: outcomeColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Q${index + 1}",
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted),
                ),
                if (item.questionVersion.createdByUserId != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Text(
                      "Your Question",
                      style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.amber[800]),
                    ),
                  ),
                ],
                if (timeSpent > 0) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.timer_outlined, size: 12, color: AppColors.muted),
                  const SizedBox(width: 2),
                  Text(
                    "${timeSpent}s",
                    style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.bold),
                  ),
                ],
                const Spacer(),
                if (score != null) ...[
                  Text(
                    "${double.tryParse(score.toString())?.toStringAsFixed(2) ?? score} pts",
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  const SizedBox(width: 12),
                ],
                InkWell(
                  onTap: () => _toggleBookmark(item.questionVersion.questionId, item.questionVersion.id),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _bookmarkedQuestionIds.contains(item.questionVersion.questionId)
                          ? AppColors.saffron.withOpacity(0.08)
                          : Colors.transparent,
                      border: Border.all(
                        color: _bookmarkedQuestionIds.contains(item.questionVersion.questionId)
                            ? AppColors.saffron.withOpacity(0.3)
                            : AppColors.line,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _bookmarkedQuestionIds.contains(item.questionVersion.questionId)
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: _bookmarkedQuestionIds.contains(item.questionVersion.questionId)
                              ? AppColors.saffron
                              : AppColors.muted,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _bookmarkedQuestionIds.contains(item.questionVersion.questionId)
                              ? "Marked for Revision"
                              : "Mark for Revision",
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _bookmarkedQuestionIds.contains(item.questionVersion.questionId)
                                ? AppColors.saffron
                                : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Question body
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MarkdownBody(
                  data: q.questionStatement,
                  styleSheet: MarkdownStyleSheet(
                    p: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.45),
                  ),
                ),
                if (q.supplementaryStatement != null && q.supplementaryStatement!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      q.supplementaryStatement!,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted, fontStyle: FontStyle.italic, height: 1.4),
                    ),
                  ),
                ],
                if (q.questionPrompt != null && q.questionPrompt!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    q.questionPrompt!,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                ],
                const SizedBox(height: 16),
                if (item.questionFormat.questionFamily != 'mains_subjective') ...[
                  // Options
                  ...q.options.asMap().entries.map((optEntry) {
                    final optIdx = optEntry.key;
                    final opt = optEntry.value;
                    final key = _optionKey(opt, optIdx);
                    final text = _optionText(opt, optIdx);
                    final isSelected = userSelected == key;
                    final isCorrect = correctAns == key;

                    Color borderCol = AppColors.line;
                    Color bgCol = Colors.white;
                    Widget? trailingIcon;

                    if (isCorrect) {
                      borderCol = AppColors.emerald;
                      bgCol = AppColors.emerald.withOpacity(0.05);
                      trailingIcon = const Icon(Icons.check_rounded, color: AppColors.emerald, size: 16);
                    } else if (isSelected) {
                      borderCol = AppColors.berry;
                      bgCol = AppColors.berry.withOpacity(0.05);
                      trailingIcon = const Icon(Icons.close_rounded, color: AppColors.berry, size: 16);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: bgCol,
                        border: Border.all(color: borderCol, width: 1.5),
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
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: (isCorrect || isSelected) ? Colors.white : AppColors.ink,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 3.0),
                              child: MarkdownBody(
                                data: text,
                                styleSheet: MarkdownStyleSheet(
                                  p: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (trailingIcon != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: trailingIcon,
                            ),
                        ],
                      ),
                    );
                  }),

                  // Explanation
                  if (q.explanation != null && q.explanation!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.civic.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.civic.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb_outline_rounded, size: 14, color: AppColors.civic),
                              const SizedBox(width: 6),
                              Text(
                                "EXPLANATION",
                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.civic, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          MarkdownBody(
                            data: q.explanation!,
                            styleSheet: MarkdownStyleSheet(
                              p: GoogleFonts.inter(fontSize: 12, color: AppColors.muted, height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else ...[
                  // Mains Subjective UI
                  _buildSubjectiveSection(item),

                  // Model Answer (if any)
                  if ((q.explanation != null && q.explanation!.trim().isNotEmpty) ||
                      (q.contentJson['model_answer'] != null && q.contentJson['model_answer'].toString().trim().isNotEmpty) ||
                      (q.contentJson['mains_details'] != null &&
                       q.contentJson['mains_details']['model_answer'] != null &&
                       q.contentJson['mains_details']['model_answer'].toString().trim().isNotEmpty)) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.civic.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.civic.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.assignment_rounded, size: 14, color: AppColors.civic),
                              const SizedBox(width: 6),
                              Text(
                                "UPSC REFERENCE MODEL ANSWER",
                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.civic, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          MarkdownBody(
                            data: (q.explanation != null && q.explanation!.trim().isNotEmpty)
                                ? q.explanation!
                                : (q.contentJson['model_answer'] != null && q.contentJson['model_answer'].toString().trim().isNotEmpty)
                                    ? q.contentJson['model_answer'].toString()
                                    : q.contentJson['mains_details']['model_answer'].toString(),
                            styleSheet: MarkdownStyleSheet(
                              p: GoogleFonts.inter(fontSize: 12, color: AppColors.muted, height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectiveSection(TestQuestionItem item) {
    final response = item.response;
    if (response == null) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.paper.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Text(
          "No answer response was submitted for this question.",
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.muted,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final isEvaluating = _evaluatingQuestionIds.contains(item.questionVersion.questionId) ||
        response.evaluationStatus == 'ai_evaluating';

    if (_editingAnswerId == response.id) {
      // Manual Evaluation Form
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.brand.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.brand.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rate_review_rounded, size: 16, color: AppColors.brand),
                const SizedBox(width: 8),
                Text(
                  "MANUAL EVALUATION & MARKS",
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brand,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Score Obtained", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _manualScoreController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: "e.g. 6.5",
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.muted.withOpacity(0.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.brand)),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.ink),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Maximum Marks", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _manualMaxScoreController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: "e.g. 10",
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.muted.withOpacity(0.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.brand)),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.ink),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text("Manually Checked Copy URL (Optional)", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted)),
            const SizedBox(height: 6),
            TextField(
              controller: _manualCheckedCopyUrlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: "https://example.com/checked-copy.pdf",
                hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.muted.withOpacity(0.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.brand)),
                fillColor: Colors.white,
                filled: true,
              ),
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Strengths (one per line)", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.emerald)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _manualStrengthsController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: "e.g. Good introduction\nAddressed core parts",
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.muted.withOpacity(0.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.emerald)),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.ink),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Improvement areas", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.berry)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _manualWeaknessesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: "e.g. Improve conclusion\nWord limit exceeded",
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.muted.withOpacity(0.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.berry)),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.ink),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text("Detailed Feedback Report (Markdown/HTML supported)", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted)),
            const SizedBox(height: 6),
            TextField(
              controller: _manualFeedbackController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Write detailed review, structure analysis, etc...",
                hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.muted.withOpacity(0.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.brand)),
                fillColor: Colors.white,
                filled: true,
              ),
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.ink),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isSavingManual ? null : _cancelManualEvaluation,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: const BorderSide(color: AppColors.line),
                  ),
                  child: Text(
                    "Cancel",
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.muted),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSavingManual ? null : _handleSaveManualEvaluation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSavingManual) ...[
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        "Save Evaluation",
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final canEvaluate = _checkCanEvaluate(_review!);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Submitted Answer Text
          if (response.studentAnswerText != null && response.studentAnswerText!.trim().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "SUBMITTED ANSWER TEXT",
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.muted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    response.studentAnswerText!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.ink,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Submitted Answer File URL
          if (response.answerFileUrl != null && response.answerFileUrl!.trim().isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final uri = Uri.parse(response.answerFileUrl!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.brand.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.brand),
                        const SizedBox(width: 8),
                        Text(
                          "Open Submitted Answer Copy",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brand,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Evaluation Report (if evaluated or needs_manual_review)
          if (response.evaluationStatus == 'evaluated' || response.evaluationStatus == 'needs_manual_review') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: response.evaluationStatus == 'evaluated'
                    ? AppColors.paper.withOpacity(0.5)
                    : AppColors.saffron.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: response.evaluationStatus == 'evaluated'
                      ? AppColors.line
                      : AppColors.saffron.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header row: title + score
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            response.evaluationStatus == 'evaluated'
                                ? Icons.auto_awesome_rounded
                                : Icons.pending_actions_rounded,
                            size: 16,
                            color: response.evaluationStatus == 'evaluated'
                                ? AppColors.brand
                                : AppColors.saffron,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            response.evaluationStatus == 'evaluated'
                                ? "AI EVALUATION REPORT"
                                : "PENDING MANUAL REVIEW",
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: response.evaluationStatus == 'evaluated'
                                  ? AppColors.ink
                                  : AppColors.saffron,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      if (response.score != null)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              response.score!.toStringAsFixed(1),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.brand,
                              ),
                            ),
                            Text(
                              "/${response.maxScore != null ? response.maxScore!.toStringAsFixed(0) : item.marks.toStringAsFixed(0)}",
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  // Needs manual review message
                  if (response.evaluationStatus == 'needs_manual_review') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.saffron.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "AI evaluation encountered an issue with this answer. A mentor will review and assign marks manually. You'll be notified once complete.",
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.ink, height: 1.4),
                      ),
                    ),
                  ],

                  if (response.evaluationStatus == 'evaluated') ...[
                    const SizedBox(height: 12),

                    // ── Marking Scheme Breakdown ──────────────────────────
                    Builder(builder: (context) {
                      final score = response.score ?? 0;
                      final maxScore = response.maxScore ?? item.marks;
                      final pct = maxScore > 0 ? (score / maxScore * 100).clamp(0.0, 100.0) : 0.0;
                      final grade = pct >= 80
                          ? ("Outstanding", AppColors.brand)
                          : pct >= 65
                              ? ("Good", AppColors.emerald)
                              : pct >= 50
                                  ? ("Average", AppColors.saffron)
                                  : ("Needs Work", AppColors.berry);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "MARKING SCHEME",
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.muted,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            "${score.toStringAsFixed(1)} / ${maxScore.toStringAsFixed(0)} marks",
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: grade.$2.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              grade.$1,
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: grade.$2,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: pct / 100,
                                          minHeight: 6,
                                          backgroundColor: AppColors.line,
                                          valueColor: AlwaysStoppedAnimation<Color>(grade.$2),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${pct.toStringAsFixed(0)}% of total marks secured",
                                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),

                    // Open checked copy with notes
                    if (response.checkedCopyUrl != null && response.checkedCopyUrl!.trim().isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () async {
                            final uri = Uri.parse(response.checkedCopyUrl!);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.brand.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.assignment_turned_in_rounded, size: 14, color: AppColors.brand),
                                const SizedBox(width: 8),
                                Text(
                                  "Open Checked Copy with Notes",
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.brand,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Strengths / Weaknesses Grid
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.emerald.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.emerald.withOpacity(0.1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "KEY STRENGTHS",
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.emerald,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (response.strengths != null && response.strengths!.isNotEmpty)
                                  ...response.strengths!.map((s) => Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text("• ", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.emerald)),
                                            Expanded(
                                              child: Text(
                                                s,
                                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.emerald, height: 1.3),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ))
                                else
                                  Text(
                                    "Structured layout maintained.",
                                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.emerald.withOpacity(0.7)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.berry.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.berry.withOpacity(0.1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "AREAS OF IMPROVEMENT",
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.berry,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (response.weaknesses != null && response.weaknesses!.isNotEmpty)
                                  ...response.weaknesses!.map((w) => Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text("• ", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.berry)),
                                            Expanded(
                                              child: Text(
                                                w,
                                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.berry, height: 1.3),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ))
                                else
                                  Text(
                                    "Link relevant commissions/case laws.",
                                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.berry.withOpacity(0.7)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Detailed Feedback Report ──────────────────────────
                    if (response.feedback != null && response.feedback!.trim().isNotEmpty) ...[
                      Text(
                        "DETAILED FEEDBACK REPORT",
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.muted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.line),
                        ),
                        // No maxHeight constraint — show full feedback
                        child: MarkdownBody(
                          data: response.feedback!,
                          styleSheet: MarkdownStyleSheet(
                            p: GoogleFonts.inter(fontSize: 13, color: AppColors.ink, height: 1.5),
                            h3: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink),
                            strong: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Tab: Topics ──────────────────────────────────────────────────────────

  List<_TopicPerformanceTreeNode> _buildTopicsTree(ResultReview review) {
    final Map<int, _TopicPerformanceTreeNode> nodeMap = {};
    for (var nodeJson in _rawTaxonomyNodes) {
      final int id = int.tryParse(nodeJson['id']?.toString() ?? '') ?? 0;
      final String name = nodeJson['name'] as String? ?? '';
      final String nodeType = nodeJson['node_type'] as String? ?? '';
      final int? parentId = nodeJson['parent_id'] != null ? int.tryParse(nodeJson['parent_id'].toString()) : null;
      final String? nodeContentType = nodeJson['content_type'] as String?;

      if (id != 0) {
        nodeMap[id] = _TopicPerformanceTreeNode(
          id: id,
          name: name,
          nodeType: nodeType,
          parentId: parentId,
          contentType: nodeContentType,
        );
      }
    }

    // Populate metrics from result's topic breakdowns
    for (final TopicBreakdown breakdown in review.topicBreakdowns ?? <TopicBreakdown>[]) {
      final int? nodeId = breakdown.taxonomyNodeId;
      if (nodeId != null && nodeMap.containsKey(nodeId)) {
        final node = nodeMap[nodeId]!;
        node.ownCorrectCount = node.ownCorrectCount + breakdown.correctCount;
        node.ownIncorrectCount = node.ownIncorrectCount + breakdown.incorrectCount;
        node.ownUnattemptedCount = node.ownUnattemptedCount + breakdown.unattemptedCount;
        node.ownTotalQuestions = node.ownTotalQuestions + breakdown.totalQuestions;
        node.ownTimeWeightedSeconds = node.ownTimeWeightedSeconds + (breakdown.avgTimeSeconds * breakdown.totalQuestions);
        node.ownAvgTimeSeconds = node.ownTotalQuestions > 0
            ? node.ownTimeWeightedSeconds / node.ownTotalQuestions
            : 0.0;
      }
    }

    final List<_TopicPerformanceTreeNode> rootNodes = [];
    for (var node in nodeMap.values) {
      if (node.parentId != null && nodeMap.containsKey(node.parentId)) {
        nodeMap[node.parentId]!.children.add(node);
      } else {
        rootNodes.add(node);
      }
    }

    for (var root in rootNodes) {
      root.calculateCumulativeMetrics();
    }

    // Filter to only show branches tested in this exam
    final filteredRoots = rootNodes.where((node) => node.totalQuestions > 0).toList();

    void filterChildren(_TopicPerformanceTreeNode node) {
      node.children.retainWhere((c) => c.totalQuestions > 0);
      for (var child in node.children) {
        filterChildren(child);
      }
    }
    for (var root in filteredRoots) {
      filterChildren(root);
    }

    void sortNodeAndChildren(_TopicPerformanceTreeNode node) {
      node.children.sort((a, b) => a.accuracy.compareTo(b.accuracy));
      for (var child in node.children) {
        sortNodeAndChildren(child);
      }
    }

    filteredRoots.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    for (var root in filteredRoots) {
      sortNodeAndChildren(root);
    }

    return filteredRoots;
  }

  String _topicNodeTypeLabel(String nodeType) {
    if (nodeType == 'source_bucket') return 'Source';
    if (nodeType.isEmpty) return 'Topic';
    return nodeType.replaceAll('_', ' ');
  }

  Color _topicAccuracyColor(double accuracy, {bool hasData = true}) {
    if (!hasData) return AppColors.muted;
    if (accuracy >= 0.7) return AppColors.emerald;
    if (accuracy >= 0.4) return AppColors.saffron;
    return AppColors.berry;
  }

  List<_TopicPerformanceTreeNode> _flattenTopicNodes(List<_TopicPerformanceTreeNode> roots) {
    final nodes = <_TopicPerformanceTreeNode>[];
    void visit(_TopicPerformanceTreeNode node) {
      nodes.add(node);
      for (final child in node.children) {
        visit(child);
      }
    }

    for (final root in roots) {
      visit(root);
    }
    return nodes;
  }

  Widget _buildTopicSummaryBanner(List<_TopicPerformanceTreeNode> roots) {
    final nodes = _flattenTopicNodes(roots).where((node) => node.totalQuestions > 0).toList();
    final totalQuestions = roots.fold<int>(0, (sum, node) => sum + node.totalQuestions);
    final correct = roots.fold<int>(0, (sum, node) => sum + node.correctCount);
    final incorrect = roots.fold<int>(0, (sum, node) => sum + node.incorrectCount);
    final skipped = roots.fold<int>(0, (sum, node) => sum + node.unattemptedCount);
    final answered = correct + incorrect;
    final accuracy = answered > 0 ? correct / answered : 0.0;
    final weakCount = nodes.where((node) => node.attemptedQuestions > 0 && node.accuracy < 0.5).length;
    final strongCount = nodes.where((node) => node.attemptedQuestions > 0 && node.accuracy >= 0.7).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: const [BoxShadow(color: Color(0x040F172A), offset: Offset(0, 6), blurRadius: 16)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.civic.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_tree_rounded, color: AppColors.civic, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Topic-wise result map", style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      "Shows cumulative performance at subject, topic, and subtopic levels.",
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTopicStatChip("Accuracy", "${(accuracy * 100).round()}%", _topicAccuracyColor(accuracy, hasData: answered > 0)),
              _buildTopicStatChip("Questions", totalQuestions.toString(), AppColors.civic),
              _buildTopicStatChip("Answered", answered.toString(), AppColors.brand),
              _buildTopicStatChip("Skipped", skipped.toString(), AppColors.saffron),
              _buildTopicStatChip("Weak", weakCount.toString(), AppColors.berry),
              _buildTopicStatChip("Strong", strongCount.toString(), AppColors.emerald),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopicStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _buildResultTopicNode(int depth, _TopicPerformanceTreeNode node) {
    final isExpanded = _expandedTopicNodes.contains(node.id);
    final hasChildren = node.children.isNotEmpty;
    final hasAnsweredData = node.attemptedQuestions > 0;
    final color = _topicAccuracyColor(node.accuracy, hasData: hasAnsweredData);
    final typeLabel = _topicNodeTypeLabel(node.nodeType);
    final indent = depth * 14.0;
    final icon = node.nodeType == 'subject'
        ? Icons.folder_open_rounded
        : (node.nodeType == 'topic' ? Icons.bookmark_border_rounded : Icons.radio_button_unchecked_rounded);

    final row = Container(
      margin: EdgeInsets.only(left: depth == 0 ? 0 : 8, top: 5, bottom: 5),
      padding: EdgeInsets.fromLTRB(12 + indent, 12, 12, 12),
      decoration: BoxDecoration(
        color: depth == 0 ? Colors.white : AppColors.paper.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isExpanded ? AppColors.civic.withOpacity(0.28) : AppColors.line, width: isExpanded ? 1.4 : 1),
      ),
      child: Row(
        children: [
          if (hasChildren)
            Icon(isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded, size: 19, color: AppColors.muted)
          else
            const SizedBox(width: 19),
          const SizedBox(width: 5),
          Icon(icon, size: depth == 0 ? 17 : 14, color: depth == 0 ? AppColors.civic : AppColors.muted),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        node.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: depth == 0 ? 13 : 12,
                          fontWeight: depth == 0 ? FontWeight.w800 : FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    _buildTopicLevelBadge(typeLabel),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "${node.correctCount}/${node.totalQuestions} correct-ready | ${node.unattemptedCount} skipped | Avg ${node.avgTimeSeconds.round()}s/Q",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    value: hasAnsweredData ? node.accuracy.clamp(0.0, 1.0).toDouble() : 0,
                    backgroundColor: AppColors.line.withOpacity(0.45),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  hasAnsweredData ? "${(node.accuracy * 100).round()}%" : "--",
                  style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  hasAnsweredData ? "${node.attemptedQuestions} ans" : "",
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: hasChildren
              ? () {
                  setState(() {
                    if (isExpanded) {
                      _expandedTopicNodes.remove(node.id);
                    } else {
                      _expandedTopicNodes.add(node.id);
                    }
                  });
                }
              : null,
          borderRadius: BorderRadius.circular(14),
          child: row,
        ),
        if (hasChildren && isExpanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Column(children: node.children.map((child) => _buildResultTopicNode(depth + 1, child)).toList()),
          ),
      ],
    );
  }

  Widget _buildTopicLevelBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.muted),
      ),
    );
  }

  Widget _buildTopicNodeWidget(int depth, _TopicPerformanceTreeNode node) {
    final bool isExpanded = _expandedTopicNodes.contains(node.id);
    final bool hasChildren = node.children.isNotEmpty;

    final Color accuracyColor = node.accuracy >= 0.7 
        ? AppColors.emerald 
        : (node.accuracy >= 0.4 ? AppColors.saffron : AppColors.berry);

    final double indent = depth * 16.0;
    final IconData nodeIcon = depth == 0 
        ? Icons.folder_open_rounded 
        : (depth == 1 ? Icons.bookmark_border_rounded : Icons.radio_button_unchecked_rounded);

    Widget nodeContent = Padding(
      padding: EdgeInsets.only(
        left: 12.0 + indent,
        right: 12.0,
        top: depth == 0 ? 12.0 : 8.0,
        bottom: depth == 0 ? 12.0 : 8.0,
      ),
      child: Row(
        children: [
          if (hasChildren)
            Icon(
              isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
              size: 18,
              color: AppColors.muted,
            )
          else
            const SizedBox(width: 18),
          const SizedBox(width: 4),
          Icon(
            nodeIcon,
            size: depth == 0 ? 16 : (depth == 1 ? 14 : 10),
            color: depth == 0 ? AppColors.civic : AppColors.muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.name,
                  style: GoogleFonts.inter(
                    fontSize: depth == 0 ? 13 : (depth == 1 ? 12 : 11),
                    fontWeight: depth == 0 ? FontWeight.w700 : (depth == 1 ? FontWeight.w600 : FontWeight.normal),
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${node.nodeType.toUpperCase()} • ${node.correctCount}/${node.totalQuestions} Correct  ·  Avg ${node.avgTimeSeconds.round()}s/Q",
                  style: GoogleFonts.inter(
                    fontSize: 9, 
                    color: AppColors.muted, 
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${(node.accuracy * 100).round()}% Accuracy",
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: accuracyColor,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: (60 * node.accuracy).clamp(0.0, 60.0),
                    height: 4,
                    decoration: BoxDecoration(
                      color: accuracyColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (depth == 0) {
      nodeContent = Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isExpanded ? AppColors.civic.withOpacity(0.3) : AppColors.line,
            width: isExpanded ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x040F172A),
              offset: Offset(0, 2),
              blurRadius: 6,
            )
          ],
        ),
        child: nodeContent,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: hasChildren ? () {
            setState(() {
              if (isExpanded) {
                _expandedTopicNodes.remove(node.id);
              } else {
                _expandedTopicNodes.add(node.id);
              }
            });
          } : null,
          borderRadius: BorderRadius.circular(12),
          child: nodeContent,
        ),
        if (hasChildren && isExpanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              children: node.children.map((child) => _buildTopicNodeWidget(depth + 1, child)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildTopicsTab(ResultReview review) {
    final roots = _buildTopicsTree(review);

    if (roots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              const Icon(Icons.track_changes_rounded, size: 48, color: AppColors.muted),
              const SizedBox(height: 16),
              Text("No topic breakdowns available.", style: GoogleFonts.inter(color: AppColors.muted, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopicSummaryBanner(roots),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _expandedTopicNodes.addAll(
                      _flattenTopicNodes(roots)
                          .where((node) => node.children.isNotEmpty)
                          .map((node) => node.id),
                    );
                  });
                },
                icon: const Icon(Icons.unfold_more_rounded, size: 16),
                label: const Text("Expand all"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _expandedTopicNodes.clear();
                  });
                },
                icon: const Icon(Icons.unfold_less_rounded, size: 16),
                label: const Text("Collapse"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.paper.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line, width: 1),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: roots.length,
            itemBuilder: (context, index) {
              return _buildResultTopicNode(0, roots[index]);
            },
          ),
        ),
        const SizedBox(height: 20),
        // Legend
        Wrap(
          spacing: 12,
          children: [
            _buildLegend(AppColors.berry, "Weak (<40%)"),
            _buildLegend(AppColors.saffron, "Moderate (40–70%)"),
            _buildLegend(AppColors.emerald, "Strong (≥70%)"),
          ],
        ),
      ],
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 10, width: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ─── Tab: Time ────────────────────────────────────────────────────────────

  Widget _buildTimeTab(ResultReview review) {
    final questions = review.questions;

    if (questions.isEmpty) {
      return const Center(child: Text("No time data available."));
    }

    final totalTimeSpent = questions.fold<int>(
      0,
      (sum, q) =>
          sum +
          ((q.scoreItem?['time_spent_seconds'] as num?)?.toInt() ??
              q.response?.timeSpentSeconds ??
              0),
    );

    final avgTime = questions.isNotEmpty ? totalTimeSpent / questions.length : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Time Analysis", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),

        // Time Summary stats
        Row(
          children: [
            Expanded(
              child: _buildTimeStatCard(
                "Total Duration",
                "${review.testTemplate.durationMinutes} min",
                Icons.timer_outlined,
                AppColors.civic,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTimeStatCard(
                "Time Spent",
                "${(totalTimeSpent / 60).toStringAsFixed(1)} min",
                Icons.timer,
                AppColors.saffron,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTimeStatCard(
                "Avg/Question",
                "${avgTime.toStringAsFixed(0)}s",
                Icons.speed_rounded,
                AppColors.brand,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Text("Per-Question Time Breakdown", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          "Highlighting questions where time exceeded 1.5x average (overtime)",
          style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Bar chart per question
        ...questions.asMap().entries.map((entry) {
          final idx = entry.key;
          final q = entry.value;
          final timeSpent = (q.scoreItem?['time_spent_seconds'] as num?)?.toInt() ??
              q.response?.timeSpentSeconds ??
              0;
          final outcome = q.scoreItem?['outcome'] as String?;
          final maxBar = questions.map((qq) {
            return (qq.scoreItem?['time_spent_seconds'] as num?)?.toInt() ??
                qq.response?.timeSpentSeconds ??
                0;
          }).reduce((a, b) => a > b ? a : b);

          final barPct = maxBar > 0 ? (timeSpent / maxBar).clamp(0.0, 1.0) : 0.0;
          Color barColor = AppColors.muted;
          if (outcome == 'correct') barColor = AppColors.emerald;
          if (outcome == 'incorrect') barColor = AppColors.berry;

          final isOvertime = timeSpent > (avgTime * 1.5);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isOvertime ? AppColors.saffron.withOpacity(0.5) : AppColors.line,
                width: isOvertime ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    "Q${idx + 1}",
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.ink),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.line.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: barPct,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isOvertime) ...[
                      const Icon(Icons.warning_amber_rounded, color: AppColors.saffron, size: 14),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      "${timeSpent}s",
                      style: GoogleFonts.inter(
                        fontSize: 11, 
                        fontWeight: FontWeight.bold, 
                        color: isOvertime ? AppColors.saffron : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: [
            _buildLegend(AppColors.emerald, "Correct"),
            _buildLegend(AppColors.berry, "Incorrect"),
            _buildLegend(AppColors.muted, "Unattempted"),
            _buildLegend(AppColors.saffron, "Overtime (>1.5x Avg)"),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x020F172A),
            offset: Offset(0, 4),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: AppColors.muted,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Score Gauge Widget ───────────────────────────────────────────────────────

class _ScoreGauge extends StatelessWidget {
  final double percentage;

  const _ScoreGauge({required this.percentage});

  @override
  Widget build(BuildContext context) {
    final color = percentage >= 70
        ? AppColors.emerald
        : percentage >= 40
            ? AppColors.saffron
            : AppColors.berry;

    return SizedBox(
      height: 110,
      width: 110,
      child: CustomPaint(
        painter: _GaugePainter(percentage: percentage.clamp(0.0, 100.0), color: color),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "${percentage.round()}%",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Text(
                "score",
                style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percentage;
  final Color color;

  _GaugePainter({required this.percentage, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;
    const startAngle = -pi / 2;
    final sweepAngle = 2 * pi * (percentage / 100);

    // Background track
    final trackPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.percentage != percentage || oldDelegate.color != color;
}

class _TopicPerformanceTreeNode {
  final int id;
  final String name;
  final String nodeType;
  final int? parentId;
  final String? contentType;

  int ownCorrectCount = 0;
  int ownIncorrectCount = 0;
  int ownUnattemptedCount = 0;
  int ownTotalQuestions = 0;
  double ownAvgTimeSeconds = 0.0;
  double ownTimeWeightedSeconds = 0.0;

  int correctCount = 0;
  int incorrectCount = 0;
  int unattemptedCount = 0;
  int totalQuestions = 0;
  double avgTimeSeconds = 0.0;

  final List<_TopicPerformanceTreeNode> children = [];

  _TopicPerformanceTreeNode({
    required this.id,
    required this.name,
    required this.nodeType,
    this.parentId,
    this.contentType,
  });

  int get attemptedQuestions => correctCount + incorrectCount;

  double get accuracy {
    if (attemptedQuestions == 0) return 0.0;
    return correctCount / attemptedQuestions;
  }

  void calculateCumulativeMetrics() {
    correctCount = ownCorrectCount;
    incorrectCount = ownIncorrectCount;
    unattemptedCount = ownUnattemptedCount;
    totalQuestions = ownTotalQuestions;
    double weightedTimeSum = ownAvgTimeSeconds * ownTotalQuestions;

    for (var child in children) {
      child.calculateCumulativeMetrics();
      correctCount = correctCount + child.correctCount;
      incorrectCount = incorrectCount + child.incorrectCount;
      unattemptedCount = unattemptedCount + child.unattemptedCount;
      totalQuestions = totalQuestions + child.totalQuestions;
      weightedTimeSum = weightedTimeSum + (child.avgTimeSeconds * child.totalQuestions);
    }

    avgTimeSeconds = totalQuestions > 0 ? weightedTimeSum / totalQuestions : 0.0;
  }
}
