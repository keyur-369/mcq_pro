import 'package:flutter/material.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/models/question.dart';
import 'package:mcq_test_app/features/student/screens/student_dashboard.dart';

class ResultScreen extends StatelessWidget {
  final int score;
  final int total;
  final List<Question> questions;
  final Map<String, String> selectedAnswers;

  const ResultScreen({
    super.key,
    required this.score,
    required this.total,
    required this.questions,
    required this.selectedAnswers,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total == 0 ? 0.0 : (score / total) * 100;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Results'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              'Test Submitted!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: total == 0 ? 0 : score / total,
                    strokeWidth: 12,
                    backgroundColor: AppColors.surface,
                    color: AppColors.purple,
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '$score/$total',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildStatRow('Correct Answers', '$score', AppColors.boardGreen),
            const SizedBox(height: 12),
            _buildStatRow('Wrong / Unanswered', '${total - score}', AppColors.jeeRed),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const StudentDashboard()),
                (route) => false,
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Back to Dashboard'),
            ),
            const SizedBox(height: 48),
            const Divider(color: AppColors.surface),
            const SizedBox(height: 24),
            const Text(
              'Test Review',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: questions.length,
              itemBuilder: (context, index) {
                return _buildQuestionReview(questions[index], index + 1);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionReview(Question question, int questionNumber) {
    final userAnswer = selectedAnswers[question.id];
    final isCorrect = userAnswer == question.correctAnswer;
    final isUnanswered = userAnswer == null;

    Color headerColor = isCorrect ? AppColors.boardGreen : AppColors.jeeRed;
    String statusText = isCorrect ? 'Correct' : (isUnanswered ? 'Unanswered' : 'Wrong');
    IconData statusIcon = isCorrect ? Icons.check_circle : (isUnanswered ? Icons.help_outline : Icons.cancel);

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: headerColor.withValues(alpha: 0.5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question $questionNumber',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Row(
                  children: [
                    Icon(statusIcon, color: headerColor, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(color: headerColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              question.questionText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            _buildOptionRow('A', question.optionA, question.correctAnswer, userAnswer),
            const SizedBox(height: 8),
            _buildOptionRow('B', question.optionB, question.correctAnswer, userAnswer),
            const SizedBox(height: 8),
            _buildOptionRow('C', question.optionC, question.correctAnswer, userAnswer),
            const SizedBox(height: 8),
            _buildOptionRow('D', question.optionD, question.correctAnswer, userAnswer),
            if (!isCorrect && question.explanation.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text('Explanation', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      question.explanation,
                      style: const TextStyle(height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRow(String optionKey, String optionText, String correctAnswer, String? userAnswer) {
    bool isCorrectOption = optionKey == correctAnswer;
    bool isSelectedOption = optionKey == userAnswer;

    Color optionColor = AppColors.surface;
    Color textColor = AppColors.textPrimary;
    IconData? icon;
    Color iconColor = Colors.transparent;

    if (isCorrectOption) {
      optionColor = AppColors.boardGreen.withValues(alpha: 0.12);
      textColor = AppColors.boardGreen;
      icon = Icons.check_circle;
      iconColor = AppColors.boardGreen;
    } else if (isSelectedOption && !isCorrectOption) {
      optionColor = AppColors.jeeRed.withValues(alpha: 0.12);
      textColor = AppColors.jeeRed;
      icon = Icons.cancel;
      iconColor = AppColors.jeeRed;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: optionColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (isCorrectOption || (isSelectedOption && !isCorrectOption)) 
              ? textColor.withValues(alpha: 0.45)
              : AppColors.surface,
        ),
      ),
      child: Row(
        children: [
          Text(
            '$optionKey. ',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          Expanded(
            child: Text(
              optionText,
              style: TextStyle(color: textColor),
            ),
          ),
          if (icon != null) ...[
            const SizedBox(width: 8),
            Icon(icon, color: iconColor, size: 20),
          ]
        ],
      ),
    );
  }
}
