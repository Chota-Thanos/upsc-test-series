import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import 'content_type_screen.dart';

/// Top-level hub screen shown in the bottom nav 'Tests' tab.
/// Has 4 top-level tabs: GK | CSAT | Mains | Revision
class TestsHubScreen extends StatefulWidget {
  final int initialIndex;
  final int initialSubIndex;
  const TestsHubScreen({super.key, this.initialIndex = 0, this.initialSubIndex = 0});

  @override
  State<TestsHubScreen> createState() => _TestsHubScreenState();
}

class _TestsHubScreenState extends State<TestsHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<_ContentTab> _tabs = [
    _ContentTab(contentType: 'gk', label: 'General Studies', shortLabel: 'GS'),
    _ContentTab(contentType: 'aptitude', label: 'CSAT / Aptitude', shortLabel: 'CSAT'),
    _ContentTab(contentType: 'mains', label: 'Mains', shortLabel: 'Mains'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialIndex >= 0 && widget.initialIndex < _tabs.length
          ? widget.initialIndex
          : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Color(0x10000000), blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(3),
              dividerColor: Colors.transparent,
              labelColor: AppColors.ink,
              unselectedLabelColor: AppColors.muted,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: _tabs.map((t) => Tab(text: t.shortLabel)).toList(),
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _tabs.map((t) {
              final idx = _tabs.indexOf(t);
              final initialSub = idx == widget.initialIndex ? widget.initialSubIndex : 0;
              return ContentTypeScreen(
                contentType: t.contentType,
                label: t.label,
                initialTabIndex: initialSub,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ContentTab {
  final String contentType;
  final String label;
  final String shortLabel;
  const _ContentTab({required this.contentType, required this.label, required this.shortLabel});
}
