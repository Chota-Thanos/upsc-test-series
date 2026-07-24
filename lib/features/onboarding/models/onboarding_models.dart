// Models for the mentor onboarding application flow — a regular user applying
// to become a mentor. Mirrors the web `/profile/apply` multi-step form and
// its `/api/v1/onboarding/applications` payloads.

class OnboardingAsset {
  final String bucket;
  final String path;
  final String fileName;
  final String? mimeType;
  final int? sizeBytes;
  final String? uploadedAt;
  final String? url;

  OnboardingAsset({
    required this.bucket,
    required this.path,
    required this.fileName,
    this.mimeType,
    this.sizeBytes,
    this.uploadedAt,
    this.url,
  });

  factory OnboardingAsset.fromJson(Map<String, dynamic> json) {
    return OnboardingAsset(
      bucket: json['bucket']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? '',
      mimeType: json['mime_type']?.toString(),
      sizeBytes: int.tryParse(json['size_bytes']?.toString() ?? ''),
      uploadedAt: json['uploaded_at']?.toString(),
      url: json['url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'bucket': bucket,
        'path': path,
        'file_name': fileName,
        if (mimeType != null) 'mime_type': mimeType,
        if (sizeBytes != null) 'size_bytes': sizeBytes,
        if (uploadedAt != null) 'uploaded_at': uploadedAt,
        if (url != null) 'url': url,
      };
}

class OnboardingApplication {
  final int id;
  final int userId;
  final String desiredRole;
  final String fullName;
  final String? city;
  final int? yearsExperience;
  final String phone;
  final String? about;
  final String status; // draft | pending | approved | rejected | more_info_required
  final Map<String, dynamic> details;
  final String? reviewerNote;
  final String? reviewedAt;
  final String createdAt;

  OnboardingApplication({
    required this.id,
    required this.userId,
    required this.desiredRole,
    required this.fullName,
    this.city,
    this.yearsExperience,
    required this.phone,
    this.about,
    required this.status,
    required this.details,
    this.reviewerNote,
    this.reviewedAt,
    required this.createdAt,
  });

  factory OnboardingApplication.fromJson(Map<String, dynamic> json) {
    return OnboardingApplication(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      userId: int.tryParse(json['user_id']?.toString() ?? '') ?? 0,
      desiredRole: json['desired_role']?.toString() ?? 'mentor',
      fullName: json['full_name']?.toString() ?? '',
      city: json['city']?.toString(),
      yearsExperience: int.tryParse(json['years_experience']?.toString() ?? ''),
      phone: json['phone']?.toString() ?? '',
      about: json['about']?.toString(),
      status: json['status']?.toString() ?? 'draft',
      details: json['details'] is Map
          ? Map<String, dynamic>.from(json['details'] as Map)
          : <String, dynamic>{},
      reviewerNote: json['reviewer_note']?.toString(),
      reviewedAt: json['reviewed_at']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  bool get isEditable =>
      status == 'draft' || status == 'rejected' || status == 'more_info_required';
}
