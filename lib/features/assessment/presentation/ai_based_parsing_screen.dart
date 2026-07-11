import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/assessment_service.dart';
import '../models/assessment_models.dart';

class AiBasedParsingScreen extends StatefulWidget {
  final int? testTemplateId;
  final String? contentType;
  final int? categoryNodeId;
  const AiBasedParsingScreen({super.key, this.testTemplateId, this.contentType, this.categoryNodeId});

  @override
  State<AiBasedParsingScreen> createState() => _AiBasedParsingScreenState();
}

class _AiBasedParsingScreenState extends State<AiBasedParsingScreen> {
  late AssessmentService _service;

  // Configuration States
  bool _loadingExams = true;
  String? _error;
  String? _successMessage;

  List<Exam> _exams = [];
  int? _selectedExamId;
  List<ExamLevel> _levels = [];
  int? _selectedLevelId;

  // Taxonomy states
  List<Map<String, dynamic>> _nodes = [];
  List<Map<String, dynamic>> _subjects = [];
  int? _selectedSubjectId;
  List<Map<String, dynamic>> _topics = [];
  int? _selectedTopicId;

  // Input states
  String _parseMode = 'file'; // file or text
  late String _contentType; // gk, aptitude, or mains
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  PlatformFile? _selectedFile;
  List<PlatformFile> _selectedImages = [];

  // Target Test States
  int? _testTemplateId;
  bool _loadingTemplates = false;
  List<AssessmentTestTemplate> _privateTemplates = [];
  int? _selectedTemplateId; // null means "Create New Custom Test"
  final TextEditingController _newTestTitleController = TextEditingController();
  bool _isTemplateLocked = false;
  String? _lockedTemplateTitle;

  // Output/Results states
  bool _parsing = false;
  bool _saving = false;
  ParsedResult? _parsedResult;
  final Map<int, String> _selectedAnswers = {};

  @override
  void initState() {
    super.initState();
    _contentType = widget.contentType ?? 'gk';
    _testTemplateId = widget.testTemplateId;
    if (_testTemplateId != null) {
      _isTemplateLocked = true;
    }
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = AssessmentService(apiClient: apiClient);
    _fetchExams();
    _fetchPrivateTemplates();
  }

  @override
  void dispose() {
    _textController.dispose();
    _instructionsController.dispose();
    _newTestTitleController.dispose();
    super.dispose();
  }

  Future<void> _fetchPrivateTemplates() async {
    if (_isTemplateLocked) {
      try {
        final paper = await _service.getAssessmentTestPaper(_testTemplateId!);
        final templateMap = paper['template'] as Map<String, dynamic>? ?? {};
        setState(() {
          _lockedTemplateTitle = templateMap['title'] as String?;
        });
      } catch (e) {
        debugPrint("Error fetching locked template: $e");
      }
      return;
    }

    setState(() {
      _loadingTemplates = true;
    });
    try {
      final templates = await _service.getAssessmentTests(
        accessType: 'private',
        limit: 100,
      );
      setState(() {
        _privateTemplates = templates;
        _loadingTemplates = false;
        _selectedTemplateId = null;
      });
    } catch (e) {
      debugPrint("Error loading private templates: $e");
      setState(() {
        _loadingTemplates = false;
      });
    }
  }

  Future<void> _fetchExams() async {
    setState(() {
      _loadingExams = true;
      _error = null;
    });

    try {
      final exams = await _service.getAssessmentExams();
      setState(() {
        _exams = exams;
        _loadingExams = false;
      });

      if (exams.isNotEmpty) {
        _selectedExamId = exams.first.id;
        await _fetchExamData();
      }
    } catch (e) {
      setState(() {
        _error = "Failed to load exams: $e";
        _loadingExams = false;
      });
    }
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      setState(() {
        _selectedImages.addAll(result.files);
      });
    } catch (e) {
      debugPrint("Error picking images: $e");
    }
  }

  void _moveImageUp(int index) {
    if (index <= 0) return;
    setState(() {
      final item = _selectedImages.removeAt(index);
      _selectedImages.insert(index - 1, item);
    });
  }

  void _moveImageDown(int index) {
    if (index >= _selectedImages.length - 1) return;
    setState(() {
      final item = _selectedImages.removeAt(index);
      _selectedImages.insert(index + 1, item);
    });
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _fetchExamData() async {
    if (_selectedExamId == null) return;
    setState(() {
      _error = null;
      _nodes.clear();
      _subjects.clear();
      _selectedSubjectId = null;
      _topics.clear();
      _selectedTopicId = null;
    });

    try {
      final levels = await _service.getAssessmentExamLevels(_selectedExamId!);
      final nodes = _contentType == 'mains'
          ? await _service.getMainsTaxonomyNodes(_selectedExamId!)
          : await _service.getTaxonomyNodes(_selectedExamId!);

      setState(() {
        _levels = levels;
        if (levels.isNotEmpty) {
          _selectedLevelId = levels.first.id;
        }
        _nodes = nodes;
        _filterSubjects();
        if (widget.categoryNodeId != null) {
          _prefillCategory();
        }
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load exam configurations: $e";
      });
    }
  }

  void _prefillCategory() {
    if (widget.categoryNodeId == null || _nodes.isEmpty) return;

    final nodeMap = {for (var n in _nodes) int.tryParse(n['id']?.toString() ?? '') ?? 0: n};
    final targetNode = nodeMap[widget.categoryNodeId];
    if (targetNode != null) {
      int subjectId = targetNode['id'] as int;
      int? topicId;
      if (targetNode['parent_id'] != null) {
        final parent = nodeMap[targetNode['parent_id']];
        if (parent != null && parent['parent_id'] != null) {
          topicId = parent['id'] as int;
          subjectId = parent['parent_id'] as int;
        } else {
          topicId = targetNode['id'] as int;
          subjectId = targetNode['parent_id'] as int;
        }
      }

      setState(() {
        _selectedSubjectId = subjectId;
        _filterTopics();
        _selectedTopicId = topicId;
      });
    }
  }

  void _filterSubjects() {
    final subs = _contentType == 'mains'
        ? _nodes.where((n) => n['node_type'] == 'paper').toList()
        : _nodes.where((n) => n['node_type'] == 'subject' && n['content_type'] == _contentType).toList();

    setState(() {
      _subjects = subs;
      if (subs.isNotEmpty) {
        _selectedSubjectId = subs.first['id'] as int;
        _filterTopics();
      } else {
        _selectedSubjectId = null;
        _topics.clear();
        _selectedTopicId = null;
      }
    });
  }

  void _filterTopics() {
    if (_selectedSubjectId == null) {
      setState(() {
        _topics.clear();
        _selectedTopicId = null;
      });
      return;
    }

    final tops = _contentType == 'mains'
        ? _nodes.where((n) => n['parent_id'] == _selectedSubjectId).toList()
        : _nodes.where((n) => n['node_type'] == 'topic' && n['parent_id'] == _selectedSubjectId).toList();

    setState(() {
      _topics = tops;
      _selectedTopicId = null; // Default to none/empty (saves to subject level)
    });
  }

  Future<void> _pickFile() async {
    setState(() {
      _error = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'doc', 'docx'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Failed to pick file: $e";
      });
    }
  }

  Future<void> _handleParse() async {
    setState(() {
      _error = null;
      _parsedResult = null;
    });

    if (_parseMode == 'text' && _textController.text.trim().isEmpty) {
      setState(() {
        _error = "Please paste the raw text to parse.";
      });
      return;
    }

    if (_parseMode == 'images' && _selectedImages.isEmpty) {
      setState(() {
        _error = "Please capture/select at least one photo page.";
      });
      return;
    }

    if (_parseMode == 'file' && _selectedFile == null) {
      setState(() {
        _error = "Please upload/select a document file.";
      });
      return;
    }

    setState(() {
      _parsing = true;
    });

    try {
      ParsedResult result;
      if (_parseMode == 'text') {
        result = await _service.aiParseText(
          rawText: _textController.text.trim(),
          contentType: _contentType,
          instructions: _instructionsController.text.trim(),
        );
      } else if (_parseMode == 'images') {
        final List<Map<String, String>> imagesPayload = [];
        for (final img in _selectedImages) {
          List<int> bytes;
          if (img.bytes != null) {
            bytes = img.bytes!;
          } else if (img.path != null) {
            bytes = await io.File(img.path!).readAsBytes();
          } else {
            continue;
          }
          final mime = lookupMimeType(img.name) ?? 'image/jpeg';
          final base64Data = base64Encode(bytes);
          imagesPayload.add({
            'base64_data': "data:$mime;base64,$base64Data",
            'mime_type': mime,
          });
        }

        result = await _service.aiParseImages(
          images: imagesPayload,
          contentType: _contentType,
          instructions: _instructionsController.text.trim(),
        );
      } else {
        List<int> bytes;
        if (_selectedFile!.bytes != null) {
          bytes = _selectedFile!.bytes!;
        } else if (_selectedFile!.path != null) {
          final file = io.File(_selectedFile!.path!);
          bytes = await file.readAsBytes();
        } else {
          throw Exception("Could not read file data. Try another file.");
        }

        final mimeType = lookupMimeType(_selectedFile!.name) ?? 'application/pdf';
        final base64String = "data:$mimeType;base64,${base64Encode(bytes)}";

        result = await _service.aiParseFile(
          base64Data: base64String,
          filename: _selectedFile!.name,
          mimeType: mimeType,
          contentType: _contentType,
          instructions: _instructionsController.text.trim(),
        );
      }

      setState(() {
        _parsedResult = result;
        _parsing = false;
      });

      if (result.questions.isEmpty) {
        setState(() {
          _error = "AI did not extract any questions. Try copying cleaner text.";
        });
      }
    } catch (e) {
      setState(() {
        _error = "AI parsing failed: $e";
        _parsing = false;
      });
    }
  }

  Future<void> _handleSaveQuestions() async {
    if (_parsedResult == null || _selectedExamId == null || _selectedLevelId == null || _selectedSubjectId == null) return;

    setState(() {
      _saving = true;
      _error = null;
      _successMessage = null;
    });

    try {
      int? targetId = _isTemplateLocked ? _testTemplateId : _selectedTemplateId;
      if (targetId == null) {
        if (_newTestTitleController.text.trim().isEmpty) {
          setState(() {
            _error = "Please enter a title for the new custom test.";
            _saving = false;
          });
          return;
        }
        targetId = await _service.createUserCustomTest(
          title: _newTestTitleController.text.trim(),
          examId: _selectedExamId!,
          examLevelId: _selectedLevelId!,
          questionIds: [],
          testType: _contentType == 'mains' ? 'mains_test' : 'sectional_test',
        );
      }

      await _service.aiSaveQuestions(
        examId: _selectedExamId!,
        examLevelId: _selectedLevelId!,
        subjectNodeId: _selectedSubjectId!,
        topicNodeId: _selectedTopicId,
        passageTitle: _parsedResult!.passageTitle,
        passageText: _parsedResult!.passageText,
        questions: _parsedResult!.questions,
        testTemplateId: targetId,
      );

      setState(() {
        _saving = false;
        _successMessage = "Successfully saved ${_parsedResult!.questions.length} questions to library!";
      });

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      setState(() {
        _error = "Failed to save questions: $e";
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(
          "AI Test Parser",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loadingExams
          ? const Center(child: CircularProgressIndicator(color: AppColors.civic))
          : Column(
              children: [
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: AppColors.berry.withOpacity(0.1),
                    child: Text(
                      _error!,
                      style: GoogleFonts.inter(
                        color: AppColors.berry,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                if (_successMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: AppColors.emerald.withOpacity(0.1),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: GoogleFonts.inter(
                              color: AppColors.emerald,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSetupSection(),
                        const SizedBox(height: 20),
                        if (_parsedResult == null) ...[
                          _buildInputSection(),
                          const SizedBox(height: 20),
                          _buildActionBtn(),
                        ] else ...[
                          _buildPreviewSection(),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_parsedResult != null) ...[
                  Container(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          offset: const Offset(0, -4),
                          blurRadius: 10,
                        ),
                      ],
                      border: const Border(
                        top: BorderSide(color: AppColors.line),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSaveBtn(),
                        const SizedBox(height: 8),
                        _buildResetBtn(),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildSetupSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_suggest_rounded, color: AppColors.civic, size: 20),
              const SizedBox(width: 8),
              Text(
                "Syllabus Mapping",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content Type Segment
          Row(
            children: [
              Expanded(
                child: _buildChoiceChip(
                  label: "General Studies",
                  isSelected: _contentType == 'gk',
                  onTap: () {
                    setState(() {
                      _contentType = 'gk';
                    });
                    _fetchExamData();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildChoiceChip(
                  label: "Aptitude (CSAT)",
                  isSelected: _contentType == 'aptitude',
                  onTap: () {
                    setState(() {
                      _contentType = 'aptitude';
                    });
                    _fetchExamData();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildChoiceChip(
                  label: "Mains",
                  isSelected: _contentType == 'mains',
                  onTap: () {
                    setState(() {
                      _contentType = 'mains';
                    });
                    _fetchExamData();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Exam Profile Dropdown
          Text(
            "Exam Profile",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedExamId,
                isExpanded: true,
                items: _exams.map((exam) {
                  return DropdownMenuItem<int>(
                    value: exam.id,
                    child: Text(
                      exam.name,
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.ink),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedExamId = val;
                    });
                    _fetchExamData();
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Exam Level Dropdown
          if (_levels.isNotEmpty) ...[
            Text(
              "Exam level",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedLevelId,
                  isExpanded: true,
                  items: _levels.map((lvl) {
                    return DropdownMenuItem<int>(
                      value: lvl.id,
                      child: Text(
                        lvl.name,
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.ink),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedLevelId = val;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Subject Dropdown
          Text(
            "Subject Category",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedSubjectId,
                isExpanded: true,
                hint: Text("Select Subject", style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted)),
                items: _subjects.map((sub) {
                  return DropdownMenuItem<int>(
                    value: sub['id'] as int,
                    child: Text(
                      sub['name'] as String,
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.ink),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedSubjectId = val;
                    });
                    _filterTopics();
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Topic Dropdown (Optional)
          if (_selectedSubjectId != null && _topics.isNotEmpty) ...[
            Text(
              "Topic (Optional)",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _selectedTopicId,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        "None (Keep at Subject level)",
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted, fontStyle: FontStyle.italic),
                      ),
                    ),
                    ..._topics.map((top) {
                      return DropdownMenuItem<int?>(
                        value: top['id'] as int,
                        child: Text(
                          top['name'] as String,
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.ink),
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedTopicId = val;
                    });
                  },
                ),
              ),
            ),
          ],
          if (_loadingTemplates) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator(color: AppColors.civic)),
          ] else ...[
            const Divider(height: 24),
            Text(
              "Target Custom Test",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            if (_isTemplateLocked)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.civic.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.civic.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, color: AppColors.civic, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lockedTemplateTitle ?? "Loading test template title...",
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.civic,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _selectedTemplateId,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          "— Create New Custom Test —",
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.civic, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ..._privateTemplates.map((temp) {
                        return DropdownMenuItem<int?>(
                          value: temp.id,
                          child: Text(
                            temp.title,
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.ink),
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedTemplateId = val;
                      });
                    },
                  ),
                ),
              ),
              if (_selectedTemplateId == null) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _newTestTitleController,
                  decoration: InputDecoration(
                    hintText: "Enter New Test Name",
                    hintStyle: GoogleFonts.inter(color: AppColors.muted, fontSize: 13),
                    fillColor: Colors.white,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.civic, width: 1.5),
                    ),
                  ),
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.ink),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? AppColors.civic.withOpacity(0.1) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.civic : AppColors.line,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? AppColors.civic : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Text("Document", style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  selected: _parseMode == 'file',
                  selectedColor: AppColors.civic.withOpacity(0.15),
                  checkmarkColor: AppColors.civic,
                  labelStyle: TextStyle(color: _parseMode == 'file' ? AppColors.civic : AppColors.muted),
                  onSelected: (val) {
                    if (val) setState(() => _parseMode = 'file');
                  },
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ChoiceChip(
                  label: Text("OCR Photos", style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  selected: _parseMode == 'images',
                  selectedColor: AppColors.civic.withOpacity(0.15),
                  checkmarkColor: AppColors.civic,
                  labelStyle: TextStyle(color: _parseMode == 'images' ? AppColors.civic : AppColors.muted),
                  onSelected: (val) {
                    if (val) setState(() => _parseMode = 'images');
                  },
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ChoiceChip(
                  label: Text("Paste Text", style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  selected: _parseMode == 'text',
                  selectedColor: AppColors.civic.withOpacity(0.15),
                  checkmarkColor: AppColors.civic,
                  labelStyle: TextStyle(color: _parseMode == 'text' ? AppColors.civic : AppColors.muted),
                  onSelected: (val) {
                    if (val) setState(() => _parseMode = 'text');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_parseMode == 'file') ...[
            Text(
              "PDF or Text Document",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.paper.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line, style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 36, color: AppColors.civic),
                    const SizedBox(height: 10),
                    Text(
                      _selectedFile != null ? _selectedFile!.name : "Select PDF / TXT Document",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _selectedFile != null ? AppColors.ink : AppColors.muted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_selectedFile != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        "${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB",
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else if (_parseMode == 'images') ...[
            Text(
              "OCR Photo Pages (Reorderable)",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.paper.withOpacity(0.4),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (_selectedImages.isEmpty) ...[
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.photo_library_outlined, size: 36, color: AppColors.muted),
                          const SizedBox(height: 8),
                          Text(
                            "No images selected",
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _pickImages,
                            icon: const Icon(Icons.add_a_photo_outlined, size: 14),
                            label: const Text("Capture/Select Photos"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.civic,
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _selectedImages.length,
                      separatorBuilder: (_, __) => const Divider(height: 12, color: AppColors.line),
                      itemBuilder: (context, index) {
                        final file = _selectedImages[index];
                        return Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: file.bytes != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(file.bytes!, fit: BoxFit.cover),
                                    )
                                  : (file.path != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.file(io.File(file.path!), fit: BoxFit.cover),
                                        )
                                      : const Icon(Icons.image, color: AppColors.muted)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    file.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  Text(
                                    "${(file.size / 1024).toStringAsFixed(1)} KB",
                                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_upward_rounded, size: 16, color: AppColors.civic),
                              onPressed: index > 0 ? () => _moveImageUp(index) : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_downward_rounded, size: 16, color: AppColors.civic),
                              onPressed: index < _selectedImages.length - 1 ? () => _moveImageDown(index) : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.berry),
                              onPressed: () => _removeImage(index),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add_photo_alternate_outlined, size: 16, color: AppColors.civic),
                      label: const Text("Add More Photos", style: TextStyle(color: AppColors.civic, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            Text(
              "Raw Content text",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: "Paste questions, passages, or quiz notes here...",
                hintStyle: GoogleFonts.inter(color: AppColors.muted, fontSize: 13),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
              ),
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.ink),
            ),
          ],
          const SizedBox(height: 16),

          // Instructions input
          Text(
            "Instructions for AI Generator (Optional)",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _instructionsController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "e.g. Focus on climate changes, align with UPSC structure...",
              hintStyle: GoogleFonts.inter(color: AppColors.muted, fontSize: 13),
              fillColor: Colors.white,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.line),
              ),
            ),
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.ink),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.civic,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: _parsing ? null : _handleParse,
        child: _parsing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.settings_suggest_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Parse Document",
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    final result = _parsedResult!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.rate_review_rounded, color: AppColors.emerald, size: 20),
            const SizedBox(width: 8),
            Text(
              "Parsed Preview (${result.questions.length} questions)",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (result.passageTitle != null && result.passageTitle!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.brand.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.brand.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.passageTitle!,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.brand),
                ),
                if (result.passageText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    result.passageText!,
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.ink),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],

        // Questions Pool List
        Column(
          children: result.questions.asMap().entries.map((entry) {
            final idx = entry.key;
            final q = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Question ${idx + 1}",
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    q.questionStatement,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.ink),
                  ),
                  if (q.suppQuestionStatement != null && q.suppQuestionStatement!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: MarkdownBody(
                        data: q.suppQuestionStatement!,
                        styleSheet: MarkdownStyleSheet(
                          p: GoogleFonts.inter(fontSize: 13, color: AppColors.muted, height: 1.4, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ),
                  ],
                  if (q.questionPrompt != null && q.questionPrompt!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.civic.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.civic.withOpacity(0.1)),
                      ),
                      child: Text(
                        q.questionPrompt!,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.civic),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Render options in an attemptable format
                  ...q.options.map((opt) {
                    final selectedKey = _selectedAnswers[idx];
                    final hasSelected = selectedKey != null;
                    final isSelected = selectedKey == opt.key;
                    final isCorrect = opt.key.toUpperCase() == q.correctAnswer.toUpperCase();

                    Color cardBgColor = Colors.white;
                    Color borderColor = AppColors.line;
                    Widget? trailingIcon;

                    if (hasSelected) {
                      if (isCorrect) {
                        cardBgColor = AppColors.emerald.withOpacity(0.08);
                        borderColor = AppColors.emerald;
                        trailingIcon = const Icon(Icons.check_circle, color: AppColors.emerald, size: 16);
                      } else if (isSelected) {
                        cardBgColor = AppColors.berry.withOpacity(0.08);
                        borderColor = AppColors.berry;
                        trailingIcon = const Icon(Icons.cancel, color: AppColors.berry, size: 16);
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        onTap: () {
                          if (!hasSelected) {
                            setState(() {
                              _selectedAnswers[idx] = opt.key;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hasSelected && isCorrect
                                      ? AppColors.emerald
                                      : (hasSelected && isSelected ? AppColors.berry : AppColors.paper),
                                ),
                                child: Text(
                                  opt.key,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: hasSelected && (isCorrect || isSelected) ? Colors.white : AppColors.muted,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  opt.text,
                                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.ink),
                                ),
                              ),
                              if (trailingIcon != null) trailingIcon,
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSaveBtn() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emerald,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: _saving ? null : _handleSaveQuestions,
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_done_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Save to Private Library",
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildResetBtn() {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          setState(() {
            _parsedResult = null;
            _selectedFile = null;
            _textController.clear();
            _selectedAnswers.clear();
          });
        },
        child: Text(
          "Reset Parser",
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
            color: AppColors.muted,
          ),
        ),
      ),
    );
  }
}
