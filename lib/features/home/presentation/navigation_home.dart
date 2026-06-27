import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../assessment/presentation/tests_hub_screen.dart';
import '../../assessment/presentation/assessment_dashboard_screen.dart';
import '../../study_plans/presentation/study_plan_list_screen.dart';
import '../../mentors/presentation/mentor_list_screen.dart';
import '../../mentors/presentation/my_bookings_screen.dart';
import 'home_screen.dart';

class NavigationHome extends StatefulWidget {
  const NavigationHome({super.key});

  @override
  State<NavigationHome> createState() => _NavigationHomeState();
}

class _NavigationHomeState extends State<NavigationHome> {
  int _currentIndex = 0;
  int _testsSubIndex = 0;
  int _testsSubSubIndex = 0;

  void _onTabSelected(int index, {int subIndex = 0, int subSubIndex = 0}) {
    setState(() {
      _currentIndex = index;
      if (index == 2) {
        _testsSubIndex = subIndex;
        _testsSubSubIndex = subSubIndex;
      }
    });
  }

  void _showLogoutDialog(BuildContext context, ApiClient apiClient) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Sign Out", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          content: const Text("Are you sure you want to sign out of UPSC Test Series?"),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                apiClient.logout();
              },
              child: const Text("Sign Out", style: TextStyle(color: AppColors.berry)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiClient = Provider.of<ApiClient>(context);
    final username = apiClient.user?['username'] ?? 'Student';
    final email = apiClient.user?['email'] ?? '';
    final hasPremium = apiClient.hasEntitlement('assessment.premium_tests');

    final screens = [
      HomeScreen(onTabSelected: (index, {int subIndex = 0, int subSubIndex = 0}) {
        _onTabSelected(index, subIndex: subIndex, subSubIndex: subSubIndex);
      }),
      const AssessmentDashboardScreen(),
      TestsHubScreen(
        key: ValueKey('tests_hub_${_testsSubIndex}_$_testsSubSubIndex'),
        initialIndex: _testsSubIndex,
        initialSubIndex: _testsSubSubIndex,
      ),
      const StudyPlanListScreen(),
      const MentorListScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.civic.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.school_rounded,
                color: AppColors.civic,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          "Coaching Hub",
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (hasPremium) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "PRO",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    "UPSC Test Series",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) {
              if (value == 'bookings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MyBookingsScreen()),
                );
              } else if (value == 'logout') {
                _showLogoutDialog(context, apiClient);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    const Divider(height: 16),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'bookings',
                child: Row(
                  children: [
                    const Icon(Icons.book_online_rounded, color: AppColors.civic, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      "My Mentor Bookings",
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, color: AppColors.berry, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      "Sign Out",
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.berry),
                    ),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Chip(
                backgroundColor: AppColors.paper,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                avatar: CircleAvatar(
                  backgroundColor: hasPremium ? const Color(0xFFF59E0B).withOpacity(0.2) : AppColors.civic.withOpacity(0.2),
                  child: hasPremium
                      ? const Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 12)
                      : Text(
                          username.isNotEmpty ? username[0].toUpperCase() : 'S',
                          style: const TextStyle(color: AppColors.civic, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        username,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (hasPremium) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                    ],
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.muted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: Colors.white,
          indicatorColor: AppColors.civic.withOpacity(0.08),
          height: 65,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: _currentIndex == 0 ? AppColors.civic : AppColors.muted),
              selectedIcon: const Icon(Icons.home_rounded, color: AppColors.civic),
              label: "Home",
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined, color: _currentIndex == 1 ? AppColors.civic : AppColors.muted),
              selectedIcon: const Icon(Icons.bar_chart_rounded, color: AppColors.civic),
              label: "Dashboard",
            ),
            NavigationDestination(
              icon: Icon(Icons.quiz_outlined, color: _currentIndex == 2 ? AppColors.civic : AppColors.muted),
              selectedIcon: const Icon(Icons.quiz_rounded, color: AppColors.civic),
              label: "Tests",
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined, color: _currentIndex == 3 ? AppColors.civic : AppColors.muted),
              selectedIcon: const Icon(Icons.calendar_month_rounded, color: AppColors.civic),
              label: "Study Plans",
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded, color: _currentIndex == 4 ? AppColors.civic : AppColors.muted),
              selectedIcon: const Icon(Icons.people_rounded, color: AppColors.civic),
              label: "Mentors",
            ),
          ],
        ),
      ),
    );
  }
}
