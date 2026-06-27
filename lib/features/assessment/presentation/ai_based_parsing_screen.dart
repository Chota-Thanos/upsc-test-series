import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/assessment_service.dart';
import '../models/assessment_models.dart';

class AiBasedParsingScreen extends StatefulWidget {
  final int? testTemplateId;
  final String? contentType;
  const AiBasedParsingScreen({super.key, this.testTemplateId, this.contentType});

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
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load exam configurations: $e";
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
        // Prefix with correct base64 dataURI header
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
                          const SizedBox(height: 20),
                          _buildSaveBtn(),
                          const SizedBox(height: 12),
                          _buildResetBtn(),
                        ],
                      ],
                    ),
                  ),
                ),
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
                  label: Text("Document Upload", style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  selected: _parseMode == 'file',
                  selectedColor: AppColors.civic.withOpacity(0.15),
                  checkmarkColor: AppColors.civic,
                  labelStyle: TextStyle(color: _parseMode == 'file' ? AppColors.civic : AppColors.muted),
                  onSelected: (val) {
                    if (val) setState(() => _parseMode = 'file');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: Text("Paste Text Pool", style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
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
                  const SizedBox(height: 12),

                  // Render options
                  ...q.options.map((opt) {
                    final isCorrect = opt.key.toUpperCase() == q.correctAnswer.toUpperCase();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isCorrect ? AppColors.emerald.withOpacity(0.08) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isCorrect ? AppColors.emerald : AppColors.line),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCorrect ? AppColors.emerald : AppColors.paper,
                            ),
                            child: Text(
                              opt.key,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isCorrect ? Colors.white : AppColors.muted,
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
                          if (isCorrect)
                            const Icon(Icons.check_circle, color: AppColors.emerald, size: 16),
                        ],
                      ),
                    );
                  }).toList(),

                  // Render explanation
                  if (q.explanation != null && q.explanation!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.paper.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Explanation:",
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.muted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            q.explanation!,
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.ink),
                          ),
                        ],
                      ),
                    ),
                  ],
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
