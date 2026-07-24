import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../../mentors/models/mentor_models.dart';
import '../models/mentor_workspace_models.dart';

/// Provider-side (mentor) API surface. Mirrors the web `/mentor/workspace`
/// dashboard: managing incoming student requests, triage, evaluation,
/// availability slots, the mentor's own profile/settings, and notifications.
class MentorWorkspaceService extends ChangeNotifier {
  final ApiClient apiClient;

  MentorWorkspaceService({required this.apiClient});

  // --- Incoming requests (provider mode) ---

  Future<List<MentorRequest>> getIncomingRequests() async {
    final List<dynamic> data =
        await apiClient.get('/api/v1/mentorship/requests?mode=provider');
    return data
        .map((e) => MentorRequest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> setRequestStatus(int requestId, String status) async {
    // status: accepted | rejected | completed
    await apiClient.put(
      '/api/v1/mentorship/requests/$requestId/status',
      {'status': status},
    );
  }

  Future<Map<String, dynamic>> startSessionNow(int requestId) async {
    final data = await apiClient.post(
      '/api/v1/mentorship/requests/$requestId/start-now',
      {},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> offerSlots(int requestId, List<int> slotIds) async {
    await apiClient.post(
      '/api/v1/mentorship/requests/$requestId/offer-slots',
      {'slot_ids': slotIds},
    );
  }

  // --- Chat ---

  Future<List<MentorshipMessage>> getMessages(int requestId) async {
    final List<dynamic> data =
        await apiClient.get('/api/v1/mentorship/requests/$requestId/messages');
    return data
        .map((e) =>
            MentorshipMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> sendMessage(int requestId, String body) async {
    await apiClient.post(
      '/api/v1/mentorship/requests/$requestId/messages',
      {'body': body},
    );
  }

  // --- Agendas ---

  Future<List<MentorshipAgenda>> getAgendas(int requestId) async {
    final List<dynamic> data =
        await apiClient.get('/api/v1/mentorship/requests/$requestId/agendas');
    return data
        .map((e) =>
            MentorshipAgenda.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> proposeAgenda(
    int requestId,
    String title,
    String? description,
  ) async {
    await apiClient.post(
      '/api/v1/mentorship/requests/$requestId/agendas',
      {
        'title': title,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
  }

  Future<void> agreeAgenda(int agendaId) async {
    await apiClient.put('/api/v1/mentorship/agendas/$agendaId/agree', {});
  }

  Future<void> proposeSolveAgenda(int agendaId) async {
    await apiClient.put(
        '/api/v1/mentorship/agendas/$agendaId/solve-propose', {});
  }

  Future<void> confirmSolveAgenda(int agendaId) async {
    await apiClient.put(
        '/api/v1/mentorship/agendas/$agendaId/solve-confirm', {});
  }

  Future<void> deleteAgenda(int agendaId) async {
    await apiClient.delete('/api/v1/mentorship/agendas/$agendaId');
  }

  // --- Availability slots ---

  Future<List<MentorSlot>> getMySlots(int mentorId) async {
    final List<dynamic> data =
        await apiClient.get('/api/v1/mentorship/slots?mentor_id=$mentorId');
    return data
        .map((e) => MentorSlot.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Create one or more slots. Each entry needs starts_at/ends_at ISO strings.
  Future<void> createSlots(List<Map<String, dynamic>> slots) async {
    await apiClient.post('/api/v1/mentorship/slots', {'slots': slots});
  }

  Future<void> deactivateSlot(int slotId) async {
    await apiClient.delete('/api/v1/mentorship/slots/$slotId');
  }

  // --- Evaluation ---

  /// Submit an evaluation. When [mainsAnswerAttemptId] is present the request is
  /// routed to the platform Mains evaluation endpoint; otherwise it goes to the
  /// mentorship module's custom-copy evaluation endpoint.
  Future<void> submitEvaluation({
    required int requestId,
    int? mainsAnswerAttemptId,
    required double score,
    required double maxScore,
    String? feedback,
    String? checkedCopyUrl,
    String? checkedCopyFileName,
    required List<String> strengths,
    required List<String> weaknesses,
  }) async {
    final payload = {
      'score': score,
      'max_score': maxScore,
      if (feedback != null && feedback.trim().isNotEmpty)
        'feedback': feedback.trim(),
      if (checkedCopyUrl != null && checkedCopyUrl.isNotEmpty)
        'checked_copy_url': checkedCopyUrl,
      if (checkedCopyFileName != null && checkedCopyFileName.isNotEmpty)
        'checked_copy_file_name': checkedCopyFileName,
      'strengths': strengths,
      'weaknesses': weaknesses,
    };

    if (mainsAnswerAttemptId != null) {
      await apiClient.patch(
        '/api/v1/assessment/mains/answers/$mainsAnswerAttemptId/evaluation',
        payload,
      );
    } else {
      await apiClient.put(
        '/api/v1/mentorship/requests/$requestId/custom-copy-evaluation',
        payload,
      );
    }
  }

  /// Reserve an upload URL for the mentor's checked copy.
  Future<Map<String, String>> uploadCheckedCopyMetadata(String fileName) async {
    final data = await apiClient.post(
      '/api/v1/onboarding/assets/upload',
      {'file_name': fileName, 'asset_kind': 'checked_copy'},
    );
    return {
      'file_name': fileName,
      'url': (data['url'] as String?) ?? '',
    };
  }

  // --- Profile & settings ---

  Future<MentorOwnProfile?> getMyProfile(int userId) async {
    try {
      final data = await apiClient.get('/api/v1/mentorship/profiles/$userId');
      if (data is Map) {
        return MentorOwnProfile.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (e) {
      // A directly-promoted mentor may not have a profile row yet.
      debugPrint("No mentor profile yet: $e");
      return null;
    }
  }

  Future<void> updateProfile(Map<String, dynamic> payload) async {
    await apiClient.put('/api/v1/mentorship/profile', payload);
  }

  /// Reserve an upload URL for the mentor's profile photo.
  Future<String> uploadProfilePhotoMetadata(String fileName) async {
    final data = await apiClient.post(
      '/api/v1/onboarding/assets/upload',
      {'file_name': fileName, 'asset_kind': 'headshot'},
    );
    return (data['url'] as String?) ?? '';
  }

  Future<List<String>> getTargetExams() async {
    try {
      final data = await apiClient.get('/api/v1/mentorship/settings');
      if (data is Map && data['target_exams'] is List) {
        return List<String>.from(data['target_exams'] as List);
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching target exams: $e");
      return [];
    }
  }

  // --- Notifications ---

  Future<List<MentorNotification>> getNotifications() async {
    final data = await apiClient.get('/api/v1/notifications');
    if (data is List) {
      return data
          .map((e) =>
              MentorNotification.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  Future<void> markNotificationRead(int id) async {
    await apiClient.put('/api/v1/notifications/$id/read', {});
  }

  Future<void> markAllNotificationsRead() async {
    await apiClient.put('/api/v1/notifications/mark-all-read', {});
  }
}
