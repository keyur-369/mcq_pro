import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/ai_generator_service.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/animated_page.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/models/test.dart';
import 'package:mcq_test_app/models/question.dart';
import 'package:mcq_test_app/features/teacher/screens/question_preview_screen.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mcq_test_app/core/providers/api_key_provider.dart';

enum GenerationMode { topic, pdf }

class CreateTestScreen extends ConsumerStatefulWidget {
  const CreateTestScreen({super.key});

  @override
  ConsumerState<CreateTestScreen> createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends ConsumerState<CreateTestScreen> {
  int _currentStep = 0;
  String? selectedClass = '11';
  String? selectedMedium = 'English';
  String? selectedLevel = 'Boards / GUJCET';
  String? selectedSubject = 'Physics';
  String selectedModel = 'gemini-2.5-flash';
  GenerationMode genMode = GenerationMode.topic;
  PlatformFile? selectedPdf;

  final _topicController = TextEditingController();
  final _topicHintController = TextEditingController();
  final _mcqCountController = TextEditingController(text: '10');
  final _durationController = TextEditingController(text: '30');
  bool _isLoading = false;

  List<String> _getAvailableSubjects(String? level) {
    if (level == 'NEET') return ['Physics', 'Chemistry', 'Biology'];
    if (level == 'JEE') return ['Physics', 'Chemistry', 'Math'];
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

  void _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) setState(() => selectedPdf = result.files.first);
  }

  void _generateQuestions() async {
    final count = int.tryParse(_mcqCountController.text) ?? 10;
    final duration = int.tryParse(_durationController.text) ?? 30;

    setState(() => _isLoading = true);
    try {
      if (genMode == GenerationMode.topic && _topicController.text.trim().isEmpty) throw 'Please enter a topic';
      if (genMode == GenerationMode.pdf && selectedPdf == null) throw 'Please select a PDF file first';

      final test = Test(
        teacherId: SupabaseService().currentUser?.id ?? '',
        testCode: _generateUniqueCode(),
        studentClass: selectedClass ?? '11',
        medium: selectedMedium?.toLowerCase() ?? 'english',
        subject: selectedSubject ?? 'Physics',
        topic: genMode == GenerationMode.pdf ? _topicHintController.text : _topicController.text,
        level: selectedLevel?.split(' / ').first.toLowerCase() ?? 'boards',
        duration: duration,
        status: TestStatus.draft,
      );

      final selectedKey = ref.read(selectedApiKeyProvider);
      if (selectedKey == null) throw 'Please select an AI API key on the dashboard first';

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
          apiKey: selectedKey.key,
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
          apiKey: selectedKey.key,
          modelName: selectedModel,
        );
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuestionPreviewScreen(test: test, questions: questions),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Create New Test'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          AppGradientBackground(
            child: SafeArea(
              child: AnimatedPage(
                child: Column(
                  children: [
                    _buildStepper(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_currentStep == 0) _buildStepOne() else _buildStepTwo(),
                            const SizedBox(height: 32),
                            _buildNavigationButtons(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
      child: Row(
        children: [
          _buildStepIndicator(0, 'Configure', Icons.settings_rounded),
          Expanded(child: Container(height: 2, color: _currentStep == 1 ? AppColors.primary : AppColors.border)),
          _buildStepIndicator(1, 'Generate', Icons.auto_awesome_rounded),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, IconData icon) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive || isCompleted ? AppColors.primary : AppColors.cardLight,
            border: Border.all(color: isActive ? AppColors.primary : AppColors.border, width: 2),
            boxShadow: isActive ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
          ),
          child: Icon(
            isCompleted ? Icons.check_rounded : icon,
            color: isActive || isCompleted ? Colors.white : AppColors.textMuted,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildStepOne() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Target Students', 'Select class and medium'),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            children: [
              _buildChoiceGroup('Standard', ['11', '12'], selectedClass, (val) => setState(() => selectedClass = val)),
              const Divider(height: 32),
              _buildChoiceGroup('Medium', ['English', 'Gujarati'], selectedMedium, (val) => setState(() => selectedMedium = val)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildSectionTitle('Exam Details', 'Choose level and subject'),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Competition Level'),
              _buildSegmentedButton(
                ['Boards / GUJCET', 'NEET', 'JEE'],
                selectedLevel,
                _onLevelChanged,
              ),
              const SizedBox(height: 24),
              _buildLabel('Subject'),
              DropdownButtonFormField<String>(
                value: selectedSubject,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.book_rounded, color: AppColors.primary.withOpacity(0.7)),
                  filled: true,
                  fillColor: AppColors.background,
                ),
                items: _getAvailableSubjects(selectedLevel)
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => selectedSubject = val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepTwo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Source Material', 'How should AI generate questions?'),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Generation Mode'),
              _buildSegmentedButton(
                ['By Topic', 'By PDF'],
                genMode == GenerationMode.topic ? 'By Topic' : 'By PDF',
                (val) => setState(() => genMode = val == 'By Topic' ? GenerationMode.topic : GenerationMode.pdf),
              ),
              const SizedBox(height: 24),
              if (genMode == GenerationMode.topic) ...[
                _buildLabel('Main Topic'),
                TextField(
                  controller: _topicController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Newton\'s Laws of Motion',
                    prefixIcon: Icon(Icons.topic_rounded),
                  ),
                ),
              ] else ...[
                _buildLabel('Reference Document'),
                _buildPdfPicker(),
                const SizedBox(height: 16),
                _buildLabel('Focus Area (Optional)'),
                TextField(
                  controller: _topicHintController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Focus on Page 12-15',
                    prefixIcon: Icon(Icons.lightbulb_outline_rounded),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildSectionTitle('Test Parameters', 'Set quantity and time limit'),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Question Count'),
                        TextField(
                          controller: _mcqCountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '10',
                            prefixIcon: Icon(Icons.numbers_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Duration (min)'),
                        TextField(
                          controller: _durationController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '30',
                            prefixIcon: Icon(Icons.timer_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildLabel('AI Engine'),
              DropdownButtonFormField<String>(
                value: selectedModel,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.psychology_rounded)),
                items: [
                  {'name': 'Gemini 2.5 Flash (Fast)', 'id': 'gemini-2.5-flash'},
                  {'name': 'Gemini 2.5 Flash Lite (Light)', 'id': 'gemini-2.5-flash-lite'},
                ].map((e) => DropdownMenuItem(value: e['id'], child: Text(e['name']!))).toList(),
                onChanged: (val) => setState(() => selectedModel = val!),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPdfPicker() {
    return InkWell(
      onTap: _pickPdf,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selectedPdf != null ? AppColors.primarySoft : AppColors.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selectedPdf != null ? AppColors.primary : AppColors.border,
            width: selectedPdf != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selectedPdf != null ? AppColors.primary : AppColors.textMuted.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.picture_as_pdf_rounded,
                color: selectedPdf != null ? Colors.white : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedPdf?.name ?? 'Select PDF File',
                    style: TextStyle(
                      color: selectedPdf != null ? AppColors.textPrimary : AppColors.textMuted,
                      fontWeight: selectedPdf != null ? FontWeight.bold : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (selectedPdf != null)
                    Text(
                      '${(selectedPdf!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                ],
              ),
            ),
            if (selectedPdf != null) const Icon(Icons.check_circle_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentStep == 1)
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _currentStep = 0),
              child: const Text('Back'),
            ),
          ),
        if (_currentStep == 1) const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _currentStep == 0 ? () => setState(() => _currentStep = 1) : _generateQuestions,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_currentStep == 0 ? 'Continue' : 'Generate Test'),
                const SizedBox(width: 8),
                Icon(_currentStep == 0 ? Icons.arrow_forward_rounded : Icons.auto_awesome_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.white.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SpinKitCubeGrid(color: AppColors.primary, size: 60.0),
            const SizedBox(height: 32),
            Text(
              'AI is crafting your questions...',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Analyzing source material and formatting options',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        Text(subtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 13),
      ),
    );
  }

  Widget _buildChoiceGroup(String label, List<String> options, String? selected, Function(String) onSelect) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const Spacer(),
        Wrap(
          spacing: 8,
          children: options.map((opt) {
            final isSelected = opt == selected;
            return ChoiceChip(
              label: Text(opt),
              selected: isSelected,
              onSelected: (_) => onSelect(opt),
              showCheckmark: false,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSegmentedButton(List<String> options, String? selected, Function(String) onSelect) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: options.map((opt) {
          final isSelected = opt == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected ? const LinearGradient(colors: AppColors.primaryGradient) : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))] : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  opt,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
