import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import 'self_test_builder_tab.dart';
import 'my_tests_tab.dart';

/// A self-contained page for one content type (GK, CSAT, or Mains).
/// Has 2 tabs: Create Test + Performance
class ContentTypeScreen extends StatefulWidget {
  final String contentType; // 'gk' | 'aptitude' | 'mains'
  final String label;       // Display label e.g. 'General Studies'
  final int initialTabIndex;
  const ContentTypeScreen({
    super.key,
    required this.contentType,
    required this.label,
    this.initialTabIndex = 0,
  });

  @override
  State<ContentTypeScreen> createState() => _ContentTypeScreenState();
}

class _ContentTypeScreenState extends State<ContentTypeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex >= 0 && widget.initialTabIndex < 3
          ? widget.initialTabIndex
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
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.civic,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.civic,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
            tabs: const [
              Tab(text: 'Create Test'),
              Tab(text: 'My Tests'),
              Tab(text: 'Revision'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              SelfTestBuilderTab(contentType: widget.contentType),
              MyTestsTab(contentType: widget.contentType, onlyInProgress: true),
              SelfTestBuilderTab(
                contentType: widget.contentType,
                isRevisionMode: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
