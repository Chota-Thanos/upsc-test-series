import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/mentor_service.dart';
import '../models/mentor_models.dart';

class MentorDetailScreen extends StatefulWidget {
  final int mentorUserId;
  const MentorDetailScreen({super.key, required this.mentorUserId});

  @override
  State<MentorDetailScreen> createState() => _MentorDetailScreenState();
}

class _MentorDetailScreenState extends State<MentorDetailScreen> {
  late MentorService _service;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  MentorProfile? _mentor;
  List<MainsAttempt> _mainsAttempts = [];
  bool _loadingAttempts = false;

  // Booking request form states
  String _preferredMode = "video"; // video or chat_only
  bool _attachCopy = false;
  String _copySource = "upload"; // upload or platform
  int? _selectedAttemptId;
  Map<String, String>? _uploadedCopyData;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = MentorService(apiClient: apiClient);
    _loadMentorDetails();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadMentorDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profiles = await _service.getMentorProfiles();
      final mentor = profiles.firstWhere(
        (m) => m.userId == widget.mentorUserId,
      );
      setState(() {
        _mentor = mentor;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _fetchAttempts() async {
    setState(() {
      _loadingAttempts = true;
    });

    try {
      final attempts = await _service.getMyMainsAttempts();
      setState(() {
        _mainsAttempts = attempts;
        if (attempts.isNotEmpty) {
          _selectedAttemptId = attempts.first.id;
        }
      });
    } catch (e) {
      debugPrint("Failed to load subjective attempts: $e");
    } finally {
      setState(() {
        _loadingAttempts = false;
      });
    }
  }

  Future<void> _pickAndUploadCopy() async {
    try {
      final copyData = await _service.uploadStudentCopyMetadata(
        "mains_answer_sheet.pdf",
      );
      setState(() {
        _uploadedCopyData = copyData;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mock answer sheet copy uploaded.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Upload error: $e")));
    }
  }

  Future<void> _submitRequest() async {
    if (_attachCopy) {
      if (_copySource == 'upload' && _uploadedCopyData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Please select and upload a scanned copy of your answer sheet first.",
            ),
          ),
        );
        return;
      }
      if (_copySource == 'platform' && _selectedAttemptId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "No Mains attempts linked. Go submit a test or choose upload copy.",
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      _submitting = true;
    });

    try {
      await _service.submitMentorshipRequest(
        mentorId: _mentor!.id,
        mainsAttemptId: _attachCopy && _copySource == 'platform'
            ? _selectedAttemptId
            : null,
        studentCopy: _attachCopy && _copySource == 'upload'
            ? _uploadedCopyData
            : null,
        preferredMode: _preferredMode,
        note: _noteController.text,
      );
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                "Success",
                style: AppTypography.cardTitle.copyWith(fontSize: 16),
              ),
              content: const Text(
                "Mentorship request sent successfully! You can track bookings and initiate Agora Video calls once accepted by the mentor on the web dashboard.",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Return to mentors list
                  },
                  child: const Text("OK"),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to submit request: $e")));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _launchWebBooking() async {
    if (_mentor == null) return;
    final url = Uri.parse(
      "${ApiConstants.webAppUrl}/mentors/${widget.mentorUserId}",
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
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
        appBar: AppBar(title: const Text("Error")),
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
                  onPressed: _loadMentorDetails,
                  child: const Text("RETRY"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final m = _mentor!;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(
          "Mentor Profile",
          style: AppTypography.title.copyWith(fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.line, height: 1),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.ink,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Card Details
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (m.profileImageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            m.profileImageUrl!,
                            height: 64,
                            width: 64,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          height: 64,
                          width: 64,
                          decoration: BoxDecoration(
                            color: AppColors.civic.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              m.displayName.isNotEmpty
                                  ? m.displayName[0].toUpperCase()
                                  : 'M',
                              style: AppTypography.statValue.copyWith(
                                fontSize: 26,
                                color: AppColors.civic,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  m.displayName,
                                  style: AppTypography.title.copyWith(
                                    fontSize: 16,
                                  ),
                                ),
                                if (m.isVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: AppColors.civic,
                                    size: 18,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              m.headline ?? "UPSC Coach & Evaluator",
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.line),
                  const SizedBox(height: 12),

                  Text(
                    "Biography",
                    style: AppTypography.sectionHeader.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    m.bio ??
                        "Experienced civil service mentor guiding students.",
                    style: AppTypography.body.copyWith(height: 1.35),
                  ),

                  if (m.education != null && m.education!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      "Education",
                      style: AppTypography.sectionHeader.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m.education!,
                      style: AppTypography.body.copyWith(height: 1.35),
                    ),
                  ],

                  // Specialties & Highlights
                  if (m.specializationTags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      "Specialties",
                      style: AppTypography.sectionHeader.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: m.specializationTags
                          .map(
                            (t) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.paper,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                t,
                                style: AppTypography.caption.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],

                  if (m.highlights.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      "Highlights",
                      style: AppTypography.sectionHeader.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    ...m.highlights.map(
                      (hl) => Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: AppColors.saffron,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(hl, style: AppTypography.body),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Booking Request form Panel
            Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      height: 54,
                      width: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.civic.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.laptop_chromebook_rounded,
                        color: AppColors.civic,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Book Consultation Session",
                    style: AppTypography.title.copyWith(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Mentorship bookings and secure one-time payments are managed on our web platform. Review coach availability and book your slot on your dashboard.",
                    style: AppTypography.body.copyWith(height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.line),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Consultation Fee",
                        style: AppTypography.caption.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "₹1,000 / Session",
                        style: AppTypography.statValue.copyWith(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      backgroundColor: AppColors.civic,
                    ),
                    onPressed: _launchWebBooking,
                    child: Text(
                      "BOOK SESSION ON WEB",
                      style: AppTypography.button.copyWith(
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
