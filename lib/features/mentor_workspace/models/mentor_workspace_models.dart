// Models for the mentor-side (provider) workspace: incoming student
// requests with joined session/evaluation data, availability slots,
// notifications, and the mentor's own editable profile.

int _asInt(dynamic v, [int fallback = 0]) =>
    int.tryParse(v?.toString() ?? '') ?? fallback;

int? _asIntOrNull(dynamic v) => int.tryParse(v?.toString() ?? '');

double? _asDoubleOrNull(dynamic v) => double.tryParse(v?.toString() ?? '');

List<String> _asStringList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : <String>[];

class MentorRequest {
  final int id;
  final int userId;
  final int mentorId;
  final int? mainsAnswerAttemptId;
  final String preferredMode;
  final String? note;
  final String status;
  final int? scheduledSlotId;
  final String paymentStatus;
  final double paymentAmount;
  final String paymentCurrency;
  final Map<String, dynamic>? meta;
  final String createdAt;

  // Joined fields
  final String? learnerName;
  final String? learnerEmail;
  final int? sessionId;
  final String? sessionStartsAt;
  final String? sessionEndsAt;
  final String? sessionMeetingLink;
  final String? sessionStatus;

  // Linked mains-attempt evaluation fields
  final String? evaluationStatus;
  final double? evaluationScore;
  final double? evaluationMaxScore;
  final String? evaluationFeedback;
  final String? evaluationCheckedCopyUrl;
  final List<String> evaluationStrengths;
  final List<String> evaluationWeaknesses;
  final String? attemptAnswerFileUrl;
  final String? attemptStudentAnswerText;
  final String? attemptQuestionStatement;

  MentorRequest({
    required this.id,
    required this.userId,
    required this.mentorId,
    this.mainsAnswerAttemptId,
    required this.preferredMode,
    this.note,
    required this.status,
    this.scheduledSlotId,
    required this.paymentStatus,
    required this.paymentAmount,
    required this.paymentCurrency,
    this.meta,
    required this.createdAt,
    this.learnerName,
    this.learnerEmail,
    this.sessionId,
    this.sessionStartsAt,
    this.sessionEndsAt,
    this.sessionMeetingLink,
    this.sessionStatus,
    this.evaluationStatus,
    this.evaluationScore,
    this.evaluationMaxScore,
    this.evaluationFeedback,
    this.evaluationCheckedCopyUrl,
    required this.evaluationStrengths,
    required this.evaluationWeaknesses,
    this.attemptAnswerFileUrl,
    this.attemptStudentAnswerText,
    this.attemptQuestionStatement,
  });

  factory MentorRequest.fromJson(Map<String, dynamic> json) {
    return MentorRequest(
      id: _asInt(json['id']),
      userId: _asInt(json['user_id']),
      mentorId: _asInt(json['mentor_id']),
      mainsAnswerAttemptId: _asIntOrNull(json['mains_answer_attempt_id']),
      preferredMode: json['preferred_mode']?.toString() ?? 'video',
      note: json['note'] as String?,
      status: json['status']?.toString() ?? 'requested',
      scheduledSlotId: _asIntOrNull(json['scheduled_slot_id']),
      paymentStatus: json['payment_status']?.toString() ?? 'pending',
      paymentAmount: _asDoubleOrNull(json['payment_amount']) ?? 0,
      paymentCurrency: json['payment_currency']?.toString() ?? 'INR',
      meta: json['meta'] is Map
          ? Map<String, dynamic>.from(json['meta'] as Map)
          : null,
      createdAt: json['created_at']?.toString() ?? '',
      learnerName: json['learner_name'] as String?,
      learnerEmail: json['learner_email'] as String?,
      sessionId: _asIntOrNull(json['session_id']),
      sessionStartsAt: json['session_starts_at']?.toString(),
      sessionEndsAt: json['session_ends_at']?.toString(),
      sessionMeetingLink: json['session_meeting_link'] as String?,
      sessionStatus: json['session_status']?.toString(),
      evaluationStatus: json['evaluation_status']?.toString(),
      evaluationScore: _asDoubleOrNull(json['evaluation_score']),
      evaluationMaxScore: _asDoubleOrNull(json['evaluation_max_score']),
      evaluationFeedback: json['evaluation_feedback'] as String?,
      evaluationCheckedCopyUrl: json['evaluation_checked_copy_url'] as String?,
      evaluationStrengths: _asStringList(json['evaluation_strengths']),
      evaluationWeaknesses: _asStringList(json['evaluation_weaknesses']),
      attemptAnswerFileUrl: json['attempt_answer_file_url'] as String?,
      attemptStudentAnswerText: json['attempt_student_answer_text'] as String?,
      attemptQuestionStatement: json['attempt_question_statement'] as String?,
    );
  }

  /// Custom copy the student attached directly to the request (no linked
  /// mains attempt), as stored under meta.student_copy.
  Map<String, dynamic>? get studentCopy => meta?['student_copy'] is Map
      ? Map<String, dynamic>.from(meta!['student_copy'] as Map)
      : null;

  /// Evaluation stored on the request meta (used for custom copies).
  Map<String, dynamic>? get customEvaluation => meta?['evaluation'] is Map
      ? Map<String, dynamic>.from(meta!['evaluation'] as Map)
      : null;

  bool get hasCopyToEvaluate =>
      mainsAnswerAttemptId != null || studentCopy != null;

  String get learnerLabel =>
      (learnerName?.trim().isNotEmpty ?? false) ? learnerName! : 'Student #$userId';
}

class MentorSlot {
  final int id;
  final int mentorId;
  final String startsAt;
  final String endsAt;
  final String mode;
  final int bookedCount;
  final int maxBookings;
  final String? meetingLink;
  final String? title;
  final String? description;
  final bool isActive;

  MentorSlot({
    required this.id,
    required this.mentorId,
    required this.startsAt,
    required this.endsAt,
    required this.mode,
    required this.bookedCount,
    required this.maxBookings,
    this.meetingLink,
    this.title,
    this.description,
    required this.isActive,
  });

  factory MentorSlot.fromJson(Map<String, dynamic> json) {
    return MentorSlot(
      id: _asInt(json['id']),
      mentorId: _asInt(json['mentor_id']),
      startsAt: json['starts_at']?.toString() ?? '',
      endsAt: json['ends_at']?.toString() ?? '',
      mode: json['mode']?.toString() ?? 'video',
      bookedCount: _asInt(json['booked_count']),
      maxBookings: _asInt(json['max_bookings'], 1),
      meetingLink: json['meeting_link'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  bool get isBooked => bookedCount >= maxBookings;
}

class MentorNotification {
  final int id;
  final String type;
  final String title;
  final String message;
  final String? link;
  final bool isRead;
  final String createdAt;

  MentorNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.link,
    required this.isRead,
    required this.createdAt,
  });

  factory MentorNotification.fromJson(Map<String, dynamic> json) {
    return MentorNotification(
      id: _asInt(json['id']),
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      link: json['link']?.toString(),
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

/// The mentor's own profile as editable from the workspace, including
/// visibility settings that are not part of the public directory model.
class MentorOwnProfile {
  final String displayName;
  final String? headline;
  final String? bio;
  final int yearsExperience;
  final String? city;
  final String? profileImageUrl;
  final String? publicEmail;
  final String? education;
  final bool isPublic;
  final bool isActive;
  final List<String> specializationTags;
  final List<String> highlights;
  final List<String> credentials;
  final List<String> specifications;
  final List<String> exams;
  final String specializationType; // all_areas | specific_field
  final String mentorType; // evaluation_mentorship | only_mentorship
  final String evaluationSource; // any_source | own_questions
  final List<Map<String, dynamic>> questionPdfs;

  MentorOwnProfile({
    required this.displayName,
    this.headline,
    this.bio,
    required this.yearsExperience,
    this.city,
    this.profileImageUrl,
    this.publicEmail,
    this.education,
    required this.isPublic,
    required this.isActive,
    required this.specializationTags,
    required this.highlights,
    required this.credentials,
    required this.specifications,
    required this.exams,
    required this.specializationType,
    required this.mentorType,
    required this.evaluationSource,
    required this.questionPdfs,
  });

  factory MentorOwnProfile.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] is Map
        ? Map<String, dynamic>.from(json['meta'] as Map)
        : <String, dynamic>{};
    return MentorOwnProfile(
      displayName: json['display_name']?.toString() ?? '',
      headline: json['headline'] as String?,
      bio: json['bio'] as String?,
      yearsExperience: _asInt(json['years_experience']),
      city: json['city'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      publicEmail: json['public_email'] as String?,
      education: json['education'] as String?,
      isPublic: json['is_public'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      specializationTags: _asStringList(json['specialization_tags']),
      highlights: _asStringList(json['highlights']),
      credentials: _asStringList(json['credentials']),
      specifications: _asStringList(json['specifications']),
      exams: _asStringList(json['exams']),
      specializationType:
          json['specialization_type']?.toString() ?? 'all_areas',
      mentorType: json['mentor_type']?.toString() ?? 'evaluation_mentorship',
      evaluationSource:
          meta['evaluation_source']?.toString() ?? 'any_source',
      questionPdfs: meta['question_pdfs'] is List
          ? (meta['question_pdfs'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[],
    );
  }
}
