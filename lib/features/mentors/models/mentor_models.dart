class MentorProfile {
  final int id;
  final int userId;
  final String displayName;
  final String? headline;
  final String? bio;
  final int yearsExperience;
  final String? city;
  final String? profileImageUrl;
  final String? education;
  final bool isVerified;
  final List<String> specializationTags;
  final List<String> highlights;
  final List<String> credentials;
  final String email;
  final String username;
  final List<String> specifications;
  final List<String> exams;
  final String specializationType; // all_areas, specific_field
  final String mentorType; // evaluation_mentorship, only_mentorship
  final Map<String, dynamic>? meta;

  MentorProfile({
    required this.id,
    required this.userId,
    required this.displayName,
    this.headline,
    this.bio,
    required this.yearsExperience,
    this.city,
    this.profileImageUrl,
    this.education,
    required this.isVerified,
    required this.specializationTags,
    required this.highlights,
    required this.credentials,
    required this.email,
    required this.username,
    required this.specifications,
    required this.exams,
    required this.specializationType,
    required this.mentorType,
    this.meta,
  });

  factory MentorProfile.fromJson(Map<String, dynamic> json) {
    return MentorProfile(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      userId: int.tryParse(json['user_id']?.toString() ?? '') ?? 0,
      displayName: json['display_name'] as String? ?? '',
      headline: json['headline'] as String?,
      bio: json['bio'] as String?,
      yearsExperience: int.tryParse(json['years_experience']?.toString() ?? '') ?? 0,
      city: json['city'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      education: json['education'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      specializationTags: List<String>.from(json['specialization_tags'] ?? []),
      highlights: List<String>.from(json['highlights'] ?? []),
      credentials: List<String>.from(json['credentials'] ?? []),
      email: json['email'] as String? ?? '',
      username: json['username'] as String? ?? '',
      specifications: List<String>.from(json['specifications'] ?? []),
      exams: List<String>.from(json['exams'] ?? []),
      specializationType: json['specialization_type'] as String? ?? 'all_areas',
      mentorType: json['mentor_type'] as String? ?? 'only_mentorship',
      meta: json['meta'] is Map ? Map<String, dynamic>.from(json['meta'] as Map) : null,
    );
  }
}

class MainsAttempt {
  final int id;
  final int questionVersionId;
  final String submittedAt;
  final String questionStatement;
  final String? questionPrompt;
  final String? paperName;
  final String evaluationStatus;

  MainsAttempt({
    required this.id,
    required this.questionVersionId,
    required this.submittedAt,
    required this.questionStatement,
    this.questionPrompt,
    this.paperName,
    required this.evaluationStatus,
  });

  factory MainsAttempt.fromJson(Map<String, dynamic> json) {
    return MainsAttempt(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      questionVersionId: int.tryParse(json['question_version_id']?.toString() ?? '') ?? 0,
      submittedAt: json['submitted_at'] as String? ?? '',
      questionStatement: json['question_statement'] as String? ?? '',
      questionPrompt: json['question_prompt'] as String?,
      paperName: json['paper_name'] as String?,
      evaluationStatus: json['evaluation_status'] as String? ?? '',
    );
  }
}

