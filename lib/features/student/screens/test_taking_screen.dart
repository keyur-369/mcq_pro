import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/models/test.dart';
import 'package:mcq_test_app/models/question.dart';
import 'package:mcq_test_app/features/student/screens/result_screen.dart';

class TestTakingScreen extends StatefulWidget {
  final Test test;
  const TestTakingScreen({super.key, required this.test});

  @override
  State<TestTakingScreen> createState() => _TestTakingScreenState();
}

class _TestTakingScreenState extends State<TestTakingScreen> with WidgetsBindingObserver {
  late int _remainingSeconds;
  Timer? _timer;
  int _currentQuestionIndex = 0;
  final Map<String, String> _selectedAnswers = {}; // questionId: selectedOption
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
          SnackBar(content: Text('Failed to load questions: $e')),
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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _submitTest(); // Auto submit on minimize
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
        if (_selectedAnswers[q.id] == q.correctAnswer) {
          score++;
        }
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
          SnackBar(content: Text('Submission failed: $e')),
        );
        setState(() => _isLoading = false);
        _startTimer(); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Disable back button
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot exit test once started!')),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Q${_currentQuestionIndex + 1}/${_questions.isNotEmpty ? _questions.length : '-'}'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: AppColors.orange, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(_remainingSeconds),
                      style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: _questions.isEmpty ? 0 : (_currentQuestionIndex + 1) / _questions.length,
                    backgroundColor: AppColors.surface,
                    color: AppColors.purple,
                  ),
                  const SizedBox(height: 32),
                  if (_questions.isNotEmpty) 
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _questions[_currentQuestionIndex].questionText,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 32),
                            ..._buildOptions(_questions[_currentQuestionIndex]),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              if (_currentQuestionIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _currentQuestionIndex--),
                    child: const Text('Previous'),
                  ),
                ),
              if (_currentQuestionIndex > 0) const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_currentQuestionIndex < _questions.length - 1) {
                            setState(() => _currentQuestionIndex++);
                          } else {
                            _showSubmitDialog();
                          }
                        },
                  child: Text(_currentQuestionIndex < _questions.length - 1 ? 'Next' : 'Submit'),
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
        title: const Text('Submit Test'),
        content: const Text('Are you sure you want to submit your test?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: _submitTest, child: const Text('Submit')),
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
      return GestureDetector(
        onTap: () => setState(() => _selectedAnswers[question.id] = entry.key),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.purple.withOpacity(0.1) : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.purple : AppColors.surface,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: isSelected ? AppColors.purple : Colors.grey),
                  color: isSelected ? AppColors.purple : Colors.transparent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text('${entry.key}. ${entry.value}', style: const TextStyle(fontSize: 16))),
            ],
          ),
        ),
      );
    }).toList();
  }
}
