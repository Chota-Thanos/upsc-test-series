import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/constants.dart';
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
    final apiClient = Provider.of<ApiClient>(context, listen: false);

    if (apiClient.isGuestMode) {
      setState(() {
        _loadingStats = false;
        _loadingActiveAttempts = false;
        _stats = null;
        _activeAttempts = [];
      });
      _loadStudyPlans();
      _loadMentors();
      return;
    }

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
    final hasPremium = apiClient.hasEntitlement('assessment.premium_tests');

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Stack(
        children: [
          RefreshIndicator(
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
                    height: 135,
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
                    height: 135,
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
                    bottom: 12,
                    left: 20,
                    right: 20,
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 20,
                          child: Text(
                            username.isNotEmpty ? username[0].toUpperCase() : 'S',
                            style: const TextStyle(
                              color: AppColors.civic,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "Namaste, $username! 👋",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
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
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: hasPremium ? const Color(0xFF10B981) : Colors.amber.shade700,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      hasPremium ? "PRO" : "FREE",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Accelerate your UPSC preparation journey.",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
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

              if (_activeAttempts.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "In-Progress Attempts",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._activeAttempts.map((attempt) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.line, width: 1),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.civic.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.timer_outlined,
                                  color: AppColors.civic,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      attempt.testTemplate.title,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Started on ${attempt.startedAt.split('T').first}. You left this test in between.",
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.civic,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                                    fontSize: 10,
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
                            apiClient.isGuestMode
                                ? _buildGuestStatsPlaceholder(context, apiClient)
                                : _loadingStats || _stats == null
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

                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Column 1: Labels
                                              Expanded(
                                                flex: 12,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const SizedBox(height: 38), // Space matching header row
                                                    _buildTableSidebarCell("Correct", AppColors.emerald),
                                                    _buildTableSidebarCell("Incorrect", AppColors.berry),
                                                    _buildTableSidebarCell("Unattempted", AppColors.muted),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Column 2: GK
                                              Expanded(
                                                flex: 10,
                                                child: Column(
                                                  children: [
                                                    _buildTableHeaderCell("GK", AppColors.civic),
                                                    _buildColumnContent(true, gkTotal, gkPctCorrect, gkPctIncorrect, gkPctUnattempted),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Column 3: CSAT
                                              Expanded(
                                                flex: 10,
                                                child: Column(
                                                  children: [
                                                    _buildTableHeaderCell("CSAT", AppColors.saffron),
                                                    _buildColumnContent(false, csatTotal, csatPctCorrect, csatPctIncorrect, csatPctUnattempted),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 16.0),
                                            child: Divider(color: AppColors.line, height: 1),
                                          ),
                                          Row(
                                            children: [
                                              const Icon(Icons.border_color_rounded, color: Colors.purple, size: 16),
                                              const SizedBox(width: 8),
                                              Text(
                                                "MAINS WRITING",
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.purple,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildMainsMetricCard(
                                                  "Questions",
                                                  mains.attemptsCount.toString(),
                                                  Icons.description_outlined,
                                                  AppColors.civic,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: _buildMainsMetricCard(
                                                  "Evaluated",
                                                  mains.evaluatedCount.toString(),
                                                  Icons.assignment_turned_in_outlined,
                                                  AppColors.brand,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildMainsMetricCard(
                                                  "Total Score",
                                                  mains.totalMaxScore.toStringAsFixed(0),
                                                  Icons.military_tech_outlined,
                                                  AppColors.emerald,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: _buildMainsMetricCard(
                                                  "Your Score",
                                                  mains.totalScore.toStringAsFixed(1),
                                                  Icons.insights_rounded,
                                                  AppColors.saffron,
                                                ),
                                              ),
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
              Container(
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
              Container(
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
      ],
    ),
  );
}

  Widget _buildTableHeaderCell(String text, Color color) {
    return Container(
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTableSidebarCell(String text, Color dotColor) {
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(String value) {
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.paper.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }

  Widget _buildColumnContent(bool isGk, int total, double pctCorrect, double pctIncorrect, double pctUnattempted) {
    if (total == 0) {
      return Container(
        height: 132, // Height matching 3 rows of cells (3 * 44)
        alignment: Alignment.center,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isGk ? AppColors.civic : AppColors.saffron,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => widget.onTabSelected(2, subIndex: isGk ? 0 : 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow_rounded, size: 14),
              const SizedBox(width: 4),
              Text(
                "Start",
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Column(
        children: [
          _buildTableCell("${pctCorrect.toStringAsFixed(0)}%"),
          _buildTableCell("${pctIncorrect.toStringAsFixed(0)}%"),
          _buildTableCell("${pctUnattempted.toStringAsFixed(0)}%"),
        ],
      );
    }
  }

  Widget _buildMainsMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.12), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ],
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



  Widget _buildGuestStatsPlaceholder(BuildContext context, ApiClient apiClient) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.civic.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.civic.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Icon(Icons.analytics_outlined, color: AppColors.civic, size: 36),
          const SizedBox(height: 12),
          Text(
            "Unlock Performance Analytics",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            "Take mock tests and practice quizzes as a guest to build your dashboard. Sign in to save progress forever.",
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.muted,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.civic,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              apiClient.setGuestMode(false);
            },
            child: const Text("Sign In / Register", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
