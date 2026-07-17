import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../models/assessment_models.dart';

class AssessmentService extends ChangeNotifier {
  final ApiClient apiClient;

  AssessmentService({required this.apiClient});

  // Fetch all exams
  Future<List<Exam>> getAssessmentExams() async {
    try {
      final List<dynamic> data = await apiClient.get(
        '/api/v1/assessment/exams?limit=100',
      );
      return data
          .map((json) => Exam.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint("Error fetching exams: $e");
      rethrow;
    }
  }

  // Fetch all exam levels for a given exam
  Future<List<ExamLevel>> getAssessmentExamLevels(int examId) async {
    try {
      final List<dynamic> data = await apiClient.get(
        '/api/v1/assessment/exams/$examId/levels?limit=100',
      );
      return data
          .map((json) => ExamLevel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint("Error fetching exam levels: $e");
      rethrow;
    }
  }

  // Fetch test templates
  Future<List<AssessmentTestTemplate>> getAssessmentTests({
    int? examId,
    int? examLevelId,
    String? accessType,
    String? status,
    int page = 1,
    int limit = 24,
  }) async {
    final offset = (page - 1) * limit;
    final Map<String, String> queryParams = {
      'limit': limit.toString(),
      'offset': offset.toString(),
      'status': status ?? 'published',
    };
    if (examId != null) queryParams['exam_id'] = examId.toString();
    if (examLevelId != null)
      queryParams['exam_level_id'] = examLevelId.toString();
    if (accessType != null) queryParams['access_type'] = accessType;

    final queryString = Uri(queryParameters: queryParams).query;
    try {
      final List<dynamic> data = await apiClient.get(
        '/api/v1/assessment/test-templates?$queryString',
      );
      return data
          .map(
            (json) =>
                AssessmentTestTemplate.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint("Error fetching test templates: $e");
      rethrow;
    }
  }

  // Fetch single test template paper detail
  Future<Map<String, dynamic>> getAssessmentTestPaper(int id) async {
    try {
      final Map<String, dynamic> data = await apiClient.get(
        '/api/v1/assessment/test-templates/$id/paper',
      );
      return data;
    } catch (e) {
      debugPrint("Error fetching test paper $id: $e");
      rethrow;
    }
  }

  // Fetch test series list
  Future<List<TestSeries>> getAssessmentSeries({
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
      final List<dynamic> data = await apiClient.get(
        '/api/v1/assessment/test-series?$queryString',
      );
      return data
          .map((json) => TestSeries.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint("Error fetching test series: $e");
      rethrow;
    }
  }

  // Fetch single test series detail
  Future<TestSeriesDetail> getAssessmentSeriesDetail(int id) async {
    try {
      final Map<String, dynamic> data = await apiClient.get(
        '/api/v1/assessment/test-series/$id',
      );
      return TestSeriesDetail.fromJson(data);
    } catch (e) {
      debugPrint("Error fetching test series detail $id: $e");
      rethrow;
    }
  }

  // Fetch assessment student dashboard
  Future<AssessmentDashboardResponse> getAssessmentDashboard() async {
    try {
      final Map<String, dynamic> data = await apiClient.get(
        '/api/v1/assessment/me/dashboard',
      );
      return AssessmentDashboardResponse.fromJson(data);
    } catch (e) {
      debugPrint("Error fetching assessment dashboard: $e");
      rethrow;
    }
  }

  // Fetch student topic metrics
  Future<List<Map<String, dynamic>>> getStudentTopicMetrics() async {
    try {
      final List<dynamic> data = await apiClient.get(
        '/api/v1/assessment/me/topic-metrics',
      );
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint("Error fetching student topic metrics: $e");
      rethrow;
    }
  }

  // Fetch deep category performance with attempted questions
  Future<Map<String, dynamic>> getCategoryPerformance(
    int taxonomyNodeId,
  ) async {
    try {
      final Map<String, dynamic> data = await apiClient.get(
        '/api/v1/assessment/me/categories/$taxonomyNodeId/performance',
      );
      return data;
    } catch (e) {
      debugPrint("Error fetching category performance $taxonomyNodeId: $e");
      rethrow;
    }
  }

  // Fetch my attempts list
  Future<List<StudentAttemptSummary>> getMyAssessmentAttempts({
    String? contentType,
  }) async {
    try {
      final String url = contentType != null
          ? '/api/v1/assessment/me/attempts?limit=20&content_type=$contentType'
          : '/api/v1/assessment/me/attempts?limit=20';
      final List<dynamic> data = await apiClient.get(url);
      return data
          .map(
            (json) =>
                StudentAttemptSummary.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint("Error fetching attempts list: $e");
      rethrow;
    }
  }

  // Fetch result review
  Future<ResultReview> getResultReview(int id) async {
    try {
      final Map<String, dynamic> data = await apiClient.get(
        '/api/v1/assessment/results/$id/review',
      );
      return ResultReview.fromJson(data);
    } catch (e) {
      debugPrint("Error fetching result review $id: $e");
      rethrow;
    }
  }

  // Start attempt for test template
  Future<int> startAttempt(int testTemplateId) async {
    try {
      final Map<String, dynamic> data = await apiClient.post(
        '/api/v1/assessment/test-templates/$testTemplateId/attempts/start',
        {},
      );
      return data['id'] as int;
    } catch (e) {
      debugPrint("Error starting attempt for template $testTemplateId: $e");
      rethrow;
    }
  }

  // Fetch paper for an active attempt
  Future<AttemptPaper> getAttemptPaper(int attemptId) async {
    try {
      final Map<String, dynamic> data = await apiClient.get(
        '/api/v1/assessment/attempts/$attemptId/paper',
      );
      return AttemptPaper.fromJson(data);
    } catch (e) {
      debugPrint("Error fetching attempt paper $attemptId: $e");
      rethrow;
    }
  }

  // Save/Autosave response for MCQ question
  Future<void> saveResponse({
    required int attemptId,
    required int questionVersionId,
    required dynamic selectedAnswer,
    required String status,
    required bool isMarkedForReview,
    int timeSpentSeconds = 0,
  }) async {
    try {
      await apiClient.put('/api/v1/assessment/attempts/$attemptId/responses', {
        'question_version_id': questionVersionId,
        'selected_answer': selectedAnswer,
        'status': status,
        'is_marked_for_review': isMarkedForReview,
        'time_spent_seconds': timeSpentSeconds,
      });
    } catch (e) {
      debugPrint(
        "Error saving response for question $questionVersionId in attempt $attemptId: $e",
      );
      rethrow;
    }
  }

  // Fetch subjective answers for attempt
  Future<List<dynamic>> getMainsSubjectiveAnswers(int attemptId) async {
    try {
      final List<dynamic> data = await apiClient.get(
        '/api/v1/assessment/mains/attempts/$attemptId/answers',
      );
      return data;
    } catch (e) {
      debugPrint("Error fetching mains answers for attempt $attemptId: $e");
      return [];
    }
  }

  // Submit subjective answer response sheet
  Future<Map<String, dynamic>> submitMainsAnswer({
    required int attemptId,
    required int questionVersionId,
    String? answerText,
    String? answerFileUrl,
  }) async {
    try {
      // Build payload excluding null optional fields to avoid Zod validation rejection
      final Map<String, dynamic> payload = {
        'question_version_id': questionVersionId,
        'attempt_id': attemptId,
      };
      if (answerText != null && answerText.isNotEmpty) {
        payload['student_answer_text'] = answerText;
      }
      if (answerFileUrl != null && answerFileUrl.isNotEmpty) {
        payload['answer_file_url'] = answerFileUrl;
      }

      final dynamic data = await apiClient
          .post('/api/v1/assessment/mains/answers', payload);

      // Mark status as answered locally
      await saveResponse(
        attemptId: attemptId,
        questionVersionId: questionVersionId,
        selectedAnswer: null,
        status: 'answered',
        isMarkedForReview: false,
      );

      return data as Map<String, dynamic>;
    } catch (e) {
      debugPrint("Error submitting mains answer: $e");
      rethrow;
    }
  }

  // Trigger AI evaluation for a subjective answer
  Future<Map<String, dynamic>> triggerMainsAiEvaluation(int mainsAnswerId) async {
    try {
      final dynamic data = await apiClient.post(
        '/api/v1/assessment/mains/answers/$mainsAnswerId/ai-evaluate',
        {},
      );
      return data as Map<String, dynamic>;
    } catch (e) {
      debugPrint("Error triggering AI evaluation for mains answer $mainsAnswerId: $e");
      rethrow;
    }
  }

  // Save manual evaluation / grading for a subjective answer
  Future<Map<String, dynamic>> submitManualEvaluation({
    required int mainsAnswerId,
    required double score,
    required double maxScore,
    String? feedback,
    String? checkedCopyUrl,
    List<String>? strengths,
    List<String>? weaknesses,
  }) async {
    try {
      // Build payload excluding null optional fields to avoid Zod validation rejection
      final Map<String, dynamic> payload = {
        'score': score,
        'max_score': maxScore,
      };
      if (feedback != null && feedback.isNotEmpty) payload['feedback'] = feedback;
      if (checkedCopyUrl != null && checkedCopyUrl.isNotEmpty) payload['checked_copy_url'] = checkedCopyUrl;
      if (strengths != null) payload['strengths'] = strengths;
      if (weaknesses != null) payload['weaknesses'] = weaknesses;

      final dynamic data = await apiClient.patch(
        '/api/v1/assessment/mains/answers/$mainsAnswerId/evaluation',
        payload,
      );
      return data as Map<String, dynamic>;
    } catch (e) {
      debugPrint("Error saving manual evaluation for mains answer $mainsAnswerId: $e");
      rethrow;
    }
  }


  // Submit complete attempt
  Future<int> submitAttempt(
    int attemptId,
    int remainingSeconds,
    int durationMinutes,
  ) async {
    try {
      final timeSpent = (durationMinutes * 60) - remainingSeconds;
      final Map<String, dynamic> data = await apiClient
          .post('/api/v1/assessment/attempts/$attemptId/submit', {
            'submit_idempotency_key':
                'submit-$attemptId-${DateTime.now().millisecondsSinceEpoch}',
            'time_spent_seconds': timeSpent > 0 ? timeSpent : 0,
          });
      return data['id'] as int;
    } catch (e) {
      debugPrint("Error submitting attempt $attemptId: $e");
      rethrow;
    }
  }

  // Fetch taxonomy nodes (subjects/topics/subtopics) for wizard
  Future<List<Map<String, dynamic>>> getTaxonomyNodes(int examId) async {
    try {
      final List<dynamic> data = await apiClient.get(
        '/api/v1/assessment/taxonomy-nodes?exam_id=$examId&limit=1000',
      );
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint("Error fetching taxonomy nodes: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMainsTaxonomyNodes(int examId) async {
    try {
      final List<dynamic> data = await apiClient.get(
        '/api/v1/assessment/mains/taxonomy-nodes?exam_id=$examId&limit=1000',
      );
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint("Error fetching mains taxonomy nodes: $e");
      rethrow;
    }
  }

  // Fetch excluded taxonomy nodes for current student user
  Future<Map<String, List<int>>> getExcludedTaxonomyNodes() async {
    try {
      final Map<String, dynamic> data = await apiClient.get(
        '/api/v1/assessment/taxonomy/excluded',
      );
      return {
        'objective': List<int>.from(data['objective'] ?? []),
        'mains': List<int>.from(data['mains'] ?? []),
      };
    } catch (e) {
      debugPrint("Error fetching excluded taxonomy nodes: $e");
      rethrow;
    }
  }

  // Save excluded taxonomy nodes for current student user
  Future<void> updateExcludedTaxonomyNodes({
    required String taxonomyType,
    required List<int> excludedNodeIds,
  }) async {
    try {
      await apiClient.post(
        '/api/v1/assessment/taxonomy/excluded',
        {
          'taxonomy_type': taxonomyType,
          'excluded_node_ids': excludedNodeIds,
        },
      );
    } catch (e) {
      debugPrint("Error saving excluded taxonomy nodes: $e");
      rethrow;
    }
  }

  // Fetch question natures for wizard
  Future<List<Map<String, dynamic>>> getQuestionNatures(int examId) async {
    try {
      final List<dynamic> data = await apiClient.get(
        '/api/v1/assessment/question-natures?exam_id=$examId',
      );
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint("Error fetching question natures: $e");
      rethrow;
    }
  }

  // Start a dynamic practice test attempt (wizard flow)
  Future<int> startDynamicAttempt({
    required int examId,
    required int examLevelId,
    required int subjectNodeId,
    int? topicNodeId,
    int? subtopicNodeId,
    int? questionNatureId,
    int questionCount = 20,
    String testType = 'quick_test',
    String questionFamily = 'objective',
    bool includeAttempted = false,
  }) async {
    try {
      final payload = {
        'exam_id': examId,
        'exam_level_id': examLevelId,
        'subject_node_id': subjectNodeId,
        if (topicNodeId != null) 'topic_node_id': topicNodeId,
        if (subtopicNodeId != null) 'subtopic_node_id': subtopicNodeId,
        if (questionNatureId != null) 'question_nature_id': questionNatureId,
        'question_count': questionCount,
        'test_type': testType,
        'question_family': questionFamily,
        'include_attempted': includeAttempted,
      };
      final Map<String, dynamic> data = await apiClient.post(
        '/api/v1/assessment/attempts/dynamic',
        payload,
      );
      return data['id'] as int;
    } catch (e) {
      debugPrint("Error starting dynamic attempt: $e");
      rethrow;
    }
  }

  // Fetch question counts for nodes
  Future<List<Map<String, dynamic>>> getQuestionCounts(
    int examId,
    String questionFamily,
  ) async {
    try {
      final List<dynamic> data = await apiClient.get(
        '/api/v1/assessment/question-counts?exam_id=$examId&question_family=$questionFamily',
      );
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint("Error fetching question counts: $e");
      return [];
    }
  }

  // Start a compiled practice test attempt
  Future<int> startCompiledAttempt({
    required int examId,
    required String testType,
    required List<Map<String, dynamic>> categories,
    bool includeAttempted = false,
    String? title,
  }) async {
    try {
      final payload = {
        'exam_id': examId,
        'test_type': testType,
        'categories': categories,
        'include_attempted': includeAttempted,
        if (title != null) 'title': title,
      };
      final Map<String, dynamic> data = await apiClient.post(
        '/api/v1/assessment/attempts/compiled',
        payload,
      );
      return data['id'] as int;
    } catch (e) {
      debugPrint("Error starting compiled attempt: $e");
      rethrow;
    }
  }

  // AI generate questions for a subject when pool is empty
  Future<void> generateAIQuestions({
    required int examId,
    required int examLevelId,
    required int subjectNodeId,
    int? topicNodeId,
    int? subtopicNodeId,
    int? questionNatureId,
    int count = 5,
  }) async {
    try {
      final payload = {
        'exam_id': examId,
        'exam_level_id': examLevelId,
        'subject_node_id': subjectNodeId,
        if (topicNodeId != null) 'topic_node_id': topicNodeId,
        if (subtopicNodeId != null) 'subtopic_node_id': subtopicNodeId,
        if (questionNatureId != null) 'question_nature_id': questionNatureId,
        'count': count,
      };
      await apiClient.post(
        '/api/v1/assessment/attempts/dynamic/generate',
        payload,
      );
    } catch (e) {
      debugPrint("Error generating AI questions: $e");
      rethrow;
    }
  }

  // Fetch mentor booking requests by the student
  Future<List<Map<String, dynamic>>> getMyBookingRequests() async {
    try {
      final List<dynamic> data = await apiClient.get(
        '/api/v1/mentors/me/requests?limit=50',
      );
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint("Error fetching booking requests: $e");
      rethrow;
    }
  }

  // Fetch list of questions with category combos and used/unused indicators
  Future<List<Question>> getQuestions({
    required int examId,
    required String contentType,
    List<int>? subjectNodeIds,
    List<int>? topicNodeIds,
    List<int>? subtopicNodeIds,
    int limit = 100,
  }) async {
    try {
      final Map<String, String> queryParams = {
        'exam_id': examId.toString(),
        'content_type': contentType,
        'limit': limit.toString(),
      };
      if (subjectNodeIds != null && subjectNodeIds.isNotEmpty) {
        queryParams['subject_node_ids'] = subjectNodeIds.join(',');
      }
      if (topicNodeIds != null && topicNodeIds.isNotEmpty) {
        queryParams['topic_node_ids'] = topicNodeIds.join(',');
      }
      if (subtopicNodeIds != null && subtopicNodeIds.isNotEmpty) {
        queryParams['subtopic_node_ids'] = subtopicNodeIds.join(',');
      }

      final queryString = Uri(queryParameters: queryParams).query;
      final List<dynamic> data = await apiClient.get(
        '/api/v1/assessment/questions?$queryString',
      );
      return data
          .map((json) => Question.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint("Error fetching questions: $e");
      rethrow;
    }
  }

  // Create a user custom test template and return its ID
  Future<int> createUserCustomTest({
    required String title,
    String? description,
    required int examId,
    required int examLevelId,
    List<int>? questionIds,
    List<Map<String, dynamic>>? categories,
    String? testType,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        'title': title,
        if (description != null) 'description': description,
        'exam_id': examId,
        'exam_level_id': examLevelId,
        if (questionIds != null) 'question_ids': questionIds,
        if (categories != null) 'categories': categories,
        if (testType != null) 'test_type': testType,
      };
      final Map<String, dynamic> data = await apiClient.post(
        '/api/v1/assessment/user/custom-tests',
        payload,
      );
      return data['id'] as int;
    } catch (e) {
      debugPrint("Error creating user custom test: $e");
      rethrow;
    }
  }

  // Add questions to a user custom test template — either explicit question
  // ids, or category specs resolved server-side (any taxonomy level).
  Future<void> addQuestionsToUserTest({
    required int testTemplateId,
    List<int>? questionIds,
    List<Map<String, dynamic>>? categories,
  }) async {
    try {
      await apiClient.post(
        '/api/v1/assessment/user/custom-tests/$testTemplateId/add-questions',
        {
          if (questionIds != null) 'question_ids': questionIds,
          if (categories != null) 'categories': categories,
        },
      );
    } catch (e) {
      debugPrint("Error adding questions to custom test: $e");
      rethrow;
    }
  }

  // Fetch a single custom test template by ID
  Future<AssessmentTestTemplate> getTestTemplate(int id) async {
    try {
      final Map<String, dynamic> data = await apiClient.get(
        '/api/v1/assessment/test-templates/$id',
      );
      return AssessmentTestTemplate.fromJson(data);
    } catch (e) {
      debugPrint("Error fetching test template $id: $e");
      rethrow;
    }
  }

  // Get all user custom test templates (private access). contentType, when
  // given, is resolved server-side against actual question tagging (not a
  // guessed exam_level_id), so it stays correct regardless of what ids a given
  // environment's exam_levels rows happen to have.
  Future<List<AssessmentTestTemplate>> getUserCustomTests({String? contentType}) async {
    try {
      final query = StringBuffer('/api/v1/assessment/test-templates?access_type=private&limit=100');
      if (contentType != null) query.write('&content_type=$contentType');
      final List<dynamic> data = await apiClient.get(query.toString());
      return data
          .map((json) => AssessmentTestTemplate.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint("Error fetching user custom tests: $e");
      rethrow;
    }
  }

  // Delete a test template
  Future<void> deleteTestTemplate(int templateId) async {
    try {
      await apiClient.delete('/api/v1/assessment/test-templates/$templateId');
    } catch (e) {
      debugPrint("Error deleting test template: $e");
      rethrow;
    }
  }

  Map<String, dynamic> _normalizeParsedData(dynamic rawData) {
    if (rawData is List) {
      return {
        'success': true,
        'questions': rawData,
      };
    } else if (rawData is Map) {
      return Map<String, dynamic>.from(rawData);
    } else {
      throw Exception("Invalid response format from AI parser");
    }
  }

  // Parse raw text for questions using AI
  Future<ParsedResult> aiParseText({
    required String rawText,
    required String contentType,
    String? instructions,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        'raw_text': rawText,
        'content_type': contentType,
        if (instructions != null && instructions.isNotEmpty) 'instructions': instructions,
      };
      final dynamic rawData = await apiClient.post(
        '/api/v1/assessment/user/ai/parse-text',
        payload,
      );
      final Map<String, dynamic> data = _normalizeParsedData(rawData);
      return ParsedResult.fromJson(data);
    } catch (e) {
      debugPrint("Error parsing text with AI: $e");
      rethrow;
    }
  }

  // Parse files for questions using AI
  Future<ParsedResult> aiParseFile({
    required String base64Data,
    required String filename,
    required String mimeType,
    required String contentType,
    String? instructions,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        'base64_data': base64Data,
        'filename': filename,
        'mime_type': mimeType,
        'content_type': contentType,
        if (instructions != null && instructions.isNotEmpty) 'instructions': instructions,
      };
      final dynamic rawData = await apiClient.post(
        '/api/v1/assessment/user/ai/parse-file',
        payload,
      );
      final Map<String, dynamic> data = _normalizeParsedData(rawData);
      return ParsedResult.fromJson(data);
    } catch (e) {
      debugPrint("Error parsing file with AI: $e");
      rethrow;
    }
  }

  Future<ParsedResult> aiParseImages({
    required List<Map<String, String>> images,
    required String contentType,
    String? instructions,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        'images': images,
        'content_type': contentType,
        if (instructions != null && instructions.isNotEmpty) 'instructions': instructions,
      };
      final dynamic rawData = await apiClient.post(
        '/api/v1/assessment/user/ai/parse-images',
        payload,
      );
      final Map<String, dynamic> data = _normalizeParsedData(rawData);
      return ParsedResult.fromJson(data);
    } catch (e) {
      debugPrint("Error parsing images with AI: $e");
      rethrow;
    }
  }

  // Save AI parsed questions into the user library
  Future<void> aiSaveQuestions({
    required int examId,
    required int examLevelId,
    required int subjectNodeId,
    int? topicNodeId,
    String? passageTitle,
    String? passageText,
    required List<ParsedQuestion> questions,
    int? testTemplateId,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        'exam_id': examId,
        'exam_level_id': examLevelId,
        'subject_node_id': subjectNodeId,
        if (topicNodeId != null) 'topic_node_id': topicNodeId,
        if (passageTitle != null && passageTitle.isNotEmpty) 'passage_title': passageTitle,
        if (passageText != null && passageText.isNotEmpty) 'passage_text': passageText,
        'questions': questions.map((q) => q.toJson()).toList(),
        if (testTemplateId != null) 'test_template_id': testTemplateId,
      };
      await apiClient.post(
        '/api/v1/assessment/user/ai/save-questions',
        payload,
      );
    } catch (e) {
      debugPrint("Error saving parsed questions: $e");
      rethrow;
    }
  }

  // Fetch bookmarked questions
  Future<List<dynamic>> getBookmarks() async {
    try {
      final List<dynamic> data = await apiClient.get(
        '/api/v1/assessment/me/bookmarks',
      );
      return data;
    } catch (e) {
      debugPrint("Error fetching bookmarks: $e");
      rethrow;
    }
  }

  // Add bookmark
  Future<void> addBookmark(int questionId, int questionVersionId) async {
    try {
      await apiClient.post('/api/v1/assessment/me/bookmarks', {
        'question_id': questionId,
        'question_version_id': questionVersionId,
      });
    } catch (e) {
      debugPrint("Error adding bookmark: $e");
      rethrow;
    }
  }

  // Remove bookmark
  Future<void> removeBookmark(int questionId) async {
    try {
      await apiClient.delete('/api/v1/assessment/me/bookmarks/$questionId');
    } catch (e) {
      debugPrint("Error removing bookmark: $e");
      rethrow;
    }
  }

  // Fetch Mains questions
  Future<List<Question>> getMainsQuestions({
    required int examId,
    int? topicNodeId,
    int limit = 100,
  }) async {
    try {
      final Map<String, String> queryParams = {
        'exam_id': examId.toString(),
        'limit': limit.toString(),
      };
      if (topicNodeId != null) {
        queryParams['topic_node_id'] = topicNodeId.toString();
      }

      final queryString = Uri(queryParameters: queryParams).query;
      final List<dynamic> data = await apiClient.get(
        '/api/v1/assessment/mains/questions?$queryString',
      );
      return data
          .map((json) => Question.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint("Error fetching Mains questions: $e");
      rethrow;
    }
  }

  // Perform OCR using Gemini
  Future<String> performOcr(List<String> imagesBase64) async {
    try {
      final dynamic data = await apiClient.post('/api/v1/assessment/mains/ocr', {
        'images_base64': imagesBase64,
      });
      if (data != null && data is Map) {
        return data['extracted_text']?.toString() ?? '';
      }
      return '';
    } catch (e) {
      debugPrint("Error performing OCR: $e");
      rethrow;
    }
  }
}
