import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/assessment_service.dart';
import '../models/assessment_models.dart';
import 'attempt_engine_screen.dart';
import 'custom_test_create_screen.dart';

class CustomTestsListScreen extends StatefulWidget {
  final String? contentType;
  const CustomTestsListScreen({super.key, this.contentType});

  @override
  State<CustomTestsListScreen> createState() => _CustomTestsListScreenState();
}

class _CustomTestsListScreenState extends State<CustomTestsListScreen> {
  late AssessmentService _service;
  bool _loading = true;
  String? _error;
  List<AssessmentTestTemplate> _tests = [];
  int? _deletingId;
  int? _startingId;

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = AssessmentService(apiClient: apiClient);
    _fetchCustomTests();
  }

  Future<void> _fetchCustomTests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getUserCustomTests();
      setState(() {
        _tests = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load custom tests: $e";
        _loading = false;
      });
    }
  }

  Future<void> _handleStartAttempt(int templateId) async {
    setState(() {
      _startingId = templateId;
      _error = null;
    });
    try {
      final attemptId = await _service.startAttempt(templateId);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AttemptEngineScreen(attemptId: attemptId),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = "Failed to start test attempt: $e";
        _startingId = null;
      });
    }
  }

  Future<void> _handleDeleteTest(int templateId) async {
    final bool confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              "Delete Custom Test",
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
            content: const Text("Are you sure you want to delete this custom test template?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text("Cancel", style: GoogleFonts.inter(color: AppColors.muted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text("Delete", style: GoogleFonts.inter(color: AppColors.berry, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() {
      _deletingId = templateId;
      _error = null;
    });

    try {
      await _service.deleteTestTemplate(templateId);
      setState(() {
        _tests.removeWhere((t) => t.id == templateId);
      });
    } catch (e) {
      setState(() {
        _error = "Failed to delete test template: $e";
      });
    } finally {
      setState(() {
        _deletingId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(
          "My Custom Tests",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppColors.berry.withOpacity(0.1),
              child: Text(
                _error!,
                style: GoogleFonts.inter(
                  color: AppColors.berry,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.civic))
                : _tests.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tests.length,
                        itemBuilder: (context, index) {
                          final test = _tests[index];
                          return _buildTestCard(test);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomTestCreateScreen(
                contentType: widget.contentType,
              ),
            ),
          );
          _fetchCustomTests(); // Refresh list on return
        },
        backgroundColor: AppColors.civic,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_outlined, size: 64, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(
              "No Custom Tests Created",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Create a tailored practice exam by combining specific syllabus categories and question counts.",
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CustomTestCreateScreen(
                      contentType: widget.contentType,
                    ),
                  ),
                );
                _fetchCustomTests();
              },
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text("Build Test"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.civic,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCard(AssessmentTestTemplate test) {
    final bool isMains = test.testType == "mains_test";
    final String typeLabel = isMains
        ? "Mains"
        : test.title.toLowerCase().contains("csat") || test.title.toLowerCase().contains("aptitude")
            ? "CSAT"
            : "GS";

    final Color badgeBg = typeLabel == "Mains"
        ? AppColors.berry.withOpacity(0.08)
        : typeLabel == "CSAT"
            ? AppColors.saffron.withOpacity(0.08)
            : AppColors.civic.withOpacity(0.08);

    final Color badgeText = typeLabel == "Mains"
        ? AppColors.berry
        : typeLabel == "CSAT"
            ? AppColors.saffron
            : AppColors.civic;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "$typeLabel Test",
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeText,
                    ),
                  ),
                ),
                Text(
                  test.createdAt.split('T').first,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              test.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildStatBadge(Icons.layers_outlined, "${test.questionCount ?? test.totalMarks.round()} Qs"),
                const SizedBox(width: 12),
                _buildStatBadge(Icons.timer_outlined, "${test.durationMinutes} Min"),
                const SizedBox(width: 12),
                _buildStatBadge(Icons.emoji_events_outlined, "${test.totalMarks.round()} Marks"),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.line, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: _startingId == test.id ? null : () => _handleStartAttempt(test.id),
                      icon: _startingId == test.id
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(
                        "Attempt",
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 38,
                  width: 44,
                  child: OutlinedButton(
                    onPressed: _deletingId == test.id ? null : () => _handleDeleteTest(test.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.berry,
                      side: const BorderSide(color: AppColors.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: EdgeInsets.zero,
                    ),
                    child: _deletingId == test.id
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.berry))
                        : const Icon(Icons.delete_outline_rounded, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.muted),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.ink.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
