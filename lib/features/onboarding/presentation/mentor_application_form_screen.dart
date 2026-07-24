import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/onboarding_service.dart';
import '../models/onboarding_models.dart';

/// Multi-section mentor application form. Native counterpart to the web
/// `/profile/apply` wizard. Supports saving a draft and submitting for review.
class MentorApplicationFormScreen extends StatefulWidget {
  final OnboardingService service;
  final OnboardingApplication? existing;

  const MentorApplicationFormScreen({
    super.key,
    required this.service,
    this.existing,
  });

  @override
  State<MentorApplicationFormScreen> createState() =>
      _MentorApplicationFormScreenState();
}

class _MentorApplicationFormScreenState
    extends State<MentorApplicationFormScreen> {
  final _fullName = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _yearsExp = TextEditingController();
  final _about = TextEditingController();
  final _occupation = TextEditingController();
  final _rollNumber = TextEditingController();
  final _upscYears = TextEditingController();
  final _mainsWritten = TextEditingController();
  final _interviewsFaced = TextEditingController();
  final _optionalSubject = TextEditingController();
  final _institutes = TextEditingController();
  final _videoUrl = TextEditingController();

  final Set<String> _gsPrefs = {};
  OnboardingAsset? _headshot;
  final List<OnboardingAsset> _proofs = [];
  OnboardingAsset? _sampleEvaluation;

  String? _uploadingKind;
  bool _submitting = false;
  bool _savingDraft = false;

  static const _gsOptions = ["GS1", "GS2", "GS3", "GS4", "Essay"];

  @override
  void initState() {
    super.initState();
    final app = widget.existing;
    if (app != null) {
      _fullName.text = app.fullName;
      _city.text = app.city ?? "";
      _phone.text = app.phone;
      _yearsExp.text = app.yearsExperience?.toString() ?? "";
      _about.text = app.about ?? "";
      final d = app.details;
      _occupation.text = d['current_occupation']?.toString() ?? "";
      _rollNumber.text = d['upsc_roll_number']?.toString() ?? "";
      _upscYears.text = d['upsc_years']?.toString() ?? "";
      _mainsWritten.text = d['mains_written_count']?.toString() ?? "";
      _interviewsFaced.text = d['interview_faced_count']?.toString() ?? "";
      _optionalSubject.text = d['optional_subject']?.toString() ?? "";
      _videoUrl.text = d['intro_video_url']?.toString() ?? "";
      if (d['gs_preferences'] is List) {
        _gsPrefs.addAll((d['gs_preferences'] as List).map((e) => e.toString()));
      }
      if (d['institute_associations'] is List) {
        _institutes.text =
            (d['institute_associations'] as List).join(", ");
      }
      if (d['professional_headshot'] is Map) {
        _headshot = OnboardingAsset.fromJson(
            Map<String, dynamic>.from(d['professional_headshot'] as Map));
      }
      if (d['sample_evaluation'] is Map) {
        _sampleEvaluation = OnboardingAsset.fromJson(
            Map<String, dynamic>.from(d['sample_evaluation'] as Map));
      }
      if (d['proof_documents'] is List) {
        for (final p in (d['proof_documents'] as List)) {
          if (p is Map) {
            _proofs.add(
                OnboardingAsset.fromJson(Map<String, dynamic>.from(p)));
          }
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _fullName, _city, _phone, _yearsExp, _about, _occupation, _rollNumber,
      _upscYears, _mainsWritten, _interviewsFaced, _optionalSubject,
      _institutes, _videoUrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  int? _toInt(String v) => v.trim().isEmpty ? null : int.tryParse(v.trim());

  List<String> _splitCommas(String v) =>
      v.split(",").map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  Map<String, dynamic> _buildDetails() {
    return {
      'current_occupation':
          _occupation.text.trim().isEmpty ? null : _occupation.text.trim(),
      'professional_headshot': _headshot?.toJson(),
      'upsc_roll_number':
          _rollNumber.text.trim().isEmpty ? null : _rollNumber.text.trim(),
      'upsc_years':
          _upscYears.text.trim().isEmpty ? null : _upscYears.text.trim(),
      'proof_documents': _proofs.map((p) => p.toJson()).toList(),
      'mains_written_count': _toInt(_mainsWritten.text),
      'interview_faced_count': _toInt(_interviewsFaced.text),
      'optional_subject': _optionalSubject.text.trim().isEmpty
          ? null
          : _optionalSubject.text.trim(),
      'gs_preferences': _gsPrefs.toList(),
      'mentorship_years': _toInt(_yearsExp.text),
      'institute_associations': _splitCommas(_institutes.text),
      'sample_evaluation': _sampleEvaluation?.toJson(),
      'intro_video_url':
          _videoUrl.text.trim().isEmpty ? null : _videoUrl.text.trim(),
    };
  }

  Future<void> _upload(String assetKind) async {
    setState(() => _uploadingKind = assetKind);
    try {
      // The backend issues a mock upload URL keyed off the filename; we send a
      // representative name per asset kind.
      final fileName = "${assetKind}_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final asset = await widget.service.uploadAsset(fileName, assetKind);
      if (!mounted) return;
      setState(() {
        switch (assetKind) {
          case 'headshot':
            _headshot = asset;
            break;
          case 'sample_evaluation':
            _sampleEvaluation = asset;
            break;
          case 'proof_document':
            _proofs.add(asset);
            break;
        }
      });
      _toast("Attached ${asset.fileName}");
    } catch (e) {
      _toast("Upload failed: $e");
    } finally {
      if (mounted) setState(() => _uploadingKind = null);
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _savingDraft = true);
    try {
      await widget.service.saveDraft({
        'full_name': _fullName.text.trim(),
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'years_experience': _toInt(_yearsExp.text),
        'phone': _phone.text.trim(),
        'about': _about.text.trim().isEmpty ? null : _about.text.trim(),
        'details': _buildDetails(),
      });
      _toast("Draft saved");
    } catch (e) {
      _toast("Failed to save draft: $e");
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  Future<void> _submit() async {
    if (_fullName.text.trim().length < 2) {
      _toast("Full name is required");
      return;
    }
    if (_phone.text.trim().length < 7) {
      _toast("A valid phone number is required");
      return;
    }
    final exp = _toInt(_yearsExp.text);
    if (exp != null && (exp < 0 || exp > 60)) {
      _toast("Years of experience must be between 0 and 60");
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.service.submit({
        'full_name': _fullName.text.trim(),
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'years_experience': exp,
        'phone': _phone.text.trim(),
        'about': _about.text.trim().isEmpty ? null : _about.text.trim(),
        'details': _buildDetails(),
      });
      _toast("Application submitted for review");
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _toast("Failed to submit: $e");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text("Mentor Application",
            style: AppTypography.title.copyWith(fontSize: 17)),
        actions: [
          TextButton(
            onPressed: _savingDraft ? null : _saveDraft,
            child: _savingDraft
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("Save draft"),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section("Basic Profile", [
            _field("Full name *", _fullName),
            _field("Phone number *", _phone,
                keyboardType: TextInputType.phone),
            _field("City", _city),
            _field("Years of experience", _yearsExp,
                keyboardType: TextInputType.number),
            _field("About you", _about, maxLines: 3),
          ]),
          const SizedBox(height: 16),
          _section("UPSC Details", [
            _field("Current occupation", _occupation),
            _field("UPSC roll number", _rollNumber),
            _field("UPSC attempt years (e.g. 2019-2022)", _upscYears),
            _field("Mains written count", _mainsWritten,
                keyboardType: TextInputType.number),
            _field("Interviews faced count", _interviewsFaced,
                keyboardType: TextInputType.number),
          ]),
          const SizedBox(height: 16),
          _section("Domain Focus", [
            _field("Optional subject", _optionalSubject),
            const SizedBox(height: 4),
            Text("GS preferences",
                style: AppTypography.eyebrowSmall
                    .copyWith(color: AppColors.muted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _gsOptions.map((g) {
                final selected = _gsPrefs.contains(g);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _gsPrefs.remove(g);
                    } else {
                      _gsPrefs.add(g);
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.civic : Colors.white,
                      border: Border.all(
                          color:
                              selected ? AppColors.civic : AppColors.line),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(g,
                        style: AppTypography.caption.copyWith(
                          color: selected ? Colors.white : AppColors.ink,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            _field("Institute associations (comma separated)", _institutes),
          ]),
          const SizedBox(height: 16),
          _section("Skill Assessment", [
            _uploadRow(
                "Professional headshot", 'headshot', _headshot?.fileName),
            _uploadRow("Proof documents", 'proof_document',
                _proofs.isEmpty ? null : "${_proofs.length} attached"),
            _uploadRow("Sample checked copy", 'sample_evaluation',
                _sampleEvaluation?.fileName),
            const SizedBox(height: 4),
            _field("Intro video URL", _videoUrl,
                keyboardType: TextInputType.url),
          ]),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.civic,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text("Submit for Review"),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
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
          Text(title, style: AppTypography.cardTitle.copyWith(fontSize: 15)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: maxLines > 1,
          isDense: true,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _uploadRow(String label, String assetKind, String? attached) {
    final busy = _uploadingKind == assetKind;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(attached ?? "Not attached",
                    style: AppTypography.caption.copyWith(
                        color: attached != null
                            ? AppColors.emerald
                            : AppColors.muted)),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : () => _upload(assetKind),
            icon: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file_rounded, size: 16),
            label: Text(attached != null ? "Replace" : "Attach"),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.civic,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
