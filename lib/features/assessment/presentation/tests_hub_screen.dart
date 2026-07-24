import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/tour/app_tour_service.dart';
import 'content_type_screen.dart';

/// Top-level hub screen shown in the bottom nav 'Tests' tab.
/// Has 4 top-level tabs: GK | CSAT | Mains | Revision
class TestsHubScreen extends StatefulWidget {
  final int initialIndex;
  final int initialSubIndex;
  // NavigationHome keeps every bottom-nav tab alive in an IndexedStack, so
  // this screen is built even when a different tab is on screen. The tour
  // must only auto-start once this screen is actually visible — see
  // _maybeAutoStartTour and didUpdateWidget below.
  final bool isActive;
  const TestsHubScreen({
    super.key,
    this.initialIndex = 0,
    this.initialSubIndex = 0,
    this.isActive = true,
  });

  @override
  State<TestsHubScreen> createState() => _TestsHubScreenState();
}

class _TestsHubScreenState extends State<TestsHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final GlobalKey _tourTabBarKey = GlobalKey();
  bool _tourChecked = false;

  static const List<_ContentTab> _tabs = [
    _ContentTab(contentType: 'gk', label: 'General Studies', shortLabel: 'GS'),
    _ContentTab(
      contentType: 'aptitude',
      label: 'CSAT / Aptitude',
      shortLabel: 'CSAT',
    ),
    _ContentTab(contentType: 'mains', label: 'Mains', shortLabel: 'Mains'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex:
          widget.initialIndex >= 0 && widget.initialIndex < _tabs.length
          ? widget.initialIndex
          : 0,
    );
    // TabBarView pre-builds neighbouring pages too, so a ContentTypeScreen's
    // own isActive needs to track the live selected index, not just the
    // initial one.
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant TestsHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      // Only now actually on screen — re-run the first-visit check.
      _tourChecked = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _maybeAutoStartTour(BuildContext showcaseContext) async {
    if (!widget.isActive) return;
    if (!await AppTourService.shouldShowTour(
      AppTourService.contentTypeSelectKey,
    ))
      return;
    if (!mounted || !showcaseContext.mounted) return;
    // Only mark as seen once we've confirmed the target is actually attached
    // — otherwise a transient miss would silently burn the one-time flag.
    if (_tourTabBarKey.currentContext == null) return;
    await AppTourService.markTourSeen(AppTourService.contentTypeSelectKey);
    if (!mounted || !showcaseContext.mounted) return;
    ShowCaseWidget.of(showcaseContext).startShowCase([_tourTabBarKey]);
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (ctx) {
        if (!_tourChecked && widget.isActive) {
          _tourChecked = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _maybeAutoStartTour(ctx);
          });
        }
        return Column(
          children: [
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Showcase(
                key: _tourTabBarKey,
                title: "Choose What to Practice",
                description:
                    "Switch between General Studies, CSAT, and Mains here — each has its own set of topics to build a test from.",
                targetBorderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x10000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.all(3),
                    dividerColor: Colors.transparent,
                    labelColor: AppColors.ink,
                    unselectedLabelColor: AppColors.muted,
                    labelStyle: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.ink,
                    ),
                    unselectedLabelStyle: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    tabs: _tabs.map((t) => Tab(text: t.shortLabel)).toList(),
                  ),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _tabs.map((t) {
                  final idx = _tabs.indexOf(t);
                  final initialSub = idx == widget.initialIndex
                      ? widget.initialSubIndex
                      : 0;
                  return ContentTypeScreen(
                    contentType: t.contentType,
                    label: t.label,
                    initialTabIndex: initialSub,
                    isActive: widget.isActive && _tabController.index == idx,
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ContentTab {
  final String contentType;
  final String label;
  final String shortLabel;
  const _ContentTab({
    required this.contentType,
    required this.label,
    required this.shortLabel,
  });
}
