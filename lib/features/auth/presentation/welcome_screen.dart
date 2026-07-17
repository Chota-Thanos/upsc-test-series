import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int? _diagnosticTestId;
  bool _fetchingTest = true; // true until the initial fetch resolves
  bool _loadingDiagnostic = false;
  bool _loadingCustom = false;

  static const _stats = [
    ("10,000+", "Aspirants"),
    ("120+", "Verified Mentors"),
    ("50,000+", "Tests Taken"),
  ];

  static const _features = [
    (
      Icons.auto_stories_rounded,
      "Smart Test Builder",
      "Build custom GS & CSAT tests by topic. Track weak areas with question-level analytics.",
      Color(0xFF6366F1),
      Color(0xFFEEF2FF),
    ),
    (
      Icons.school_rounded,
      "1:1 Mentorship",
      "Get personal guidance and Mains answer evaluations from verified UPSC toppers.",
      Color(0xFF0891B2),
      Color(0xFFECFEFF),
    ),
    (
      Icons.route_rounded,
      "Structured Study Plans",
      "Follow expert-curated roadmaps tailored to your exam timeline and target.",
      Color(0xFF059669),
      Color(0xFFECFDF5),
    ),
    (
      Icons.edit_note_rounded,
      "Notes Workspace",
      "Build a personal revision notebook and organise your preparation in one place.",
      Color(0xFFD97706),
      Color(0xFFFFFBEB),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fetchDiagnosticTest();
  }

  Future<void> _fetchDiagnosticTest() async {
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    try {
      final dynamic raw = await apiClient.get(
        '/api/v1/assessment/test-templates?test_type=diagnostic_test&access_type=free&status=published&limit=1',
        withToken: false,
      );
      if (raw is List && raw.isNotEmpty && mounted) {
        final id = int.tryParse(raw.first['id']?.toString() ?? '');
        setState(() => _diagnosticTestId = id);
      }
    } catch (e) {
      debugPrint('_fetchDiagnosticTest error: $e');
    } finally {
      if (mounted) setState(() => _fetchingTest = false);
    }
  }

  Future<void> _onTakeDiagnosticTest() async {
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    setState(() => _loadingDiagnostic = true);
    try {
      await apiClient.startGuestDiagnosticFlow(testId: _diagnosticTestId);
    } finally {
      if (mounted) setState(() => _loadingDiagnostic = false);
    }
  }

  Future<void> _onBuildCustomTest() async {
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    setState(() => _loadingCustom = true);
    try {
      await apiClient.startGuestCustomTestFlow();
    } finally {
      if (mounted) setState(() => _loadingCustom = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Image.asset('assets/images/logo.png', height: 30, fit: BoxFit.contain),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: Text(
                      "Sign In",
                      style: GoogleFonts.inter(color: AppColors.civic, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable content ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero text
                    Text(
                      "Prepare smarter.\nClear UPSC.",
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.ink,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Custom practice tests · Expert mentorship · Structured study plans.",
                      style: GoogleFonts.inter(color: AppColors.muted, fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 28),

                    // Primary CTA: Diagnostic Test — only shown when a published test exists
                    if (_fetchingTest)
                      ElevatedButton.icon(
                        onPressed: null,
                        icon: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)),
                        label: const Text("Loading…", overflow: TextOverflow.ellipsis, softWrap: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.civic.withValues(alpha: 0.6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      )
                    else if (_diagnosticTestId != null)
                      ElevatedButton.icon(
                        onPressed: _loadingDiagnostic ? null : _onTakeDiagnosticTest,
                        icon: _loadingDiagnostic
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.flash_on_rounded, size: 18),
                        label: const Text("Take a Free Diagnostic Test", overflow: TextOverflow.ellipsis, softWrap: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.civic,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    const SizedBox(height: 10),

                    // Secondary CTA: Build Custom Test
                    OutlinedButton.icon(
                      onPressed: _loadingCustom ? null : _onBuildCustomTest,
                      icon: _loadingCustom
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.civic))
                          : const Icon(Icons.tune_rounded, size: 18),
                      label: const Text("Build a Custom Test", overflow: TextOverflow.ellipsis, softWrap: false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.civic, width: 1.5),
                        foregroundColor: AppColors.civic,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),

                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.line),
                        foregroundColor: AppColors.ink,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text("Create Free Account", overflow: TextOverflow.ellipsis, softWrap: false),
                    ),

                    if (_diagnosticTestId != null) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          "No account needed for the diagnostic test",
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Stats row
                    Row(
                      children: _stats.map((s) {
                        return Expanded(
                          child: Column(
                            children: [
                              Text(s.$1, style: GoogleFonts.plusJakartaSans(color: AppColors.ink, fontSize: 17, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(s.$2, style: GoogleFonts.inter(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 28),
                    Container(height: 1, color: AppColors.line),
                    const SizedBox(height: 24),

                    // Features
                    Text(
                      "What's inside",
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.ink),
                    ),
                    const SizedBox(height: 14),
                    ..._features.map((f) {
                      final (icon, title, desc, iconColor, bgColor) = f;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, color: iconColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
                                  const SizedBox(height: 2),
                                  Text(desc, style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.muted, height: 1.4)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => Provider.of<ApiClient>(context, listen: false).setGuestMode(true),
                        child: Text(
                          "Explore without an account →",
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
