import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/providers/api_key_provider.dart';
import 'package:mcq_test_app/core/services/ai_generator_service.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/animated_page.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/features/teacher/screens/question_preview_screen.dart';
import 'package:mcq_test_app/models/question.dart';
import 'package:mcq_test_app/models/teacher_assignment.dart';
import 'package:mcq_test_app/models/test.dart';

enum GenerationMode { topic, pdf }

/// ---------------------------------------------------------------------------
/// Liquid glass primitive (same look as the teacher dashboard).
/// Tip: move this into core/widgets/glass_card.dart and import it from both
/// screens instead of keeping two copies.
/// ---------------------------------------------------------------------------
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? tint;
  final VoidCallback? onTap;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 28,
    this.blur = 24,
    this.tint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    final innerBr = BorderRadius.circular(radius - 1.2);
    final base = tint ?? Colors.white;
    final glow = tint ?? AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: glow.withOpacity(0.16),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          borderRadius: br,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.95),
              Colors.white.withOpacity(0.25),
              Colors.white.withOpacity(0.10),
              Colors.white.withOpacity(0.55),
            ],
            stops: const [0.0, 0.35, 0.65, 1.0],
          ),
        ),
        child: ClipRRect(
          borderRadius: innerBr,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          base.withOpacity(0.50),
                          base.withOpacity(0.16),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -40,
                  bottom: -40,
                  child: IgnorePointer(
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            glow.withOpacity(0.18),
                            glow.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 64,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.34),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: innerBr,
                    splashColor: Colors.white.withOpacity(0.25),
                    highlightColor: Colors.white.withOpacity(0.10),
                    child: Padding(padding: padding, child: child),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreateTestScreen extends ConsumerStatefulWidget {
  const CreateTestScreen({super.key});

  @override
  ConsumerState<CreateTestScreen> createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends ConsumerState<CreateTestScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  String? selectedClass = '11';
  String? selectedDivision;
  String? selectedMedium = 'English';
  String? selectedLevel = 'Boards / GUJCET';
  String? selectedSubject = 'Physics';
  String selectedModel = 'gemini-2.5-flash';
  GenerationMode genMode = GenerationMode.topic;
  PlatformFile? selectedPdf;

  List<String> _allowedStandards = ['11', '12'];
  List<String> _allowedMediums = ['English', 'Gujarati'];
  List<String> _allowedSubjects = ['Physics', 'Chemistry', 'Biology', 'Math'];
  List<String> _allowedDivisions = ['A', 'B', 'C'];

  final _topicController = TextEditingController();
  final _topicHintController = TextEditingController();
  final _mcqCountController = TextEditingController(text: '10');
  final _durationController = TextEditingController(text: '30');

  bool _isLoading = false;

  // ── Real progress state ──────────────────────────────────────────────────
  int _generatedCount = 0; // actual questions generated so far
  int _targetCount = 0; // total requested

  // ── Animation controllers ────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadTeacherScope();
  }

  void _loadTeacherScope() async {
    final user = SupabaseService().currentUser;
    if (user != null) {
      final List<TeacherAssignment> list = await SupabaseService()
          .getTeacherAssignments(user.id);
      if (list.isNotEmpty && mounted) {
        setState(() {
          _allowedStandards = list.map((a) => a.standard).toSet().toList();
          _allowedMediums = list.map((a) => a.medium).toSet().toList();
          _allowedSubjects = list.map((a) => a.subject).toSet().toList();
          _allowedDivisions = list.map((a) => a.division).toSet().toList();

          if (!_allowedStandards.contains(selectedClass) &&
              _allowedStandards.isNotEmpty) {
            selectedClass = _allowedStandards.first;
          }
          if (!_allowedMediums.contains(selectedMedium) &&
              _allowedMediums.isNotEmpty) {
            selectedMedium = _allowedMediums.first;
          }
          if (!_allowedSubjects.contains(selectedSubject) &&
              _allowedSubjects.isNotEmpty) {
            selectedSubject = _allowedSubjects.first;
          }
          if (_allowedDivisions.isNotEmpty) {
            selectedDivision = _allowedDivisions.first;
          }
        });
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  List<String> _getAvailableSubjects(String? level) {
    List<String> base;
    if (level == 'NEET') {
      base = ['Physics', 'Chemistry', 'Biology'];
    } else if (level == 'JEE') {
      base = ['Physics', 'Chemistry', 'Math'];
    } else {
      base = ['Physics', 'Chemistry', 'Biology', 'Math'];
    }

    final filtered = base.where((s) => _allowedSubjects.contains(s)).toList();
    return filtered.isNotEmpty ? filtered : base;
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

  Future<List<int>> _readFileBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes!;
    if (file.path != null) return await File(file.path!).readAsBytes();
    throw 'Could not read file data';
  }

  // ── Generation ───────────────────────────────────────────────────────────

  void _generateQuestions() async {
    final count = int.tryParse(_mcqCountController.text) ?? 10;
    final duration = int.tryParse(_durationController.text) ?? 30;

    setState(() {
      _isLoading = true;
      _targetCount = count;
      _generatedCount = 0;
    });

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
        division: selectedDivision,
        medium: selectedMedium?.toLowerCase() ?? 'english',
        subject: selectedSubject ?? 'Physics',
        topic: genMode == GenerationMode.pdf
            ? _topicHintController.text
            : _topicController.text,
        level: selectedLevel?.split(' / ').first.toLowerCase() ?? 'boards',
        duration: duration,
        status: TestStatus.draft,
      );

      final selectedKey = ref.read(selectedApiKeyProvider);
      if (selectedKey == null) {
        throw 'Please select an AI API key on the dashboard first';
      }

      // onProgress: called each time a batch finishes with actual count
      void onProgress(int generatedSoFar) {
        if (mounted) {
          setState(() => _generatedCount = generatedSoFar);
        }
      }

      final aiService = AiGeneratorService();
      List<Question> questions;
      if (genMode == GenerationMode.pdf) {
        questions = await aiService.generateQuestionsFromPdf(
          subject: test.subject,
          topic: test.topic,
          level: test.level,
          count: count,
          testId: '',
          medium: test.medium,
          pdfBytes: await _readFileBytes(selectedPdf!),
          apiKey: selectedKey.key,
          modelName: selectedModel,
          onProgress: onProgress,
        );
      } else {
        questions = await aiService.generateQuestions(
          subject: test.subject,
          topic: test.topic,
          level: test.level,
          count: count,
          testId: '',
          medium: test.medium,
          apiKey: selectedKey.key,
          modelName: selectedModel,
          onProgress: onProgress,
        );
      }

      if (aiService.estimatedTokensUsed > 0) {
        try {
          await SupabaseService().incrementTokenUsage(
            selectedKey.id,
            aiService.estimatedTokensUsed,
          );
          ref.invalidate(apiKeysProvider);
          // ignore: empty_catches
        } catch (_) {}
      }

      // Snap to full before navigating
      if (mounted) setState(() => _generatedCount = questions.length);

      await Future.delayed(const Duration(milliseconds: 400));

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AppGradientBackground(
            child: Stack(
              children: [
                // Ambient colour blobs so the glass has something to refract.
                _ambientBlob(
                  top: -60,
                  left: -70,
                  size: 260,
                  color: AppColors.primary,
                  opacity: 0.35,
                ),
                _ambientBlob(
                  top: 320,
                  right: -90,
                  size: 260,
                  color: AppColors.secondary,
                  opacity: 0.26,
                ),
                _ambientBlob(
                  bottom: 30,
                  left: -80,
                  size: 240,
                  color: AppColors.accent,
                  opacity: 0.26,
                ),
                SafeArea(
                  child: AnimatedPage(
                    child: Column(
                      children: [
                        _buildHeader(),
                        _buildStepper(),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 280),
                                  switchInCurve: Curves.easeOutCubic,
                                  transitionBuilder: (child, anim) =>
                                      FadeTransition(
                                        opacity: anim,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0, 0.03),
                                            end: Offset.zero,
                                          ).animate(anim),
                                          child: child,
                                        ),
                                      ),
                                  child: KeyedSubtree(
                                    key: ValueKey(_currentStep),
                                    child: _currentStep == 0
                                        ? _buildStepOne()
                                        : _buildStepTwo(),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                _buildNavigationButtons(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _ambientBlob({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required Color color,
    required double opacity,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withOpacity(opacity), color.withOpacity(0.0)],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: _GlassCard(
        radius: 26,
        blur: 26,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Tooltip(
              message: 'Back',
              child: _GlassCard(
                radius: 15,
                blur: 12,
                padding: const EdgeInsets.all(10),
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Create New Test',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _currentStep == 0
                        ? 'Step 1 of 2 · Configure'
                        : 'Step 2 of 2 · Generate',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: AppColors.primaryGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withOpacity(0.8)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Loading overlay ──────────────────────────────────────────────────────

  Widget _buildLoadingOverlay() {
    final progress = _targetCount == 0
        ? 0.0
        : (_generatedCount / _targetCount).clamp(0.0, 1.0);
    final percent = (progress * 100).round();

    // Dynamic status message based on progress
    final String statusMsg;
    if (_generatedCount == 0) {
      statusMsg = 'Preparing batches...';
    } else if (progress < 0.5) {
      statusMsg = 'Generating questions in parallel...';
    } else if (progress < 1.0) {
      statusMsg = 'Almost there, finishing up...';
    } else {
      statusMsg = 'All questions ready!';
    }

    final done = progress >= 1.0;

    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          color: Colors.white.withOpacity(0.40),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _GlassCard(
                radius: 34,
                blur: 26,
                padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Spinner / done check
                    SizedBox(
                      height: 64,
                      child: done
                          ? TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) =>
                            Transform.scale(scale: value, child: child),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 60,
                        ),
                      )
                          : ScaleTransition(
                        scale: _pulseAnimation,
                        child: const SpinKitCubeGrid(
                          color: AppColors.primary,
                          size: 56,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'AI is crafting your questions...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        statusMsg,
                        key: ValueKey(statusMsg),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),

                    // Glass progress track
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: progress),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: value.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: value >= 1.0
                                          ? [
                                        AppColors.success,
                                        const Color(0xFF34D399),
                                      ]
                                          : AppColors.primaryGradient,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Percentage — animated number flip
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.5),
                          end: Offset.zero,
                        ).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: Text(
                        '$percent%',
                        key: ValueKey(percent),
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: done ? AppColors.success : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Real question count — animated number flip
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, animation) => SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.6),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          ),
                        ),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: Text(
                        '$_generatedCount of $_targetCount questions generated',
                        key: ValueKey(_generatedCount),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Stepper ──────────────────────────────────────────────────────────────

  Widget _buildStepper() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(44, 16, 44, 12),
      child: Row(
        children: [
          _buildStepIndicator(0, 'Configure', Icons.settings_rounded),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22, left: 10, right: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    colors: _currentStep == 1
                        ? AppColors.primaryGradient
                        : [
                      Colors.white.withOpacity(0.7),
                      Colors.white.withOpacity(0.45),
                    ],
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                ),
              ),
            ),
          ),
          _buildStepIndicator(1, 'Generate', Icons.auto_awesome_rounded),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, IconData icon) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;
    final filled = isActive || isCompleted;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: filled
                ? const LinearGradient(
              colors: AppColors.primaryGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : LinearGradient(
              colors: [
                Colors.white.withOpacity(0.70),
                Colors.white.withOpacity(0.30),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(filled ? 0.85 : 0.7),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: (filled ? AppColors.primary : Colors.black).withOpacity(
                  filled ? 0.35 : 0.06,
                ),
                blurRadius: filled ? 16 : 8,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            isCompleted ? Icons.check_rounded : icon,
            color: filled ? Colors.white : AppColors.textMuted,
            size: 21,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            color: isActive ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  // ── Step 1 ───────────────────────────────────────────────────────────────

  Widget _buildStepOne() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Target Students', 'Select class and medium'),
        const SizedBox(height: 14),
        _GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChoiceGroup(
                'Standard',
                Icons.school_rounded,
                _allowedStandards,
                selectedClass,
                    (val) => setState(() => selectedClass = val),
              ),
              if (_allowedDivisions.isNotEmpty) ...[
                _glassDivider(),
                _buildChoiceGroup(
                  'Division',
                  Icons.meeting_room_rounded,
                  ['All', ..._allowedDivisions],
                  selectedDivision ?? 'All',
                      (val) =>
                      setState(() => selectedDivision = val == 'All' ? null : val),
                ),
              ],
              _glassDivider(),
              _buildChoiceGroup(
                'Medium',
                Icons.translate_rounded,
                _allowedMediums,
                selectedMedium,
                    (val) => setState(() => selectedMedium = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _buildSectionTitle('Exam Details', 'Choose level and subject'),
        const SizedBox(height: 14),
        _GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Competition Level'),
              _buildSegmentedButton(const [
                'Boards / GUJCET',
                'NEET',
                'JEE',
              ], selectedLevel, _onLevelChanged),
              const SizedBox(height: 22),
              _buildLabel('Subject'),
              DropdownButtonFormField<String>(
                value: selectedSubject,
                dropdownColor: Colors.white.withOpacity(0.96),
                borderRadius: BorderRadius.circular(20),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _fieldDecoration(icon: Icons.book_rounded),
                items: _getAvailableSubjects(
                  selectedLevel,
                ).map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => selectedSubject = val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 2 ───────────────────────────────────────────────────────────────

  Widget _buildStepTwo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Source Material',
          'How should AI generate questions?',
        ),
        const SizedBox(height: 14),
        _GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Generation Mode'),
              _buildSegmentedButton(
                const ['By Topic', 'By PDF'],
                genMode == GenerationMode.topic ? 'By Topic' : 'By PDF',
                    (val) => setState(
                      () => genMode = val == 'By Topic'
                      ? GenerationMode.topic
                      : GenerationMode.pdf,
                ),
              ),
              const SizedBox(height: 22),
              if (genMode == GenerationMode.topic) ...[
                _buildLabel('Main Topic'),
                TextField(
                  controller: _topicController,
                  decoration: _fieldDecoration(
                    hint: "e.g. Newton's Laws of Motion",
                    icon: Icons.topic_rounded,
                  ),
                ),
              ] else ...[
                _buildLabel('Reference Document'),
                _buildPdfPicker(),
                const SizedBox(height: 16),
                _buildLabel('Focus Area (Optional)'),
                TextField(
                  controller: _topicHintController,
                  decoration: _fieldDecoration(
                    hint: 'e.g. Focus on Page 12-15',
                    icon: Icons.lightbulb_outline_rounded,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
        _buildSectionTitle('Test Parameters', 'Set quantity and time limit'),
        const SizedBox(height: 14),
        _GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Question Count'),
                        TextField(
                          controller: _mcqCountController,
                          keyboardType: TextInputType.number,
                          decoration: _fieldDecoration(
                            hint: '10',
                            icon: Icons.numbers_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Duration (min)'),
                        TextField(
                          controller: _durationController,
                          keyboardType: TextInputType.number,
                          decoration: _fieldDecoration(
                            hint: '30',
                            icon: Icons.timer_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _buildLabel('AI Engine'),
              DropdownButtonFormField<String>(
                value: selectedModel,
                isExpanded: true,
                dropdownColor: Colors.white.withOpacity(0.96),
                borderRadius: BorderRadius.circular(20),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _fieldDecoration(icon: Icons.psychology_rounded),
                items:
                [
                  {
                    'name': 'Gemini 2.5 Flash (Fast)',
                    'id': 'gemini-2.5-flash',
                  },
                  {
                    'name': 'Gemini 2.5 Flash Lite (Light)',
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
                onChanged: (val) => setState(() => selectedModel = val!),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── PDF picker ───────────────────────────────────────────────────────────

  Widget _buildPdfPicker() {
    final picked = selectedPdf != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _pickPdf,
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: picked
                      ? [
                    AppColors.primary.withOpacity(0.18),
                    AppColors.primary.withOpacity(0.06),
                  ]
                      : [
                    Colors.white.withOpacity(0.60),
                    Colors.white.withOpacity(0.28),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: picked
                      ? AppColors.primary.withOpacity(0.7)
                      : Colors.white.withOpacity(0.85),
                  width: picked ? 1.6 : 1.2,
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      gradient: picked
                          ? const LinearGradient(
                        colors: AppColors.primaryGradient,
                      )
                          : null,
                      color: picked ? null : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.8)),
                    ),
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: picked ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedPdf?.name ?? 'Select PDF File',
                          style: TextStyle(
                            color: picked
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            fontWeight: picked
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          picked
                              ? '${(selectedPdf!.size / 1024 / 1024).toStringAsFixed(2)} MB'
                              : 'Tap to browse your files',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    picked
                        ? Icons.check_circle_rounded
                        : Icons.upload_file_rounded,
                    color: picked ? AppColors.primary : AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Navigation buttons ───────────────────────────────────────────────────

  Widget _buildNavigationButtons() {
    final isFirst = _currentStep == 0;

    return Row(
      children: [
        if (!isFirst) ...[
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Material(
                  color: Colors.white.withOpacity(0.45),
                  child: InkWell(
                    onTap: () => setState(() => _currentStep = 0),
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.85),
                          width: 1.2,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.arrow_back_rounded,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Back',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: AppColors.primaryGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.55)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.38),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // top sheen
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 28,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.28),
                              Colors.white.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isFirst
                          ? () => setState(() => _currentStep = 1)
                          : _generateQuestions,
                      child: SizedBox(
                        height: 56,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isFirst ? 'Continue' : 'Generate Test',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isFirst
                                  ? Icons.arrow_forward_rounded
                                  : Icons.auto_awesome_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Shared UI helpers ────────────────────────────────────────────────────

  InputDecoration _fieldDecoration({String? hint, required IconData icon}) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c, width: w),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.primary.withOpacity(0.75)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.55),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: border(Colors.white.withOpacity(0.85), 1.2),
      enabledBorder: border(Colors.white.withOpacity(0.85), 1.2),
      focusedBorder: border(AppColors.primary, 1.6),
    );
  }

  Widget _glassDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.0),
              Colors.white.withOpacity(0.9),
              Colors.white.withOpacity(0.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
    );
  }

  /// Label (with icon) on top, glass pill options wrapping underneath.
  /// Wrapping avoids overflow when there are many divisions / mediums.
  Widget _buildChoiceGroup(
      String label,
      IconData icon,
      List<String> options,
      String? selected,
      Function(String) onSelect,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((opt) {
            final isSelected = opt == selected;
            return GestureDetector(
              onTap: () => onSelect(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                    colors: AppColors.primaryGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.62),
                      Colors.white.withOpacity(0.28),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(isSelected ? 0.8 : 0.75),
                  ),
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                      : [],
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSegmentedButton(
      List<String> options,
      String? selected,
      Function(String) onSelect,
      ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.55),
                Colors.white.withOpacity(0.22),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.8)),
          ),
          child: Row(
            children: options.map((opt) {
              final isSelected = opt == selected;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(opt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                        colors: AppColors.primaryGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                          : null,
                      borderRadius: BorderRadius.circular(14),
                      border: isSelected
                          ? Border.all(color: Colors.white.withOpacity(0.6))
                          : null,
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        opt,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Dispose ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _pulseController.dispose();
    _topicController.dispose();
    _topicHintController.dispose();
    _mcqCountController.dispose();
    _durationController.dispose();
    super.dispose();
  }
}