import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/assessment_service.dart';
import '../models/assessment_models.dart';
import 'attempt_engine_screen.dart';
import 'custom_tests_list_screen.dart';

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
  final List<Map<String, dynamic>> _addedCategories = []; // List of {'node': node, 'count': count}
  final Map<int, int> _selectedQuantities = {};

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
      }
    } catch (e) {
      setState(() {
        _error = "Failed to fetch exam profiles: $e";
        _loadingExams = false;
      });
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
    roots.sort((a, b) => a.displayOrder.compareTo(b.displayOrder) == 0
        ? a.name.compareTo(b.name)
        : a.displayOrder.compareTo(b.displayOrder));

    setState(() {
      _activeTree = roots;
    });
  }

  void _sortChildren(_TreeNode node) {
    if (node.children.isNotEmpty) {
      node.children.sort((a, b) => a.displayOrder.compareTo(b.displayOrder) == 0
          ? a.name.compareTo(b.name)
          : a.displayOrder.compareTo(b.displayOrder));
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
      final index = _addedCategories.indexWhere((item) => item['node'].id == node.id);
      if (index >= 0) {
        final currentCount = _addedCategories[index]['count'] as int;
        _addedCategories[index]['count'] = min(currentCount + count, available);
      } else {
        _addedCategories.add({
          'node': node,
          'count': count,
        });
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
    return _addedCategories.fold(0, (sum, item) => sum + (item['count'] as int));
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
        const SnackBar(content: Text('Please add questions from at least one category')),
      );
      return;
    }

    final totalQs = _getTotalAddedQuestions();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    if (totalQs > 10 && !apiClient.hasEntitlement('assessment.premium_tests')) {
      _showPremiumLimitDialog();
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
        examLevelId: 1, // Fallback
        questionIds: allPickedQuestionIds,
        testType: _contentType == 'mains' ? 'mains_test' : 'sectional_test',
      );

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
        _error = "Failed to create custom test: $e";
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiClient = Provider.of<ApiClient>(context);
    final hasPremium = apiClient.hasEntitlement('assessment.premium_tests');
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(
          "Create Custom Test",
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
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_outlined, color: AppColors.civic),
            tooltip: "My Custom Tests",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CustomTestsListScreen(
                    contentType: _contentType,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _loadingExams
          ? const Center(child: CircularProgressIndicator(color: AppColors.civic))
          : Column(
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
                              border: Border.all(color: const Color(0xFFFFD8A8)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: Color(0xFFEA580C), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Free Tier: Custom tests are limited to 10 questions. Upgrade for unlimited questions.",
                                    style: GoogleFonts.inter(
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
                        // Title Input
                        Text(
                          "Test Name",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            hintText: "e.g. Ancient History revision",
                            hintStyle: GoogleFonts.inter(color: AppColors.muted, fontSize: 13),
                            fillColor: Colors.white,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.line),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.line),
                            ),
                          ),
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.ink),
                        ),
                        const SizedBox(height: 16),

                        // Exam Profile selector
                        Text(
                          "Exam Profile",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedExamId,
                              isExpanded: true,
                              items: _exams.map((exam) {
                                return DropdownMenuItem<int>(
                                  value: exam.id,
                                  child: Text(
                                    exam.name,
                                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.ink),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedExamId = val;
                                  });
                                  _fetchCategories();
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Content Type Selector (only if not passed)
                        if (widget.contentType == null) ...[
                          Text(
                            "Content Type",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
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
                          const SizedBox(height: 20),
                        ],

                        // Selected Categories summary
                        if (_addedCategories.isNotEmpty) ...[
                          Text(
                            "Selected Categories",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
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
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          "$count Qs",
                                          style: GoogleFonts.inter(
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Total Questions:",
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      "${_getTotalAddedQuestions()}",
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w900,
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

                        // Syllabus / Category tree builder
                        Text(
                          "Syllabus Filters",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_loadingCategories || _loadingCounts)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: CircularProgressIndicator(color: AppColors.civic),
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
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          _buildTreeNodes(_activeTree, 0),
                      ],
                    ),
                  ),
                ),
                _buildStickyBottomBar(hasPremium),
              ],
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
            style: GoogleFonts.inter(
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
    final bool isAdded = _addedCategories.any((item) => item['node'].id == node.id);

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
                      isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
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
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (available > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.civic.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "$available Qs",
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.civic,
                      ),
                    ),
                  )
                else
                  Text(
                    "No Qs",
                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.muted),
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
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.remove, size: 14, color: AppColors.ink),
                          onPressed: currentVal > 1
                              ? () => setState(() => _selectedQuantities[node.id] = currentVal - 1)
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            "$currentVal",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.add, size: 14, color: AppColors.ink),
                          onPressed: currentVal < available
                              ? () => setState(() => _selectedQuantities[node.id] = currentVal + 1)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _addQuantityToTest(node, available),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAdded ? AppColors.line : AppColors.civic,
                      foregroundColor: isAdded ? AppColors.ink : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isAdded ? "Add More" : "Add Qs",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
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
                  hasPremium ? "$totalQs Selected" : "$totalQs Selected / 10 Max",
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: (!hasPremium && totalQs > 10) ? AppColors.berry : AppColors.ink,
                  ),
                ),
                Text(
                  hasPremium ? "Unlimited (Premium Active)" : "Free Account Limit",
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: (!hasPremium && totalQs > 10) ? AppColors.berry : AppColors.muted,
                    fontWeight: (!hasPremium && totalQs > 10) ? FontWeight.bold : FontWeight.normal,
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
                onPressed: _submitting || totalQs == 0 ? null : _handleCreateCustomTest,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        children: [
                          Text(
                            "Create & Start",
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
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

  void _showPremiumLimitDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 10),
              Text(
                "Limit Exceeded",
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: Text(
            "Custom tests for free accounts are limited to a maximum of 10 questions. Upgrade to Assessment Premium for unlimited questions, sectional tests, and AI subjective grading.",
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
}
