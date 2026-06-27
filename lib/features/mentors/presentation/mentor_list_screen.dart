import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/mentor_service.dart';
import '../models/mentor_models.dart';
import 'mentor_detail_screen.dart';
import 'my_bookings_screen.dart';

class MentorListScreen extends StatefulWidget {
  const MentorListScreen({super.key});

  @override
  State<MentorListScreen> createState() => _MentorListScreenState();
}

class _MentorListScreenState extends State<MentorListScreen> {
  late MentorService _service;
  bool _loading = true;
  String? _error;

  List<MentorProfile> _mentors = [];
  List<String> _targetExams = [];
  String _searchQuery = "";
  String _selectedExamFilter = "all";
  String _selectedScopeFilter = "all"; // all, all_areas, specific_field
  String _selectedTypeFilter = "all"; // all, evaluation_mentorship, only_mentorship
  String? _selectedFocusTag;
  int _minExperience = 0;

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = MentorService(apiClient: apiClient);
    _loadMentorsData();
  }

  Future<void> _loadMentorsData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final mentors = await _service.getMentorProfiles();
      final exams = await _service.getTargetExams();
      setState(() {
        _mentors = mentors;
        _targetExams = exams;
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
    if (_loading && _mentors.isEmpty) {
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
                ElevatedButton(onPressed: _loadMentorsData, child: const Text("RETRY")),
              ],
            ),
          ),
        ),
      );
    }

    // Extraction of unique specialization focus tags
    final Set<String> focusTags = {};
    for (var m in _mentors) {
      focusTags.addAll(m.specializationTags);
    }
    final sortedTags = focusTags.toList()..sort();

    // Filters application
    final filteredMentors = _mentors.where((m) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          m.displayName.toLowerCase().contains(q) ||
          (m.headline ?? '').toLowerCase().contains(q) ||
          (m.bio ?? '').toLowerCase().contains(q);

      final matchesExam = _selectedExamFilter == 'all' || m.exams.contains(_selectedExamFilter);
      final matchesScope = _selectedScopeFilter == 'all' || m.specializationType == _selectedScopeFilter;
      final matchesType = _selectedTypeFilter == 'all' || m.mentorType == _selectedTypeFilter;
      final matchesTag = _selectedFocusTag == null || m.specializationTags.contains(_selectedFocusTag);
      final matchesExp = m.yearsExperience >= _minExperience;

      return matchesSearch && matchesExam && matchesScope && matchesType && matchesTag && matchesExp;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Premium Welcome Card style Hero Header Panel
                    Stack(
                      children: [
                        Container(
                          height: 180,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage(
                                'https://images.unsplash.com/photo-1513258496099-48168024aec0?q=80&w=600&auto=format&fit=crop',
                              ),
                              fit: BoxFit.cover,
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                          ),
                        ),
                        Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.civic.withOpacity(0.95),
                                AppColors.civic.withOpacity(0.7),
                                Colors.transparent,
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: const BorderRadius.all(Radius.circular(24)),
                          ),
                        ),
                        Positioned(
                          bottom: 20,
                          left: 20,
                          right: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "EXPERT ADVISORY",
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Discover UPSC Mentors",
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Connect 1-on-1 with civil servants and exam veterans to unlock copy evaluation sessions.",
                                style: GoogleFonts.inter(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // My Bookings button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.line),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
                        );
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.civic),
                      label: Text(
                        "My Booking Requests",
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.civic),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Filters Workspace
                    TextField(
                      decoration: const InputDecoration(
                        hintText: "Search mentors by name, paper focus...",
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Experience Filter
                          _buildDropdownFilter<int>(
                            value: _minExperience,
                            hint: "Any Experience",
                            items: const [
                              DropdownMenuItem(value: 0, child: Text("Any Experience")),
                              DropdownMenuItem(value: 2, child: Text("2+ Years")),
                              DropdownMenuItem(value: 5, child: Text("5+ Years")),
                              DropdownMenuItem(value: 8, child: Text("8+ Years")),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _minExperience = val ?? 0;
                              });
                            },
                          ),
                          const SizedBox(width: 8),

                          // Mentorship Type
                          _buildDropdownFilter<String>(
                            value: _selectedTypeFilter,
                            hint: "Any Type",
                            items: const [
                              DropdownMenuItem(value: "all", child: Text("Any Type")),
                              DropdownMenuItem(value: "evaluation_mentorship", child: Text("Evaluation + Mentor")),
                              DropdownMenuItem(value: "only_mentorship", child: Text("Only Mentorship")),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedTypeFilter = val ?? "all";
                              });
                            },
                          ),
                          const SizedBox(width: 8),

                          // Exam coverage
                          _buildDropdownFilter<String>(
                            value: _selectedExamFilter,
                            hint: "Any Exam",
                            items: [
                              const DropdownMenuItem(value: "all", child: Text("Any Exam")),
                              ..._targetExams.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedExamFilter = val ?? "all";
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick Tags focus selector
                    if (sortedTags.isNotEmpty) ...[
                      Text(
                        "FILTER BY SUBJECT FOCUS",
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.muted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 32,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: sortedTags.length + 1,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (context, idx) {
                            if (idx == 0) {
                              final isSelected = _selectedFocusTag == null;
                              return ChoiceChip(
                                label: const Text("All Focus"),
                                selected: isSelected,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedFocusTag = null;
                                  });
                                },
                              );
                            }
                            final tag = sortedTags[idx - 1];
                            final isSelected = _selectedFocusTag == tag;
                            return ChoiceChip(
                              label: Text(tag),
                              selected: isSelected,
                              onSelected: (_) {
                                  setState(() {
                                    _selectedFocusTag = tag;
                                  });
                              },
                            );
                          },
                        ),
                      )
                    ]
                  ],
                ),
              ),
            )
          ];
        },
        body: filteredMentors.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people_outline_rounded, color: AppColors.muted, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      "No mentors match your search filters.",
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.muted),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filteredMentors.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final mentor = filteredMentors[index];
                  return _buildMentorCard(mentor);
                },
              ),
      ),
    );
  }

  Widget _buildDropdownFilter<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.ink),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildMentorCard(MentorProfile mentor) {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Basic avatar + name block
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mentor.profileImageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(mentor.profileImageUrl!, height: 52, width: 52, fit: BoxFit.cover),
                )
              else
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: AppColors.civic.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      mentor.displayName.isNotEmpty ? mentor.displayName[0].toUpperCase() : 'M',
                      style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.civic),
                    ),
                  ),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          mentor.displayName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        if (mentor.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, color: AppColors.civic, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mentor.headline ?? "UPSC Mentorship Veteran",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 12),

          // Short bio
          if (mentor.bio != null) ...[
            Text(
              mentor.bio!,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.muted,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
          ],

          // Type and Scope tags
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildCompactBadge(
                mentor.mentorType == 'only_mentorship' ? "Only Guidance" : "Evaluation + Mentorship",
                AppColors.civic.withOpacity(0.08),
                AppColors.civic,
              ),
              _buildCompactBadge(
                mentor.specializationType == 'specific_field' ? "Topic Expert" : "General Syllabus Guide",
                AppColors.paper,
                AppColors.ink,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Exams / Experience spec
          Row(
            children: [
              const Icon(Icons.history_toggle_off_rounded, color: AppColors.muted, size: 14),
              const SizedBox(width: 4),
              Text(
                "${mentor.yearsExperience} Years Exp",
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted),
              ),
              if (mentor.exams.isNotEmpty) ...[
                const SizedBox(width: 16),
                const Icon(Icons.menu_book_rounded, color: AppColors.muted, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    mentor.exams.join(', '),
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.line),
          const SizedBox(height: 10),

          // Pricing + Details buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "CONSULTATION FEE",
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.muted),
                  ),
                  Text(
                    "₹1,000",
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink),
                  ),
                ],
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
                      builder: (_) => MentorDetailScreen(mentorUserId: mentor.userId),
                    ),
                  );
                },
                child: const Text("REQUEST DETAILS"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBadge(String text, Color bg, Color labelColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.line.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: labelColor,
        ),
      ),
    );
  }
}
