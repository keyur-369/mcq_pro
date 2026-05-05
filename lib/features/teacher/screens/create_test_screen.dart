import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/ai_generator_service.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/models/test.dart';
import 'package:mcq_test_app/models/question.dart';
import 'package:mcq_test_app/features/teacher/screens/question_preview_screen.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

enum GenerationMode { topic, pdf }

class CreateTestScreen extends StatefulWidget {
  const CreateTestScreen({super.key});

  @override
  State<CreateTestScreen> createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends State<CreateTestScreen> {
  String? selectedClass = '11';
  String? selectedMedium = 'English';
  String? selectedLevel = 'Boards / GUJCET';
  String? selectedSubject = 'Physics';
  String selectedModel = 'gemini-2.5-flash';
  GenerationMode genMode = GenerationMode.topic;
  PlatformFile? selectedPdf;

  List<String> _getAvailableSubjects(String? level) {
    if (level == 'NEET') {
      return ['Physics', 'Chemistry', 'Biology'];
    } else if (level == 'JEE') {
      return ['Physics', 'Chemistry', 'Math'];
    }
    return ['Physics', 'Chemistry', 'Biology', 'Math'];
  }

  void _onLevelChanged(String val) {
    setState(() {
      selectedLevel = val;
      final subjects = _getAvailableSubjects(val);
      if (selectedSubject == null || !subjects.contains(selectedSubject)) {
        selectedSubject = subjects.first;
      }
    });
  }

  String _generateUniqueCode() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  final _topicController = TextEditingController();
  final _topicHintController = TextEditingController();
  final _mcqCountController = TextEditingController();
  final _durationController = TextEditingController();

  void _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() => selectedPdf = result.files.first);
    }
  }

  bool _isLoading = false;

  void _generateQuestions() async {
    final count = int.tryParse(_mcqCountController.text) ?? 10;
    final duration = int.tryParse(_durationController.text) ?? 30;

    setState(() => _isLoading = true);

    try {
      if (genMode == GenerationMode.topic &&
          _topicController.text.trim().isEmpty) {
        throw 'Please enter a topic';
      }
      if (genMode == GenerationMode.pdf && selectedPdf == null) {
        throw 'Please select a PDF file first';
      }

      final test = Test(
        teacherId: SupabaseService().currentUser?.id ?? '',
        testCode: _generateUniqueCode(),
        studentClass: selectedClass ?? '11',
        medium: selectedMedium?.toLowerCase() ?? 'english',
        subject: selectedSubject ?? 'Physics',
        topic: genMode == GenerationMode.pdf
            ? _topicHintController.text
            : _topicController.text,
        level: selectedLevel?.split(' / ').first.toLowerCase() ?? 'boards',
        duration: duration,
        status: TestStatus.draft,
      );

      List<Question> questions;
      if (genMode == GenerationMode.pdf) {
        questions = await AiGeneratorService().generateQuestionsFromPdf(
          subject: test.subject,
          topic: test.topic,
          level: test.level,
          count: count,
          testId: '',
          medium: test.medium,
          pdfBytes: await _readFileBytes(selectedPdf!),
          modelName: selectedModel,
        );
      } else {
        questions = await AiGeneratorService().generateQuestions(
          subject: test.subject,
          topic: test.topic,
          level: test.level,
          count: count,
          testId: '',
          medium: test.medium,
          modelName: selectedModel,
        );
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                QuestionPreviewScreen(test: test, questions: questions),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<int>> _readFileBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes!;
    if (file.path != null) return await File(file.path!).readAsBytes();
    throw 'Could not read file data';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Create New Test'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Class'),
                        _buildSegmentedButton(
                          ['11', '12'],
                          selectedClass,
                          (val) => setState(() => selectedClass = val),
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Medium'),
                        _buildSegmentedButton(
                          ['English', 'Gujarati'],
                          selectedMedium,
                          (val) => setState(() => selectedMedium = val),
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Exam Level'),
                        _buildSegmentedButton(
                          ['Boards / GUJCET', 'NEET', 'JEE'],
                          selectedLevel,
                          _onLevelChanged,
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Subject'),
                        DropdownButtonFormField<String>(
                          value: selectedSubject,
                          decoration: _fieldDecoration(
                            hintText: 'Select Subject',
                          ),
                          items: _getAvailableSubjects(selectedLevel)
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => selectedSubject = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Generation Mode'),
                        _buildSegmentedButton(
                          ['By Topic', 'By PDF'],
                          genMode == GenerationMode.topic
                              ? 'By Topic'
                              : 'By PDF',
                          (val) => setState(
                            () => genMode = val == 'By Topic'
                                ? GenerationMode.topic
                                : GenerationMode.pdf,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (genMode == GenerationMode.topic) ...[
                          _buildLabel('Topic'),
                          TextField(
                            controller: _topicController,
                            decoration: _fieldDecoration(
                              hintText: 'Enter topic name',
                            ),
                          ),
                        ] else ...[
                          _buildLabel('Material (PDF)'),
                          InkWell(
                            onTap: _pickPdf,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selectedPdf != null
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.picture_as_pdf_outlined,
                                    color: selectedPdf != null
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      selectedPdf?.name ??
                                          'Select PDF Material',
                                      style: TextStyle(
                                        color: selectedPdf != null
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                        fontWeight: selectedPdf != null
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (selectedPdf != null)
                                    const Icon(
                                      Icons.check_circle,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildLabel('Topic Hint (Optional)'),
                          TextField(
                            controller: _topicHintController,
                            decoration: _fieldDecoration(
                              hintText: 'e.g. Focus on Chapter 3',
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('No. of MCQs'),
                                  TextField(
                                    controller: _mcqCountController,
                                    keyboardType: TextInputType.number,
                                    decoration: _fieldDecoration(
                                      hintText: 'e.g. 25',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Duration (min)'),
                                  TextField(
                                    controller: _durationController,
                                    keyboardType: TextInputType.number,
                                    decoration: _fieldDecoration(
                                      hintText: 'e.g. 45',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('AI Model'),
                        DropdownButtonFormField<String>(
                          value: selectedModel,
                          decoration: _fieldDecoration(
                            hintText: 'Select AI Model',
                          ),
                          items:
                              [
                                    {
                                      'name': 'Gemini 2.5 Flash',
                                      'id': 'gemini-2.5-flash',
                                    },
                                    {
                                      'name': 'Gemini 2.5 Flash Lite',
                                      'id': 'gemini-2.5-flash-lite',
                                    },

                                  ]
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e['id'],
                                      child: Text(e['name']!),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) =>
                              setState(() => selectedModel = val!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _generateQuestions,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Generate Questions with AI'),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: SpinKitPulse(color: AppColors.primary, size: 50.0),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  InputDecoration _fieldDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }

  Widget _buildSegmentedButton(
    List<String> options,
    String? selected,
    Function(String) onSelect,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: options.map((opt) {
          final isSelected = opt == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(opt),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  opt,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _topicController.dispose();
    _topicHintController.dispose();
    _mcqCountController.dispose();
    _durationController.dispose();
    super.dispose();
  }
}
