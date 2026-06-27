import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../models/study_plan_models.dart';

class StudyPlanService extends ChangeNotifier {
  final ApiClient apiClient;

  StudyPlanService({required this.apiClient});

  // Fetch all study plans
  Future<List<StudyPlanSummary>> getStudyPlans({
    int? examId,
    int page = 1,
    int limit = 20,
  }) async {
    final offset = (page - 1) * limit;
    final Map<String, String> queryParams = {
      'limit': limit.toString(),
      'offset': offset.toString(),
      'status': 'published',
    };
    if (examId != null) queryParams['exam_id'] = examId.toString();

    final queryString = Uri(queryParameters: queryParams).query;
    try {
      final List<dynamic> data = await apiClient.get('/api/v1/study-plans?$queryString');
      return data.map((json) => StudyPlanSummary.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint("Error fetching study plans: $e");
      rethrow;
    }
  }

  // Fetch details of a specific study plan
  Future<StudyPlanDetail> getStudyPlan(int id) async {
    try {
      final Map<String, dynamic> data = await apiClient.get('/api/v1/study-plans/$id');
      return StudyPlanDetail.fromJson(data);
    } catch (e) {
      debugPrint("Error fetching study plan details $id: $e");
      rethrow;
    }
  }

  // Enroll in / Unlock a study plan
  Future<void> enrollInStudyPlan(int planId) async {
    try {
      await apiClient.post('/api/v1/study-plans/$planId/enroll', {'provider': 'manual'});
    } catch (e) {
      debugPrint("Error enrolling in study plan $planId: $e");
      rethrow;
    }
  }

  // Update study plan item progress
  Future<void> updateItemProgress(int itemId, String status) async {
    try {
      await apiClient.put(
        '/api/v1/study-plan-items/$itemId/progress',
        {'status': status},
      );
    } catch (e) {
      debugPrint("Error updating progress for item $itemId: $e");
      rethrow;
    }
  }

  // Start study plan test attempt
  Future<int> startTestAttempt(int testTemplateId, int planItemId) async {
    try {
      final Map<String, dynamic> data = await apiClient.post(
        '/api/v1/study-plan-tests/$testTemplateId/attempts/start',
        {'plan_item_id': planItemId},
      );
      return data['id'] as int;
    } catch (e) {
      debugPrint("Error starting test attempt for study plan test $testTemplateId: $e");
      rethrow;
    }
  }

  // Fetch paper for active study plan test attempt
  Future<StudyPlanAttemptPaper> getStudyPlanAttemptPaper(int attemptId) async {
    try {
      final Map<String, dynamic> data = await apiClient.get('/api/v1/study-plan-attempts/$attemptId/paper');
      return StudyPlanAttemptPaper.fromJson(data);
    } catch (e) {
      debugPrint("Error fetching study plan attempt paper $attemptId: $e");
      rethrow;
    }
  }

  // Save response for study plan test question
  Future<void> saveStudyPlanResponse({
    required int attemptId,
    required int questionId,
    required dynamic selectedAnswer,
    String? answerText,
    required String status,
    required bool isMarkedForReview,
  }) async {
    try {
      await apiClient.put(
        '/api/v1/study-plan-attempts/$attemptId/responses',
        {
          'question_id': questionId,
          'selected_answer': selectedAnswer,
          'answer_text': answerText,
          'status': status,
          'is_marked_for_review': isMarkedForReview,
        },
      );
    } catch (e) {
      debugPrint("Error saving response for question $questionId in study plan attempt $attemptId: $e");
      rethrow;
    }
  }

  // Submit complete study plan test attempt
  Future<int> submitStudyPlanAttempt(int attemptId) async {
    try {
      final Map<String, dynamic> data = await apiClient.post(
        '/api/v1/study-plan-attempts/$attemptId/submit',
        {},
      );
      return data['id'] as int;
    } catch (e) {
      debugPrint("Error submitting study plan attempt $attemptId: $e");
      rethrow;
    }
  }

  // Fetch study plan result review
  Future<Map<String, dynamic>> getStudyPlanResultReview(int resultId) async {
    try {
      final Map<String, dynamic> data = await apiClient.get(
        '/api/v1/study-plan-results/$resultId/review',
      );
      return data;
    } catch (e) {
      debugPrint("Error fetching study plan result review $resultId: $e");
      rethrow;
    }
  }
}

