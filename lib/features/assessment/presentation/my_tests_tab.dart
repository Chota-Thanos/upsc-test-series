import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/assessment_service.dart';
import '../models/assessment_models.dart';
import 'result_review_screen.dart';
import 'attempt_engine_screen.dart';

class MyTestsTab extends StatefulWidget {
  final String? contentType;
  const MyTestsTab({super.key, this.contentType});

  @override
  State<MyTestsTab> createState() => _MyTestsTabState();
}

class _MyTestsTabState extends State<MyTestsTab> {
  late AssessmentService _service;
  bool _loading = true;
  String? _error;
  List<StudentAttemptSummary> _attempts = [];

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = AssessmentService(apiClient: apiClient);
    _loadAttempts();
  }

  Future<void> _loadAttempts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final attempts = await _service.getMyAssessmentAttempts(contentType: widget.contentType);
      setState(() {
        _attempts = attempts;
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.civic));
    }
    
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.berry, size: 48),
              const SizedBox(height: 16),
              Text(
                "Could not load your tests",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadAttempts,
                child: const Text("RETRY"),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAttempts,
      color: AppColors.civic,
      child: _attempts.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.quiz_outlined, color: AppColors.muted, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        "No tests found",
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "You haven't compiled or started any tests yet.",
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _attempts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final attempt = _attempts[index];
                final result = attempt.result;
                final hasReport = result != null;
                final test = attempt.testTemplate;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                    boxShadow: const [
                      BoxShadow(color: Color(0x05000000), blurRadius: 8, offset: Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  test.title,
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Attempted on ${attempt.startedAt.split('T')[0]}",
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: attempt.status == 'completed'
                                  ? AppColors.emerald.withOpacity(0.1)
                                  : AppColors.saffron.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              attempt.status.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: attempt.status == 'completed' ? AppColors.emerald : AppColors.saffron,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (hasReport)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Score: ${result.score.toStringAsFixed(1)}",
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600, color: AppColors.civic, fontSize: 14),
                            ),
                            Text(
                              "Accuracy: ${(result.accuracy * 100).round()}%",
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600, color: AppColors.brand, fontSize: 14),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.civic),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            if (attempt.status == 'completed') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ResultReviewScreen(resultId: result!.id)),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => AttemptEngineScreen(attemptId: attempt.id)),
                              );
                            }
                          },
                          child: Text(
                            attempt.status == 'completed' ? "View Detailed Report" : "Resume Test",
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.civic),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
