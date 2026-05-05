import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
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

  @override
  void initState() {
    super.initState();
    _questions = List.from(widget.questions);
  }

  bool _isLoading = false;

  void _saveTest(TestStatus status) async {
    setState(() => _isLoading = true);
    try {
      final supabase = SupabaseService();
      
      String testId;
      if (widget.test.id.isNotEmpty) {
        // Update existing test status
        testId = widget.test.id;
        await supabase.updateTest(testId, status);
      } else {
        // Create new test
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

        // Save questions only for new tests (assuming drafts already have them)
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
          SnackBar(content: Text('Test ${status == TestStatus.published ? 'published' : 'saved as draft'} successfully!')),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Questions'),
      ),
      body: Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _questions.length,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  children: [
                    _buildTestInfoCard(),
                    _buildQuestionCard(_questions[index], index),
                  ],
                );
              }
              return _buildQuestionCard(_questions[index], index);
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: SpinKitPulse(color: AppColors.purple, size: 50.0),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => _saveTest(TestStatus.draft),
                child: const Text('Save as Draft'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
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
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      color: AppColors.purple.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.purple, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.vpn_key_outlined, color: AppColors.purple),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Unique Test ID',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Row(
                  children: [
                    Text(widget.test.testCode ?? 'N/A',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2)),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18, color: AppColors.purple),
                      onPressed: () {
                        if (widget.test.testCode != null) {
                          Clipboard.setData(ClipboardData(text: widget.test.testCode!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Test ID copied to clipboard!')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Question question, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.purple),
                ),
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () {}),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent), onPressed: () {}),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(question.questionText, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            _buildOption('A', question.optionA, question.correctAnswer == 'A'),
            _buildOption('B', question.optionB, question.correctAnswer == 'B'),
            _buildOption('C', question.optionC, question.correctAnswer == 'C'),
            _buildOption('D', question.optionD, question.correctAnswer == 'D'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Explanation:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(question.explanation, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(String label, String text, bool isCorrect) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCorrect ? AppColors.purple : AppColors.surface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
          if (isCorrect) const Icon(Icons.check_circle, color: AppColors.purple, size: 16),
        ],
      ),
    );
  }
}
