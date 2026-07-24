import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/mentor_workspace_service.dart';
import '../models/mentor_workspace_models.dart';
import 'mentor_request_detail_screen.dart';
import 'mentor_availability_tab.dart';
import 'mentor_profile_tab.dart';

/// Root shell for users with the `mentor` role. Provides the mentor workspace:
/// dashboard, student requests, availability desk, and profile/settings — the
/// native counterpart to the web `/mentor/workspace` dashboard.
class MentorNavigationHome extends StatefulWidget {
  const MentorNavigationHome({super.key});

  @override
  State<MentorNavigationHome> createState() => _MentorNavigationHomeState();
}

class _MentorNavigationHomeState extends State<MentorNavigationHome> {
  late MentorWorkspaceService _service;
  late ApiClient _apiClient;
  int _currentIndex = 0;
  int? _mentorUserId;

  List<MentorRequest> _requests = [];
  bool _loadingRequests = true;

  List<MentorNotification> _notifications = [];
  int _unread = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = MentorWorkspaceService(apiClient: _apiClient);
    _mentorUserId = int.tryParse(_apiClient.user?['id']?.toString() ?? '');
    _loadRequests();
    _loadNotifications();
    _pollTimer = Timer.periodic(
        const Duration(seconds: 15), (_) => _loadNotifications());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() => _loadingRequests = true);
    try {
      final data = await _service.getIncomingRequests();
      if (mounted) setState(() => _requests = data);
    } catch (e) {
      debugPrint("Failed to load requests: $e");
    } finally {
      if (mounted) setState(() => _loadingRequests = false);
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final data = await _service.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = data;
          _unread = data.where((n) => !n.isRead).length;
        });
      }
    } catch (e) {
      debugPrint("Failed to load notifications: $e");
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Sign Out",
            style: AppTypography.cardTitle.copyWith(fontSize: 16)),
        content: const Text("Sign out of the mentor workspace?"),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _apiClient.logout();
            },
            child: const Text("Sign Out",
                style: TextStyle(color: AppColors.berry)),
          ),
        ],
      ),
    );
  }

  Future<void> _openNotifications() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _NotificationsSheet(
        notifications: _notifications,
        onMarkAllRead: () async {
          await _service.markAllNotificationsRead();
          await _loadNotifications();
        },
        onTap: (n) async {
          if (!n.isRead) {
            await _service.markNotificationRead(n.id);
            await _loadNotifications();
          }
          if (mounted) Navigator.pop(context);
          // Route notification into the relevant tab.
          if (n.link != null && n.link!.contains("calendar")) {
            setState(() => _currentIndex = 2);
          } else {
            setState(() => _currentIndex = 1);
          }
        },
      ),
    );
    await _loadNotifications();
  }

  void _openRequest(MentorRequest request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MentorRequestDetailScreen(request: request),
      ),
    ).then((_) => _loadRequests());
  }

  @override
  Widget build(BuildContext context) {
    final email = _apiClient.user?['email'] ?? '';
    final username = _apiClient.user?['username'] ?? 'Mentor';

    final tabs = [
      _DashboardTab(
        requests: _requests,
        loading: _loadingRequests,
        onRefresh: _loadRequests,
        onGoToRequests: () => setState(() => _currentIndex = 1),
        onGoToCalendar: () => setState(() => _currentIndex = 2),
      ),
      _RequestsTab(
        requests: _requests,
        loading: _loadingRequests,
        onRefresh: _loadRequests,
        onOpen: _openRequest,
      ),
      if (_mentorUserId != null)
        MentorAvailabilityTab(service: _service, mentorUserId: _mentorUserId!)
      else
        const Center(child: Text("Missing mentor id")),
      if (_mentorUserId != null)
        MentorProfileTab(service: _service, mentorUserId: _mentorUserId!)
      else
        const Center(child: Text("Missing mentor id")),
    ];

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
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
              child: const Icon(Icons.workspace_premium_rounded,
                  color: AppColors.civic, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Mentor Desk",
                    style: AppTypography.title.copyWith(fontSize: 16)),
                Text("Verified Mentor", style: AppTypography.caption),
              ],
            ),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.notifications_outlined,
                    color: AppColors.ink),
                onPressed: _openNotifications,
              ),
              if (_unread > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: AppColors.berry, shape: BoxShape.circle),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      "$_unread",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            offset: const Offset(0, 50),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (v) {
              if (v == 'logout') _showLogoutDialog();
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username,
                        style: AppTypography.cardTitle.copyWith(fontSize: 14)),
                    if (email.isNotEmpty)
                      Text(email, style: AppTypography.caption),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded,
                        color: AppColors.berry, size: 20),
                    SizedBox(width: 10),
                    Text("Sign Out"),
                  ],
                ),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.only(right: 12, left: 4),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Color(0x1A4F46E5),
                child: Icon(Icons.person, color: AppColors.civic, size: 18),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.civic.withOpacity(0.08),
        height: 65,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.civic),
            label: "Dashboard",
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon:
                Icon(Icons.assignment_rounded, color: AppColors.civic),
            label: "Requests",
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon:
                Icon(Icons.calendar_month_rounded, color: AppColors.civic),
            label: "Availability",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.civic),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final List<MentorRequest> requests;
  final bool loading;
  final Future<void> Function() onRefresh;
  final VoidCallback onGoToRequests;
  final VoidCallback onGoToCalendar;

  const _DashboardTab({
    required this.requests,
    required this.loading,
    required this.onRefresh,
    required this.onGoToRequests,
    required this.onGoToCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final pending = requests.where((r) => r.status == 'requested').length;
    final active = requests.where((r) => r.status == 'accepted').length;
    final completed = requests.where((r) => r.status == 'completed').length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.ink, AppColors.civic],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("COACHING OPERATIONS ACTIVE",
                    style: AppTypography.eyebrowSmall
                        .copyWith(color: Colors.white70)),
                const SizedBox(height: 8),
                Text("Welcome back!",
                    style: AppTypography.title
                        .copyWith(color: Colors.white, fontSize: 24)),
                const SizedBox(height: 8),
                Text(
                  "Manage copy evaluations, run 1:1 video sessions, and configure your availability.",
                  style: AppTypography.body.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _metric("Pending", pending, AppColors.saffron),
              const SizedBox(width: 12),
              _metric("Active", active, AppColors.emerald),
              const SizedBox(width: 12),
              _metric("Completed", completed, AppColors.civic),
            ],
          ),
          const SizedBox(height: 16),
          _quickCard(
            icon: Icons.assignment_rounded,
            title: "Student Requests",
            subtitle: "$pending new requests waiting for review.",
            onTap: onGoToRequests,
          ),
          const SizedBox(height: 12),
          _quickCard(
            icon: Icons.calendar_month_rounded,
            title: "Availability Desk",
            subtitle: "Configure and bulk-generate your slots.",
            onTap: onGoToCalendar,
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("$value",
                style: AppTypography.title.copyWith(color: color, fontSize: 26)),
            const SizedBox(height: 4),
            Text(label,
                style: AppTypography.eyebrowSmall
                    .copyWith(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _quickCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.civic.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.civic),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          AppTypography.cardTitle.copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _RequestsTab extends StatelessWidget {
  final List<MentorRequest> requests;
  final bool loading;
  final Future<void> Function() onRefresh;
  final void Function(MentorRequest) onOpen;

  const _RequestsTab({
    required this.requests,
    required this.loading,
    required this.onRefresh,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: requests.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 120),
                Icon(Icons.inbox_outlined,
                    size: 48, color: AppColors.muted.withOpacity(0.6)),
                const SizedBox(height: 12),
                Center(
                  child: Text("No student requests yet",
                      style: AppTypography.cardTitle.copyWith(fontSize: 15)),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (_, i) {
                final r = requests[i];
                return _requestTile(r);
              },
            ),
    );
  }

  Widget _requestTile(MentorRequest r) {
    Color chipColor;
    switch (r.status) {
      case 'accepted':
        chipColor = AppColors.emerald;
        break;
      case 'completed':
        chipColor = AppColors.civic;
        break;
      case 'rejected':
      case 'cancelled':
      case 'expired':
        chipColor = AppColors.berry;
        break;
      default:
        chipColor = AppColors.saffron;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => onOpen(r),
        title: Text(r.learnerLabel,
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.civic.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                    r.preferredMode == 'video' ? "Video" : "Chat",
                    style: AppTypography.eyebrowSmall
                        .copyWith(color: AppColors.civic)),
              ),
              if (r.hasCopyToEvaluate) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text("Copy",
                      style: AppTypography.eyebrowSmall
                          .copyWith(color: AppColors.emerald)),
                ),
              ],
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: chipColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(r.status.toUpperCase(),
              style: AppTypography.eyebrowSmall.copyWith(color: chipColor)),
        ),
      ),
    );
  }
}

class _NotificationsSheet extends StatelessWidget {
  final List<MentorNotification> notifications;
  final Future<void> Function() onMarkAllRead;
  final void Function(MentorNotification) onTap;

  const _NotificationsSheet({
    required this.notifications,
    required this.onMarkAllRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (_, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Text("Notifications",
                      style: AppTypography.cardTitle.copyWith(fontSize: 17)),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      await onMarkAllRead();
                    },
                    child: const Text("Mark all read"),
                  ),
                ],
              ),
            ),
            Expanded(
              child: notifications.isEmpty
                  ? Center(
                      child: Text("No notifications yet",
                          style: AppTypography.caption))
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: notifications.length,
                      itemBuilder: (_, i) {
                        final n = notifications[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: n.isRead
                                ? Colors.white
                                : AppColors.civic.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: n.isRead
                                    ? AppColors.line
                                    : AppColors.civic.withOpacity(0.2)),
                          ),
                          child: ListTile(
                            onTap: () => onTap(n),
                            title: Text(n.title,
                                style: AppTypography.body
                                    .copyWith(fontWeight: FontWeight.w600)),
                            subtitle: Text(n.message,
                                style: AppTypography.caption),
                            trailing: n.isRead
                                ? null
                                : Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                        color: AppColors.civic,
                                        shape: BoxShape.circle),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
