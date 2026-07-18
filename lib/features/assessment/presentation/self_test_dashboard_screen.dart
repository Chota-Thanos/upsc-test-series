import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'self_test_builder_tab.dart';
import 'my_tests_tab.dart';

class SelfTestDashboardScreen extends StatefulWidget {
  const SelfTestDashboardScreen({super.key});

  @override
  State<SelfTestDashboardScreen> createState() =>
      _SelfTestDashboardScreenState();
}

class _SelfTestDashboardScreenState extends State<SelfTestDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.civic,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.civic,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: AppTypography.button.copyWith(
            fontSize: 14,
            color: AppColors.civic,
          ),
          unselectedLabelStyle: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: "Self Test"),
            Tab(text: "My Tests"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [SelfTestBuilderTab(), MyTestsTab()],
      ),
    );
  }
}
