import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import 'self_test_builder_tab.dart';
import 'category_performance_detail_screen.dart';

class CategoryDetailScreen extends StatefulWidget {
  final int nodeId;
  final String nodeName;
  final String contentType;
  const CategoryDetailScreen({
    super.key,
    required this.nodeId,
    required this.nodeName,
    required this.contentType,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          widget.nodeName,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.ink),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.civic,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.civic,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: const [
            Tab(text: 'Create Test'),
            Tab(text: 'Performance'),
            Tab(text: 'Revision'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SelfTestBuilderTab(
            contentType: widget.contentType,
            rootNodeId: widget.nodeId,
          ),
          CategoryPerformanceDetailScreen(
            taxonomyNodeId: widget.nodeId,
            initialTitle: widget.nodeName,
            contentType: widget.contentType,
          ),
          SelfTestBuilderTab(
            contentType: widget.contentType,
            isRevisionMode: true,
            rootNodeId: widget.nodeId,
          ),
        ],
      ),
    );
  }
}
