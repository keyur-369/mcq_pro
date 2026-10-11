import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/animated_page.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/features/student/screens/result_screen.dart';
import 'package:mcq_test_app/models/test.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test History'),
      ),
      body: AppGradientBackground(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: SupabaseService().getStudentHistory(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final attempts = snapshot.data ?? [];
            if (attempts.isEmpty) {
              return const Center(
                child: Text(
                  'No past tests found.',
                  style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                ),
              );
            }

            return AnimatedPage(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: attempts.length,
                itemBuilder: (context, index) {
                  final attempt = attempts[index];
                  dynamic rawTestData = attempt['tests'];
                  Map<String, dynamic>? testData;
                  if (rawTestData is Map<String, dynamic>) {
                    testData = rawTestData;
                  } else if (rawTestData is List && rawTestData.isNotEmpty && rawTestData.first is Map<String, dynamic>) {
                    testData = rawTestData.first as Map<String, dynamic>;
                  }

                  // Handle case where test data might be missing (deleted test)
                  if (testData == null) {
                    return const SizedBox.shrink();
                  }

                  final attemptId = attempt['id']?.toString() ?? '';
                  final testId = testData['id']?.toString() ?? '';
                  final subject = testData['subject']?.toString() ?? 'Unknown Subject';
                  final topic = testData['topic']?.toString() ?? 'Unknown Topic';
                  final score = (attempt['score'] is int)
                      ? attempt['score'] as int
                      : (int.tryParse(attempt['score']?.toString() ?? '') ?? 0);
                  final submittedAtStr = attempt['submitted_at']?.toString();

                  DateTime? submittedAt;
                  if (submittedAtStr != null) {
                    submittedAt = DateTime.tryParse(submittedAtStr);
                  }

                  final testModel = Test.fromMap(testData);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text('$subject: $topic', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            'Score: $score',
                            style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          if (submittedAt != null)
                            Text(
                              'Date: ${DateFormat.yMMMd().add_jm().format(submittedAt.toLocal())}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _openResultPreview(context, attemptId, testId, score, test: testModel),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          minimumSize: const Size(0, 36),
                        ),
                        child: const Text('Review'),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _openResultPreview(BuildContext context, String attemptId, String testId, int score, {Test? test}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final supabase = SupabaseService();
      final questions = await supabase.getTestQuestions(testId);
      final selectedAnswers = await supabase.getAttemptAnswers(attemptId);

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              score: score,
              total: questions.length,
              questions: questions,
              selectedAnswers: selectedAnswers,
              test: test,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load test details: $e')),
        );
      }
    }
  }
}
