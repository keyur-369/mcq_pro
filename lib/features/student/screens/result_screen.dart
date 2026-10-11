import 'package:flutter/material.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/pdf_export_service.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/animated_page.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/core/widgets/app_section_title.dart';
import 'package:mcq_test_app/models/question.dart';
import 'package:mcq_test_app/models/test.dart';
import 'package:mcq_test_app/features/student/screens/student_dashboard.dart';

class ResultScreen extends StatefulWidget {
  final int score;
  final int total;
  final List<Question> questions;
  final Map<String, String> selectedAnswers;
  final Test? test;
  final String? studentName;
  final String? rollNumber;

  const ResultScreen({
    super.key,
    required this.score,
    required this.total,
    required this.questions,
    required this.selectedAnswers,
    this.test,
    this.studentName,
    this.rollNumber,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isDownloadingPdf = false;

  void _downloadSolutionsPdf() async {
    setState(() => _isDownloadingPdf = true);
    try {
      final supabase = SupabaseService();
      final user = supabase.currentUser;

      String name = widget.studentName ?? 'Student';
      String rollNo = widget.rollNumber ?? 'N/A';

      if (user != null && (widget.studentName == null || widget.rollNumber == null)) {
        final profile = await supabase.getUserProfile(user.id);
        if (profile != null) {
          name = profile.name ?? profile.email;
          rollNo = profile.rollNo ?? 'N/A';
        }
      }

      final fallbackTest = widget.test ?? Test(
        teacherId: '',
        studentClass: '11',
        medium: 'English',
        subject: 'General Assessment',
        topic: 'Test Solutions',
        level: 'Boards',
        duration: 30,
        status: TestStatus.published,
      );

      final filePath = await PdfExportService.generateAndSaveSolutionPdf(
        test: fallbackTest,
        questions: widget.questions,
        selectedAnswers: widget.selectedAnswers,
        score: widget.score,
        total: widget.total,
        studentName: name,
        rollNumber: rollNo,
      );

      if (mounted) {
        if (filePath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 Solution report saved: $filePath'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download was cancelled')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF generation failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final percentage = widget.total == 0 ? 0.0 : (widget.score / widget.total) * 100;

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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                _buildScoreOverview(context, percentage),
                const SizedBox(height: 20),
                _buildAnalysisSummary(),
                const SizedBox(height: 24),

                // Download Test with Solutions Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isDownloadingPdf ? null : _downloadSolutionsPdf,
                    icon: _isDownloadingPdf
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Icon(Icons.picture_as_pdf_rounded, size: 22),
                    label: Text(
                      _isDownloadingPdf ? 'Generating PDF...' : 'Download Test with Solutions',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Back to Dashboard Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StudentDashboard(),
                      ),
                      (route) => false,
                    ),
                    icon: const Icon(Icons.home_rounded, size: 20),
                    label: const Text(
                      'Back to Dashboard',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Questions Review Header
                Row(
                  children: [
                    const AppSectionTitle(title: 'Review Questions'),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.questions.length} Qs',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.questions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    return _buildQuestionReview(
                      context,
                      widget.questions[index],
                      index + 1,
                    );
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
    final remark = percentage >= 80
        ? 'Exceptional Work!'
        : (percentage >= 50 ? 'Good Effort!' : 'Keep Practicing!');
    final remarkIcon = percentage >= 80
        ? Icons.emoji_events_rounded
        : (percentage >= 50
            ? Icons.thumb_up_rounded
            : Icons.trending_up_rounded);

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(remarkIcon, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        remark,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'You correctly answered ${widget.score} out of ${widget.total} questions.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: widget.total == 0 ? 0 : widget.score / widget.total,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
                Text(
                  '${widget.score}/${widget.total}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisSummary() {
    return Row(
      children: [
        Expanded(
          child: _statTile(
            icon: Icons.check_circle_rounded,
            color: AppColors.success,
            value: '${widget.score}',
            label: 'Correct',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _statTile(
            icon: Icons.cancel_rounded,
            color: AppColors.error,
            value: '${widget.total - widget.score}',
            label: 'Wrong',
          ),
        ),
      ],
    );
  }

  Widget _statTile({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return AppCard(
      color: color.withOpacity(0.05),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionReview(
    BuildContext context,
    Question question,
    int questionNumber,
  ) {
    final userAnswer = widget.selectedAnswers[question.id];
    final isCorrect = userAnswer == question.correctAnswer;
    final isUnanswered = userAnswer == null || userAnswer.isEmpty;

    Color statusColor = isCorrect
        ? AppColors.success
        : (isUnanswered ? AppColors.warning : AppColors.error);
    String statusText = isCorrect
        ? 'Correct'
        : (isUnanswered ? 'Unanswered' : 'Incorrect');
    IconData statusIcon = isCorrect
        ? Icons.check_circle_rounded
        : (isUnanswered ? Icons.remove_circle_rounded : Icons.cancel_rounded);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$questionNumber',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            question.questionText,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          _buildOptionRow('A', question.optionA, question.correctAnswer, userAnswer),
          const SizedBox(height: 8),
          _buildOptionRow('B', question.optionB, question.correctAnswer, userAnswer),
          const SizedBox(height: 8),
          _buildOptionRow('C', question.optionC, question.correctAnswer, userAnswer),
          const SizedBox(height: 8),
          _buildOptionRow('D', question.optionD, question.correctAnswer, userAnswer),
          if (question.explanation.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_rounded, color: AppColors.primary, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Explanation & Solution',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    question.explanation,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionRow(
    String key,
    String text,
    String correct,
    String? user,
  ) {
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: (isCorrect || isSelected) ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: textColor.withOpacity(
                (isCorrect || isSelected) ? 0.12 : 0.06,
              ),
              shape: BoxShape.circle,
            ),
            child: Text(
              key,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: textColor,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 13.5,
                fontWeight: (isCorrect || isSelected)
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
          if (icon != null) ...[
            const SizedBox(width: 8),
            Icon(icon, color: textColor, size: 17),
          ],
        ],
      ),
    );
  }
}
