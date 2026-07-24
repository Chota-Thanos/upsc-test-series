import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.berry,
                  size: 44,
                ),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadPlans,
                  child: const Text("RETRY"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        title: Text(
          "Study Plans",
          style: AppTypography.title.copyWith(fontSize: 20),
        ),
      ),
      body: _plans.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    color: AppColors.muted,
                    size: 44,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "No study plans published yet.",
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(14),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.66,
              ),
              itemCount: _plans.length,
              itemBuilder: (context, index) => _buildPlanCard(_plans[index]),
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
    final String fallbackUrl =
        coverFallbacks[plan.id.abs() % coverFallbacks.length];

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudyPlanDetailScreen(planId: plan.id),
          ),
        );
      },
      child: Container(
        decoration: AppTheme.cardDecoration,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover artwork with level pill + rating badge overlay
            Stack(
              children: [
                SizedBox(
                  height: 92,
                  width: double.infinity,
                  child: Image.network(
                    resolvedCover ?? fallbackUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Image.network(fallbackUrl, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 7,
                  left: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      plan.levelLabel?.toUpperCase() ?? "PRELIMS",
                      style: AppTypography.eyebrowSmall.copyWith(
                        fontSize: 8.5,
                        color: AppColors.civic,
                      ),
                    ),
                  ),
                ),
                if (plan.totalReviews > 0)
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.saffron,
                            size: 11,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            plan.averageRating.toStringAsFixed(1),
                            style: AppTypography.eyebrowSmall.copyWith(
                              fontSize: 9.5,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // Details block
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle.copyWith(height: 1.25),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "${plan.durationWeeks} weeks · ${plan.testCount ?? 0} tests",
                      style: AppTypography.caption.copyWith(fontSize: 10.5),
                    ),
                    const Spacer(),
                    Text(
                      priceStr,
                      style: AppTypography.statValue.copyWith(
                        fontSize: 13.5,
                        color: plan.isFree
                            ? AppColors.emerald
                            : AppColors.civic,
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
