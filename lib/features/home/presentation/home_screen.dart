import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../assessment/data/assessment_service.dart';
import '../../assessment/models/assessment_models.dart';
import '../../assessment/presentation/attempt_engine_screen.dart';
import '../../study_plans/data/study_plan_service.dart';
import '../../study_plans/models/study_plan_models.dart';
import '../../study_plans/presentation/study_plan_detail_screen.dart';
import '../../mentors/data/mentor_service.dart';
import '../../mentors/models/mentor_models.dart';
import '../../mentors/presentation/mentor_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int, {int subIndex, int subSubIndex}) onTabSelected;
  const HomeScreen({super.key, required this.onTabSelected});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late AssessmentService _assessmentService;
  late StudyPlanService _studyPlanService;
  late MentorService _mentorService;

  bool _loadingStats = true;
  bool _loadingPlans = true;
  bool _loadingMentors = true;
  bool _loadingActiveAttempts = true;

  AssessmentDashboardResponse? _stats;
  List<StudyPlanSummary> _plans = [];
  List<MentorProfile> _mentors = [];
  List<StudentAttemptSummary> _activeAttempts = [];

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _assessmentService = AssessmentService(apiClient: apiClient);
    _studyPlanService = StudyPlanService(apiClient: apiClient);
    _mentorService = MentorService(apiClient: apiClient);
    
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    _loadDashboardStats();
    _loadStudyPlans();
    _loadMentors();
    _loadActiveAttempts();
  }

  Future<void> _loadActiveAttempts() async {
    try {
      final attempts = await _assessmentService.getMyAssessmentAttempts();
      final active = attempts.where((a) => a.status == 'in_progress').toList();
      if (mounted) {
        setState(() {
          _activeAttempts = active;
          _loadingActiveAttempts = false;
        });
      }
    } catch (e) {
      debugPrint("Failed to load active attempts: $e");
      if (mounted) {
        setState(() => _loadingActiveAttempts = false);
      }
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      final stats = await _assessmentService.getAssessmentDashboard();
      if (mounted) {
        setState(() {
          _stats = stats;
          _loadingStats = false;
        });
      }
    } catch (e) {
      debugPrint("Failed to load home page stats: $e");
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _loadStudyPlans() async {
    try {
      final plans = await _studyPlanService.getStudyPlans(limit: 5);
      if (mounted) {
        setState(() {
          _plans = plans;
          _loadingPlans = false;
        });
      }
    } catch (e) {
      debugPrint("Failed to load home page study plans: $e");
      if (mounted) setState(() => _loadingPlans = false);
    }
  }

  Future<void> _loadMentors() async {
    try {
      final mentors = await _mentorService.getMentorProfiles();
      if (mounted) {
        setState(() {
          _mentors = mentors.take(5).toList();
          _loadingMentors = false;
        });
      }
    } catch (e) {
      debugPrint("Failed to load home page mentors: $e");
      if (mounted) setState(() => _loadingMentors = false);
    }
  }

  String? _resolveImageUrl(String? rawUrl) {
    final value = rawUrl?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) {
      return '${ApiConstants.baseUrl}$value';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final apiClient = Provider.of<ApiClient>(context);
    final username = apiClient.user?['username'] ?? 'Student';

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Premium Welcome Banner with Image Background
              Stack(
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(
                          'https://images.unsplash.com/photo-1513258496099-48168024aec0?q=80&w=600&auto=format&fit=crop',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.civic.withOpacity(0.95),
                          AppColors.civic.withOpacity(0.75),
                          Colors.transparent,
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 24,
                          child: Text(
                            username.isNotEmpty ? username[0].toUpperCase() : 'S',
                            style: const TextStyle(
                              color: AppColors.civic,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Namaste, $username! 👋",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Accelerate your UPSC preparation journey.",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
               _buildSubscriptionBanner(apiClient),
              const SizedBox(height: 16),

              if (_activeAttempts.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "In-Progress Attempts",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._activeAttempts.map((attempt) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFF7ED), Color(0xFFFFFBEB)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: const Color(0xFFFED7AA), width: 1.5),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x06000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF97316).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.timer_outlined,
                                  color: Color(0xFFF97316),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      attempt.testTemplate.title,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Started on ${attempt.startedAt.split('T').first}. You left this test in between.",
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF97316),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AttemptEngineScreen(attemptId: attempt.id),
                                    ),
                                  );
                                  _loadAllData(); // reload on return
                                },
                                child: Text(
                                  "RESUME",
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Glimpse 1: Performance Summary Metric Panel
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Your Performance Radar",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => widget.onTabSelected(1), // Switch to Dashboard Tab
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x06000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.bar_chart_rounded, color: AppColors.civic, size: 22),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Scorecard Analytics",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ],
                                ),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _loadingStats || _stats == null
                                ? const Center(
                                    child: SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.civic),
                                    ),
                                  )
                                : Builder(
                                    builder: (context) {
                                      final gk = _stats!.gk;
                                      final gkTotal = gk.totalCorrect + gk.totalIncorrect + gk.totalUnattempted;
                                      final gkPctCorrect = gkTotal > 0 ? (gk.totalCorrect / gkTotal) * 100 : 0.0;
                                      final gkPctIncorrect = gkTotal > 0 ? (gk.totalIncorrect / gkTotal) * 100 : 0.0;
                                      final gkPctUnattempted = gkTotal > 0 ? (gk.totalUnattempted / gkTotal) * 100 : 0.0;

                                      final csat = _stats!.aptitude;
                                      final csatTotal = csat.totalCorrect + csat.totalIncorrect + csat.totalUnattempted;
                                      final csatPctCorrect = csatTotal > 0 ? (csat.totalCorrect / csatTotal) * 100 : 0.0;
                                      final csatPctIncorrect = csatTotal > 0 ? (csat.totalIncorrect / csatTotal) * 100 : 0.0;
                                      final csatPctUnattempted = csatTotal > 0 ? (csat.totalUnattempted / csatTotal) * 100 : 0.0;

                                      final mains = _stats!.mains;

                                      return Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildPerformanceRadarColumn(
                                            title: "GS PRELIMS",
                                            accentColor: AppColors.civic,
                                            items: [
                                              _buildRadarMetricRow("Total Qs", gkTotal.toString(), null),
                                              _buildRadarMetricRow("Correct", "${gkPctCorrect.toStringAsFixed(0)}%", AppColors.emerald),
                                              _buildRadarMetricRow("Incorrect", "${gkPctIncorrect.toStringAsFixed(0)}%", AppColors.berry),
                                              _buildRadarMetricRow("Skipped", "${gkPctUnattempted.toStringAsFixed(0)}%", AppColors.muted),
                                            ],
                                          ),
                                          const SizedBox(width: 8),
                                          _buildPerformanceRadarColumn(
                                            title: "CSAT DRILL",
                                            accentColor: AppColors.saffron,
                                            items: [
                                              _buildRadarMetricRow("Total Qs", csatTotal.toString(), null),
                                              _buildRadarMetricRow("Correct", "${csatPctCorrect.toStringAsFixed(0)}%", AppColors.emerald),
                                              _buildRadarMetricRow("Incorrect", "${csatPctIncorrect.toStringAsFixed(0)}%", AppColors.berry),
                                              _buildRadarMetricRow("Skipped", "${csatPctUnattempted.toStringAsFixed(0)}%", AppColors.muted),
                                            ],
                                          ),
                                          const SizedBox(width: 8),
                                          _buildPerformanceRadarColumn(
                                            title: "MAINS WRITING",
                                            accentColor: Colors.purple,
                                            items: [
                                              _buildRadarMetricRow("Attempts", mains.attemptsCount.toString(), null),
                                              _buildRadarMetricRow("Avg Score", mains.avgScore.toStringAsFixed(1), AppColors.civic),
                                              _buildRadarMetricRow("Max Score", mains.maxScore.toStringAsFixed(1), AppColors.emerald),
                                              _buildRadarMetricRow("Evaluated", mains.evaluatedCount.toString(), AppColors.brand),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Glimpse 2: Self Test Builder Scopes
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Self Test Builder",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => widget.onTabSelected(2), // Switch to Tests Tab (default to GK)
                      child: Text(
                        "Explore Hub →",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.civic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildPracticeCard(
                            label: "GS Prelims",
                            subtitle: "General Studies",
                            icon: Icons.public_rounded,
                            color: const Color(0xFFE8F2FF),
                            iconColor: const Color(0xFF0F75FC),
                            onTap: () => widget.onTabSelected(2, subIndex: 0),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPracticeCard(
                            label: "CSAT Drill",
                            subtitle: "Aptitude Tests",
                            icon: Icons.calculate_rounded,
                            color: const Color(0xFFFFF2E6),
                            iconColor: const Color(0xFFFF8800),
                            onTap: () => widget.onTabSelected(2, subIndex: 1),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPracticeCard(
                            label: "Mains Hub",
                            subtitle: "Subjective essays",
                            icon: Icons.border_color_rounded,
                            color: const Color(0xFFF3E5F5),
                            iconColor: Colors.purple,
                            onTap: () => widget.onTabSelected(2, subIndex: 2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPracticeCard(
                            label: "Bookmarks & Revision",
                            subtitle: "Category revision",
                            icon: Icons.bookmark_rounded,
                            color: const Color(0xFFFFEBEE),
                            iconColor: AppColors.berry,
                            onTap: () => widget.onTabSelected(2, subIndex: 0, subSubIndex: 2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Glimpse 3: Active Study Plans (horizontal scroll with real data & images)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Structured Study Plans",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => widget.onTabSelected(3),
                      child: Text(
                        "All Plans",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.civic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 205,
                child: _loadingPlans
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.civic),
                      )
                    : _plans.isEmpty
                        ? _buildEmptyStateCard("No study plans available at the moment.")
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            itemCount: _plans.length,
                            itemBuilder: (context, index) {
                              final plan = _plans[index];
                              return _buildStudyPlanCard(plan);
                            },
                          ),
              ),
              const SizedBox(height: 24),

              // Glimpse 4: Available Mentors (horizontal scroll with real topper details & avatars)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Connect with Top Mentors",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => widget.onTabSelected(4),
                      child: Text(
                        "All Mentors",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.civic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 175,
                child: _loadingMentors
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.civic),
                      )
                    : _mentors.isEmpty
                        ? _buildEmptyStateCard("No mentors available right now.")
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            itemCount: _mentors.length,
                            itemBuilder: (context, index) {
                              final mentor = _mentors[index];
                              return _buildMentorCard(mentor);
                            },
                          ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceRadarColumn({
    required String title,
    required Color accentColor,
    required List<Widget> items,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.paper.withOpacity(0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildRadarMetricRow(String label, String value, Color? bulletColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (bulletColor != null)
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    color: bulletColor,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeCard({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x04000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildStudyPlanCard(StudyPlanSummary plan) {
    final resolvedCover = _resolveImageUrl(plan.coverImageUrl);
    final List<String> coverFallbacks = [
      'https://images.unsplash.com/photo-1506880018603-83d5b814b5a6?q=80&w=400&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?q=80&w=400&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?q=80&w=400&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?q=80&w=400&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1501504905252-473c47e087f8?q=80&w=400&auto=format&fit=crop',
    ];
    final String fallbackUrl = coverFallbacks[plan.id.abs() % coverFallbacks.length];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudyPlanDetailScreen(planId: plan.id),
          ),
        );
      },
      child: Container(
        width: 240,
        margin: const EdgeInsets.only(right: 12.0, bottom: 4.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x04000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: SizedBox(
                height: 85,
                width: double.infinity,
                child: Image.network(
                  resolvedCover ?? fallbackUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Image.network(
                    fallbackUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    plan.subtitle ?? plan.description ?? 'Complete UPSC Preparation Syllabus',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: AppColors.muted,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "${plan.durationWeeks} Weeks",
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (plan.testCount != null)
                        Text(
                          "${plan.testCount} Practice Tests",
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.civic,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMentorCard(MentorProfile mentor) {
    final resolvedAvatar = _resolveImageUrl(mentor.profileImageUrl);
    final List<String> avatarFallbacks = [
      'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?q=80&w=200&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1560250097-0b93528c311a?q=80&w=200&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1580489944761-15a19d654956?q=80&w=200&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?q=80&w=200&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200&auto=format&fit=crop',
    ];
    final String fallbackUrl = avatarFallbacks[mentor.userId.abs() % avatarFallbacks.length];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MentorDetailScreen(mentorUserId: mentor.userId),
          ),
        );
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12.0, bottom: 4.0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x04000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.civic.withOpacity(0.1),
                  backgroundImage: NetworkImage(resolvedAvatar ?? fallbackUrl),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mentor.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (mentor.isVerified)
                            const Icon(Icons.verified_rounded, color: Colors.blue, size: 10),
                          const SizedBox(width: 3),
                          Text(
                            mentor.yearsExperience > 0 ? "${mentor.yearsExperience} yrs exp" : "Top Expert",
                            style: GoogleFonts.inter(fontSize: 9, color: AppColors.muted, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              mentor.headline ?? "IAS Expert Mentor",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.muted,
                height: 1.3,
              ),
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.civic.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Book 1:1 Session",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.civic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.muted,
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionBanner(ApiClient apiClient) {
    final hasPremium = apiClient.hasEntitlement('assessment.premium_tests');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasPremium 
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)] 
              : [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasPremium ? const Color(0xFF334155) : const Color(0xFFFFD8A8),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: hasPremium ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFF97316).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasPremium ? Icons.verified_user_rounded : Icons.info_outline_rounded,
              color: hasPremium ? const Color(0xFF10B981) : const Color(0xFFF97316),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPremium ? "Premium Account Active" : "Free Tier Account",
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: hasPremium ? Colors.white : const Color(0xFF7C2D12),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasPremium 
                      ? "Unlimited Custom Test building & Mains tab unlocked." 
                      : "Custom tests are limited to 10 questions. Sectional and Mains tests are locked.",
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: hasPremium ? const Color(0xFFCBD5E1) : const Color(0xFF9A3412),
                  ),
                ),
              ],
            ),
          ),
          if (!hasPremium) ...[
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final url = Uri.parse("${ApiConstants.webAppUrl}/pricing");
                if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                  debugPrint("Could not launch $url");
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                "Upgrade",
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
