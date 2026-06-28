import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/animated_page.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/core/widgets/formula_text.dart';
import 'package:mcq_test_app/models/test.dart';
import 'package:mcq_test_app/models/question.dart';
import 'package:mcq_test_app/features/student/screens/result_screen.dart';

class TestTakingScreen extends StatefulWidget {
  final Test test;
  const TestTakingScreen({super.key, required this.test});

  @override
  State<TestTakingScreen> createState() => _TestTakingScreenState();
}

class _TestTakingScreenState extends State<TestTakingScreen>
    with WidgetsBindingObserver {
  late int _remainingSeconds;
  Timer? _timer;
  int _currentQuestionIndex = 0;
  final Map<String, String> _selectedAnswers = {};
  List<Question> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.test.duration * 60;
    WidgetsBinding.instance.addObserver(this);
    _loadQuestions();
  }

  void _loadQuestions() async {
    try {
      final questions = await SupabaseService().getTestQuestions(widget.test.id);
      if (mounted) {
        setState(() {
          _questions = questions;
          _isLoading = false;
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load questions: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _submitTest();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _submitTest();
        }
      });
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _submitTest() async {
    _timer?.cancel();
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      int score = 0;
      for (var q in _questions) {
        if (_selectedAnswers[q.id] == q.correctAnswer) score++;
      }

      await SupabaseService().submitAttempt(
        testId: widget.test.id,
        score: score,
        selectedAnswers: _selectedAnswers,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              score: score,
              total: _questions.length,
              questions: _questions,
              selectedAnswers: _selectedAnswers,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isLoading = false);
        _startTimer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _questions.isEmpty
        ? 0.0
        : (_currentQuestionIndex + 1) / _questions.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot exit test once started!'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
              'Question ${_currentQuestionIndex + 1} of ${_questions.length}'),
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _remainingSeconds < 60
                    ? AppColors.error.withOpacity(0.1)
                    : AppColors.cardLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _remainingSeconds < 60
                      ? AppColors.error
                      : AppColors.border,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: _remainingSeconds < 60
                        ? AppColors.error
                        : AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: TextStyle(
                      color: _remainingSeconds < 60
                          ? AppColors.error
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: AppGradientBackground(
          child: _isLoading && _questions.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
            child: AnimatedPage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor: AppColors.cardLight,
                            valueColor:
                            const AlwaysStoppedAnimation<Color>(
                                AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(progress * 100).toInt()}% completed',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_questions.isNotEmpty)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ✅ Formula-aware question card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                    color: AppColors.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: FormulaText(
                                _questions[_currentQuestionIndex]
                                    .questionText,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  height: 1.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            ..._buildOptions(
                                _questions[_currentQuestionIndex]),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: const Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              if (_currentQuestionIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        setState(() => _currentQuestionIndex--),
                    child: const Text('Back'),
                  ),
                ),
              if (_currentQuestionIndex > 0) const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                    if (_currentQuestionIndex <
                        _questions.length - 1) {
                      setState(() => _currentQuestionIndex++);
                    } else {
                      _showSubmitDialog();
                    }
                  },
                  child: Text(
                    _currentQuestionIndex < _questions.length - 1
                        ? 'Next Question'
                        : 'Finish Test',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSubmitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Submit Test?'),
        content: const Text(
            'You are about to finish the test. Are you sure you want to submit your answers?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Review')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitTest();
            },
            style:
            ElevatedButton.styleFrom(minimumSize: const Size(100, 45)),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOptions(Question question) {
    final options = {
      'A': question.optionA,
      'B': question.optionB,
      'C': question.optionC,
      'D': question.optionD,
    };

    return options.entries.map((entry) {
      final isSelected = _selectedAnswers[question.id] == entry.key;
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GestureDetector(
          onTap: () =>
              setState(() => _selectedAnswers[question.id] = entry.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:
              isSelected ? AppColors.primarySoft : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textMuted,
                      width: 2,
                    ),
                    color: isSelected
                        ? AppColors.primary
                        : Colors.transparent,
                  ),
                  child: Center(
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  // ✅ Formula-aware option text
                  child: FormulaText(
                    entry.value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary, size: 24),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }
}