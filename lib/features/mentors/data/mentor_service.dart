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

  // Fetch the student's own mentorship requests (with mentor/session/evaluation details)
  Future<List<Map<String, dynamic>>> getMyRequests() async {
    try {
      final List<dynamic> data = await apiClient.get(
        '/api/v1/mentorship/requests?mode=user',
      );
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint("Error fetching mentorship requests: $e");
      rethrow;
    }
  }

  // --- Chat ---

  Future<List<MentorshipMessage>> getMessages(int requestId) async {
    try {
      final List<dynamic> data = await apiClient.get(
        '/api/v1/mentorship/requests/$requestId/messages',
      );
      return data
          .map((json) => MentorshipMessage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint("Error fetching mentorship messages: $e");
      rethrow;
    }
  }

  Future<MentorshipMessage> sendMessage(int requestId, String body) async {
    try {
      final data = await apiClient.post(
        '/api/v1/mentorship/requests/$requestId/messages',
        {'body': body},
      );
      return MentorshipMessage.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      debugPrint("Error sending mentorship message: $e");
      rethrow;
    }
  }

  // --- Agendas ---

  Future<List<MentorshipAgenda>> getAgendas(int requestId) async {
    try {
      final List<dynamic> data = await apiClient.get(
        '/api/v1/mentorship/requests/$requestId/agendas',
      );
      return data
          .map((json) => MentorshipAgenda.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint("Error fetching mentorship agendas: $e");
      rethrow;
    }
  }

  Future<MentorshipAgenda> proposeAgenda(
    int requestId,
    String title,
    String? description,
  ) async {
    try {
      final data = await apiClient.post(
        '/api/v1/mentorship/requests/$requestId/agendas',
        {
          'title': title,
          'description': description?.trim().isNotEmpty == true
              ? description!.trim()
              : null,
        },
      );
      return MentorshipAgenda.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      debugPrint("Error proposing mentorship agenda: $e");
      rethrow;
    }
  }

  Future<void> agreeToAgenda(int agendaId) async {
    try {
      await apiClient.put('/api/v1/mentorship/agendas/$agendaId/agree', {});
    } catch (e) {
      debugPrint("Error agreeing to agenda: $e");
      rethrow;
    }
  }

  Future<void> proposeSolveAgenda(int agendaId) async {
    try {
      await apiClient.put(
        '/api/v1/mentorship/agendas/$agendaId/solve-propose',
        {},
      );
    } catch (e) {
      debugPrint("Error proposing agenda solve: $e");
      rethrow;
    }
  }

  Future<void> confirmSolveAgenda(int agendaId) async {
    try {
      await apiClient.put(
        '/api/v1/mentorship/agendas/$agendaId/solve-confirm',
        {},
      );
    } catch (e) {
      debugPrint("Error confirming agenda solve: $e");
      rethrow;
    }
  }

  Future<void> deleteAgenda(int agendaId) async {
    try {
      await apiClient.delete('/api/v1/mentorship/agendas/$agendaId');
    } catch (e) {
      debugPrint("Error deleting agenda: $e");
      rethrow;
    }
  }

  // --- Payment ---

  Future<Map<String, dynamic>> createPaymentOrder(int requestId) async {
    try {
      final data = await apiClient.post(
        '/api/v1/mentorship/requests/$requestId/payment/order',
        {},
      );
      return Map<String, dynamic>.from(data as Map);
    } catch (e) {
      debugPrint("Error creating mentorship payment order: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyPayment({
    required int requestId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final data = await apiClient.post(
        '/api/v1/mentorship/requests/$requestId/payment/verify',
        {
          'razorpay_order_id': orderId,
          'razorpay_payment_id': paymentId,
          'razorpay_signature': signature,
        },
      );
      return Map<String, dynamic>.from(data as Map);
    } catch (e) {
      debugPrint("Error verifying mentorship payment: $e");
      rethrow;
    }
  }

  // --- Scheduling ---

  Future<List<Map<String, dynamic>>> getMentorSlots(int mentorId) async {
    try {
      final List<dynamic> data = await apiClient.get(
        '/api/v1/mentorship/slots?mentor_id=$mentorId&active_only=true',
      );
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint("Error fetching mentor slots: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> bookSlot(int requestId, int slotId) async {
    try {
      final data = await apiClient.post(
        '/api/v1/mentorship/requests/$requestId/book-slot',
        {'slot_id': slotId},
      );
      return Map<String, dynamic>.from(data as Map);
    } catch (e) {
      debugPrint("Error booking slot: $e");
      rethrow;
    }
  }

  // --- Video call ---

  Future<MentorshipCallCredentials> getAgoraToken(int sessionId) async {
    try {
      final data = await apiClient.get(
        '/api/v1/mentorship/sessions/$sessionId/agora-token',
      );
      return MentorshipCallCredentials.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      debugPrint("Error fetching mentorship Agora token: $e");
      rethrow;
    }
  }
}
