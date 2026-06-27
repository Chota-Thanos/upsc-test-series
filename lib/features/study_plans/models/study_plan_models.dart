class StudyPlanSummary {
  final int id;
  final String title;
  final String slug;
  final String? subtitle;
  final String? description;
  final int examId;
  final int? subjectNodeId;
  final String? examName;
  final String? subjectName;
  final int durationWeeks;
  final String? levelLabel;
  final String language;
  final String? coverImageUrl;
  final String? previewVideoUrl;
  final int priceAmountMinor;
  final String currency;
  final String status;
  final int? itemCount;
  final int? testCount;
  final String? publishedAt;

  StudyPlanSummary({
    required this.id,
    required this.title,
    required this.slug,
    this.subtitle,
    this.description,
    required this.examId,
    this.subjectNodeId,
    this.examName,
    this.subjectName,
    required this.durationWeeks,
    this.levelLabel,
    required this.language,
    this.coverImageUrl,
    this.previewVideoUrl,
    required this.priceAmountMinor,
    required this.currency,
    required this.status,
    this.itemCount,
    this.testCount,
    this.publishedAt,
  });

  factory StudyPlanSummary.fromJson(Map<String, dynamic> json) {
    return StudyPlanSummary(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String?,
      examId: int.tryParse(json['exam_id']?.toString() ?? '') ?? 0,
      subjectNodeId: json['subject_node_id'] != null ? int.tryParse(json['subject_node_id'].toString()) : null,
      examName: json['exam_name'] as String?,
      subjectName: json['subject_name'] as String?,
      durationWeeks: int.tryParse(json['duration_weeks']?.toString() ?? '') ?? 0,
      levelLabel: json['level_label'] as String?,
      language: json['language'] as String? ?? 'en',
      coverImageUrl: json['cover_image_url'] as String?,
      previewVideoUrl: json['preview_video_url'] as String?,
      priceAmountMinor: int.tryParse(json['price_amount_minor']?.toString() ?? '') ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      status: json['status'] as String? ?? 'draft',
      itemCount: json['item_count'] != null ? int.tryParse(json['item_count'].toString()) : null,
      testCount: json['test_count'] != null ? int.tryParse(json['test_count'].toString()) : null,
      publishedAt: json['published_at'] as String?,
    );
  }
}

class StudyPlanTestTemplate {
  final int id;
  final String title;
  final String slug;
  final String? description;
  final int examId;
  final int examLevelId;
  final String testType; // prelims_test, csat_test, mains_test
  final int durationMinutes;
  final double totalMarks;
  final double negativeMarksPerQuestion;
  final String? instructions;
  final String status;
  final int? questionCount;

  StudyPlanTestTemplate({
    required this.id,
    required this.title,
    required this.slug,
    this.description,
    required this.examId,
    required this.examLevelId,
    required this.testType,
    required this.durationMinutes,
    required this.totalMarks,
    required this.negativeMarksPerQuestion,
    this.instructions,
    required this.status,
    this.questionCount,
  });

  factory StudyPlanTestTemplate.fromJson(Map<String, dynamic> json) {
    return StudyPlanTestTemplate(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      examId: int.tryParse(json['exam_id']?.toString() ?? '') ?? 0,
      examLevelId: int.tryParse(json['exam_level_id']?.toString() ?? '') ?? 0,
      testType: json['test_type'] as String? ?? '',
      durationMinutes: int.tryParse(json['duration_minutes']?.toString() ?? '') ?? 0,
      totalMarks: double.tryParse(json['total_marks']?.toString() ?? '0') ?? 0.0,
      negativeMarksPerQuestion: double.tryParse(json['negative_marks_per_question']?.toString() ?? '0') ?? 0.0,
      instructions: json['instructions'] as String?,
      status: json['status'] as String? ?? 'draft',
      questionCount: json['question_count'] != null ? int.tryParse(json['question_count'].toString()) : null,
    );
  }
}

class StudyPlanItemProgress {
  final int id;
  String status; // not_started, in_progress, completed
  final String? completedAt;
  final int? testAttemptId;

  StudyPlanItemProgress({
    required this.id,
    required this.status,
    this.completedAt,
    this.testAttemptId,
  });

  factory StudyPlanItemProgress.fromJson(Map<String, dynamic> json) {
    return StudyPlanItemProgress(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      status: json['status'] as String? ?? 'not_started',
      completedAt: json['completed_at'] as String?,
      testAttemptId: json['test_attempt_id'] != null ? int.tryParse(json['test_attempt_id'].toString()) : null,
    );
  }
}

class StudyPlanItem {
  final int id;
  final int planId;
  final int weekNo;
  final int dayNo;
  final int displayOrder;
  final String itemType; // reading, revision, prelims_test, csat_test, mains_test, live_lecture
  final String title;
  final String? description;
  final int? estimatedMinutes;
  final String? resourceUrl;
  final String? lectureUrl;
  final int? testTemplateId;
  final bool isPreview;
  final StudyPlanTestTemplate? testTemplate;
  StudyPlanItemProgress? progress;

  StudyPlanItem({
    required this.id,
    required this.planId,
    required this.weekNo,
    required this.dayNo,
    required this.displayOrder,
    required this.itemType,
    required this.title,
    this.description,
    this.estimatedMinutes,
    this.resourceUrl,
    this.lectureUrl,
    this.testTemplateId,
    required this.isPreview,
    this.testTemplate,
    this.progress,
  });

  factory StudyPlanItem.fromJson(Map<String, dynamic> json) {
    return StudyPlanItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      planId: int.tryParse(json['plan_id']?.toString() ?? '') ?? 0,
      weekNo: int.tryParse(json['week_no']?.toString() ?? '') ?? 1,
      dayNo: int.tryParse(json['day_no']?.toString() ?? '') ?? 1,
      displayOrder: int.tryParse(json['display_order']?.toString() ?? '') ?? 0,
      itemType: json['item_type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      estimatedMinutes: json['estimated_minutes'] != null ? int.tryParse(json['estimated_minutes'].toString()) : null,
      resourceUrl: json['resource_url'] as String?,
      lectureUrl: json['lecture_url'] as String?,
      testTemplateId: json['test_template_id'] != null ? int.tryParse(json['test_template_id'].toString()) : null,
      isPreview: json['is_preview'] as bool? ?? false,
      testTemplate: json['test_template'] != null
          ? StudyPlanTestTemplate.fromJson(json['test_template'] as Map<String, dynamic>)
          : null,
      progress: json['progress'] != null
          ? StudyPlanItemProgress.fromJson(json['progress'] as Map<String, dynamic>)
          : null,
    );
  }
}

class StudyPlanDetail {
  final StudyPlanSummary summary;
  final bool hasAccess;
  final Map<String, dynamic>? enrollment;
  final Map<String, dynamic>? progressSummary;
  final List<StudyPlanItem> items;

  StudyPlanDetail({
    required this.summary,
    required this.hasAccess,
    this.enrollment,
    this.progressSummary,
    required this.items,
  });

  factory StudyPlanDetail.fromJson(Map<String, dynamic> json) {
    var itemsList = (json['items'] as List? ?? [])
        .map((i) => StudyPlanItem.fromJson(i as Map<String, dynamic>))
        .toList();
    return StudyPlanDetail(
      summary: StudyPlanSummary.fromJson(json),
      hasAccess: json['has_access'] as bool? ?? false,
      enrollment: json['enrollment'] is Map ? Map<String, dynamic>.from(json['enrollment'] as Map) : null,
      progressSummary: json['progress_summary'] is Map
          ? Map<String, dynamic>.from(json['progress_summary'] as Map)
          : null,
      items: itemsList,
    );
  }
}

class StudyPlanQuestion {
  final int id;
  final int? testTemplateId;
  final int displayOrder;
  final String questionFamily; // objective, mains_subjective
  final String questionStatement;
  final String? supplementaryStatement;
  final String? questionPrompt;
  final List<dynamic> options;
  final dynamic correctAnswer;
  final String? explanation;
  final String? modelAnswer;
  final double marks;
  final double negativeMarks;
  final int? subjectNodeId;
  final int? topicNodeId;
  final int? subtopicNodeId;
  final int? questionNatureId;
  final Map<String, dynamic>? sourcePayload;
  StudyPlanQuestionResponse? response;

  StudyPlanQuestion({
    required this.id,
    this.testTemplateId,
    required this.displayOrder,
    required this.questionFamily,
    required this.questionStatement,
    this.supplementaryStatement,
    this.questionPrompt,
    required this.options,
    this.correctAnswer,
    this.explanation,
    this.modelAnswer,
    required this.marks,
    required this.negativeMarks,
    this.subjectNodeId,
    this.topicNodeId,
    this.subtopicNodeId,
    this.questionNatureId,
    this.sourcePayload,
    this.response,
  });

  factory StudyPlanQuestion.fromJson(Map<String, dynamic> json) {
    return StudyPlanQuestion(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      testTemplateId: json['test_template_id'] != null ? int.tryParse(json['test_template_id'].toString()) : null,
      displayOrder: int.tryParse(json['display_order']?.toString() ?? '') ?? 0,
      questionFamily: json['question_family'] as String? ?? 'objective',
      questionStatement: json['question_statement'] as String? ?? '',
      supplementaryStatement: json['supplementary_statement'] as String?,
      questionPrompt: json['question_prompt'] as String?,
      options: json['options'] as List<dynamic>? ?? [],
      correctAnswer: json['correct_answer'],
      explanation: json['explanation'] as String?,
      modelAnswer: json['model_answer'] as String?,
      marks: double.tryParse(json['marks']?.toString() ?? '0') ?? 0.0,
      negativeMarks: double.tryParse(json['negative_marks']?.toString() ?? '0') ?? 0.0,
      subjectNodeId: json['subject_node_id'] != null ? int.tryParse(json['subject_node_id'].toString()) : null,
      topicNodeId: json['topic_node_id'] != null ? int.tryParse(json['topic_node_id'].toString()) : null,
      subtopicNodeId: json['subtopic_node_id'] != null ? int.tryParse(json['subtopic_node_id'].toString()) : null,
      questionNatureId: json['question_nature_id'] != null ? int.tryParse(json['question_nature_id'].toString()) : null,
      sourcePayload: json['source_payload'] is Map ? Map<String, dynamic>.from(json['source_payload'] as Map) : null,
      response: json['response'] != null
          ? StudyPlanQuestionResponse.fromJson(json['response'] as Map<String, dynamic>)
          : null,
    );
  }
}

class StudyPlanQuestionResponse {
  final int id;
  dynamic selectedAnswer;
  final String? answerText;
  String status; // not_visited, answered, skipped, marked_for_review
  bool isMarkedForReview;

  StudyPlanQuestionResponse({
    required this.id,
    this.selectedAnswer,
    this.answerText,
    required this.status,
    required this.isMarkedForReview,
  });

  factory StudyPlanQuestionResponse.fromJson(Map<String, dynamic> json) {
    return StudyPlanQuestionResponse(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      selectedAnswer: json['selected_answer'],
      answerText: json['answer_text'] as String?,
      status: json['status'] as String? ?? 'not_visited',
      isMarkedForReview: json['is_marked_for_review'] as bool? ?? false,
    );
  }
}

class StudyPlanAttemptPaper {
  final int id;
  final String status; // in_progress, submitted, expired, cancelled
  final String startedAt;
  final String? submittedAt;
  final String? expiresAt;
  final int timeSpentSeconds;
  final StudyPlanTestTemplate testTemplate;
  final Map<String, dynamic>? result;
  final List<StudyPlanQuestion> questions;

  StudyPlanAttemptPaper({
    required this.id,
    required this.status,
    required this.startedAt,
    this.submittedAt,
    this.expiresAt,
    required this.timeSpentSeconds,
    required this.testTemplate,
    this.result,
    required this.questions,
  });

  factory StudyPlanAttemptPaper.fromJson(Map<String, dynamic> json) {
    var questionList = (json['questions'] as List? ?? [])
        .map((q) => StudyPlanQuestion.fromJson(q as Map<String, dynamic>))
        .toList();
    return StudyPlanAttemptPaper(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      status: json['status'] as String? ?? 'in_progress',
      startedAt: json['started_at'] as String? ?? '',
      submittedAt: json['submitted_at'] as String?,
      expiresAt: json['expires_at'] as String?,
      timeSpentSeconds: int.tryParse(json['time_spent_seconds']?.toString() ?? '') ?? 0,
      testTemplate: StudyPlanTestTemplate.fromJson(json['test_template'] as Map<String, dynamic>? ?? {}),
      result: json['result'] is Map ? Map<String, dynamic>.from(json['result'] as Map) : null,
      questions: questionList,
    );
  }
}

