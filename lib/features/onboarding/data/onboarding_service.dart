import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../models/onboarding_models.dart';

/// API surface for the mentor onboarding application flow. Backs the
/// "Apply as Mentor" screens for regular users.
class OnboardingService extends ChangeNotifier {
  final ApiClient apiClient;

  OnboardingService({required this.apiClient});

  /// The current user's onboarding applications (newest first).
  Future<List<OnboardingApplication>> getMyApplications() async {
    final data = await apiClient.get('/api/v1/onboarding/applications/me');
    if (data is List) {
      return data
          .map((e) =>
              OnboardingApplication.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  /// Save a draft (partial data allowed).
  Future<OnboardingApplication> saveDraft(Map<String, dynamic> payload) async {
    final data = await apiClient.post(
      '/api/v1/onboarding/applications/draft',
      {...payload, 'desired_role': 'mentor'},
    );
    return OnboardingApplication.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Submit a complete application for review.
  Future<OnboardingApplication> submit(Map<String, dynamic> payload) async {
    final data = await apiClient.post(
      '/api/v1/onboarding/applications',
      {...payload, 'desired_role': 'mentor'},
    );
    return OnboardingApplication.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Reserve an upload URL for a proof/headshot/sample asset.
  Future<OnboardingAsset> uploadAsset(String fileName, String assetKind) async {
    final data = await apiClient.post(
      '/api/v1/onboarding/assets/upload',
      {'file_name': fileName, 'asset_kind': assetKind},
    );
    return OnboardingAsset.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
