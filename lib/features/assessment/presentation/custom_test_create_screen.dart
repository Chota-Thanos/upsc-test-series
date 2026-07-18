import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/tour/app_tour_service.dart';
import '../../../../core/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/assessment_service.dart';
import '../models/assessment_models.dart';
import 'attempt_engine_screen.dart';
import 'custom_tests_list_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class _TreeNode {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? imageUrl;
  final String nodeType;
  final int? parentId;
  final String? contentType;
  final int displayOrder;
  final List<_TreeNode> children;

  _TreeNode({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.imageUrl,
    required this.nodeType,
    this.parentId,
    this.contentType,
    this.displayOrder = 0,
    List<_TreeNode>? children,
  }) : children = children ?? [];
}

class CustomTestCreateScreen extends StatefulWidget {
  final String? contentType;
  const CustomTestCreateScreen({super.key, this.contentType});

  @override
  State<CustomTestCreateScreen> createState() => _CustomTestCreateScreenState();
}

class _CustomTestCreateScreenState extends State<CustomTestCreateScreen> {
  late AssessmentService _service;

  // Page Steps: 'name' = step 1 (enter test name), 'build' = step 2 (add questions)
  String _step = 'name';

  // Page States
  bool _loadingExams = true;
  bool _loadingCategories = false;
  bool _loadingCounts = false;
  bool _submitting = false;
  String? _error;

  List<Exam> _exams = [];
  int? _selectedExamId;
  late String _contentType;
  final TextEditingController _titleController = TextEditingController();

  // Categories & Question Counts States
  List<Map<String, dynamic>> _allNodes = [];
  List<_TreeNode> _activeTree = [];
  Map<int, int> _questionCounts = {};
  final Set<int> _expandedNodes = {};

  // Basket for Custom Test
  final List<Map<String, dynamic>> _addedCategories =
      []; // List of {'node': node, 'count': count}
  final Map<int, int> _selectedQuantities = {};

  // Tour
  final GlobalKey _tourCategoriesKey = GlobalKey();
  final GlobalKey _tourBottomBarKey = GlobalKey();
  bool _tourChecked = false;

  @override
  void initState() {
    super.initState();
    _contentType = widget.contentType ?? 'gk';
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = AssessmentService(apiClient: apiClient);
    _fetchInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _loadingExams = true;
      _error = null;
    });

    try {
      final exams = await _service.getAssessmentExams();
      setState(() {
        _exams = exams;
        _loadingExams = false;
      });

      if (exams.isNotEmpty) {
        _selectedExamId = exams.first.id;
        await _fetchCategories();
        await _restoreGuestSavedCustomTest();
      }
    } catch (e) {
      setState(() {
        _error = "Failed to fetch exam profiles: $e";
        _loadingExams = false;
      });
    }
  }

  Future<void> _restoreGuestSavedCustomTest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('guest_saved_custom_test');
      if (raw == null) return;

      final config = jsonDecode(raw) as Map<String, dynamic>;
      final savedTitle = config['title'] as String? ?? '';
      final savedExamId = config['selectedExamId'] as int?;
      final savedContentType = config['contentType'] as String? ?? 'gk';
      final savedCategories = config['addedCategories'] as List? ?? [];

      if (mounted) {
        setState(() {
          _titleController.text = savedTitle;
          if (savedExamId != null) _selectedExamId = savedExamId;
          _contentType = savedContentType;

          _addedCategories.clear();
          for (var cat in savedCategories) {
            final node = _TreeNode(
              id: cat['id'] as int,
              name: cat['name'] as String? ?? '',
              slug: cat['slug'] as String? ?? '',
              nodeType: cat['nodeType'] as String? ?? '',
              parentId: cat['parentId'] as int?,
              contentType: cat['contentType'] as String?,
            );
            final count = cat['count'] as int;
            _addedCategories.add({'node': node, 'count': count});
            _selectedQuantities[node.id] = count;
          }
        });
      }

      await prefs.remove('guest_saved_custom_test');
    } catch (e) {
      debugPrint("Failed to restore guest saved custom test: $e");
    }
  }

  Future<void> _fetchCategories() async {
    if (_selectedExamId == null) return;
    setState(() {
      _loadingCategories = true;
      _addedCategories.clear();
      _selectedQuantities.clear();
      _expandedNodes.clear();
    });

    try {
      final nodes = _contentType == 'mains'
          ? await _service.getMainsTaxonomyNodes(_selectedExamId!)
          : await _service.getTaxonomyNodes(_selectedExamId!);

      setState(() {
        _allNodes = nodes;
        _loadingCategories = false;
      });

      _buildActiveTree();
      await _fetchCounts();
    } catch (e) {
      setState(() {
        _error = "Failed to load categories: $e";
        _loadingCategories = false;
      });
    }
  }

  Future<void> _fetchCounts() async {
    if (_selectedExamId == null) return;
    setState(() => _loadingCounts = true);
    try {
      final String family = _contentType == 'mains'
          ? 'mains_subjective'
          : 'objective';
      final counts = await _service.getQuestionCounts(_selectedExamId!, family);
      final Map<int, int> newCounts = {};
      for (var c in counts) {
        final nodeId = int.tryParse(c['node_id']?.toString() ?? '');
        if (nodeId == null) continue;
        newCounts[nodeId] =
            int.tryParse(c['question_count']?.toString() ?? '') ?? 0;
      }
      setState(() {
        _questionCounts = newCounts;
        _loadingCounts = false;
      });
    } catch (e) {
      debugPrint("Failed to load question counts: $e");
      setState(() => _loadingCounts = false);
    }
  }

  void _buildActiveTree() {
    List<Map<String, dynamic>> sourceNodes;
    if (_contentType == 'mains') {
      sourceNodes = _allNodes;
    } else {
      sourceNodes = _allNodes
          .where((n) => n['content_type'] == _contentType)
          .toList();
    }

    final Map<int, _TreeNode> nodeMap = {};
    final List<_TreeNode> roots = [];

    for (var n in sourceNodes) {
      final id = int.tryParse(n['id']?.toString() ?? '') ?? 0;
      nodeMap[id] = _TreeNode(
        id: id,
        name: n['name'] as String? ?? '',
        slug: n['slug'] as String? ?? '',
        description: n['description'] as String?,
        imageUrl: n['image_url'] as String?,
        nodeType: n['node_type'] as String? ?? '',
        parentId: n['parent_id'] != null
            ? int.tryParse(n['parent_id'].toString())
            : null,
        contentType: n['content_type'] as String?,
        displayOrder: int.tryParse(n['display_order']?.toString() ?? '') ?? 0,
      );
    }

    for (var n in sourceNodes) {
      final current = nodeMap[int.tryParse(n['id']?.toString() ?? '') ?? 0];
      if (current == null) continue;

      if (current.parentId != null) {
        final parent = nodeMap[current.parentId];
        if (parent != null) {
          parent.children.add(current);
          continue;
        }
      }
      roots.add(current);
    }

    // Sort children
    for (var root in roots) {
      _sortChildren(root);
    }
    roots.sort(
      (a, b) => a.displayOrder.compareTo(b.displayOrder) == 0
          ? a.name.compareTo(b.name)
          : a.displayOrder.compareTo(b.displayOrder),
    );

    setState(() {
      _activeTree = roots;
      // Auto-expand all root (first-level) nodes
      _expandedNodes.addAll(roots.map((n) => n.id));
    });
  }

  void _sortChildren(_TreeNode node) {
    if (node.children.isNotEmpty) {
      node.children.sort(
        (a, b) => a.displayOrder.compareTo(b.displayOrder) == 0
            ? a.name.compareTo(b.name)
            : a.displayOrder.compareTo(b.displayOrder),
      );
      for (var child in node.children) {
        _sortChildren(child);
      }
    }
  }

  int _getCategoryQuantity(int nodeId, int available) {
    if (!_selectedQuantities.containsKey(nodeId)) {
      _selectedQuantities[nodeId] = min(10, available);
    }
    return _selectedQuantities[nodeId]!;
  }

  void _addQuantityToTest(_TreeNode node, int available) {
    final count = _getCategoryQuantity(node.id, available);
    if (count <= 0) return;

    setState(() {
      final index = _addedCategories.indexWhere(
        (item) => item['node'].id == node.id,
      );
      if (index >= 0) {
        final currentCount = _addedCategories[index]['count'] as int;
        _addedCategories[index]['count'] = min(currentCount + count, available);
      } else {
        _addedCategories.add({'node': node, 'count': count});
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Added $count questions from ${node.name}"),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _removeCategory(int nodeId) {
    setState(() {
      _addedCategories.removeWhere((item) => item['node'].id == nodeId);
    });
  }

  int _getTotalAddedQuestions() {
    return _addedCategories.fold(
      0,
      (sum, item) => sum + (item['count'] as int),
    );
  }

  Future<void> _handleCreateCustomTest() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a test title')),
      );
      return;
    }

    if (_addedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add questions from at least one category'),
        ),
      );
      return;
    }

    final totalQs = _getTotalAddedQuestions();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    final hasPremium = apiClient.hasEntitlement('assessment.premium_tests');

    // Guests can build and start a real test too (server caps them at 10
    // questions, same as the free-tier check below) — no sign-in wall here.
    if (totalQs > _questionCap(hasPremium)) {
      _showPremiumLimitDialog(hasPremium);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final List<int> allPickedQuestionIds = [];

      for (var item in _addedCategories) {
        final node = item['node'] as _TreeNode;
        final count = item['count'] as int;

        final List<int> subjectNodeIds = [];
        final List<int> topicNodeIds = [];

        if (_contentType == 'mains') {
          if (node.nodeType == 'paper') {
            subjectNodeIds.add(node.id);
          } else {
            topicNodeIds.add(node.id);
          }
        } else {
          if (node.nodeType == 'subject') {
            subjectNodeIds.add(node.id);
          } else if (node.nodeType == 'topic') {
            topicNodeIds.add(node.id);
          }
        }

        List<Question> qs;
        if (_contentType == 'mains') {
          qs = await _service.getMainsQuestions(
            examId: _selectedExamId!,
            topicNodeId: topicNodeIds.isNotEmpty ? topicNodeIds.first : null,
          );
        } else {
          qs = await _service.getQuestions(
            examId: _selectedExamId!,
            contentType: _contentType,
            subjectNodeIds: subjectNodeIds.isNotEmpty ? subjectNodeIds : null,
            topicNodeIds: topicNodeIds.isNotEmpty ? topicNodeIds : null,
          );
        }

        if (qs.isNotEmpty) {
          final shuffled = List<Question>.from(qs)..shuffle();
          final picked = shuffled
              .take(min(count, shuffled.length))
              .map((q) => q.id)
              .toList();
          allPickedQuestionIds.addAll(picked);
        }
      }

      if (allPickedQuestionIds.isEmpty) {
        throw Exception("No questions found in selected categories.");
      }

      final templateId = await _service.createUserCustomTest(
        title: _titleController.text.trim(),
        examId: _selectedExamId!,
        contentType: _contentType,
        questionIds: allPickedQuestionIds,
        testType: _contentType == 'mains' ? 'mains_test' : 'sectional_test',
      );

      final attemptId = await _service.startAttempt(templateId);

      if (apiClient.isGuestMode) {
        await apiClient.setPendingGuestClaim(attemptId);
      }

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
        _error = "Failed to create custom test: $e";
        _submitting = false;
      });
    }
  }

  void _startBuildStepTour(BuildContext ctx) {
    ShowCaseWidget.of(
      ctx,
    ).startShowCase([_tourCategoriesKey, _tourBottomBarKey]);
  }

  Future<void> _maybeAutoStartTour(BuildContext ctx) async {
    if (await AppTourService.shouldShowTour(AppTourService.createScreenKey)) {
      await AppTourService.markTourSeen(AppTourService.createScreenKey);
      if (mounted) _startBuildStepTour(ctx);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (ctx) {
        final apiClient = Provider.of<ApiClient>(context);
        final hasPremium = apiClient.hasEntitlement('assessment.premium_tests');

        if (_step == 'name') {
          return _buildNameStep();
        }

        // Build step: check tour first time we arrive here
        if (!_tourChecked) {
          _tourChecked = true;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _maybeAutoStartTour(ctx),
          );
        }

        return _buildBuildStep(ctx, hasPremium);
      },
    );
  }

  Widget _buildBuildStep(BuildContext ctx, bool hasPremium) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _titleController.text.isEmpty
                  ? "Custom Test"
                  : _titleController.text,
              style: AppTypography.title.copyWith(fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              "Adding questions",
              style: AppTypography.caption.copyWith(fontSize: 11),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          onPressed: () => setState(() => _step = 'name'),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.map_outlined,
              color: AppColors.civic,
              size: 20,
            ),
            tooltip: "App Tour",
            onPressed: () => _startBuildStepTour(ctx),
          ),
          IconButton(
            icon: const Icon(Icons.assignment_outlined, color: AppColors.civic),
            tooltip: "My Custom Tests",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CustomTestsListScreen(contentType: _contentType),
                ),
              );
            },
          ),
        ],
      ),
      body: _loadingExams
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.civic),
            )
          : Column(
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!hasPremium) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFFD8A8),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: Color(0xFFEA580C),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Free Tier: ${_contentType == 'mains' ? 'Mains' : 'GK/CSAT'} tests are limited to ${_questionCap(false)} questions. Upgrade to Premium for up to ${_questionCap(true)}.",
                                    style: AppTypography.body.copyWith(
                                      color: const Color(0xFF9A3412),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Selected Categories summary
                        if (_addedCategories.isNotEmpty) ...[
                          // Test name header above the basket
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppColors.civic.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.civic.withOpacity(0.12),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.bookmark_rounded,
                                  size: 14,
                                  color: AppColors.civic,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _titleController.text,
                                    style: AppTypography.title.copyWith(
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "Questions Added",
                            style: AppTypography.eyebrowLarge.copyWith(
                              fontSize: 10,
                              color: AppColors.muted,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Column(
                              children: [
                                ..._addedCategories.map((item) {
                                  final node = item['node'] as _TreeNode;
                                  final count = item['count'] as int;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            node.name,
                                            style: AppTypography.body.copyWith(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          "$count Qs",
                                          style: AppTypography.body.copyWith(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.civic,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        GestureDetector(
                                          onTap: () => _removeCategory(node.id),
                                          child: const Icon(
                                            Icons.remove_circle_outline,
                                            color: AppColors.berry,
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const Divider(color: AppColors.line),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Total Questions:",
                                      style: AppTypography.body.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      "${_getTotalAddedQuestions()}",
                                      style: AppTypography.cardTitle.copyWith(
                                        fontSize: 15,
                                        color: AppColors.civic,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Content type selector above categories
                        if (widget.contentType == null) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Content Type",
                            style: AppTypography.eyebrowLarge.copyWith(
                              fontSize: 10,
                              color: AppColors.muted,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildChoiceChip(
                                  label: "General Studies",
                                  isSelected: _contentType == 'gk',
                                  onTap: () {
                                    setState(() => _contentType = 'gk');
                                    _fetchCategories();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildChoiceChip(
                                  label: "CSAT",
                                  isSelected: _contentType == 'aptitude',
                                  onTap: () {
                                    setState(() => _contentType = 'aptitude');
                                    _fetchCategories();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildChoiceChip(
                                  label: "Mains",
                                  isSelected: _contentType == 'mains',
                                  onTap: () {
                                    setState(() => _contentType = 'mains');
                                    _fetchCategories();
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Syllabus / Category tree builder
                        Showcase(
                          key: _tourCategoriesKey,
                          title: "Browse & Add Questions",
                          description:
                              "Expand any subject to see its topics, then tap the quantity stepper and 'Add Qs' to include them in your test.",
                          targetBorderRadius: BorderRadius.circular(8),
                          child: Text(
                            "Browse & Add Questions",
                            style: AppTypography.sectionHeader.copyWith(
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_loadingCategories || _loadingCounts)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: CircularProgressIndicator(
                                color: AppColors.civic,
                              ),
                            ),
                          )
                        else if (_activeTree.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Text(
                              "No syllabus categories available for selected exam.",
                              style: AppTypography.body.copyWith(fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          _buildTreeNodes(_activeTree, 0),
                      ],
                    ),
                  ),
                ),
                Showcase(
                  key: _tourBottomBarKey,
                  title: "Create & Start Your Test",
                  description:
                      "Once you've added questions, tap 'Create & Start' to generate your test and begin immediately.",
                  targetBorderRadius: BorderRadius.circular(16),
                  child: _buildStickyBottomBar(hasPremium),
                ),
              ],
            ),
    );
  }

  Widget _buildNameStep() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  height: 72,
                  width: 72,
                  decoration: BoxDecoration(
                    color: AppColors.civic.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.civic,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Name your test",
                  style: AppTypography.display.copyWith(
                    fontSize: 26,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Give your custom practice test a name.\nYou'll pick topics on the next step.",
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                // Name input card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "TEST NAME",
                        style: AppTypography.eyebrowLarge.copyWith(
                          fontSize: 10,
                          color: AppColors.muted,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _titleController,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (_titleController.text.trim().isNotEmpty) {
                            setState(() => _step = 'build');
                          }
                        },
                        decoration: InputDecoration(
                          hintText: "e.g. Ancient History Focus Test",
                          hintStyle: AppTypography.body.copyWith(fontSize: 14),
                          fillColor: AppColors.paper,
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.line),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.line),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.civic,
                              width: 2,
                            ),
                          ),
                        ),
                        style: AppTypography.body.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _titleController.text.trim().isEmpty
                              ? null
                              : () {
                                  setState(() => _step = 'build');
                                },
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                          label: Text(
                            "Start Building My Test",
                            style: AppTypography.button.copyWith(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.ink,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          "You can rename it later",
                          style: AppTypography.caption.copyWith(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "← Back",
                    style: AppTypography.body.copyWith(
                      color: const Color(0xFF94A3B8),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? AppColors.civic.withOpacity(0.1) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.civic : AppColors.line,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.body.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected ? AppColors.civic : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTreeNodes(List<_TreeNode> nodes, int depth) {
    return Column(
      children: nodes.map((node) {
        final bool hasChildren = node.children.isNotEmpty;
        final bool isExpanded = _expandedNodes.contains(node.id);
        final int available = _questionCounts[node.id] ?? 0;

        return Column(
          children: [
            _buildCategoryRow(
              node: node,
              depth: depth,
              hasChildren: hasChildren,
              isExpanded: isExpanded,
              available: available,
            ),
            if (isExpanded && hasChildren)
              _buildTreeNodes(node.children, depth + 1),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCategoryRow({
    required _TreeNode node,
    required int depth,
    required bool hasChildren,
    required bool isExpanded,
    required int available,
  }) {
    final currentVal = _getCategoryQuantity(node.id, available);
    final bool isAdded = _addedCategories.any(
      (item) => item['node'].id == node.id,
    );

    return Container(
      margin: EdgeInsets.only(left: depth * 16.0, bottom: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (hasChildren)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_expandedNodes.contains(node.id)) {
                          _expandedNodes.remove(node.id);
                        } else {
                          _expandedNodes.add(node.id);
                        }
                      });
                    },
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      color: AppColors.muted,
                      size: 20,
                    ),
                  )
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    node.name,
                    style: AppTypography.cardTitle.copyWith(fontSize: 13),
                  ),
                ),
                if (available > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.civic.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "$available Qs",
                      style: AppTypography.eyebrowLarge.copyWith(
                        fontSize: 10,
                        letterSpacing: 0,
                      ),
                    ),
                  )
                else
                  Text(
                    "No Qs",
                    style: AppTypography.caption.copyWith(fontSize: 10),
                  ),
              ],
            ),
            if (available > 0) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.remove,
                            size: 14,
                            color: AppColors.ink,
                          ),
                          onPressed: currentVal > 1
                              ? () => setState(
                                  () => _selectedQuantities[node.id] =
                                      currentVal - 1,
                                )
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            "$currentVal",
                            style: AppTypography.cardTitle.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.add,
                            size: 14,
                            color: AppColors.ink,
                          ),
                          onPressed: currentVal < available
                              ? () => setState(
                                  () => _selectedQuantities[node.id] =
                                      currentVal + 1,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _addQuantityToTest(node, available),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAdded
                          ? AppColors.line
                          : AppColors.civic,
                      foregroundColor: isAdded ? AppColors.ink : Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isAdded ? "Add More" : "Add Qs",
                      style: AppTypography.button.copyWith(
                        fontSize: 11,
                        color: isAdded ? AppColors.ink : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStickyBottomBar(bool hasPremium) {
    final int totalQs = _getTotalAddedQuestions();
    final int cap = _questionCap(hasPremium);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$totalQs Selected / $cap Max",
                  style: AppTypography.cardTitle.copyWith(
                    fontSize: 15,
                    color: totalQs > cap ? AppColors.berry : AppColors.ink,
                  ),
                ),
                Text(
                  hasPremium ? "Premium Limit" : "Free Account Limit",
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    color: totalQs > cap ? AppColors.berry : AppColors.muted,
                    fontWeight: totalQs > cap
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.civic,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  elevation: 0,
                ),
                onPressed: _submitting || totalQs == 0
                    ? null
                    : _handleCreateCustomTest,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        children: [
                          Text(
                            "Create & Start",
                            style: AppTypography.button.copyWith(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.play_arrow_rounded, size: 18),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _questionCap(bool hasPremium) {
    final isMains = _contentType == 'mains';
    if (hasPremium) return isMains ? 25 : 100;
    return isMains ? 10 : 50;
  }

  void _showPremiumLimitDialog(bool hasPremium) {
    final cap = _questionCap(hasPremium);
    final kind = _contentType == 'mains' ? 'Mains' : 'GK/CSAT';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 10),
              Text(
                "Limit Exceeded",
                style: AppTypography.cardTitle.copyWith(fontSize: 16),
              ),
            ],
          ),
          content: Text(
            hasPremium
                ? "$kind tests are limited to a maximum of $cap questions, even on Assessment Premium. Remove a few questions to continue."
                : "$kind tests for free accounts are limited to a maximum of $cap questions. Upgrade to Assessment Premium for a higher limit ($kind: ${_contentType == 'mains' ? 25 : 100} questions) plus AI subjective grading.",
            style: AppTypography.body.copyWith(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                hasPremium ? "OK" : "Cancel",
                style: AppTypography.button.copyWith(color: Colors.grey),
              ),
            ),
            if (!hasPremium)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  final url = Uri.parse("${ApiConstants.webAppUrl}/pricing");
                  if (!await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication,
                  )) {
                    debugPrint("Could not launch $url");
                  }
                },
                child: Text(
                  "View Plans",
                  style: AppTypography.button.copyWith(color: Colors.white),
                ),
              ),
          ],
        );
      },
    );
  }
}
