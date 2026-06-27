import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../assessment/data/assessment_service.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  late AssessmentService _service;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _bookings = [];

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = AssessmentService(apiClient: apiClient);
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getMyBookingRequests();
      setState(() {
        _bookings = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(
          "My Mentorship Requests",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.line, height: 1),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.ink, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.civic))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.berry, size: 44),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadBookings, child: const Text("RETRY")),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBookings,
                  color: AppColors.civic,
                  child: _bookings.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _bookings.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, index) => _buildBookingCard(_bookings[index]),
                        ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: AppColors.civic.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calendar_today_rounded, size: 36, color: AppColors.civic),
              ),
              const SizedBox(height: 20),
              Text(
                "No Booking Requests",
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  "You haven't submitted any mentorship session requests yet. Browse mentors and book a session.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppColors.muted, fontSize: 13, height: 1.5, fontWeight: FontWeight.w400),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("BROWSE MENTORS"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status']?.toString() ?? 'pending';
    final createdAt = booking['created_at']?.toString() ?? '';
    final mentorName = booking['mentor']?['user']?['full_name']?.toString() ??
        booking['mentor_name']?.toString() ??
        'Mentor';
    final mentorAvatar = booking['mentor']?['user']?['avatar_url']?.toString();
    final sessionType = booking['session_type']?.toString() ?? booking['type']?.toString() ?? '';
    final availability = booking['availability_note']?.toString() ?? booking['preferred_slot']?.toString() ?? '';
    final adminNotes = booking['admin_notes']?.toString() ?? booking['mentor_notes']?.toString();
    final specialization = booking['mentor']?['specialization']?.toString() ?? '';
    final copyEvalEnabled = booking['copy_evaluation_requested'] as bool? ?? false;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    Color statusBg;

    switch (status) {
      case 'approved':
      case 'accepted':
        statusColor = AppColors.emerald;
        statusBg = AppColors.emerald.withOpacity(0.08);
        statusLabel = "Approved";
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case 'rejected':
      case 'declined':
        statusColor = AppColors.berry;
        statusBg = AppColors.berry.withOpacity(0.08);
        statusLabel = "Rejected";
        statusIcon = Icons.cancel_outlined;
        break;
      case 'completed':
        statusColor = AppColors.brand;
        statusBg = AppColors.brand.withOpacity(0.08);
        statusLabel = "Completed";
        statusIcon = Icons.verified_rounded;
        break;
      case 'scheduled':
        statusColor = AppColors.civic;
        statusBg = AppColors.civic.withOpacity(0.08);
        statusLabel = "Scheduled";
        statusIcon = Icons.event_available_rounded;
        break;
      default:
        statusColor = AppColors.saffron;
        statusBg = AppColors.saffron.withOpacity(0.08);
        statusLabel = "Pending Review";
        statusIcon = Icons.hourglass_empty_rounded;
    }

    // Format date
    String formattedDate = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        formattedDate = "${dt.day}/${dt.month}/${dt.year}";
      } catch (_) {
        formattedDate = createdAt.split('T').first;
      }
    }

    return Container(
      decoration: AppTheme.cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: statusBg,
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: statusColor),
                ),
                const Spacer(),
                if (formattedDate.isNotEmpty)
                  Text(
                    "Submitted $formattedDate",
                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),

          // Mentor info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.civic.withOpacity(0.1),
                      ),
                      child: mentorAvatar != null
                          ? ClipOval(child: Image.network(mentorAvatar, fit: BoxFit.cover))
                          : Center(
                              child: Text(
                                mentorName.isNotEmpty ? mentorName[0].toUpperCase() : 'M',
                                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.civic),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mentorName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          if (specialization.isNotEmpty)
                            Text(
                              specialization,
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w500),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(color: AppColors.line),
                const SizedBox(height: 12),

                // Request details
                if (sessionType.isNotEmpty) ...[
                  _detailRow(Icons.category_outlined, "Session Type", sessionType.replaceAll('_', ' ')),
                  const SizedBox(height: 8),
                ],
                if (availability.isNotEmpty) ...[
                  _detailRow(Icons.schedule_outlined, "Preferred Slot", availability),
                  const SizedBox(height: 8),
                ],
                if (copyEvalEnabled) ...[
                  _detailRow(Icons.description_outlined, "Copy Evaluation", "Requested"),
                  const SizedBox(height: 8),
                ],

                // Admin/mentor notes
                if (adminNotes != null && adminNotes.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: AppColors.muted),
                            const SizedBox(width: 6),
                            Text(
                              "RESPONSE NOTE",
                              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          adminNotes,
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.ink, height: 1.4, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.muted),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
        ),
      ],
    );
  }
}
