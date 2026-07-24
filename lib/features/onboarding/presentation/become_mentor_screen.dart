import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/onboarding_service.dart';
import '../models/onboarding_models.dart';
import 'mentor_application_form_screen.dart';

/// Landing + status screen for the "Apply as Mentor" flow. Shows the program
/// pitch, the user's current application status, and routes into the form.
class BecomeMentorScreen extends StatefulWidget {
  const BecomeMentorScreen({super.key});

  @override
  State<BecomeMentorScreen> createState() => _BecomeMentorScreenState();
}

class _BecomeMentorScreenState extends State<BecomeMentorScreen> {
  late OnboardingService _service;
  bool _loading = true;
  OnboardingApplication? _application;

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = OnboardingService(apiClient: apiClient);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final apps = await _service.getMyApplications();
      if (mounted) {
        setState(() => _application = apps.isNotEmpty ? apps.first : null);
      }
    } catch (e) {
      debugPrint("Failed to load applications: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm() async {
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MentorApplicationFormScreen(
          service: _service,
          existing: _application,
        ),
      ),
    );
    if (submitted == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text("Become a Mentor",
            style: AppTypography.title.copyWith(fontSize: 17)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _hero(),
                const SizedBox(height: 16),
                if (_application != null) _statusCard(_application!),
                const SizedBox(height: 16),
                _capabilities(),
                const SizedBox(height: 16),
                _eligibility(),
                const SizedBox(height: 24),
                _ctaButton(),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _hero() {
    return Container(
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
          Text("JOIN OUR ELITE NETWORK",
              style:
                  AppTypography.eyebrowSmall.copyWith(color: Colors.white70)),
          const SizedBox(height: 8),
          Text("Become a UPSC Mentor",
              style: AppTypography.title
                  .copyWith(color: Colors.white, fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            "Share your expertise, grade Mains copies, take 1-on-1 consultations, and guide serious aspirants.",
            style: AppTypography.body.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(OnboardingApplication app) {
    Color color;
    IconData icon;
    String label;
    String message;
    switch (app.status) {
      case 'pending':
        color = AppColors.saffron;
        icon = Icons.hourglass_top_rounded;
        label = "Under Review";
        message =
            "Your application is being reviewed. Credential checks complete within 48 hours.";
        break;
      case 'approved':
        color = AppColors.emerald;
        icon = Icons.verified_rounded;
        label = "Approved";
        message =
            "You're approved! Sign out and sign back in to open your mentor workspace.";
        break;
      case 'rejected':
        color = AppColors.berry;
        icon = Icons.cancel_rounded;
        label = "Not Approved";
        message = app.reviewerNote ??
            "Your application was not approved. You can revise and resubmit.";
        break;
      case 'more_info_required':
        color = AppColors.civic;
        icon = Icons.info_rounded;
        label = "More Info Required";
        message = app.reviewerNote ??
            "The review team needs more information. Please update your application.";
        break;
      default:
        color = AppColors.muted;
        icon = Icons.edit_note_rounded;
        label = "Draft Saved";
        message = "You have a saved draft. Continue where you left off.";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.cardTitle
                        .copyWith(fontSize: 15, color: color)),
                const SizedBox(height: 4),
                Text(message, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _capabilities() {
    final items = [
      "Evaluate answer sheet copies uploaded by students",
      "Schedule and conduct 1-on-1 video mentorship calls",
      "Provide direct feedback on Optional and GS preparation",
    ];
    return _infoCard("Your Key Capabilities", Icons.check_circle_outline,
        AppColors.emerald, items);
  }

  Widget _eligibility() {
    final items = [
      "Cleared UPSC Mains or faced the Civil Services Interview",
      "Verification roll number and marksheets required",
      "A sample checked copy showing your grading style",
    ];
    return _infoCard("Eligibility Criteria", Icons.shield_outlined,
        AppColors.civic, items);
  }

  Widget _infoCard(
      String title, IconData icon, Color color, List<String> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: AppTypography.cardTitle.copyWith(fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t, style: AppTypography.body)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _ctaButton() {
    final app = _application;
    if (app != null && app.status == 'pending') {
      return _disabledCta("Application Under Review");
    }
    if (app != null && app.status == 'approved') {
      return _disabledCta("Approved — Re-login to Enter Workspace");
    }

    final label = app == null
        ? "Apply as Mentor"
        : app.status == 'more_info_required'
            ? "Update Application"
            : "Resume Application";

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _openForm,
        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.civic,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _disabledCta(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.line.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(label,
          style: AppTypography.button.copyWith(color: AppColors.muted)),
    );
  }
}
