import 'dart:convert';

class Exam {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final bool isActive;

  Exam({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.isActive,
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? false,
    );
  }
}

class ExamLevel {
  final int id;
  final int examId;
  final String name;
  final String slug;
  final int displayOrder;
  final bool isActive;

  ExamLevel({
    required this.id,
    required this.examId,
    required this.name,
    required this.slug,
    required this.displayOrder,
    required this.isActive,
  });

  factory ExamLevel.fromJson(Map<String, dynamic> json) {
    return ExamLevel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      examId: int.tryParse(json['exam_id']?.toString() ?? '') ?? 0,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      displayOrder: int.tryParse(json['display_order']?.toString() ?? '') ?? 0,
      isActive: json['is_active'] as bool? ?? false,
    );
  }
}

class AssessmentTestTemplate {
  final int id;
  final String title;
  final String slug;
  final String? description;
  final int examId;
  final int examLevelId;
  final String
  testType; // quick_test, sectional_test, full_length_test, pyq_test, mains_test
  final int durationMinutes;
  final double totalMarks;
  final String accessType; // free, subscription, paid, private
  final String status;
  final int? questionCount;
  final String? publishedAt;
  final String createdAt;
  final String updatedAt;
  final int? createdByUserId;

  AssessmentTestTemplate({
    required this.id,
    required this.title,
    required this.slug,
    this.description,
    required this.examId,
    required this.examLevelId,
    required this.testType,
    required this.durationMinutes,
    required this.totalMarks,
    required this.accessType,
    required this.status,
    this.questionCount,
    this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
    this.createdByUserId,
  });

  factory AssessmentTestTemplate.fromJson(Map<String, dynamic> json) {
    return AssessmentTestTemplate(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      examId: int.tryParse(json['exam_id']?.toString() ?? '') ?? 0,
      examLevelId: int.tryParse(json['exam_level_id']?.toString() ?? '') ?? 0,
      testType: json['test_type'] as String? ?? '',
      durationMinutes:
          int.tryParse(json['duration_minutes']?.toString() ?? '') ?? 0,
      totalMarks:
          double.tryParse(json['total_marks']?.toString() ?? '0') ?? 0.0,
      accessType: json['access_type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      questionCount: json['question_count'] != null
          ? int.tryParse(json['question_count'].toString())
          : null,
      publishedAt: json['published_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      createdByUserId: json['created_by_user_id'] != null
          ? int.tryParse(json['created_by_user_id'].toString())
          : null,
    );
  }
}

class TestSection {
  final int id;
  final String title;
  final int displayOrder;
  final int? durationMinutes;
  final String? instructions;

  TestSection({
    required this.id,
    required this.title,
    required this.displayOrder,
    this.durationMinutes,
    this.instructions,
  });

  factory TestSection.fromJson(Map<String, dynamic> json) {
    return TestSection(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title'] as String? ?? '',
      displayOrder: int.tryParse(json['display_order']?.toString() ?? '') ?? 0,
      durationMinutes: json['duration_minutes'] != null
          ? int.tryParse(json['duration_minutes'].toString())
          : null,
      instructions: json['instructions'] as String?,
    );
  }
}

class QuestionFormat {
  final int id;
  final String name;
  final String slug;
  final String questionFamily;

  QuestionFormat({
    required this.id,
    required this.name,
    required this.slug,
    required this.questionFamily,
  });

  factory QuestionFormat.fromJson(Map<String, dynamic> json) {
    return QuestionFormat(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      questionFamily: json['question_family'] as String? ?? '',
    );
  }
}

class QuestionVersion {
  final int id;
  final int questionId;
  final String questionStatement;
  final String? supplementaryStatement;
  final List<dynamic> statementsFacts;
  final String? questionPrompt;
  final List<dynamic> options;
  final Map<String, dynamic> contentJson;
  final dynamic correctAnswer;
  final String? explanation;
  final int? createdByUserId;
  final bool? isAiGenerated;

  QuestionVersion({
    required this.id,
    required this.questionId,
    required this.questionStatement,
    this.supplementaryStatement,
    required this.statementsFacts,
    this.questionPrompt,
    required this.options,
    required this.contentJson,
    this.correctAnswer,
    this.explanation,
    this.createdByUserId,
    this.isAiGenerated,
  });

  factory QuestionVersion.fromJson(Map<String, dynamic> json) {
    return QuestionVersion(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      questionId: int.tryParse(json['question_id']?.toString() ?? '') ?? 0,
      questionStatement: json['question_statement'] as String? ?? '',
      supplementaryStatement: json['supplementary_statement'] as String?,
      statementsFacts: json['statements_facts'] as List<dynamic>? ?? [],
      questionPrompt: json['question_prompt'] as String?,
      options: json['options'] as List<dynamic>? ?? [],
      contentJson: json['content_json'] is Map
          ? Map<String, dynamic>.from(json['content_json'] as Map)
          : {},
      correctAnswer: json['correct_answer'],
      explanation: json['explanation'] as String?,
      createdByUserId: json['created_by_user_id'] != null
          ? int.tryParse(json['created_by_user_id'].toString())
          : null,
      isAiGenerated: json['is_ai_generated'] is bool
          ? json['is_ai_generated'] as bool
          : (json['is_ai_generated']?.toString() == 'true' || json['is_ai_generated']?.toString() == '1'),
    );
  }
}

class TestQuestionItem {
  final int id;
  final int? testSectionId;
  final int questionVersionId;
  final double marks;
  final double negativeMarks;
  final int displayOrder;
  final QuestionFormat questionFormat;
  final QuestionVersion questionVersion;
  final Map<String, dynamic>? passage;
  AttemptResponse? response;
  Map<String, dynamic>? scoreItem;

  TestQuestionItem({
    required this.id,
    this.testSectionId,
    required this.questionVersionId,
    required this.marks,
    required this.negativeMarks,
    required this.displayOrder,
    required this.questionFormat,
    required this.questionVersion,
    this.passage,
    this.response,
    this.scoreItem,
  });

  factory TestQuestionItem.fromJson(Map<String, dynamic> json) {
    return TestQuestionItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      testSectionId: json['test_section_id'] != null
          ? int.tryParse(json['test_section_id'].toString())
          : null,
      questionVersionId:
          int.tryParse(json['question_version_id']?.toString() ?? '') ?? 0,
      marks: double.tryParse(json['marks']?.toString() ?? '0') ?? 0.0,
      negativeMarks:
          double.tryParse(json['negative_marks']?.toString() ?? '0') ?? 0.0,
      displayOrder: int.tryParse(json['display_order']?.toString() ?? '') ?? 0,
      questionFormat: QuestionFormat.fromJson(
        json['question_format'] as Map<String, dynamic>? ?? {},
      ),
      questionVersion: QuestionVersion.fromJson(
        json['question_version'] as Map<String, dynamic>? ?? {},
      ),
      passage: json['passage'] is Map
          ? Map<String, dynamic>.from(json['passage'] as Map)
          : null,
      response: json['response'] != null
          ? AttemptResponse.fromJson(json['response'] as Map<String, dynamic>)
          : null,
      scoreItem: json['score_item'] is Map
          ? Map<String, dynamic>.from(json['score_item'] as Map)
          : null,
    );
  }
}

class AttemptResponse {
  final int id;
  final int questionVersionId;
  dynamic selectedAnswer;
  final String? answerText;
  String status; // not_visited, answered, skipped, marked_for_review
  bool isMarkedForReview;
  int timeSpentSeconds;
  final String? answeredAt;

  // Subjective evaluation fields
  final String? evaluationStatus;
  final double? score;
  final double? maxScore;
  final String? feedback;
  final String? checkedCopyUrl;
  final List<String>? strengths;
  final List<String>? weaknesses;
  final String? studentAnswerText;
  final String? answerFileUrl;

  AttemptResponse({
    required this.id,
    required this.questionVersionId,
    this.selectedAnswer,
    this.answerText,
    required this.status,
    required this.isMarkedForReview,
    required this.timeSpentSeconds,
    this.answeredAt,
    this.evaluationStatus,
    this.score,
    this.maxScore,
    this.feedback,
    this.checkedCopyUrl,
    this.strengths,
    this.weaknesses,
    this.studentAnswerText,
    this.answerFileUrl,
  });

  factory AttemptResponse.fromJson(Map<String, dynamic> json) {
    List<String>? parseList(dynamic val) {
      if (val == null) return null;
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      if (val is String) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is List) {
            return decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
      return null;
    }

    return AttemptResponse(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      questionVersionId:
          int.tryParse(json['question_version_id']?.toString() ?? '') ?? 0,
      selectedAnswer: json['selected_answer'],
      answerText: json['answer_text'] as String?,
      status: json['status'] as String? ?? 'not_visited',
      isMarkedForReview: json['is_marked_for_review'] as bool? ?? false,
      timeSpentSeconds:
          int.tryParse(json['time_spent_seconds']?.toString() ?? '') ?? 0,
      answeredAt: json['answered_at'] as String?,
      evaluationStatus: json['evaluation_status'] as String?,
      score: json['score'] != null ? double.tryParse(json['score'].toString()) : null,
      maxScore: json['max_score'] != null ? double.tryParse(json['max_score'].toString()) : null,
      feedback: json['feedback'] as String?,
      checkedCopyUrl: json['checked_copy_url'] as String?,
      strengths: parseList(json['strengths']),
      weaknesses: parseList(json['weaknesses']),
      studentAnswerText: json['student_answer_text'] as String?,
      answerFileUrl: json['answer_file_url'] as String?,
    );
  }
}

class AttemptPaper {
  final int id;
  final int userId;
  final int testTemplateId;
  final String status; // in_progress, submitted, expired, cancelled
  final String startedAt;
  final String? submittedAt;
  final String? expiresAt;
  final int timeSpentSeconds;
  final AssessmentTestTemplate testTemplate;
  final List<TestSection> sections;
  final List<TestQuestionItem> questions;
  final AssessmentResult? result;

  AttemptPaper({
    required this.id,
    required this.userId,
    required this.testTemplateId,
    required this.status,
    required this.startedAt,
    this.submittedAt,
    this.expiresAt,
    required this.timeSpentSeconds,
    required this.testTemplate,
    required this.sections,
    required this.questions,
    this.result,
  });

  factory AttemptPaper.fromJson(Map<String, dynamic> json) {
    var sectionList = (json['sections'] as List? ?? [])
        .map((s) => TestSection.fromJson(s as Map<String, dynamic>))
        .toList();
    var questionList = (json['questions'] as List? ?? [])
        .map((q) => TestQuestionItem.fromJson(q as Map<String, dynamic>))
        .toList();

    return AttemptPaper(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      userId: int.tryParse(json['user_id']?.toString() ?? '') ?? 0,
      testTemplateId:
          int.tryParse(json['test_template_id']?.toString() ?? '') ?? 0,
      status: json['status'] as String? ?? 'in_progress',
      startedAt: json['started_at'] as String? ?? '',
      submittedAt: json['submitted_at'] as String?,
      expiresAt: json['expires_at'] as String?,
      timeSpentSeconds:
          int.tryParse(json['time_spent_seconds']?.toString() ?? '') ?? 0,
      testTemplate: AssessmentTestTemplate.fromJson(
        json['test_template'] as Map<String, dynamic>? ?? {},
      ),
      sections: sectionList,
      questions: questionList,
      result: json['result'] != null
          ? AssessmentResult.fromJson(json['result'] as Map<String, dynamic>)
          : null,
    );
  }
}

class AssessmentResult {
  final int id;
  final int attemptId;
  final double score;
  final double maxScore;
  final double accuracy;
  final int totalQuestions;
  final int correctCount;
  final int incorrectCount;
  final int unattemptedCount;
  final double negativeMarks;
  final Map<String, dynamic> rankSnapshot;
  final double? percentileSnapshot;
  final String? cutoffStatus;
  final String createdAt;

  AssessmentResult({
    required this.id,
    required this.attemptId,
    required this.score,
    required this.maxScore,
    required this.accuracy,
    required this.totalQuestions,
    required this.correctCount,
    required this.incorrectCount,
    required this.unattemptedCount,
    required this.negativeMarks,
    required this.rankSnapshot,
    this.percentileSnapshot,
    this.cutoffStatus,
    required this.createdAt,
  });

  factory AssessmentResult.fromJson(Map<String, dynamic> json) {
    return AssessmentResult(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      attemptId: int.tryParse(json['attempt_id']?.toString() ?? '') ?? 0,
      score: double.tryParse(json['score']?.toString() ?? '0') ?? 0.0,
      maxScore: double.tryParse(json['max_score']?.toString() ?? '0') ?? 0.0,
      accuracy: double.tryParse(json['accuracy']?.toString() ?? '0') ?? 0.0,
      totalQuestions:
          int.tryParse(json['total_questions']?.toString() ?? '') ?? 0,
      correctCount: int.tryParse(json['correct_count']?.toString() ?? '') ?? 0,
      incorrectCount:
          int.tryParse(json['incorrect_count']?.toString() ?? '') ?? 0,
      unattemptedCount:
          int.tryParse(json['unattempted_count']?.toString() ?? '') ?? 0,
      negativeMarks:
          double.tryParse(json['negative_marks']?.toString() ?? '0') ?? 0.0,
      rankSnapshot: json['rank_snapshot'] is Map
          ? Map<String, dynamic>.from(json['rank_snapshot'] as Map)
          : {},
      percentileSnapshot: double.tryParse(
        json['percentile_snapshot']?.toString() ?? '',
      ),
      cutoffStatus: json['cutoff_status'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class ResultReview {
  final AssessmentResult result;
  final AttemptPaper attempt;
  final AssessmentTestTemplate testTemplate;
  final List<TestQuestionItem> questions;
  final List<TopicBreakdown>? topicBreakdowns;

  ResultReview({
    required this.result,
    required this.attempt,
    required this.testTemplate,
    required this.questions,
    this.topicBreakdowns,
  });

  factory ResultReview.fromJson(Map<String, dynamic> json) {
    var questionList = (json['questions'] as List? ?? [])
        .map((q) => TestQuestionItem.fromJson(q as Map<String, dynamic>))
        .toList();
    var breakdowns = (json['topic_breakdowns'] as List? ?? [])
        .map((t) => TopicBreakdown.fromJson(t as Map<String, dynamic>))
        .toList();

    return ResultReview(
      result: AssessmentResult.fromJson(json),
      attempt: AttemptPaper.fromJson(
        json['attempt'] as Map<String, dynamic>? ?? {},
      ),
      testTemplate: AssessmentTestTemplate.fromJson(
        json['test_template'] as Map<String, dynamic>? ?? {},
      ),
      questions: questionList,
      topicBreakdowns: breakdowns,
    );
  }
}

class TopicBreakdown {
  final int? id;
  final int? taxonomyNodeId;
  final String? taxonomyName;
  final String? questionNatureName;
  final int totalQuestions;
  final int correctCount;
  final int incorrectCount;
  final int unattemptedCount;
  final double score;
  final double accuracy;
  final double avgTimeSeconds;

  TopicBreakdown({
    this.id,
    this.taxonomyNodeId,
    this.taxonomyName,
    this.questionNatureName,
    required this.totalQuestions,
    required this.correctCount,
    required this.incorrectCount,
    required this.unattemptedCount,
    required this.score,
    required this.accuracy,
    required this.avgTimeSeconds,
  });

  factory TopicBreakdown.fromJson(Map<String, dynamic> json) {
    return TopicBreakdown(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      taxonomyNodeId: json['taxonomy_node_id'] != null
          ? int.tryParse(json['taxonomy_node_id'].toString())
          : null,
      taxonomyName: json['taxonomy_name'] as String?,
      questionNatureName: json['question_nature_name'] as String?,
      totalQuestions:
          int.tryParse(json['total_questions']?.toString() ?? '') ?? 0,
      correctCount: int.tryParse(json['correct_count']?.toString() ?? '') ?? 0,
      incorrectCount:
          int.tryParse(json['incorrect_count']?.toString() ?? '') ?? 0,
      unattemptedCount:
          int.tryParse(json['unattempted_count']?.toString() ?? '') ?? 0,
      score: double.tryParse(json['score']?.toString() ?? '0') ?? 0.0,
      accuracy: double.tryParse(json['accuracy']?.toString() ?? '0') ?? 0.0,
      avgTimeSeconds:
          double.tryParse(json['avg_time_seconds']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class StudentAttemptSummary {
  final int id;
  final int testTemplateId;
  final String status;
  final String startedAt;
  final String? submittedAt;
  final String? expiresAt;
  final int timeSpentSeconds;
  final AssessmentTestTemplate testTemplate;
  final AssessmentResult? result;

  StudentAttemptSummary({
    required this.id,
    required this.testTemplateId,
    required this.status,
    required this.startedAt,
    this.submittedAt,
    this.expiresAt,
    required this.timeSpentSeconds,
    required this.testTemplate,
    this.result,
  });

  factory StudentAttemptSummary.fromJson(Map<String, dynamic> json) {
    return StudentAttemptSummary(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      testTemplateId:
          int.tryParse(json['test_template_id']?.toString() ?? '') ?? 0,
      status: json['status'] as String? ?? '',
      startedAt: json['started_at'] as String? ?? '',
      submittedAt: json['submitted_at'] as String?,
      expiresAt: json['expires_at'] as String?,
      timeSpentSeconds:
          int.tryParse(json['time_spent_seconds']?.toString() ?? '') ?? 0,
      testTemplate: AssessmentTestTemplate.fromJson(
        json['test_template'] as Map<String, dynamic>? ?? {},
      ),
      result: json['result'] != null
          ? AssessmentResult.fromJson(json['result'] as Map<String, dynamic>)
          : null,
    );
  }
}

class AssessmentDashboardResponse {
  final AssessmentDashboard gk;
  final AssessmentDashboard aptitude;
  final MainsDashboard mains;

  AssessmentDashboardResponse({
    required this.gk,
    required this.aptitude,
    required this.mains,
  });

  factory AssessmentDashboardResponse.fromJson(Map<String, dynamic> json) {
    return AssessmentDashboardResponse(
      gk: AssessmentDashboard.fromJson(
        json['gk'] as Map<String, dynamic>? ?? {},
      ),
      aptitude: AssessmentDashboard.fromJson(
        json['aptitude'] as Map<String, dynamic>? ?? {},
      ),
      mains: MainsDashboard.fromJson(
        json['mains'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class AssessmentDashboard {
  final int attemptsCount;
  final double avgScore;
  final double avgAccuracy;
  final int totalCorrect;
  final int totalIncorrect;
  final int totalUnattempted;
  final List<WeakTopic> weakTopics;
  final List<WeakTopic> strongTopics;
  final List<TrendPoint> trend;

  AssessmentDashboard({
    required this.attemptsCount,
    required this.avgScore,
    required this.avgAccuracy,
    required this.totalCorrect,
    required this.totalIncorrect,
    required this.totalUnattempted,
    required this.weakTopics,
    required this.strongTopics,
    required this.trend,
  });

  factory AssessmentDashboard.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    final weakList = (json['weak_topics'] as List? ?? [])
        .map((w) => WeakTopic.fromJson(w as Map<String, dynamic>))
        .toList();
    final strongList = (json['strong_topics'] as List? ?? [])
        .map((w) => WeakTopic.fromJson(w as Map<String, dynamic>))
        .toList();
    final trendList = (json['trend'] as List? ?? [])
        .map((t) => TrendPoint.fromJson(t as Map<String, dynamic>))
        .toList();

    return AssessmentDashboard(
      attemptsCount: int.tryParse(summary['attempts']?.toString() ?? '') ?? 0,
      avgScore: double.tryParse(summary['avg_score']?.toString() ?? '0') ?? 0.0,
      avgAccuracy:
          double.tryParse(summary['avg_accuracy']?.toString() ?? '0') ?? 0.0,
      totalCorrect:
          int.tryParse(summary['correct_count']?.toString() ?? '') ?? 0,
      totalIncorrect:
          int.tryParse(summary['incorrect_count']?.toString() ?? '') ?? 0,
      totalUnattempted:
          int.tryParse(summary['unattempted_count']?.toString() ?? '') ?? 0,
      weakTopics: weakList,
      strongTopics: strongList,
      trend: trendList,
    );
  }
}

class MainsDashboard {
  final int attemptsCount;
  final double avgScore;
  final double maxScore;
  final double totalScore;
  final double totalMaxScore;
  final int evaluatedCount;
  final int pendingCount;
  final List<WeakTopic> weakTopics;
  final List<WeakTopic> strongTopics;
  final List<TrendPoint> trend;
  final List<MainsCategoryTrend> categoryTrends;
  final List<MainsMistake> consistentMistakes;

  MainsDashboard({
    required this.attemptsCount,
    required this.avgScore,
    required this.maxScore,
    required this.totalScore,
    required this.totalMaxScore,
    required this.evaluatedCount,
    required this.pendingCount,
    required this.weakTopics,
    required this.strongTopics,
    required this.trend,
    required this.categoryTrends,
    required this.consistentMistakes,
  });

  factory MainsDashboard.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    final weakList = (json['weak_topics'] as List? ?? [])
        .map((w) => WeakTopic.fromJson(w as Map<String, dynamic>))
        .toList();
    final strongList = (json['strong_topics'] as List? ?? [])
        .map((w) => WeakTopic.fromJson(w as Map<String, dynamic>))
        .toList();
    final trendList = (json['trend'] as List? ?? [])
        .map((t) => TrendPoint.fromJson(t as Map<String, dynamic>))
        .toList();
    final categoryTrendList = (json['category_trends'] as List? ?? [])
        .map((t) => MainsCategoryTrend.fromJson(t as Map<String, dynamic>))
        .toList();
    final mistakeList = (json['consistent_mistakes'] as List? ?? [])
        .map((m) => MainsMistake.fromJson(m as Map<String, dynamic>))
        .toList();

    return MainsDashboard(
      attemptsCount: int.tryParse(summary['attempts']?.toString() ?? '') ?? 0,
      avgScore: double.tryParse(summary['avg_score']?.toString() ?? '0') ?? 0.0,
      maxScore: double.tryParse(summary['max_score']?.toString() ?? '0') ?? 0.0,
      totalScore: double.tryParse(summary['total_score']?.toString() ?? '0') ?? 0.0,
      totalMaxScore: double.tryParse(summary['total_max_score']?.toString() ?? '0') ?? 0.0,
      evaluatedCount:
          int.tryParse(summary['evaluated_count']?.toString() ?? '') ?? 0,
      pendingCount:
          int.tryParse(summary['pending_count']?.toString() ?? '') ?? 0,
      weakTopics: weakList,
      strongTopics: strongList,
      trend: trendList,
      categoryTrends: categoryTrendList,
      consistentMistakes: mistakeList,
    );
  }
}

class MainsCategoryTrend {
  final int categoryId;
  final String categoryName;
  final String nodeType;
  final int attempts;
  final double avgScore;
  final double avgMaxScore;
  final double avgScoreRatio;
  final double latestScore;
  final double latestMaxScore;
  final String? lastEvaluatedAt;
  final List<TrendPoint> trend;

  MainsCategoryTrend({
    required this.categoryId,
    required this.categoryName,
    required this.nodeType,
    required this.attempts,
    required this.avgScore,
    required this.avgMaxScore,
    required this.avgScoreRatio,
    required this.latestScore,
    required this.latestMaxScore,
    this.lastEvaluatedAt,
    required this.trend,
  });

  factory MainsCategoryTrend.fromJson(Map<String, dynamic> json) {
    return MainsCategoryTrend(
      categoryId: int.tryParse(json['category_id']?.toString() ?? '') ?? 0,
      categoryName: json['category_name'] as String? ?? 'Unmapped category',
      nodeType: json['node_type'] as String? ?? 'category',
      attempts: int.tryParse(json['attempts']?.toString() ?? '') ?? 0,
      avgScore: double.tryParse(json['avg_score']?.toString() ?? '0') ?? 0.0,
      avgMaxScore:
          double.tryParse(json['avg_max_score']?.toString() ?? '0') ?? 0.0,
      avgScoreRatio:
          double.tryParse(json['avg_score_ratio']?.toString() ?? '0') ?? 0.0,
      latestScore:
          double.tryParse(json['latest_score']?.toString() ?? '0') ?? 0.0,
      latestMaxScore:
          double.tryParse(json['latest_max_score']?.toString() ?? '0') ?? 0.0,
      lastEvaluatedAt: json['last_evaluated_at'] as String?,
      trend: (json['trend'] as List? ?? [])
          .map((t) => TrendPoint.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MainsMistake {
  final String mistake;
  final int occurrenceCount;
  final int answerCount;
  final double avgScore;
  final double avgMaxScore;
  final double avgScoreRatio;
  final String? lastSeenAt;
  final List<String> categories;

  MainsMistake({
    required this.mistake,
    required this.occurrenceCount,
    required this.answerCount,
    required this.avgScore,
    required this.avgMaxScore,
    required this.avgScoreRatio,
    this.lastSeenAt,
    required this.categories,
  });

  factory MainsMistake.fromJson(Map<String, dynamic> json) {
    return MainsMistake(
      mistake: json['mistake'] as String? ?? '',
      occurrenceCount:
          int.tryParse(json['occurrence_count']?.toString() ?? '') ?? 0,
      answerCount: int.tryParse(json['answer_count']?.toString() ?? '') ?? 0,
      avgScore: double.tryParse(json['avg_score']?.toString() ?? '0') ?? 0.0,
      avgMaxScore:
          double.tryParse(json['avg_max_score']?.toString() ?? '0') ?? 0.0,
      avgScoreRatio:
          double.tryParse(json['avg_score_ratio']?.toString() ?? '0') ?? 0.0,
      lastSeenAt: json['last_seen_at'] as String?,
      categories: (json['categories'] as List? ?? [])
          .whereType<String>()
          .toList(),
    );
  }
}

class WeakTopic {
  final String? taxonomyName;
  final String? questionNature;
  final int questionCount;
  final double avgAccuracy;
  final double avgScore;

  WeakTopic({
    this.taxonomyName,
    this.questionNature,
    required this.questionCount,
    required this.avgAccuracy,
    required this.avgScore,
  });

  factory WeakTopic.fromJson(Map<String, dynamic> json) {
    return WeakTopic(
      taxonomyName: json['taxonomy_name'] as String?,
      questionNature: json['question_nature'] as String?,
      questionCount:
          int.tryParse(json['question_count']?.toString() ?? '') ?? 0,
      avgAccuracy:
          double.tryParse(json['avg_accuracy']?.toString() ?? '0') ?? 0.0,
      avgScore: double.tryParse(json['avg_score']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class TrendPoint {
  final String resultDate;
  final double avgScore;
  final double avgAccuracy;
  final int attempts;

  TrendPoint({
    required this.resultDate,
    required this.avgScore,
    required this.avgAccuracy,
    required this.attempts,
  });

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      resultDate: json['result_date'] as String? ?? '',
      avgScore: double.tryParse(json['avg_score']?.toString() ?? '0') ?? 0.0,
      avgAccuracy:
          double.tryParse(json['avg_accuracy']?.toString() ?? '0') ?? 0.0,
      attempts: int.tryParse(json['attempts']?.toString() ?? '') ?? 0,
    );
  }
}

class TestSeries {
  final int id;
  final String title;
  final String slug;
  final String? description;
  final int examId;
  final String? coverImageUrl;
  final String accessType;
  final String status;
  final int? itemCount;
  final String? publishedAt;
  final String createdAt;
  final String updatedAt;

  TestSeries({
    required this.id,
    required this.title,
    required this.slug,
    this.description,
    required this.examId,
    this.coverImageUrl,
    required this.accessType,
    required this.status,
    this.itemCount,
    this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TestSeries.fromJson(Map<String, dynamic> json) {
    return TestSeries(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      examId: int.tryParse(json['exam_id']?.toString() ?? '') ?? 0,
      coverImageUrl: json['cover_image_url'] as String?,
      accessType: json['access_type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      itemCount: json['item_count'] != null
          ? int.tryParse(json['item_count'].toString())
          : null,
      publishedAt: json['published_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

class TestSeriesDetail {
  final TestSeries testSeries;
  final List<TestSeriesItem> items;

  TestSeriesDetail({required this.testSeries, required this.items});

  factory TestSeriesDetail.fromJson(Map<String, dynamic> json) {
    var itemList = (json['items'] as List? ?? [])
        .map((i) => TestSeriesItem.fromJson(i as Map<String, dynamic>))
        .toList();
    return TestSeriesDetail(
      testSeries: TestSeries.fromJson(json),
      items: itemList,
    );
  }
}

class TestSeriesItem {
  final int id;
  final int testTemplateId;
  final int displayOrder;
  final String? scheduledAt;
  final String? unlockAt;
  final AssessmentTestTemplate testTemplate;

  TestSeriesItem({
    required this.id,
    required this.testTemplateId,
    required this.displayOrder,
    this.scheduledAt,
    this.unlockAt,
    required this.testTemplate,
  });

  factory TestSeriesItem.fromJson(Map<String, dynamic> json) {
    return TestSeriesItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      testTemplateId:
          int.tryParse(json['test_template_id']?.toString() ?? '') ?? 0,
      displayOrder: int.tryParse(json['display_order']?.toString() ?? '') ?? 0,
      scheduledAt: json['scheduled_at'] as String?,
      unlockAt: json['unlock_at'] as String?,
      testTemplate: AssessmentTestTemplate.fromJson(
        json['test_template'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class Question {
  final int id;
  final String questionFamily;
  final QuestionVersionModel currentVersion;
  final int subjectNodeId;
  final int? topicNodeId;
  final int? subtopicNodeId;
  final bool isUsed;
  final Map<String, dynamic>? mainsDetails;

  Question({
    required this.id,
    required this.questionFamily,
    required this.currentVersion,
    required this.subjectNodeId,
    this.topicNodeId,
    this.subtopicNodeId,
    required this.isUsed,
    this.mainsDetails,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      questionFamily: json['question_family'] as String? ?? '',
      currentVersion: QuestionVersionModel.fromJson(
        json['current_version'] as Map<String, dynamic>? ?? {},
      ),
      subjectNodeId: int.tryParse(json['subject_node_id']?.toString() ?? '') ?? 0,
      topicNodeId: json['topic_node_id'] != null ? int.tryParse(json['topic_node_id'].toString()) : null,
      subtopicNodeId: json['subtopic_node_id'] != null ? int.tryParse(json['subtopic_node_id'].toString()) : null,
      isUsed: json['is_used'] as bool? ?? false,
      mainsDetails: json['mains_details'] as Map<String, dynamic>?,
    );
  }
}

class QuestionVersionModel {
  final String questionStatement;
  final List<QuestionOption> options;
  final String? correctAnswer;
  final String? explanation;

  QuestionVersionModel({
    required this.questionStatement,
    required this.options,
    this.correctAnswer,
    this.explanation,
  });

  factory QuestionVersionModel.fromJson(Map<String, dynamic> json) {
    var optList = (json['options'] as List? ?? [])
        .map((o) => QuestionOption.fromJson(o as Map<String, dynamic>))
        .toList();
    
    String? correctKey;
    if (json['correct_answer'] != null) {
      if (json['correct_answer'] is Map) {
        correctKey = json['correct_answer']['key'] as String?;
      } else if (json['correct_answer'] is String) {
        correctKey = json['correct_answer'] as String;
      }
    }

    return QuestionVersionModel(
      questionStatement: json['question_statement'] as String? ?? '',
      options: optList,
      correctAnswer: correctKey,
      explanation: json['explanation'] as String?,
    );
  }
}

class QuestionOption {
  final String key;
  final String text;

  QuestionOption({required this.key, required this.text});

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      key: json['key'] as String? ?? json['label'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }
}

class ParsedQuestion {
  final String questionStatement;
  final String? suppQuestionStatement;
  final String? questionPrompt;
  final List<QuestionOption> options;
  final String correctAnswer;
  final String? explanation;
  final int? questionNatureId;
  final int? wordLimit;
  final double? marks;
  final String? directive;

  ParsedQuestion({
    required this.questionStatement,
    this.suppQuestionStatement,
    this.questionPrompt,
    required this.options,
    required this.correctAnswer,
    this.explanation,
    this.questionNatureId,
    this.wordLimit,
    this.marks,
    this.directive,
  });

  factory ParsedQuestion.fromJson(Map<String, dynamic> json) {
    var optList = (json['options'] as List? ?? [])
        .map((o) => QuestionOption.fromJson(o as Map<String, dynamic>))
        .toList();
    
    double? parsedMarks;
    if (json['marks'] != null) {
      parsedMarks = double.tryParse(json['marks'].toString());
    }

    int? parsedWordLimit;
    if (json['word_limit'] != null) {
      parsedWordLimit = int.tryParse(json['word_limit'].toString());
    }

    return ParsedQuestion(
      questionStatement: json['question_statement'] as String? ?? '',
      suppQuestionStatement: json['supp_question_statement'] as String?,
      questionPrompt: json['question_prompt'] as String?,
      options: optList,
      correctAnswer: json['correct_answer'] as String? ?? '',
      explanation: json['explanation'] as String?,
      questionNatureId: json['question_nature_id'] != null
          ? int.tryParse(json['question_nature_id'].toString())
          : null,
      wordLimit: parsedWordLimit,
      marks: parsedMarks,
      directive: json['directive'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_statement': questionStatement,
      if (suppQuestionStatement != null) 'supp_question_statement': suppQuestionStatement,
      if (questionPrompt != null) 'question_prompt': questionPrompt,
      'options': options.map((o) => {'key': o.key, 'text': o.text}).toList(),
      'correct_answer': correctAnswer,
      if (explanation != null) 'explanation': explanation,
      if (questionNatureId != null) 'question_nature_id': questionNatureId,
      if (wordLimit != null) 'word_limit': wordLimit,
      if (marks != null) 'marks': marks,
      if (directive != null) 'directive': directive,
    };
  }
}

class ParsedResult {
  final bool success;
  final String? passageTitle;
  final String? passageText;
  final List<ParsedQuestion> questions;

  ParsedResult({
    required this.success,
    this.passageTitle,
    this.passageText,
    required this.questions,
  });

  factory ParsedResult.fromJson(Map<String, dynamic> json) {
    var qList = (json['questions'] as List? ?? [])
        .map((q) => ParsedQuestion.fromJson(q as Map<String, dynamic>))
        .toList();
    return ParsedResult(
      success: json['success'] as bool? ?? false,
      passageTitle: json['passage_title'] as String?,
      passageText: json['passage_text'] as String?,
      questions: qList,
    );
  }
}

