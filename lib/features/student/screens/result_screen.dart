import 'package:flutter/material.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/widgets/animated_page.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/core/widgets/app_section_title.dart';
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Performance Report'),
        automaticallyImplyLeading: false,
      ),
      body: AppGradientBackground(
        child: SafeArea(
          child: AnimatedPage(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              children: [
                _buildScoreOverview(context, percentage),
                const SizedBox(height: 32),
                const AppSectionTitle(title: 'Detailed Analysis'),
                const SizedBox(height: 16),
                _buildAnalysisSummary(),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const StudentDashboard()),
                      (route) => false,
                    ),
                    child: const Text('Back to Dashboard'),
                  ),
                ),
                const SizedBox(height: 48),
                const AppSectionTitle(title: 'Review Questions'),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: questions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    return _buildQuestionReview(context, questions[index], index + 1);
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreOverview(BuildContext context, double percentage) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: total == 0 ? 0 : score / total,
                  strokeWidth: 10,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              Column(
                children: [
                  Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  Text(
                    'SCORE',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.7), letterSpacing: 2),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            percentage >= 80 ? 'Exceptional Work!' : (percentage >= 50 ? 'Good Effort!' : 'Keep Practicing!'),
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'You correctly answered $score out of $total questions.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisSummary() {
    return Row(
      children: [
        Expanded(
          child: AppCard(
            color: AppColors.success.withOpacity(0.05),
            child: Column(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
                const SizedBox(height: 8),
                Text('$score', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.success)),
                const Text('Correct', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: AppCard(
            color: AppColors.error.withOpacity(0.05),
            child: Column(
              children: [
                const Icon(Icons.cancel_rounded, color: AppColors.error, size: 24),
                const SizedBox(height: 8),
                Text('${total - score}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.error)),
                const Text('Wrong', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionReview(BuildContext context, Question question, int questionNumber) {
    final userAnswer = selectedAnswers[question.id];
    final isCorrect = userAnswer == question.correctAnswer;
    final isUnanswered = userAnswer == null;

    Color statusColor = isCorrect ? AppColors.success : (isUnanswered ? AppColors.warning : AppColors.error);
    String statusText = isCorrect ? 'Correct' : (isUnanswered ? 'Unanswered' : 'Incorrect');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question $questionNumber',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            question.questionText,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.4),
          ),
          const SizedBox(height: 24),
          _buildOptionRow('A', question.optionA, question.correctAnswer, userAnswer),
          const SizedBox(height: 10),
          _buildOptionRow('B', question.optionB, question.correctAnswer, userAnswer),
          const SizedBox(height: 10),
          _buildOptionRow('C', question.optionC, question.correctAnswer, userAnswer),
          const SizedBox(height: 10),
          _buildOptionRow('D', question.optionD, question.correctAnswer, userAnswer),
          if (!isCorrect && question.explanation.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_rounded, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text('Explanation', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question.explanation,
                    style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionRow(String key, String text, String correct, String? user) {
    final isCorrect = key == correct;
    final isSelected = key == user;
    
    Color bgColor = AppColors.background;
    Color borderColor = AppColors.border;
    Color textColor = AppColors.textSecondary;
    IconData? icon;

    if (isCorrect) {
      bgColor = AppColors.success.withOpacity(0.05);
      borderColor = AppColors.success;
      textColor = AppColors.success;
      icon = Icons.check_circle_rounded;
    } else if (isSelected) {
      bgColor = AppColors.error.withOpacity(0.05);
      borderColor = AppColors.error;
      textColor = AppColors.error;
      icon = Icons.cancel_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Text('$key. ', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          Expanded(child: Text(text, style: TextStyle(color: textColor, fontWeight: (isCorrect || isSelected) ? FontWeight.bold : FontWeight.normal))),
          if (icon != null) Icon(icon, color: textColor, size: 18),
        ],
      ),
    );
  }
}
