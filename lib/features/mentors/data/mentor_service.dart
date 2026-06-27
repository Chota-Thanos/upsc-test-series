import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../models/mentor_models.dart';

class MentorService extends ChangeNotifier {
  final ApiClient apiClient;

  MentorService({required this.apiClient});

  // Fetch all mentor profiles
  Future<List<MentorProfile>> getMentorProfiles() async {
    try {
      final List<dynamic> data = await apiClient.get('/api/v1/mentorship/profiles');
      return data.map((json) => MentorProfile.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint("Error fetching mentor profiles: $e");
      rethrow;
    }
  }

  // Fetch a single mentor profile details
  Future<MentorProfile> getMentorProfile(int id) async {
    try {
      final Map<String, dynamic> data = await apiClient.get('/api/v1/mentorship/profiles/$id');
      return MentorProfile.fromJson(data);
    } catch (e) {
      debugPrint("Error fetching mentor profile $id: $e");
      rethrow;
    }
  }

  // Fetch target exams from mentorship settings
  Future<List<String>> getTargetExams() async {
    try {
      final Map<String, dynamic> data = await apiClient.get('/api/v1/mentorship/settings');
      if (data['target_exams'] is List) {
        return List<String>.from(data['target_exams'] as List);
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching target exams from settings: $e");
      return [];
    }
  }

  // Fetch student's subjective Mains attempts (to link to evaluations)
  Future<List<MainsAttempt>> getMyMainsAttempts() async {
    try {
      final List<dynamic> data = await apiClient.get('/api/v1/assessment/mains/my-answers');
      return data.map((json) => MainsAttempt.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint("Error fetching mains attempts: $e");
      rethrow;
    }
  }

  // Upload copy file name metadata and simulate/get upload URL
  Future<Map<String, String>> uploadStudentCopyMetadata(String fileName) async {
    try {
      final Map<String, dynamic> data = await apiClient.post(
        '/api/v1/onboarding/assets/upload',
        {
          'file_name': fileName,
          'asset_kind': 'student_copy',
        },
      );
      
      final String fileUrl = data['url'] as String? ?? '';
      return {
        'file_name': fileName,
        'url': fileUrl,
      };
    } catch (e) {
      debugPrint("Error simulating copy upload: $e");
      rethrow;
    }
  }

  // Submit mentorship booking request
  Future<void> submitMentorshipRequest({
    required int mentorId,
    int? mainsAttemptId,
    Map<String, String>? studentCopy,
    required String preferredMode,
    String? note,
  }) async {
    try {
      await apiClient.post(
        '/api/v1/mentorship/requests',
        {
          'mentor_id': mentorId,
          'mains_answer_attempt_id': mainsAttemptId,
          'student_copy': studentCopy, // has 'file_name' and 'url' keys
          'preferred_mode': preferredMode,
          'note': note?.trim() != '' ? note!.trim() : null,
        },
      );
    } catch (e) {
      debugPrint("Error submitting mentorship request: $e");
      rethrow;
    }
  }
}
