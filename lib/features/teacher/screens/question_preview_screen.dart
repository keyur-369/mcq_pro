import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/animated_page.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/core/widgets/app_section_title.dart';
import 'package:mcq_test_app/models/question.dart';
import 'package:mcq_test_app/models/test.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class QuestionPreviewScreen extends StatefulWidget {
  final Test test;
  final List<Question> questions;
  const QuestionPreviewScreen({super.key, required this.test, required this.questions});

  @override
  State<QuestionPreviewScreen> createState() => _QuestionPreviewScreenState();
}

class _QuestionPreviewScreenState extends State<QuestionPreviewScreen> {
  late List<Question> _questions;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _questions = List.from(widget.questions);
  }

  void _saveTest(TestStatus status) async {
    setState(() => _isLoading = true);
    try {
      final supabase = SupabaseService();
      
      String testId;
      if (widget.test.id.isNotEmpty) {
        testId = widget.test.id;
        await supabase.updateTest(testId, status);
      } else {
        final testToSave = Test(
          teacherId: widget.test.teacherId,
          studentClass: widget.test.studentClass,
          medium: widget.test.medium,
          subject: widget.test.subject,
          topic: widget.test.topic,
          level: widget.test.level,
          duration: widget.test.duration,
          testCode: widget.test.testCode,
          status: status,
        );
        testId = await supabase.createTest(testToSave);

        final finalQuestions = _questions.map((q) => Question(
          testId: testId,
          questionText: q.questionText,
          optionA: q.optionA,
          optionB: q.optionB,
          optionC: q.optionC,
          optionD: q.optionD,
          correctAnswer: q.correctAnswer,
          explanation: q.explanation,
        )).toList();
        await supabase.saveQuestions(finalQuestions);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test ${status == TestStatus.published ? 'published' : 'saved as draft'} successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Review Questions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AppGradientBackground(
        child: Stack(
          children: [
            SafeArea(
              child: AnimatedPage(
                child: ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: _questions.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildTestInfoCard();
                    return _buildQuestionCard(_questions[index - 1], index - 1);
                  },
                ),
              ),
            ),
            if (_isLoading) _buildLoadingOverlay(),
          ],
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
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => _saveTest(TestStatus.draft),
                child: const Text('Draft'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _saveTest(TestStatus.published),
                child: const Text('Publish Test'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestInfoCard() {
    return AppCard(
      color: AppColors.primarySoft,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.vpn_key_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Unique Test ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      widget.test.testCode ?? 'N/A',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                      onPressed: () {
                        if (widget.test.testCode != null) {
                          Clipboard.setData(ClipboardData(text: widget.test.testCode!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Test ID copied!')),
                          );
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Question question, int index) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 13),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_note_rounded, size: 22, color: AppColors.textSecondary),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 22, color: AppColors.error),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question.questionText,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.4),
          ),
          const SizedBox(height: 20),
          _buildOption('A', question.optionA, question.correctAnswer == 'A'),
          _buildOption('B', question.optionB, question.correctAnswer == 'B'),
          _buildOption('C', question.optionC, question.correctAnswer == 'C'),
          _buildOption('D', question.optionD, question.correctAnswer == 'D'),
          if (question.explanation.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Explanation', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.textSecondary, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text(question.explanation, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOption(String label, String text, bool isCorrect) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isCorrect ? AppColors.success : AppColors.cardLight,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isCorrect ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isCorrect ? AppColors.success : AppColors.textPrimary,
                fontWeight: isCorrect ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (isCorrect) const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.white.withOpacity(0.8),
      child: const Center(
        child: SpinKitFadingCube(color: AppColors.primary, size: 40.0),
      ),
    );
  }
}
