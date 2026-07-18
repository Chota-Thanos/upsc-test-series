part of 'self_test_builder_tab.dart';

// One level of a subject/topic hierarchy, navigated one screen at a time
// instead of nested inline indentation — needed once a taxonomy goes 4-5
// levels deep (GK/CSAT: subject -> source bucket -> topic -> subtopic;
// Mains: paper -> subject area -> theme -> topic -> subtopic).
//
// Reads the already-fetched `_activeTree` held by the parent
// _SelfTestBuilderTabState (passed in via `levelNodes`) — no network call on
// open, so there's no refetch/refresh. Quantity edits and "Add"/"Start"
// write straight into the parent's existing `_selectedQuantities` /
// `_compiledItems` via callbacks, so nothing is lost on the way back and the
// parent's own inline tree reflects the same cart when you return to it.

// Icon + label per taxonomy level, so depth is visible at a glance instead
// of relying purely on the breadcrumb text.
IconData _drillDownNodeIcon(String nodeType, bool hasChildren) {
  if (!hasChildren) return Icons.description_rounded;
  switch (nodeType) {
    case 'subject':
    case 'paper':
      return Icons.menu_book_rounded;
    case 'source_bucket':
    case 'subject_area':
      return Icons.folder_rounded;
    case 'topic':
    case 'theme':
      return Icons.category_rounded;
    default:
      return Icons.folder_rounded;
  }
}

const Map<String, String> _drillDownLevelLabels = {
  'subject': 'Subject',
  'paper': 'Paper',
  'source_bucket': 'Source',
  'subject_area': 'Subject area',
  'topic': 'Topic',
  'theme': 'Theme',
  'subtopic': 'Subtopic',
};

const Map<String, String> _drillDownLevelLabelsPlural = {
  'subject': 'subjects',
  'paper': 'papers',
  'source_bucket': 'sources',
  'subject_area': 'subject areas',
  'topic': 'topics',
  'theme': 'themes',
  'subtopic': 'subtopics',
};

class _CategoryDrillDownScreen extends StatefulWidget {
  final List<_TreeNode> levelNodes;
  final List<String> breadcrumb;
  final int Function(int nodeId) getAvailableCount;
  final int Function(int nodeId, int available) getQuantity;
  final void Function(int nodeId, int value) setQuantity;
  final void Function(_TreeNode node) onAdd;
  final void Function(_TreeNode node) onStart;
  final void Function(_TreeNode node) onManualAdd;
  final void Function(_TreeNode node) onParseAI;
  final int Function() getCartTotal;

  const _CategoryDrillDownScreen({
    required this.levelNodes,
    required this.breadcrumb,
    required this.getAvailableCount,
    required this.getQuantity,
    required this.setQuantity,
    required this.onAdd,
    required this.onStart,
    required this.onManualAdd,
    required this.onParseAI,
    required this.getCartTotal,
  });

  @override
  State<_CategoryDrillDownScreen> createState() =>
      _CategoryDrillDownScreenState();
}

class _CategoryDrillDownScreenState extends State<_CategoryDrillDownScreen> {
  Future<void> _openChild(_TreeNode node) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: 'drilldown_${widget.breadcrumb.length}'),
        builder: (_) => _CategoryDrillDownScreen(
          levelNodes: node.children,
          breadcrumb: [...widget.breadcrumb, node.name],
          getAvailableCount: widget.getAvailableCount,
          getQuantity: widget.getQuantity,
          setQuantity: widget.setQuantity,
          onAdd: widget.onAdd,
          onStart: widget.onStart,
          onManualAdd: widget.onManualAdd,
          onParseAI: widget.onParseAI,
          getCartTotal: widget.getCartTotal,
        ),
      ),
    );
    // A quantity may have changed one or more levels deeper — refresh so this
    // level's steppers/available-count badges/cart total show current values.
    if (mounted) setState(() {});
  }

  void _jumpToBreadcrumb(int index) {
    if (index == widget.breadcrumb.length - 1) return; // already here
    Navigator.popUntil(context, (route) {
      final name = route.settings.name;
      return name == 'drilldown_$index' ||
          !(name?.startsWith('drilldown_') ?? false);
    });
  }

  void _reviewCart() {
    Navigator.popUntil(
      context,
      (route) => !(route.settings.name?.startsWith('drilldown_') ?? false),
    );
  }

  void _showAddQuestionsSheet(_TreeNode node) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Add your questions",
                    style: AppTypography.sectionHeader.copyWith(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: AppColors.ink,
                    size: 18,
                  ),
                ),
                title: Text(
                  "Write manually",
                  style: AppTypography.cardTitle.copyWith(fontSize: 13),
                ),
                subtitle: Text(
                  "Type out the question yourself",
                  style: AppTypography.caption.copyWith(fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  widget.onManualAdd(node);
                },
              ),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.civic.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.civic,
                    size: 18,
                  ),
                ),
                title: Text(
                  "Parse with AI",
                  style: AppTypography.cardTitle.copyWith(fontSize: 13),
                ),
                subtitle: Text(
                  "Upload a file, image, or text and post with A.I.",
                  style: AppTypography.caption.copyWith(fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  widget.onParseAI(node);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepper(_TreeNode node, int available) {
    final currentVal = widget.getQuantity(node.id, available);
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
                ? () => setState(
                    () => widget.setQuantity(node.id, currentVal - 1),
                  )
                : null,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              "$currentVal",
              style: AppTypography.cardTitle.copyWith(fontSize: 12),
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.add, size: 14, color: AppColors.ink),
            onPressed: currentVal < available
                ? () => setState(
                    () => widget.setQuantity(node.id, currentVal + 1),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildFolderRow(_TreeNode node) {
    final available = widget.getAvailableCount(node.id);
    final childType = node.children.first.nodeType;
    final childLabel = _drillDownLevelLabelsPlural[childType] ?? 'categories';
    return InkWell(
      onTap: () => _openChild(node),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.civic.withOpacity(0.08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                _drillDownNodeIcon(node.nodeType, true),
                size: 17,
                color: AppColors.civic,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          node.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cardTitle.copyWith(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _drillDownLevelLabels[node.nodeType] ?? 'Category',
                          style: AppTypography.eyebrowSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${node.children.length} $childLabel · $available Qs",
                    style: AppTypography.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeafRow(_TreeNode node) {
    final available = widget.getAvailableCount(node.id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.emerald.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  size: 17,
                  color: AppColors.emerald,
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
                      style: AppTypography.cardTitle.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      available > 0
                          ? "$available questions available"
                          : "No questions available",
                      style: AppTypography.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (available > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStepper(node, available),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => widget.onAdd(node)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.civic),
                      foregroundColor: AppColors.civic,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      "Add",
                      style: AppTypography.button.copyWith(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => widget.onStart(node),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          "Start",
                          style: AppTypography.button.copyWith(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () => _showAddQuestionsSheet(node),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_rounded,
                    size: 13,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Add your questions",
                    style: AppTypography.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartTotal = widget.getCartTotal();
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.breadcrumb.last,
          style: AppTypography.title.copyWith(fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          if (widget.breadcrumb.length > 1)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < widget.breadcrumb.length; i++) ...[
                      if (i > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: AppColors.muted,
                          ),
                        ),
                      GestureDetector(
                        onTap: () => _jumpToBreadcrumb(i),
                        child: Text(
                          widget.breadcrumb[i],
                          style: AppTypography.button.copyWith(
                            fontSize: 11,
                            fontWeight: i == widget.breadcrumb.length - 1
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: i == widget.breadcrumb.length - 1
                                ? AppColors.ink
                                : AppColors.civic,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          Expanded(
            child: widget.levelNodes.isEmpty
                ? Center(
                    child: Text(
                      "No sub-categories here.",
                      style: AppTypography.body.copyWith(fontSize: 13),
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.only(bottom: cartTotal > 0 ? 76 : 0),
                    children: [
                      Container(
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.line),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (final node in widget.levelNodes)
                              node.children.isNotEmpty
                                  ? _buildFolderRow(node)
                                  : _buildLeafRow(node),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: cartTotal > 0
          ? SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: InkWell(
                  onTap: _reviewCart,
                  child: Row(
                    children: [
                      Text(
                        "$cartTotal question${cartTotal == 1 ? '' : 's'} selected",
                        style: AppTypography.caption.copyWith(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "Review",
                        style: AppTypography.button.copyWith(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
