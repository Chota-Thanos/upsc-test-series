import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/constants.dart';
import '../data/study_plan_service.dart';
import '../models/study_plan_models.dart';
import 'study_plan_detail_screen.dart';

class StudyPlanListScreen extends StatefulWidget {
  const StudyPlanListScreen({super.key});

  @override
  State<StudyPlanListScreen> createState() => _StudyPlanListScreenState();
}

class _StudyPlanListScreenState extends State<StudyPlanListScreen> {
  late StudyPlanService _service;
  bool _loading = true;
  String? _error;
  List<StudyPlanSummary> _plans = [];

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = StudyPlanService(apiClient: apiClient);
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final plans = await _service.getStudyPlans();
      setState(() {
        _plans = plans;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _formatPrice(int amountMinor, String currency) {
    final double amount = amountMinor / 100;
    if (amount == 0) return "Free";
    final symbol = currency == 'INR' ? '₹' : '\$';
    return "$symbol${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}";
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
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.civic)),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.berry, size: 44),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadPlans, child: const Text("RETRY")),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: _plans.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_month_outlined, color: AppColors.muted, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    "No study plans published yet.",
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.muted),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _plans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final plan = _plans[index];
                return _buildPlanCard(plan);
              },
            ),
    );
  }

  Widget _buildPlanCard(StudyPlanSummary plan) {
    final priceStr = _formatPrice(plan.priceAmountMinor, plan.currency);
    final resolvedCover = _resolveImageUrl(plan.coverImageUrl);
    final List<String> coverFallbacks = [
      'https://images.unsplash.com/photo-1506880018603-83d5b814b5a6?q=80&w=400&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?q=80&w=400&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?q=80&w=400&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?q=80&w=400&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1501504905252-473c47e087f8?q=80&w=400&auto=format&fit=crop',
    ];
    final String fallbackUrl = coverFallbacks[plan.id.abs() % coverFallbacks.length];

    return Container(
      decoration: AppTheme.cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Course Header Artwork with Overlay
          Stack(
            children: [
              SizedBox(
                height: 120,
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
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.ink.withOpacity(0.9),
                      AppColors.ink.withOpacity(0.4),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.examName ?? "Civil Services Prep",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "${plan.durationWeeks} Weeks guided syllabus",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        plan.levelLabel?.toUpperCase() ?? "PRELIMS",
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Icon(Icons.menu_book_rounded, color: Colors.white70, size: 20),
                  ],
                ),
              ),
            ],
          ),

          // Details Block
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                if (plan.subtitle != null && plan.subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    plan.subtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.assignment_outlined, color: AppColors.muted, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      "${plan.itemCount ?? 0} Tasks done",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Icon(Icons.quiz_outlined, color: AppColors.muted, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      "${plan.testCount ?? 0} Mock tests",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      priceStr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudyPlanDetailScreen(planId: plan.id),
                          ),
                        );
                      },
                      child: Text(
                        "VIEW CURRICULUM",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

