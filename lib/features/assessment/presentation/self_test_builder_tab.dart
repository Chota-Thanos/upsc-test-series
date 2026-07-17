import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/tour/app_tour_service.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/widgets/premium_lock_overlay.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/assessment_service.dart';
import '../models/assessment_models.dart';
import 'attempt_engine_screen.dart';
import 'custom_test_create_screen.dart';
import 'custom_tests_list_screen.dart';
import 'ai_based_parsing_screen.dart';

part 'category_drill_down_screen.dart';

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
  final bool isUserNode;

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
    this.isUserNode = false,
  }) : children = children ?? [];
}

class SelfTestBuilderTab extends StatefulWidget {
  final String? contentType;
  final int? rootNodeId;
  final bool isRevisionMode;
  final int? testTemplateId;
  // Whether this specific tab is actually on screen right now — TabBarView
  // pre-builds neighbouring tabs, so this must be checked before auto-
  // starting the tour (see ContentTypeScreen).
  final bool isActive;

  const SelfTestBuilderTab({
    super.key,
    this.contentType,
    this.rootNodeId,
    this.isRevisionMode = false,
    this.testTemplateId,
    this.isActive = true,
  });

  @override
  State<SelfTestBuilderTab> createState() => _SelfTestBuilderTabState();
}

class _SelfTestBuilderTabState extends State<SelfTestBuilderTab> {
  late AssessmentService _service;
  bool _loading = true;
  String? _error;

  List<Exam> _exams = [];
  int? _selectedExamId;
  List<ExamLevel> _examLevels = [];

  String _activeTab = 'gk'; // gk, aptitude, mains

  List<Map<String, dynamic>> _objNodesRaw = [];
  List<Map<String, dynamic>> _mainsNodesRaw = [];
  Map<int, int> _questionCounts = {};
  Map<int, int> _userQuestionCounts = {};

  List<_TreeNode> _activeTree = [];
  Set<int> _expandedNodes = {};
  final Map<int, int> _selectedQuantities = {};

  // Category browser: top-level nodes render as a tab strip; selecting a tab
  // shows its children inline below via a breadcrumb, drilling deeper on the
  // same screen instead of pushing a new one.
  int? _browseActiveSubjectId;
  List<int> _browseDrillPath = [];
  Map<String, List<int>> _exclusionsMap = {'objective': [], 'mains': []};

  // Cart for compiled test
  List<Map<String, dynamic>> _compiledItems = [];

  // Bookmarks revision states
  List<dynamic> _bookmarks = [];
  bool _loadingBookmarks = false;
  final Set<int> _selectedBookmarkIds = {};
  bool _compiling = false;
  int? _selectedRevisionNodeId;
  bool _isCartExpanded = false;
  final _customTestNameController = TextEditingController(text: "My Custom Practice Test");
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // Tour — content-type-aware walkthrough of the real builder (see AppTourService)
  final GlobalKey _tourBrowseKey = GlobalKey();
  final GlobalKey _tourAddKey = GlobalKey();
  bool _tourChecked = false;

  @override
  void dispose() {
    _customTestNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SelfTestBuilderTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      // Only now actually on screen — re-run the first-visit tour check.
      _tourChecked = false;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.isRevisionMode) {
      _activeTab = 'revision';
    } else if (widget.contentType != null) {
      _activeTab = widget.contentType!;
    }
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = AssessmentService(apiClient: apiClient);
    _initData();
  }

  Future<void> _initData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final exams = await _service.getAssessmentExams();
      if (!mounted) return;
      if (exams.isNotEmpty) {
        _exams = exams;
        _selectedExamId = exams.first.id;
        // Fetched rather than hardcoded — exam_levels are auto-incremented ids
        // that can differ between environments (e.g. local dev vs production),
        // so a hardcoded id here previously caused a foreign-key error whenever
        // it didn't match the actual row id on the server being hit.
        try {
          _examLevels = await _service.getAssessmentExamLevels(_selectedExamId!);
        } catch (e) {
          debugPrint("Error loading exam levels: $e");
        }
        await _loadSyllabus();
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadSyllabus() async {
    if (_selectedExamId == null) return;
    setState(() => _loading = true);
    try {
      final objNodes = await _service.getTaxonomyNodes(_selectedExamId!);
      final mainsNodes = await _service.getMainsTaxonomyNodes(_selectedExamId!);
      _objNodesRaw = objNodes;
      _mainsNodesRaw = mainsNodes;

      // Load user syllabus exclusions (guests have no personalized syllabus)
      final apiClient = Provider.of<ApiClient>(context, listen: false);
      if (!apiClient.isGuestMode) {
        try {
          final exclusions = await _service.getExcludedTaxonomyNodes();
          _exclusionsMap = exclusions;
        } catch (e) {
          debugPrint("Error loading exclusions in app: $e");
        }
      }

      await _loadCounts();
      if (!mounted) return;
      _buildActiveTree();

      if (_activeTab == 'revision') {
        await _loadBookmarks();
      }

      if (!mounted) return;
      setState(() {
        _compiledItems.clear();
        _selectedQuantities.clear();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Could not load syllabus structure.";
        _loading = false;
      });
    }
  }

  Future<void> _loadCounts() async {
    if (_selectedExamId == null) return;
    try {
      final String family = _activeTab == 'mains'
          ? 'mains_subjective'
          : 'objective';
      final counts = await _service.getQuestionCounts(_selectedExamId!, family);
      final Map<int, int> newCounts = {};
      final Map<int, int> newUserCounts = {};
      for (var c in counts) {
        final nodeId = int.tryParse(c['node_id']?.toString() ?? '');
        if (nodeId == null) continue;
        newCounts[nodeId] =
            int.tryParse(c['question_count']?.toString() ?? '') ?? 0;
        newUserCounts[nodeId] =
            int.tryParse(c['user_question_count']?.toString() ?? '') ?? 0;
      }
      if (!mounted) return;
      setState(() {
        _questionCounts = newCounts;
        _userQuestionCounts = newUserCounts;
      });
    } catch (e) {
      debugPrint("Failed to load counts: $e");
    }
  }

  void _buildActiveTree() {
    List<Map<String, dynamic>> sourceNodes;
    if (_activeTab == 'gk') {
      sourceNodes = _objNodesRaw
          .where((n) => n['content_type'] == 'gk')
          .toList();
    } else if (_activeTab == 'aptitude') {
      sourceNodes = _objNodesRaw
          .where((n) => n['content_type'] == 'aptitude')
          .toList();
    } else {
      sourceNodes = _mainsNodesRaw; // or filtered
    }

    // Apply user exclusions recursively
    final exclusions = _activeTab == 'mains'
        ? (_exclusionsMap['mains'] ?? [])
        : (_exclusionsMap['objective'] ?? []);

    if (exclusions.isNotEmpty) {
      final excludedSet = Set<int>.from(exclusions);
      bool changed = true;
      while (changed) {
        changed = false;
        for (var n in sourceNodes) {
          final id = int.tryParse(n['id']?.toString() ?? '') ?? 0;
          final parentId = n['parent_id'] != null
              ? int.tryParse(n['parent_id'].toString())
              : null;
          if (parentId != null && excludedSet.contains(parentId) && !excludedSet.contains(id)) {
            excludedSet.add(id);
            changed = true;
          }
        }
      }
      sourceNodes = sourceNodes
          .where((n) => !excludedSet.contains(int.tryParse(n['id']?.toString() ?? '') ?? 0))
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

    // Inject virtual user question nodes under categories
    for (var node in nodeMap.values) {
      final userQuestionsCount = _userQuestionCounts[node.id] ?? 0;
      if (userQuestionsCount > 0) {
        final userNode = _TreeNode(
          id: -node.id,
          name: "Your Questions",
          slug: "user-questions",
          nodeType: "user_questions",
          parentId: node.id,
          displayOrder: 9999,
          isUserNode: true,
        );
        node.children.add(userNode);
      }
    }

    // Sort
    void sortChildren(_TreeNode node) {
      node.children.sort(
        (a, b) => a.displayOrder.compareTo(b.displayOrder) != 0
            ? a.displayOrder.compareTo(b.displayOrder)
            : a.name.compareTo(b.name),
      );
      for (var child in node.children) {
        sortChildren(child);
      }
    }

    roots.sort(
      (a, b) => a.displayOrder.compareTo(b.displayOrder) != 0
          ? a.displayOrder.compareTo(b.displayOrder)
          : a.name.compareTo(b.name),
    );
    for (var root in roots) {
      sortChildren(root);
    }

    _expandedNodes.clear(); // Clear old expansion state when tree rebuilds
    _browseActiveSubjectId = null; // Node ids belong to the old tree — re-pick a tab below
    _browseDrillPath = [];

    if (widget.rootNodeId != null) {
      final rootNode = nodeMap[widget.rootNodeId];
      if (rootNode != null) {
        rootNode.children.sort(
          (a, b) => a.displayOrder.compareTo(b.displayOrder) != 0
              ? a.displayOrder.compareTo(b.displayOrder)
              : a.name.compareTo(b.name),
        );
        for (var child in rootNode.children) {
          sortChildren(child);
        }
        setState(() {
          _activeTree = rootNode.children;
          // Auto-expand the first 2 levels of subcategories
          for (var child in _activeTree) {
            _expandedNodes.add(child.id);
            for (var subChild in child.children) {
              _expandedNodes.add(subChild.id);
            }
          }
        });
        return;
      }
    }

    setState(() {
      _activeTree = roots;
      // Auto-expand the first 2 levels of root categories and subcategories
      for (var root in _activeTree) {
        _expandedNodes.add(root.id);
        for (var child in root.children) {
          _expandedNodes.add(child.id);
        }
      }
    });
  }

  void _handleTabChange(String tab) {
    if (_activeTab == tab) return;
    setState(() {
      _activeTab = tab;
      _compiledItems.clear();
      _selectedQuantities.clear();
    });
    if (tab == 'revision') {
      _loadBookmarks();
    } else {
      _loadCounts().then((_) => _buildActiveTree());
    }
  }

  Future<void> _loadBookmarks() async {
    setState(() {
      _loadingBookmarks = true;
      _bookmarks.clear();
      _selectedBookmarkIds.clear();
    });
    try {
      final bookmarks = await _service.getBookmarks();
      List<dynamic> filteredBookmarks = bookmarks;
      if (widget.isRevisionMode && widget.contentType != null) {
        filteredBookmarks = bookmarks.where((b) {
          if (b == null || b is! Map) return false;
          final tax = b['taxonomy'] as Map? ?? {};
          return tax['content_type'] == widget.contentType;
        }).toList();
      }
      if (widget.rootNodeId != null) {
        filteredBookmarks = filteredBookmarks.where((b) {
          if (b == null || b is! Map) return false;
          final tax = b['taxonomy'] as Map? ?? {};
          final subNodeVal = tax['subject_node_id'];
          final subNode = subNodeVal is int ? subNodeVal : (subNodeVal != null ? int.tryParse(subNodeVal.toString()) : null);
          final topNodeVal = tax['topic_node_id'];
          final topNode = topNodeVal is int ? topNodeVal : (topNodeVal != null ? int.tryParse(topNodeVal.toString()) : null);
          final subtNodeVal = tax['subtopic_node_id'];
          final subtNode = subtNodeVal is int ? subtNodeVal : (subtNodeVal != null ? int.tryParse(subtNodeVal.toString()) : null);
          return subNode == widget.rootNodeId ||
              topNode == widget.rootNodeId ||
              subtNode == widget.rootNodeId;
        }).toList();
      }
      setState(() {
        _bookmarks = filteredBookmarks;
        for (var b in filteredBookmarks) {
          if (b == null || b is! Map) continue;
          final qIdVal = b['question_id'];
          final qId = qIdVal is int ? qIdVal : (qIdVal != null ? int.tryParse(qIdVal.toString()) : null);
          if (qId != null) {
            _selectedBookmarkIds.add(qId);
          }
        }
        _loadingBookmarks = false;
      });
    } catch (e) {
      debugPrint("Error loading bookmarks in test builder: $e");
      setState(() {
        _loadingBookmarks = false;
      });
    }
  }

  int _getBookmarkCountForNode(int nodeId) {
    return _bookmarks.where((b) {
      if (b == null || b is! Map) return false;
      final tax = b['taxonomy'] as Map? ?? {};
      final subNodeVal = tax['subject_node_id'];
      final subNode = subNodeVal is int ? subNodeVal : (subNodeVal != null ? int.tryParse(subNodeVal.toString()) : null);
      final topNodeVal = tax['topic_node_id'];
      final topNode = topNodeVal is int ? topNodeVal : (topNodeVal != null ? int.tryParse(topNodeVal.toString()) : null);
      final subtNodeVal = tax['subtopic_node_id'];
      final subtNode = subtNodeVal is int ? subtNodeVal : (subtNodeVal != null ? int.tryParse(subtNodeVal.toString()) : null);
      return subNode == nodeId || topNode == nodeId || subtNode == nodeId;
    }).length;
  }

  List<dynamic> _getFilteredBookmarks() {
    if (_selectedRevisionNodeId == null) return _bookmarks;
    return _bookmarks.where((b) {
      if (b == null || b is! Map) return false;
      final tax = b['taxonomy'] as Map? ?? {};
      final subNodeVal = tax['subject_node_id'];
      final subNode = subNodeVal is int ? subNodeVal : (subNodeVal != null ? int.tryParse(subNodeVal.toString()) : null);
      final topNodeVal = tax['topic_node_id'];
      final topNode = topNodeVal is int ? topNodeVal : (topNodeVal != null ? int.tryParse(topNodeVal.toString()) : null);
      final subtNodeVal = tax['subtopic_node_id'];
      final subtNode = subtNodeVal is int ? subtNodeVal : (subtNodeVal != null ? int.tryParse(subtNodeVal.toString()) : null);
      return subNode == _selectedRevisionNodeId || topNode == _selectedRevisionNodeId || subtNode == _selectedRevisionNodeId;
    }).toList();
  }

  Future<void> _startBookmarksTest() async {
    final filtered = _getFilteredBookmarks();
    final activeFilteredIds = filtered
        .map((b) {
          if (b == null || b is! Map) return null;
          final qIdVal = b['question_id'];
          return qIdVal is int ? qIdVal : (qIdVal != null ? int.tryParse(qIdVal.toString()) : null);
        })
        .whereType<int>()
        .toList();
    final qIds = _selectedBookmarkIds.where((id) => activeFilteredIds.contains(id)).toList();

    if (qIds.isEmpty || _selectedExamId == null) return;
    setState(() => _compiling = true);
    try {
      bool hasMains = false;
      for (var b in _bookmarks) {
        if (b == null || b is! Map) continue;
        final qIdVal = b['question_id'];
        final qId = qIdVal is int ? qIdVal : (qIdVal != null ? int.tryParse(qIdVal.toString()) : null);
        if (qIds.contains(qId)) {
          final tax = b['taxonomy'] as Map? ?? {};
          if (tax['content_type'] == 'mains') {
            hasMains = true;
            break;
          }
        }
      }

      String categoryName = "All Bookmarks";
      if (_selectedRevisionNodeId != null) {
        final allCategoryNodes = [..._objNodesRaw, ..._mainsNodesRaw];
        final match = allCategoryNodes.firstWhere(
          (n) {
            if (n == null) return false;
            final idVal = n['id'];
            final id = idVal is int ? idVal : (idVal != null ? int.tryParse(idVal.toString()) : null);
            return id == _selectedRevisionNodeId;
          },
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          categoryName = match['name']?.toString() ?? 'Category';
        }
      }

      final customTestId = await _service.createUserCustomTest(
        title: "Revision: $categoryName - ${DateTime.now().day}/${DateTime.now().month}",
        examId: _selectedExamId!,
        examLevelId: hasMains ? _examLevelIdForSlug('mains-written') : _examLevelIdForSlug('prelims-gs'),
        questionIds: qIds,
        testType: hasMains ? 'mains_test' : 'sectional_test',
      );

      final attemptId = await _service.startAttempt(customTestId);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AttemptEngineScreen(attemptId: attemptId),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _compiling = false);
    }
  }

  Widget _buildRevisionView() {
    if (_loadingBookmarks) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(color: AppColors.civic),
        ),
      );
    }

    if (_bookmarks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bookmark_border_rounded, size: 48, color: AppColors.muted),
              const SizedBox(height: 16),
              Text(
                "No bookmarked questions yet",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Bookmark questions you got wrong during test reviews to revise them here.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final List<Map<String, dynamic>> subjectNodes = [];
    final List<Map<String, dynamic>> allCategoryNodes;
    if (widget.contentType == 'gk') {
      allCategoryNodes = _objNodesRaw
          .where((n) => n['content_type'] == 'gk')
          .toList();
    } else if (widget.contentType == 'aptitude') {
      allCategoryNodes = _objNodesRaw
          .where((n) => n['content_type'] == 'aptitude')
          .toList();
    } else if (widget.contentType == 'mains') {
      allCategoryNodes = _mainsNodesRaw;
    } else {
      allCategoryNodes = [..._objNodesRaw, ..._mainsNodesRaw];
    }

    final isRootSubject = widget.rootNodeId != null && allCategoryNodes.any((n) {
      if (n == null) return false;
      final nodeType = n['node_type'];
      final idVal = n['id'];
      final id = idVal is int ? idVal : (idVal != null ? int.tryParse(idVal.toString()) : null);
      return (nodeType == 'subject' || nodeType == 'paper') && id == widget.rootNodeId;
    });

    int? selectedSubjectId;

    if (widget.rootNodeId == null) {
      for (var n in allCategoryNodes) {
        if (n == null) continue;
        final nodeType = n['node_type'];
        if (nodeType == 'subject' || nodeType == 'paper') {
          final idVal = n['id'];
          final nodeId = idVal is int ? idVal : (idVal != null ? int.tryParse(idVal.toString()) ?? 0 : 0);
          final count = _getBookmarkCountForNode(nodeId);
          if (count > 0) {
            subjectNodes.add({
              'id': nodeId,
              'name': n['name']?.toString() ?? '',
              'count': count,
            });
          }
        }
      }

      if (_selectedRevisionNodeId != null) {
        final isSub = allCategoryNodes.any((n) {
          if (n == null) return false;
          final nodeType = n['node_type'];
          final idVal = n['id'];
          final id = idVal is int ? idVal : (idVal != null ? int.tryParse(idVal.toString()) : null);
          return (nodeType == 'subject' || nodeType == 'paper') && id == _selectedRevisionNodeId;
        });
        if (isSub) {
          selectedSubjectId = _selectedRevisionNodeId;
        } else {
          final match = allCategoryNodes.firstWhere(
            (n) {
              if (n == null) return false;
              final idVal = n['id'];
              final id = idVal is int ? idVal : (idVal != null ? int.tryParse(idVal.toString()) : null);
              return id == _selectedRevisionNodeId;
            },
            orElse: () => {},
          );
          if (match.isNotEmpty) {
            final parentIdVal = match['parent_id'];
            selectedSubjectId = parentIdVal is int ? parentIdVal : (parentIdVal != null ? int.tryParse(parentIdVal.toString()) : null);
          }
        }
      }
    } else {
      if (isRootSubject) {
        selectedSubjectId = widget.rootNodeId;
      } else {
        final match = allCategoryNodes.firstWhere(
          (n) {
            if (n == null) return false;
            final idVal = n['id'];
            final id = idVal is int ? idVal : (idVal != null ? int.tryParse(idVal.toString()) : null);
            return id == widget.rootNodeId;
          },
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          final parentIdVal = match['parent_id'];
          selectedSubjectId = parentIdVal is int ? parentIdVal : (parentIdVal != null ? int.tryParse(parentIdVal.toString()) : null);
        }
      }
    }

    final List<Map<String, dynamic>> topicNodes = [];
    if (selectedSubjectId != null) {
      for (var n in allCategoryNodes) {
        if (n == null) continue;
        final parentIdVal = n['parent_id'];
        final parentId = parentIdVal is int ? parentIdVal : (parentIdVal != null ? int.tryParse(parentIdVal.toString()) : null);
        if (parentId == selectedSubjectId) {
          final idVal = n['id'];
          final nodeId = idVal is int ? idVal : (idVal != null ? int.tryParse(idVal.toString()) ?? 0 : 0);

          if (widget.rootNodeId != null && !isRootSubject && widget.rootNodeId != nodeId) {
            continue;
          }

          final count = _getBookmarkCountForNode(nodeId);
          if (count > 0) {
            topicNodes.add({
              'id': nodeId,
              'name': n['name']?.toString() ?? '',
              'count': count,
            });
          }
        }
      }
    }

    final List<Map<String, dynamic>> subtopicNodes = [];
    if (widget.rootNodeId != null && !isRootSubject) {
      for (var n in allCategoryNodes) {
        if (n == null) continue;
        final parentIdVal = n['parent_id'];
        final parentId = parentIdVal is int ? parentIdVal : (parentIdVal != null ? int.tryParse(parentIdVal.toString()) : null);
        if (parentId == widget.rootNodeId) {
          final idVal = n['id'];
          final nodeId = idVal is int ? idVal : (idVal != null ? int.tryParse(idVal.toString()) ?? 0 : 0);
          final count = _getBookmarkCountForNode(nodeId);
          if (count > 0) {
            subtopicNodes.add({
              'id': nodeId,
              'name': n['name']?.toString() ?? '',
              'count': count,
            });
          }
        }
      }
    }

    final filtered = _getFilteredBookmarks();
    final activeFilteredIds = filtered
        .map((b) {
          if (b == null || b is! Map) return null;
          final qIdVal = b['question_id'];
          return qIdVal is int ? qIdVal : (qIdVal != null ? int.tryParse(qIdVal.toString()) : null);
        })
        .whereType<int>()
        .toList();
    final selectedFilteredCount = _selectedBookmarkIds.where((id) => activeFilteredIds.contains(id)).length;
    final allSelected = filtered.isNotEmpty && selectedFilteredCount == filtered.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.rootNodeId == null) ...[
          Text(
            "Subject Filter",
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: AppColors.muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  selected: selectedSubjectId == null,
                  label: Text("All Categories (${_bookmarks.length})"),
                  onSelected: (val) {
                    setState(() {
                      _selectedRevisionNodeId = null;
                    });
                  },
                  selectedColor: AppColors.ink.withOpacity(0.15),
                  checkmarkColor: AppColors.ink,
                ),
                ...subjectNodes.map((s) {
                  final id = s['id'] as int;
                  final name = s['name'] as String;
                  final count = s['count'] as int;
                  final isSelected = selectedSubjectId == id;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6.0),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text("$name ($count)"),
                      onSelected: (val) {
                        setState(() {
                          _selectedRevisionNodeId = id;
                        });
                      },
                      selectedColor: AppColors.ink.withOpacity(0.15),
                      checkmarkColor: AppColors.ink,
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        if (widget.rootNodeId == null && selectedSubjectId != null && topicNodes.isNotEmpty) ...[
          Text(
            "Topic Filter",
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: AppColors.muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  selected: _selectedRevisionNodeId == selectedSubjectId,
                  label: const Text("All under Subject"),
                  onSelected: (val) {
                    setState(() {
                      _selectedRevisionNodeId = selectedSubjectId;
                    });
                  },
                  selectedColor: AppColors.civic.withOpacity(0.15),
                  checkmarkColor: AppColors.civic,
                ),
                ...topicNodes.map((t) {
                  final id = t['id'] as int;
                  final name = t['name'] as String;
                  final count = t['count'] as int;
                  final isSelected = _selectedRevisionNodeId == id;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6.0),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text("$name ($count)"),
                      onSelected: (val) {
                        setState(() {
                          _selectedRevisionNodeId = id;
                        });
                      },
                      selectedColor: AppColors.civic.withOpacity(0.15),
                      checkmarkColor: AppColors.civic,
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (widget.rootNodeId != null && isRootSubject && topicNodes.isNotEmpty) ...[
          Text(
            "Topic Filter",
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: AppColors.muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  selected: _selectedRevisionNodeId == null || _selectedRevisionNodeId == widget.rootNodeId,
                  label: Text("All Topic Bookmarks (${_bookmarks.length})"),
                  onSelected: (val) {
                    setState(() {
                      _selectedRevisionNodeId = null;
                    });
                  },
                  selectedColor: AppColors.civic.withOpacity(0.15),
                  checkmarkColor: AppColors.civic,
                ),
                ...topicNodes.map((t) {
                  final id = t['id'] as int;
                  final name = t['name'] as String;
                  final count = t['count'] as int;
                  final isSelected = _selectedRevisionNodeId == id;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6.0),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text("$name ($count)"),
                      onSelected: (val) {
                        setState(() {
                          _selectedRevisionNodeId = id;
                        });
                      },
                      selectedColor: AppColors.civic.withOpacity(0.15),
                      checkmarkColor: AppColors.civic,
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (widget.rootNodeId != null && !isRootSubject && subtopicNodes.isNotEmpty) ...[
          Text(
            "Subtopic Filter",
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: AppColors.muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  selected: _selectedRevisionNodeId == null || _selectedRevisionNodeId == widget.rootNodeId,
                  label: Text("All Topic Bookmarks (${_bookmarks.length})"),
                  onSelected: (val) {
                    setState(() {
                      _selectedRevisionNodeId = null;
                    });
                  },
                  selectedColor: AppColors.civic.withOpacity(0.15),
                  checkmarkColor: AppColors.civic,
                ),
                ...subtopicNodes.map((st) {
                  final id = st['id'] as int;
                  final name = st['name'] as String;
                  final count = st['count'] as int;
                  final isSelected = _selectedRevisionNodeId == id;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6.0),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text("$name ($count)"),
                      onSelected: (val) {
                        setState(() {
                          _selectedRevisionNodeId = id;
                        });
                      },
                      selectedColor: AppColors.civic.withOpacity(0.15),
                      checkmarkColor: AppColors.civic,
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Checkbox(
                value: allSelected,
                activeColor: AppColors.civic,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      for (var b in filtered) {
                        final qId = int.tryParse((b as Map<String, dynamic>)['question_id']?.toString() ?? '');
                        if (qId != null) _selectedBookmarkIds.add(qId);
                      }
                    } else {
                      for (var b in filtered) {
                        final qId = int.tryParse((b as Map<String, dynamic>)['question_id']?.toString() ?? '');
                        if (qId != null) _selectedBookmarkIds.remove(qId);
                      }
                    }
                  });
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Select Qs (${filtered.length})",
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.ink),
                    ),
                    Text(
                      "$selectedFilteredCount selected",
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: selectedFilteredCount == 0 || _compiling ? null : _startBookmarksTest,
                icon: _compiling
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 16),
                label: Text(
                  "Take Revision Test",
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                "No bookmarked questions in this category.",
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.bold),
              ),
            ),
          )
        else
          ...filtered.map((bookmark) {
            if (bookmark == null || bookmark is! Map) return const SizedBox();
            final b = bookmark;
            final q = b['question_version'] as Map? ?? {};
            final tax = b['taxonomy'] as Map? ?? {};
            final qIdVal = b['question_id'];
            final qId = qIdVal is int ? qIdVal : (qIdVal != null ? int.tryParse(qIdVal.toString()) ?? 0 : 0);
            final isSelected = _selectedBookmarkIds.contains(qId);
            final statement = q['question_statement']?.toString() ?? 'No statement';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.civic.withOpacity(0.4) : AppColors.line,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: isSelected,
                    activeColor: AppColors.civic,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedBookmarkIds.add(qId);
                        } else {
                          _selectedBookmarkIds.remove(qId);
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.paper,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            (tax['content_type']?.toString() ?? 'gk').toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.muted),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          statement,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.berry, size: 20),
                    onPressed: () async {
                      try {
                        await _service.removeBookmark(qId);
                        setState(() {
                          _bookmarks.removeWhere((item) {
                            if (item == null || item is! Map) return false;
                            final itemQIdVal = item['question_id'];
                            final itemQId = itemQIdVal is int ? itemQIdVal : (itemQIdVal != null ? int.tryParse(itemQIdVal.toString()) : null);
                            return itemQId == qId;
                          });
                          _selectedBookmarkIds.remove(qId);
                        });
                      } catch (e) {
                        debugPrint("Failed to delete bookmark: $e");
                      }
                    },
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 80),
      ],
    );
  }



  bool _isNodeDescendant(int childId, int parentId) {
    final parentNode = _findNodeInTree(_activeTree, parentId);
    if (parentNode == null) return false;
    return _findNodeInTree(parentNode.children, childId) != null;
  }

  int _getAvailableCount(int nodeId) {
    final node = _findNodeInTree(_activeTree, nodeId);
    if (node == null) return nodeId < 0 ? (_userQuestionCounts[-nodeId] ?? 0) : (_questionCounts[nodeId] ?? 0);
    final total = _sumNodeQuestions(node);

    int selectedOverlap = 0;
    final isNodeUser = nodeId < 0 || node.isUserNode;

    for (var item in _compiledItems) {
      final itemNode = item['node'] as _TreeNode;
      final itemCount = item['count'] as int;
      final isItemUser = itemNode.id < 0 || itemNode.isUserNode;

      if (isNodeUser == isItemUser) {
        final isDescendant = _isNodeDescendant(itemNode.id, nodeId);
        final isAncestor = _isNodeDescendant(nodeId, itemNode.id);

        if (isDescendant || isAncestor || itemNode.id == nodeId) {
          selectedOverlap += itemCount;
        }
      }
    }

    return max(0, total - selectedOverlap);
  }

  _TreeNode? _findNodeInTree(List<_TreeNode> nodes, int id) {
    for (var n in nodes) {
      if (n.id == id) return n;
      final found = _findNodeInTree(n.children, id);
      if (found != null) return found;
    }
    return null;
  }

  /// The first root category worth showcasing — prefers one with both
  /// sub-categories (so "Browse" is meaningful) and available questions (so
  /// the quantity/Add step has something to point at). Falls back to the
  /// first root node so the tour still runs on thinner syllabi.
  int? _findTourAnchorNodeId() {
    for (final node in _activeTree) {
      if (node.children.isNotEmpty && _getAvailableCount(node.id) > 0) {
        return node.id;
      }
    }
    return _activeTree.isNotEmpty ? _activeTree.first.id : null;
  }

  int _sumNodeQuestions(_TreeNode node) {
    if (node.isUserNode || node.id < 0) {
      final parentId = node.id < 0 ? -node.id : node.id;
      return _userQuestionCounts[parentId] ?? 0;
    }
    int sum = _questionCounts[node.id] ?? 0;
    for (var child in node.children) {
      if (!child.isUserNode) {
        sum += _sumNodeQuestions(child);
      }
    }
    return sum;
  }

  int _getCategoryQuantity(int nodeId, int available) {
    if (!_selectedQuantities.containsKey(nodeId)) {
      _selectedQuantities[nodeId] = min(10, available);
    }
    return _selectedQuantities[nodeId]!;
  }

  void _setSelectedQuantity(int nodeId, int value) {
    _selectedQuantities[nodeId] = value;
  }

  List<String> _breadcrumbFor(_TreeNode node) {
    final names = <String>[node.name];
    int? parentId = node.parentId;
    while (parentId != null) {
      final parent = _findNodeInTree(_activeTree, parentId);
      if (parent == null) break;
      names.insert(0, parent.name);
      parentId = parent.parentId;
    }
    return names;
  }

  Widget _buildQuantitySelector(_TreeNode node, int available) {
    final currentVal = _getCategoryQuantity(node.id, available);
    return Container(
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
                ? () {
                    setState(() {
                      _selectedQuantities[node.id] = currentVal - 1;
                    });
                  }
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
                ? () {
                    setState(() {
                      _selectedQuantities[node.id] = currentVal + 1;
                    });
                  }
                : null,
          ),
        ],
      ),
    );
  }

  void _addQuantityToTest(_TreeNode node) {
    final available = _getAvailableCount(node.id);
    if (available <= 0) return;

    final selectedCount = _getCategoryQuantity(node.id, available);

    if (widget.testTemplateId != null) {
      _addQuestionsToTargetTest(node, widget.testTemplateId!, selectedCount);
      return;
    }

    // Always accumulate into the shared cart — the destination (new test vs
    // an existing one) is chosen once, when the cart is finalized below, not
    // on every single Add tap.
    setState(() {
      final existingIdx = _compiledItems.indexWhere((item) => item['node'].id == node.id);
      final family = _activeTab == 'mains' ? 'mains_subjective' : 'objective';

      if (existingIdx >= 0) {
        final currentCount = _compiledItems[existingIdx]['count'] as int;
        _compiledItems[existingIdx]['count'] = min(currentCount + selectedCount, available);
      } else {
        _compiledItems.add({
          'node': node,
          'count': selectedCount,
          'question_family': family,
        });
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Added to cart"), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _addQuestionsToTargetTest(_TreeNode node, int testId, int count) async {
    setState(() {
      _compiling = true;
    });
    try {
      final resolved = _resolveCategory(
        node,
        _activeTab == 'mains' ? _mainsNodesRaw : _objNodesRaw,
      );
      final isMains = _activeTab == 'mains';
      final subjectId = resolved['subject_node_id'];
      final topicId = resolved['topic_node_id'];
      final subtopicId = resolved['subtopic_node_id'];

      final apiClient = Provider.of<ApiClient>(context, listen: false);
      String path = isMains ? '/api/v1/assessment/mains/questions' : '/api/v1/assessment/questions';
      final queryParams = <String, String>{
        'limit': '100',
        'subject_node_id': subjectId.toString(),
      };
      if (topicId != null) queryParams['topic_node_id'] = topicId.toString();
      if (subtopicId != null) queryParams['subtopic_node_id'] = subtopicId.toString();

      final queryString = Uri(queryParameters: queryParams).query;
      final List<dynamic> data = await apiClient.get('$path?$queryString');
      
      if (data.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No questions found in this category")),
          );
        }
        return;
      }

      final shuffled = List.from(data)..shuffle();
      final selected = shuffled.take(count).toList();
      final questionIds = selected.map<int>((q) {
        final qId = q['id'] ?? q['question_id'];
        return int.tryParse(qId.toString()) ?? 0;
      }).where((id) => id > 0).toList();

      if (questionIds.isEmpty) return;

      await _service.addQuestionsToUserTest(
        testTemplateId: testId,
        questionIds: questionIds,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Successfully added ${questionIds.length} questions!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to add questions: $e")),
        );
      }
    } finally {
      setState(() {
        _compiling = false;
      });
    }
  }

  int _examLevelIdForSlug(String slug) {
    final match = _examLevels.where((l) => l.slug == slug);
    if (match.isNotEmpty) return match.first.id;

    // Fallback only if exam levels failed to load — best-effort guess, may not
    // match the actual row id on whichever server this request hits.
    if (slug == 'prelims-csat') return 1;
    if (slug == 'mains-written') return 3;
    return 7;
  }

  int _examLevelIdForActiveTab() {
    final slug = _activeTab == 'aptitude'
        ? 'prelims-csat'
        : (_activeTab == 'mains' ? 'mains-written' : 'prelims-gs');
    return _examLevelIdForSlug(slug);
  }

  String _testTypeForActiveTab() => _activeTab == 'mains' ? 'mains_test' : 'sectional_test';

  // Builds category specs (any taxonomy level) from the whole cart, resolved
  // server-side with the same rollup logic used for live compiled attempts —
  // so a category card built from an upper-level category (not just leaves)
  // resolves correctly instead of the old client-side exact-match lookup.
  List<Map<String, dynamic>> _cartToCategories() {
    return _compiledItems.map((item) {
      final node = item['node'] as _TreeNode;
      final count = item['count'] as int;
      final family = item['question_family'] as String? ?? 'objective';
      final isMainsItem = family == 'mains_subjective';
      final sourceList = isMainsItem ? _mainsNodesRaw : _objNodesRaw;
      final targetNode = node.isUserNode ? _findNodeInTree(_activeTree, node.parentId!)! : node;
      final resolved = _resolveCategory(targetNode, sourceList);
      return {
        ...resolved,
        'question_count': count,
        'question_family': family,
        if (node.isUserNode) 'is_user_private': true,
      };
    }).toList();
  }

  Future<void> _saveCartAsNewTest() async {
    final name = _customTestNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Test name is required")),
      );
      return;
    }
    if (_compiledItems.isEmpty || _selectedExamId == null) return;

    setState(() => _compiling = true);
    try {
      await _service.createUserCustomTest(
        title: name,
        examId: _selectedExamId!,
        examLevelId: _examLevelIdForActiveTab(),
        testType: _testTypeForActiveTab(),
        categories: _cartToCategories(),
      );
      if (!mounted) return;
      setState(() {
        _compiledItems.clear();
        _isCartExpanded = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Saved \"$name\" — find it under My Tests")),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save test: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _compiling = false);
    }
  }

  Future<void> _addCartToExistingTest() async {
    if (_compiledItems.isEmpty) return;
    // Captured once from this State's own (stable) context — the dialog below closes
    // itself via Navigator.pop before its async work finishes, so ScaffoldMessenger.of()
    // on the dialog's own context would throw ("deactivated widget's ancestor is unsafe")
    // once that dialog/list-item context is gone. The messenger instance itself stays
    // valid as long as this screen (this State) is still mounted.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _compiling = true);
    List<AssessmentTestTemplate> tests = [];
    try {
      final rawTemplates = await _service.getUserCustomTests();
      final templates = (rawTemplates as dynamic) ?? <AssessmentTestTemplate>[];
      tests = templates.where((t) => t.latestAttemptStatus == null).toList();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text("Failed to load custom tests: $e")),
        );
      }
      setState(() => _compiling = false);
      return;
    }
    setState(() => _compiling = false);
    if (!mounted) return;

    if (tests.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("No Tests Found"),
          content: const Text("You do not have any unattempted custom tests. Save this cart as a new test first!"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Select Target Test",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: tests.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, idx) {
              final t = tests[idx];
              return ListTile(
                title: Text(t.title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text("${t.questionCount ?? 0} Questions"),
                trailing: const Icon(Icons.chevron_right, size: 16),
                onTap: () async {
                  Navigator.pop(context);
                  setState(() => _compiling = true);
                  try {
                    await _service.addQuestionsToUserTest(
                      testTemplateId: t.id,
                      categories: _cartToCategories(),
                    );
                    if (!mounted) return;
                    setState(() {
                      _compiledItems.clear();
                      _isCartExpanded = false;
                    });
                    messenger.showSnackBar(
                      SnackBar(content: Text("Added to \"${t.title}\"")),
                    );
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text("Failed to add questions: $e")),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _compiling = false);
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }



  Map<String, dynamic> _resolveCategory(
    _TreeNode node,
    List<Map<String, dynamic>> nodesList,
  ) {
    int subjectNodeId = node.id;
    int? topicNodeId;
    int? subtopicNodeId;

    if (node.parentId != null) {
      final parentNode = nodesList.firstWhere(
        (n) => int.tryParse(n['id']?.toString() ?? '') == node.parentId,
        orElse: () => {},
      );
      if (parentNode.isNotEmpty && parentNode['parent_id'] != null) {
        subtopicNodeId = node.id;
        topicNodeId =
            int.tryParse(parentNode['id']?.toString() ?? '') ?? node.id;
        subjectNodeId =
            int.tryParse(parentNode['parent_id']?.toString() ?? '') ??
            node.parentId!;
      } else if (parentNode.isNotEmpty) {
        topicNodeId = node.id;
        subjectNodeId = node.parentId!;
      }
    }
    return {
      'subject_node_id': subjectNodeId,
      'topic_node_id': topicNodeId,
      'subtopic_node_id': subtopicNodeId,
    };
  }

  void _openAiParsing(_TreeNode node) {
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    if (!apiClient.hasEntitlement('assessment.premium_tests')) {
      _showPremiumLockDialog();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiBasedParsingScreen(
          categoryNodeId: node.id,
          contentType: _activeTab,
        ),
      ),
    );
  }

  void _openManualAddForm(_TreeNode node) {
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    if (!apiClient.hasEntitlement('assessment.premium_tests')) {
      _showPremiumLockDialog();
      return;
    }
    if (_selectedExamId == null) return;

    final nodesList = _activeTab == 'mains' ? _mainsNodesRaw : _objNodesRaw;
    final resolved = _resolveCategory(node, nodesList);

    final statementController = TextEditingController();
    final optionAController = TextEditingController();
    final optionBController = TextEditingController();
    final optionCController = TextEditingController();
    final optionDController = TextEditingController();
    final explanationController = TextEditingController();

    String correctAnswer = 'a';
    bool markForRevision = false;

    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.line,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Add Custom Question",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Add a private question directly to ${node.name}.",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: statementController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: "Question Statement *",
                          hintText: "Enter question statement here...",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: optionAController,
                              decoration: const InputDecoration(
                                labelText: "Option A *",
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) => value == null || value.isEmpty ? "Required" : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: optionBController,
                              decoration: const InputDecoration(
                                labelText: "Option B *",
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) => value == null || value.isEmpty ? "Required" : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: optionCController,
                              decoration: const InputDecoration(
                                labelText: "Option C *",
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) => value == null || value.isEmpty ? "Required" : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: optionDController,
                              decoration: const InputDecoration(
                                labelText: "Option D *",
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) => value == null || value.isEmpty ? "Required" : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: correctAnswer,
                              decoration: const InputDecoration(
                                labelText: "Correct Answer *",
                                border: OutlineInputBorder(),
                              ),
                              items: ['a', 'b', 'c', 'd'].map((label) => DropdownMenuItem(
                                value: label,
                                child: Text("Option ${label.toUpperCase()}"),
                              )).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setSheetState(() => correctAnswer = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Row(
                            children: [
                              Checkbox(
                                value: markForRevision,
                                onChanged: (val) {
                                  if (val != null) {
                                    setSheetState(() => markForRevision = val);
                                  }
                                },
                              ),
                              Text(
                                "Mark for Revision",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: explanationController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: "Explanation (Optional)",
                          hintText: "Enter correct explanation here...",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: submitting ? null : () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: submitting ? null : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => submitting = true);
                              try {
                                final questions = [
                                  ParsedQuestion(
                                    questionStatement: statementController.text.trim(),
                                    options: [
                                      QuestionOption(key: 'a', text: optionAController.text.trim()),
                                      QuestionOption(key: 'b', text: optionBController.text.trim()),
                                      QuestionOption(key: 'c', text: optionCController.text.trim()),
                                      QuestionOption(key: 'd', text: optionDController.text.trim()),
                                    ],
                                    correctAnswer: correctAnswer,
                                    explanation: explanationController.text.trim().isEmpty ? null : explanationController.text.trim(),
                                  )
                                ];

                                await _service.aiSaveQuestions(
                                  examId: _selectedExamId!,
                                  examLevelId: _examLevelIdForActiveTab(),
                                  subjectNodeId: resolved['subject_node_id'] as int,
                                  topicNodeId: resolved['topic_node_id'] as int?,
                                  questions: questions,
                                );

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Question saved successfully!")),
                                  );
                                  await _loadCounts();
                                  _buildActiveTree();
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Failed to save: $e")),
                                );
                              } finally {
                                setSheetState(() => submitting = false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.civic,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            child: submitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text("Save"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<_TreeNode> _filterTree(List<_TreeNode> nodes, String query) {
    if (query.isEmpty) return nodes;

    final lowercaseQuery = query.toLowerCase();
    final List<_TreeNode> filtered = [];

    for (var node in nodes) {
      final bool matchesNode = node.name.toLowerCase().contains(lowercaseQuery);
      final List<_TreeNode> filteredChildren = _filterTree(node.children, query);

      if (matchesNode || filteredChildren.isNotEmpty) {
        final clonedNode = _TreeNode(
          id: node.id,
          name: node.name,
          slug: node.slug,
          description: node.description,
          imageUrl: node.imageUrl,
          nodeType: node.nodeType,
          parentId: node.parentId,
          contentType: node.contentType,
          displayOrder: node.displayOrder,
        );
        clonedNode.children.addAll(filteredChildren);

        // Auto-expand nodes containing match results
        _expandedNodes.add(node.id);

        filtered.add(clonedNode);
      }
    }

    return filtered;
  }

  void _startDirectTest(_TreeNode node) {
    _showDirectTestBottomSheet(node);
  }

  void _showDirectTestBottomSheet(_TreeNode node) {
    final available = _getAvailableCount(node.id);
    if (available <= 0) return;
    if (_selectedExamId == null) return;

    final isMains = _activeTab == 'mains';
    final defaultTitle = "${node.name} Practice Test";

    // No pre-filled text — the name must be an intentional choice, not a
    // silently-accepted auto-generated default (shown only as a hint).
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    int selectedCount = min(10, available);
    bool includeAttempted = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.line,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Start Practice Test",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Category: ${node.name}",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "TEST NAME *",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: AppColors.muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: defaultTitle,
                        filled: true,
                        fillColor: AppColors.paper.withOpacity(0.4),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.civic, width: 1.5),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Test name is required";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "NUMBER OF QUESTIONS",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: AppColors.muted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          "$selectedCount Qs",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: AppColors.civic,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: selectedCount.toDouble(),
                      min: 1,
                      max: min(100, available).toDouble(),
                      divisions: min(100, available) > 1 ? min(100, available) - 1 : 1,
                      activeColor: AppColors.civic,
                      inactiveColor: AppColors.line,
                      onChanged: (val) {
                        setSheetState(() {
                          selectedCount = val.toInt();
                        });
                      },
                    ),
                    Text(
                      "Drag to choose from 1 to ${min(100, available)} questions.",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: Text(
                        "Include already attempted questions",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      value: includeAttempted,
                      activeColor: AppColors.civic,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) {
                        setSheetState(() {
                          includeAttempted = val ?? false;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.civic,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            Navigator.pop(context); // Close bottom sheet

                            final nodesList = isMains ? _mainsNodesRaw : _objNodesRaw;
                            final targetNode = node.isUserNode ? _findNodeInTree(_activeTree, node.parentId!)! : node;
                            final category = _resolveCategory(targetNode, nodesList);
                            final family = isMains ? 'mains_subjective' : 'objective';

                            setState(() => _compiling = true);
                            try {
                              final attemptId = await _service.startCompiledAttempt(
                                examId: _selectedExamId!,
                                testType: isMains ? 'sectional_test' : 'quick_test',
                                categories: [
                                  {
                                    ...category,
                                    'question_count': selectedCount,
                                    'question_family': family,
                                    if (node.isUserNode) 'is_user_private': true,
                                  },
                                ],
                                includeAttempted: includeAttempted,
                                title: nameController.text.trim(),
                              );

                              if (mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AttemptEngineScreen(attemptId: attemptId),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (e is ApiException && e.code == 'free_test_limit_reached') {
                                if (mounted) _showFreeLimitDialog(e.message);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _compiling = false);
                            }
                          }
                        },
                        child: Text(
                          "Start Test Now",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
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
      },
    );
  }

  Future<void> _showCustomizeSyllabusModal() async {
    final List<Map<String, dynamic>> activeRawNodes = _activeTab == 'mains'
        ? _mainsNodesRaw
        : _objNodesRaw.where((n) => n['content_type'] == _activeTab).toList();

    if (activeRawNodes.isEmpty) return;

    final Map<int, List<Map<String, dynamic>>> parentToChildren = {};
    final List<Map<String, dynamic>> roots = [];

    for (var n in activeRawNodes) {
      final id = int.tryParse(n['id']?.toString() ?? '') ?? 0;
      final parentId = n['parent_id'] != null ? int.tryParse(n['parent_id'].toString()) : null;
      if (parentId != null) {
        parentToChildren.putIfAbsent(parentId, () => []).add(n);
      } else {
        roots.add(n);
      }
    }

    roots.sort((a, b) => (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
    parentToChildren.forEach((key, list) {
      list.sort((a, b) => (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
    });

    final currentExclusions = _activeTab == 'mains'
        ? (_exclusionsMap['mains'] ?? [])
        : (_exclusionsMap['objective'] ?? []);

    final Set<int> tempExcluded = Set<int>.from(currentExclusions);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void toggleNode(int nodeId, bool isChecked) {
              setDialogState(() {
                List<int> getDescendants(int id) {
                  final List<int> list = [];
                  final children = parentToChildren[id] ?? [];
                  for (var c in children) {
                    final childId = int.tryParse(c['id']?.toString() ?? '') ?? 0;
                    list.add(childId);
                    list.addAll(getDescendants(childId));
                  }
                  return list;
                }

                final descendants = getDescendants(nodeId);

                if (isChecked) {
                  tempExcluded.remove(nodeId);
                  for (var d in descendants) {
                    tempExcluded.remove(d);
                  }
                } else {
                  tempExcluded.add(nodeId);
                  for (var d in descendants) {
                    tempExcluded.add(d);
                  }
                }
              });
            }

            Widget buildFilterNode(Map<String, dynamic> n, int depth) {
              final id = int.tryParse(n['id']?.toString() ?? '') ?? 0;
              final name = n['name'] as String? ?? '';
              final type = n['node_type'] as String? ?? '';
              final isChecked = !tempExcluded.contains(id);
              final children = parentToChildren[id] ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: depth * 16.0),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isChecked,
                          activeColor: AppColors.civic,
                          onChanged: (val) {
                            if (val != null) {
                              toggleNode(id, val);
                            }
                          },
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: type == 'subject' || type == 'paper'
                                ? Colors.grey[200]
                                : type == 'source_bucket' || type == 'subject_area'
                                    ? Colors.amber[50]
                                    : Colors.indigo[50],
                            borderRadius: BorderRadius.circular(4),
                            border: type == 'source_bucket' || type == 'subject_area'
                                ? Border.all(color: Colors.amber[200]!)
                                : null,
                          ),
                          child: Text(
                            type.replaceAll('_', ' ').toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: type == 'subject' || type == 'paper'
                                  ? Colors.grey[700]
                                  : type == 'source_bucket' || type == 'subject_area'
                                      ? Colors.amber[800]
                                      : Colors.indigo[800],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isChecked ? AppColors.ink : AppColors.muted,
                              decoration: isChecked ? null : TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (children.isNotEmpty)
                    ...children.map((c) => buildFilterNode(c, depth + 1)),
                ],
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                "Customize Syllabus",
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Uncheck categories or sources to hide them from the test builder.",
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    Expanded(
                      child: ListView(
                        children: roots.map((r) => buildFilterNode(r, 0)).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() => _loading = true);
                    try {
                      await _service.updateExcludedTaxonomyNodes(
                        taxonomyType: _activeTab == 'mains' ? 'mains' : 'objective',
                        excludedNodeIds: [],
                      );
                      _exclusionsMap[_activeTab == 'mains' ? 'mains' : 'objective'] = [];
                      _buildActiveTree();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Failed to reset customization: $e")),
                      );
                    } finally {
                      setState(() => _loading = false);
                    }
                  },
                  child: Text(
                    "Reset View",
                    style: GoogleFonts.inter(color: Colors.red[600], fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: GoogleFonts.inter(color: AppColors.muted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.civic,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() => _loading = true);
                    try {
                      final list = tempExcluded.toList();
                      await _service.updateExcludedTaxonomyNodes(
                        taxonomyType: _activeTab == 'mains' ? 'mains' : 'objective',
                        excludedNodeIds: list,
                      );
                      _exclusionsMap[_activeTab == 'mains' ? 'mains' : 'objective'] = list;
                      _buildActiveTree();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Failed to save customization: $e")),
                      );
                    } finally {
                      setState(() => _loading = false);
                    }
                  },
                  child: Text("Save", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }


  // Top-level subjects rendered as a tab strip. Selecting a tab (or drilling
  // into a row below it) shows that node's children inline via a breadcrumb —
  // no separate pushed screen. Every row, whether it has children or not,
  // carries the quantity stepper + Add/Start using the rolled-up total
  // question count across its whole subtree (see _getAvailableCount), so a
  // student can pull a balanced test straight from any level.
  Widget _buildCategoryBrowser(List<_TreeNode> nodes, int? tourAnchorId) {
    if (nodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            "No categories found.",
            style: GoogleFonts.inter(color: AppColors.muted, fontSize: 13),
          ),
        ),
      );
    }

    if (_browseActiveSubjectId == null || !nodes.any((n) => n.id == _browseActiveSubjectId)) {
      _browseActiveSubjectId = nodes.first.id;
      _browseDrillPath = [];
    }

    final subjectNode = _findNodeInTree(_activeTree, _browseActiveSubjectId!) ?? nodes.first;

    final pathNodes = <_TreeNode>[subjectNode];
    for (final id in _browseDrillPath) {
      final child = _findNodeInTree(pathNodes.last.children, id);
      if (child == null) break;
      pathNodes.add(child);
    }
    if (pathNodes.length - 1 != _browseDrillPath.length) {
      _browseDrillPath = _browseDrillPath.sublist(0, pathNodes.length - 1);
    }
    final currentNode = pathNodes.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubjectTabStrip(nodes, tourAnchorId),
        const SizedBox(height: 12),
        if (pathNodes.length > 1) ...[
          _buildBrowseBreadcrumb(pathNodes),
          const SizedBox(height: 10),
        ],
        if (currentNode.children.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                "No sub-categories here.",
                style: GoogleFonts.inter(color: AppColors.muted, fontSize: 13),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int i = 0; i < currentNode.children.length; i++)
                  _buildBrowseRow(
                    currentNode.children[i],
                    isLast: i == currentNode.children.length - 1,
                    isTourAddAnchor: tourAnchorId != null &&
                        subjectNode.id == tourAnchorId &&
                        pathNodes.length == 1 &&
                        i == 0,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSubjectTabStrip(List<_TreeNode> nodes, int? tourAnchorId) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: nodes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final node = nodes[i];
          final isActive = node.id == _browseActiveSubjectId;
          final tab = InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() {
              _browseActiveSubjectId = node.id;
              _browseDrillPath = [];
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isActive ? AppColors.civic.withOpacity(0.1) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isActive ? AppColors.civic : AppColors.line),
              ),
              alignment: Alignment.center,
              child: Text(
                node.name,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isActive ? AppColors.civic : AppColors.ink,
                ),
              ),
            ),
          );
          if (tourAnchorId == null || node.id != tourAnchorId) return tab;
          return Showcase(
            key: _tourBrowseKey,
            title: "Browse categories",
            description: _tourBrowseDescription,
            targetBorderRadius: BorderRadius.circular(10),
            child: tab,
          );
        },
      ),
    );
  }

  Widget _buildBrowseBreadcrumb(List<_TreeNode> pathNodes) {
    return SizedBox(
      height: 22,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (int i = 0; i < pathNodes.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.muted),
              ),
            GestureDetector(
              onTap: () => setState(() => _browseDrillPath = _browseDrillPath.sublist(0, i)),
              child: Text(
                pathNodes[i].name,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: i == pathNodes.length - 1 ? FontWeight.w800 : FontWeight.w600,
                  color: i == pathNodes.length - 1 ? AppColors.ink : AppColors.civic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBrowseRow(_TreeNode node, {required bool isLast, bool isTourAddAnchor = false}) {
    final available = _getAvailableCount(node.id);
    final hasChildren = node.children.isNotEmpty;

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: hasChildren
                ? () => setState(() => _browseDrillPath = [..._browseDrillPath, node.id])
                : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: (hasChildren ? AppColors.civic : AppColors.emerald).withOpacity(hasChildren ? 0.08 : 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    _drillDownNodeIcon(node.nodeType, hasChildren),
                    size: 17,
                    color: hasChildren ? AppColors.civic : AppColors.emerald,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        available > 0 ? "$available questions total" : "No questions available",
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                if (hasChildren)
                  const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
              ],
            ),
          ),
          if (available > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _buildQuantitySelector(node, available),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _addQuantityToTest(node)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.civic),
                      foregroundColor: AppColors.civic,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text("Add", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _startDirectTest(node),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 2),
                        Text("Start", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () => _showAddQuestionsSheet(node),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 13, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(
                    "Add your questions",
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (!isTourAddAnchor) return content;
    return Showcase(
      key: _tourAddKey,
      title: "Add questions to your test",
      description: _tourAddDescription,
      child: content,
    );
  }

  void _showAddQuestionsSheet(_TreeNode node) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Add your questions",
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.ink),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_rounded, color: AppColors.ink, size: 18),
                ),
                title: Text("Write manually", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13)),
                subtitle: Text("Type out the question yourself", style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openManualAddForm(node);
                },
              ),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: AppColors.civic.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.auto_awesome_rounded, color: AppColors.civic, size: 18),
                ),
                title: Text("Parse with AI", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13)),
                subtitle: Text("Upload a file, image, or text and post with A.I.", style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openAiParsing(node);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // Legacy inline expand/collapse tree — superseded by _buildCategoryBrowser +
  // _CategoryDrillDownScreen (see above). No longer reachable from the
  // build() call site but left in place for now; slated for removal once
  // the grid has been verified in real use.
  Widget _buildTreeNodes(List<_TreeNode> nodes, int depth, {int? tourAnchorId}) {
    return Column(
      children: nodes.map((node) {
        final bool hasChildren = node.children.isNotEmpty;
        final bool isExpanded = _expandedNodes.contains(node.id);
        final int available = _getAvailableCount(node.id);
        final bool isRoot = depth == 0 || node.nodeType == 'subject' || node.nodeType == 'paper';

        Widget? childrenWidget;
        if (isExpanded && hasChildren) {
          childrenWidget = Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _buildTreeNodes(node.children, depth + 1, tourAnchorId: tourAnchorId),
          );
        }

        if (isRoot) {
          // Root cards always drill into a new screen (_openCategoryBrowse)
          // rather than expanding inline — never pass childrenWidget here,
          // even if search matching happened to mark this node expanded.
          return _buildRootCategoryCard(
            node: node,
            hasChildren: hasChildren,
            isExpanded: isExpanded,
            available: available,
            childrenWidget: null,
            isTourAnchor: tourAnchorId != null && node.id == tourAnchorId,
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPracticeCategoryRow(
                node: node,
                depth: depth,
                hasChildren: hasChildren,
                isExpanded: isExpanded,
                available: available,
              ),
              if (childrenWidget != null) childrenWidget,
            ],
          );
        }
      }).toList(),
    );
  }

  Future<void> _openCategoryBrowse(_TreeNode node) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'drilldown_0'),
        builder: (_) => _CategoryDrillDownScreen(
          levelNodes: node.children,
          breadcrumb: [node.name],
          getAvailableCount: _getAvailableCount,
          getQuantity: _getCategoryQuantity,
          setQuantity: _setSelectedQuantity,
          onAdd: _addQuantityToTest,
          onStart: _startDirectTest,
          onManualAdd: _openManualAddForm,
          onParseAI: _openAiParsing,
          getCartTotal: () => _compiledItems.fold<int>(0, (s, i) => s + (i['count'] as int)),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  String get _tourBrowseDescription {
    switch (_activeTab) {
      case 'mains':
        return "Papers go several levels deep — Subject Area, Theme, Topic, Subtopic. Tap here to step into any of them one level at a time.";
      case 'aptitude':
        return "Tap here to step into this subject's sources and topics one level at a time, instead of scrolling a long nested list.";
      default:
        return "Tap here to step into this subject's sources and topics one level at a time, instead of scrolling a long nested list.";
    }
  }

  Widget _buildAddStartRow(_TreeNode node, int available) {
    return Row(
      children: [
        _buildQuantitySelector(node, available),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () => _addQuantityToTest(node),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.civic,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: Text(
            "Add",
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => _startDirectTest(node),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.ink,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: Text(
            "Start",
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  String get _tourAddDescription {
    switch (_activeTab) {
      case 'mains':
        return "Set how many subjective questions you want from here, then Add — Mains tests work best with a smaller, focused set (try 5-10 to start).";
      default:
        return "Set how many questions you want from here, then Add. Repeat across categories to build a combined test, or Start for a quick one right away.";
    }
  }

  Widget _buildRootCategoryCard({
    required _TreeNode node,
    required bool hasChildren,
    required bool isExpanded,
    required int available,
    Widget? childrenWidget,
    bool isTourAnchor = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line.withOpacity(0.8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row — tapping anywhere here browses into this subject's
          // sub-categories one level at a time (see _CategoryDrillDownScreen).
          InkWell(
            onTap: hasChildren ? () => _openCategoryBrowse(node) : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: available == 0 ? const Radius.circular(16) : Radius.zero,
              bottomRight: available == 0 ? const Radius.circular(16) : Radius.zero,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 52,
                      width: 52,
                      child: _buildCategoryImage(node, iconSize: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (node.description?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            node.description!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (hasChildren) ...[
                    const SizedBox(width: 8),
                    isTourAnchor
                        ? Showcase(
                            key: _tourBrowseKey,
                            title: "Browse Sub-Categories",
                            description: _tourBrowseDescription,
                            targetBorderRadius: BorderRadius.circular(8),
                            child: const Icon(Icons.chevron_right_rounded, color: AppColors.civic, size: 24),
                          )
                        : const Icon(Icons.chevron_right_rounded, color: AppColors.civic, size: 24),
                  ],
                ],
              ),
            ),
          ),
          
          // Selection Bar (only if available > 0)
          if (available > 0) ...[
            const Divider(color: AppColors.line, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          "$available Qs",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.civic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_userQuestionCounts[node.id] != null && _userQuestionCounts[node.id]! > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              border: Border.all(color: Colors.amber.shade200),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "+${_userQuestionCounts[node.id]} yours",
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  isTourAnchor
                      ? Showcase(
                          key: _tourAddKey,
                          title: "Add Questions to Your Test",
                          description: _tourAddDescription,
                          targetBorderRadius: BorderRadius.circular(8),
                          child: _buildAddStartRow(node, available),
                        )
                      : _buildAddStartRow(node, available),
                ],
              ),
            ),
          ],



          // Children list nested inside the card!
          if (childrenWidget != null) ...[
            const Divider(color: AppColors.line, height: 1),
            Container(
              decoration: BoxDecoration(
                color: AppColors.paper.withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
              child: childrenWidget,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPracticeCategoryRow({
    required _TreeNode node,
    required int depth,
    required bool hasChildren,
    required bool isExpanded,
    required int available,
  }) {
    if (node.isUserNode) {
      final double leftPadding = (depth - 1) * 16.0;
      return Container(
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        padding: EdgeInsets.only(left: leftPadding + 8, right: 8, top: 8, bottom: 8),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withOpacity(0.4), style: BorderStyle.solid),
        ),
        child: Row(
          children: [
            Icon(Icons.person_outline_rounded, color: Colors.amber[800], size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.amber[900],
                    ),
                  ),
                  Text(
                    "Private questions submitted by you",
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.amber[800],
                    ),
                  ),
                ],
              ),
            ),
            if (available > 0) ...[
              Text(
                "$available Qs",
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.amber[900],
                ),
              ),
              const SizedBox(width: 8),
              _buildQuantitySelector(node, available),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _addQuantityToTest(node),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "Add",
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: () => _startDirectTest(node),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "Start",
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ] else ...[
              Text(
                "0 Qs",
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
            ],
          ],
        ),
      );
    }

    final double leftPadding = (depth - 1) * 16.0;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: EdgeInsets.only(left: leftPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (depth > 1) ...[
            Container(
              width: 1.5,
              height: 38,
              margin: const EdgeInsets.only(right: 12, left: 4),
              color: AppColors.line,
            ),
          ] else ...[
            Container(
              margin: const EdgeInsets.only(top: 2, right: 10),
              child: Icon(
                hasChildren ? Icons.folder_open_rounded : Icons.radio_button_checked_rounded,
                size: 14,
                color: AppColors.civic.withOpacity(0.7),
              ),
            ),
          ],
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: hasChildren ? () => _toggleExpanded(node.id) : null,
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      node.name,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ),
                                  if (hasChildren) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: AppColors.muted,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (hasChildren)
                            IconButton(
                              icon: const Icon(Icons.list_alt_rounded, color: AppColors.civic, size: 16),
                              tooltip: "Browse sub-categories",
                              onPressed: () async {
                                final breadcrumb = _breadcrumbFor(node);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    settings: RouteSettings(name: 'drilldown_0'),
                                    builder: (_) => _CategoryDrillDownScreen(
                                      levelNodes: node.children,
                                      breadcrumb: breadcrumb,
                                      getAvailableCount: _getAvailableCount,
                                      getQuantity: _getCategoryQuantity,
                                      setQuantity: _setSelectedQuantity,
                                      onAdd: _addQuantityToTest,
                                      onStart: _startDirectTest,
                                      onManualAdd: _openManualAddForm,
                                      onParseAI: _openAiParsing,
                                      getCartTotal: () => _compiledItems.fold<int>(0, (s, i) => s + (i['count'] as int)),
                                    ),
                                  ),
                                );
                                if (mounted) setState(() {});
                              },
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.only(left: 6),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.civic.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "L${depth + 1}",
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: AppColors.civic,
                        ),
                      ),
                    ),
                  ],
                ),
                if (node.description?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    node.description!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                if (available > 0) ...[
                  Row(
                    children: [
                      Text(
                        "$available Qs",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.civic,
                        ),
                      ),
                      if (_userQuestionCounts[node.id] != null && _userQuestionCounts[node.id]! > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            border: Border.all(color: Colors.amber.shade200),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "+${_userQuestionCounts[node.id]} yours",
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      _buildQuantitySelector(node, available),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _addQuantityToTest(node),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.civic,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          "Add",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: () => _startDirectTest(node),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.ink,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          "Start",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    "0 Available",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.muted.withOpacity(0.7),
                    ),
                  ),
                ],
                if (!node.isUserNode) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _openManualAddForm(node),
                        child: Row(
                          children: [
                            const Icon(Icons.add_circle_outline_rounded, size: 12, color: AppColors.civic),
                            const SizedBox(width: 4),
                            Text(
                              "Add Q",
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.civic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () {
                          final apiClient = Provider.of<ApiClient>(context, listen: false);
                          if (!apiClient.hasEntitlement('assessment.premium_tests')) {
                            _showPremiumLockDialog();
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AiBasedParsingScreen(
                                categoryNodeId: node.id,
                                contentType: _activeTab,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.psychology_outlined, size: 12, color: AppColors.civic),
                            const SizedBox(width: 4),
                            Text(
                              "Parse AI",
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.civic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCountBadge(int available) {
    final hasQuestions = available > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: hasQuestions
            ? AppColors.civic.withOpacity(0.08)
            : AppColors.paper,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: hasQuestions
              ? AppColors.civic.withOpacity(0.2)
              : AppColors.line,
        ),
      ),
      child: Text(
        hasQuestions ? "$available available" : "No questions",
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: hasQuestions ? AppColors.civic : AppColors.muted,
        ),
      ),
    );
  }

  Widget _buildCategoryImage(_TreeNode node, {required double iconSize}) {
    final imageUrl = _resolveImageUrl(node.imageUrl);
    if (imageUrl == null) {
      return Container(
        color: AppColors.civic.withOpacity(0.08),
        alignment: Alignment.center,
        child: Icon(
          Icons.category_rounded,
          color: AppColors.civic,
          size: iconSize,
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(
          color: AppColors.civic.withOpacity(0.08),
          alignment: Alignment.center,
          child: Icon(
            Icons.category_rounded,
            color: AppColors.civic,
            size: iconSize,
          ),
        );
      },
    );
  }

  String? _resolveImageUrl(String? rawUrl) {
    final value = rawUrl?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://'))
      return value;
    if (value.startsWith('/')) return '${ApiConstants.baseUrl}$value';
    return value;
  }

  void _toggleExpanded(int nodeId) {
    setState(() {
      if (_expandedNodes.contains(nodeId)) {
        _expandedNodes.remove(nodeId);
      } else {
        _expandedNodes.add(nodeId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.civic),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: AppColors.ink,
          ),
        ),
      );
    }

    final totalCartQs = _compiledItems.fold<int>(
      0,
      (sum, item) => sum + (item['count'] as int),
    );

    return ShowCaseWidget(
      builder: (showcaseContext) {
        if (!_tourChecked && widget.isActive) {
          _tourChecked = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _maybeAutoStartBuilderTour(showcaseContext);
          });
        }
        return _buildBuilderStack(totalCartQs);
      },
    );
  }

  Future<void> _maybeAutoStartBuilderTour(BuildContext showcaseContext) async {
    if (!widget.isActive) return;
    final tourKey = AppTourService.builderScreenKeyFor(_activeTab);
    if (!await AppTourService.shouldShowTour(tourKey)) return;
    if (!mounted || !showcaseContext.mounted) return;

    // GlobalKeys for the anchor row may not be attached yet on the very
    // first post-frame callback (e.g. if syllabus data just finished
    // loading this same frame). Retry across a couple of frames before
    // giving up, and — importantly — only mark the tour "seen" once it has
    // actually been shown, so a transient miss doesn't silently burn the
    // one-time flag forever.
    for (var attempt = 0; attempt < 5; attempt++) {
      final keys = <GlobalKey>[
        if (_tourBrowseKey.currentContext != null) _tourBrowseKey,
        if (_tourAddKey.currentContext != null) _tourAddKey,
      ];
      if (keys.isNotEmpty) {
        await AppTourService.markTourSeen(tourKey);
        if (!mounted || !showcaseContext.mounted) return;
        ShowCaseWidget.of(showcaseContext).startShowCase(keys);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted || !showcaseContext.mounted) return;
    }
  }

  Widget _buildBuilderStack(int totalCartQs) {
    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              Expanded(
                child: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverToBoxAdapter(
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 16,
                            bottom: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.rootNodeId == null) ...[
                                Text(
                                  "EXAM",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                    color: AppColors.muted,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "UPSC CSE",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: AppColors.civic,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              Text(
                                "Test Topics",
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  color: AppColors.ink,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Build and practice dedicated syllabus trees.",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(color: AppColors.line),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: TextField(
                                        controller: _searchController,
                                        onChanged: (val) {
                                          setState(() {
                                            _searchQuery = val.trim();
                                          });
                                        },
                                        decoration: InputDecoration(
                                          hintText: "Search categories or topics...",
                                          hintStyle: GoogleFonts.inter(
                                            color: AppColors.muted,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.search_rounded,
                                            color: AppColors.muted,
                                            size: 18,
                                          ),
                                          suffixIcon: _searchQuery.isNotEmpty
                                              ? IconButton(
                                                  icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.muted),
                                                  onPressed: () {
                                                    _searchController.clear();
                                                    setState(() {
                                                      _searchQuery = '';
                                                    });
                                                  },
                                                )
                                              : null,
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ];
                  },
                  body: _loadingBookmarks
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.civic),
                        )
                      : _activeTab == 'revision' && _bookmarks.isEmpty
                          ? Center(
                              child: Text(
                                "No bookmarks found.",
                                style: GoogleFonts.inter(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : _activeTab == 'revision'
                                  ? _buildRevisionView()
                                  : _activeTree.isEmpty
                                      ? Center(
                                          child: Text(
                                            "No categories found.",
                                            style: GoogleFonts.inter(
                                              color: AppColors.muted,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : ListView(
                                          padding: const EdgeInsets.all(16),
                                          children: [
                                            Card(
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                side: BorderSide(
                                                    color: AppColors.civic.withOpacity(0.2)),
                                              ),
                                              color: AppColors.civic.withOpacity(0.05),
                                              child: InkWell(
                                                borderRadius: BorderRadius.circular(12),
                                                onTap: _showCustomizeSyllabusModal,
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 16, vertical: 12),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.tune_rounded,
                                                        color: AppColors.civic,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              "Customize Syllabus View",
                                                              style: GoogleFonts.plusJakartaSans(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 14,
                                                                color: AppColors.ink,
                                                              ),
                                                            ),
                                                            const SizedBox(height: 2),
                                                            Text(
                                                              "Hide/show books, sources or specific topics.",
                                                              style: GoogleFonts.inter(
                                                                fontSize: 11,
                                                                color: AppColors.muted,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const Icon(
                                                        Icons.chevron_right_rounded,
                                                        color: AppColors.muted,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            _buildCategoryBrowser(
                                              _filterTree(_activeTree, _searchQuery),
                                              _findTourAnchorNodeId(),
                                            ),
                                            const SizedBox(height: 80),
                                          ],
                                        ),
                ),
              ),
              if (_compiledItems.isNotEmpty)
                const SizedBox(height: 76),
            ],
          ),
        ),

        // Bottom collapsible Panel
        if (_compiledItems.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: _isCartExpanded ? 480.0 : 76.0,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header trigger
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isCartExpanded = !_isCartExpanded;
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.line,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Custom Test Cart",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        "${_compiledItems.length} Categories • $totalCartQs / 100 Qs",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          color: totalCartQs > 100 ? Colors.red : AppColors.ink,
                                        ),
                                      ),
                                      if (totalCartQs > 100) ...[
                                        const SizedBox(width: 6),
                                        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              Icon(
                                _isCartExpanded
                                    ? Icons.keyboard_arrow_down_rounded
                                    : Icons.keyboard_arrow_up_rounded,
                                color: AppColors.civic,
                                size: 24,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(color: AppColors.line, height: 1),

                  if (_isCartExpanded)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "TEST NAME *",
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                color: AppColors.muted,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _customTestNameController,
                              decoration: InputDecoration(
                                hintText: "e.g., My Custom Practice Test",
                                filled: true,
                                fillColor: AppColors.paper.withOpacity(0.4),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.line),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.civic, width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "SELECTED CATEGORIES",
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                color: AppColors.muted,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.separated(
                                itemCount: _compiledItems.length,
                                separatorBuilder: (_, __) => const Divider(color: AppColors.line, height: 1),
                                itemBuilder: (context, index) {
                                  final item = _compiledItems[index];
                                  final node = item['node'] as _TreeNode;
                                  final count = item['count'] as int;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
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
                                        Text(
                                          "$count Qs",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppColors.civic,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded,
                                              color: Colors.red, size: 20),
                                          onPressed: () {
                                            setState(() {
                                              _compiledItems.removeAt(index);
                                              if (_compiledItems.isEmpty) {
                                                _isCartExpanded = false;
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (totalCartQs > 100) ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.withOpacity(0.15)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Max 100 questions allowed in a single test.",
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.red,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            // Destination is chosen once, here — not per Add
                            // tap. Both paths follow the same shape: name a
                            // new test, or pick from your existing ones.
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: AppColors.civic),
                                        foregroundColor: AppColors.civic,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: (totalCartQs > 0 && totalCartQs <= 100 && !_compiling)
                                          ? _addCartToExistingTest
                                          : null,
                                      child: Text(
                                        "Add to Existing",
                                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.civic,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed: (totalCartQs > 0 && totalCartQs <= 100 && !_compiling)
                                          ? _saveCartAsNewTest
                                          : null,
                                      child: _compiling
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              "Save as New Test",
                                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }


  void _showFreeLimitDialog(String message) {
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
                "Free Tests Used Up",
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: Text(
            message,
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

  void _showPremiumLockDialog() {
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
            "Manually authoring or AI-parsing new questions is a premium feature. Upgrade to Assessment Premium for unlimited access.",
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

class _SliverTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverTabHeaderDelegate({required this.child});

  @override
  double get minExtent => 68.0;

  @override
  double get maxExtent => 68.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _SliverTabHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
