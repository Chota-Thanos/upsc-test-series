import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/mentor_workspace_service.dart';
import '../models/mentor_workspace_models.dart';

/// Edit public profile + workspace visibility settings. Mirrors the web
/// workspace "Edit Public Profile" and "Workspace Settings" tabs.
class MentorProfileTab extends StatefulWidget {
  final MentorWorkspaceService service;
  final int mentorUserId;

  const MentorProfileTab({
    super.key,
    required this.service,
    required this.mentorUserId,
  });

  @override
  State<MentorProfileTab> createState() => _MentorProfileTabState();
}

class _MentorProfileTabState extends State<MentorProfileTab> {
  bool _loading = true;
  bool _saving = false;

  final _displayName = TextEditingController();
  final _headline = TextEditingController();
  final _bio = TextEditingController();
  final _yearsExp = TextEditingController(text: "0");
  final _city = TextEditingController();
  final _publicEmail = TextEditingController();
  final _education = TextEditingController();
  final _specializationTags = TextEditingController();
  final _highlights = TextEditingController();
  final _credentials = TextEditingController();
  final _exams = TextEditingController();

  String _specializationType = 'all_areas';
  String _mentorType = 'evaluation_mentorship';
  bool _isPublic = true;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _displayName.dispose();
    _headline.dispose();
    _bio.dispose();
    _yearsExp.dispose();
    _city.dispose();
    _publicEmail.dispose();
    _education.dispose();
    _specializationTags.dispose();
    _highlights.dispose();
    _credentials.dispose();
    _exams.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await widget.service.getMyProfile(widget.mentorUserId);
      if (p != null && mounted) _applyProfile(p);
    } catch (e) {
      _toast("Failed to load profile: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyProfile(MentorOwnProfile p) {
    _displayName.text = p.displayName;
    _headline.text = p.headline ?? "";
    _bio.text = p.bio ?? "";
    _yearsExp.text = p.yearsExperience.toString();
    _city.text = p.city ?? "";
    _publicEmail.text = p.publicEmail ?? "";
    _education.text = p.education ?? "";
    _specializationTags.text = p.specializationTags.join(", ");
    _highlights.text = p.highlights.join("\n");
    _credentials.text = p.credentials.join("\n");
    _exams.text = p.exams.join(", ");
    _specializationType = p.specializationType;
    _mentorType = p.mentorType;
    _isPublic = p.isPublic;
    _isActive = p.isActive;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  List<String> _splitCommas(String v) =>
      v.split(",").map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  List<String> _splitLines(String v) =>
      v.split("\n").map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  Future<void> _save() async {
    final expNum = int.tryParse(_yearsExp.text.trim());
    if (expNum == null || expNum < 0 || expNum > 60) {
      _toast("Experience must be an integer between 0 and 60");
      return;
    }
    if (_displayName.text.trim().length < 2) {
      _toast("Display name is required");
      return;
    }
    final tags = _specializationType == 'specific_field'
        ? _splitCommas(_specializationTags.text)
        : <String>[];
    if (_specializationType == 'specific_field' && tags.isEmpty) {
      _toast("Add at least one specialization tag");
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.service.updateProfile({
        'display_name': _displayName.text.trim(),
        'headline': _headline.text.trim().isEmpty ? null : _headline.text.trim(),
        'bio': _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        'years_experience': expNum,
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'public_email':
            _publicEmail.text.trim().isEmpty ? null : _publicEmail.text.trim(),
        'education':
            _education.text.trim().isEmpty ? null : _education.text.trim(),
        'specialization_tags': tags,
        'highlights': _splitLines(_highlights.text),
        'credentials': _splitLines(_credentials.text),
        'specialization_type': _specializationType,
        'mentor_type': _mentorType,
        'exams': _splitCommas(_exams.text),
        'is_public': _isPublic,
        'is_active': _isActive,
      });
      _toast("Profile saved");
    } catch (e) {
      _toast("Failed to save: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard("Public Profile", [
          _field("Display name", _displayName),
          _field("Headline", _headline),
          _field("Bio", _bio, maxLines: 3),
          _field("Years of experience", _yearsExp,
              keyboardType: TextInputType.number),
          _field("City", _city),
          _field("Public email", _publicEmail,
              keyboardType: TextInputType.emailAddress),
          _field("Education", _education),
          _field("Target exams (comma separated)", _exams),
          _field("Highlights (one per line)", _highlights, maxLines: 3),
          _field("Credentials (one per line)", _credentials, maxLines: 3),
        ]),
        const SizedBox(height: 16),
        _sectionCard("Specialization", [
          _dropdown(
            "Focus",
            _specializationType,
            const {
              'all_areas': 'All areas',
              'specific_field': 'Specific field',
            },
            (v) => setState(() => _specializationType = v),
          ),
          if (_specializationType == 'specific_field')
            _field("Specialization tags (comma separated)",
                _specializationTags),
          _dropdown(
            "Mentor type",
            _mentorType,
            const {
              'evaluation_mentorship': 'Evaluation + Mentorship',
              'only_mentorship': 'Only Mentorship',
            },
            (v) => setState(() => _mentorType = v),
          ),
        ]),
        const SizedBox(height: 16),
        _sectionCard("Workspace Settings", [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text("Public in directory",
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text("Show your profile in the mentor directory",
                style: AppTypography.caption),
            value: _isPublic,
            activeColor: AppColors.civic,
            onChanged: (v) => setState(() => _isPublic = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text("Accepting requests",
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text("Allow students to send new requests",
                style: AppTypography.caption),
            value: _isActive,
            activeColor: AppColors.civic,
            onChanged: (v) => setState(() => _isActive = v),
          ),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.civic,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text("Save Profile"),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
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

  Widget _dropdown(String label, String value, Map<String, String> options,
      ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            items: options.entries
                .map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}
