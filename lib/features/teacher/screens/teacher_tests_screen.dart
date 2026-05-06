import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/animated_page.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/models/test.dart';
import 'package:mcq_test_app/features/teacher/screens/question_preview_screen.dart';

class TeacherTestsScreen extends StatelessWidget {
  final String status; // 'draft' or 'published'
  const TeacherTestsScreen({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final supabase = SupabaseService();
    final user = supabase.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(status == 'draft' ? 'Draft Tests' : 'Published Tests'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AppGradientBackground(
        child: user == null
            ? const Center(child: Text('Please login'))
            : FutureBuilder<List<Test>>(
                future: supabase.getTeacherTests(user.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.error)));
                  }

                  final allTests = snapshot.data ?? [];
                  final tests = allTests.where((t) => t.status.name == status).toList();

                  if (tests.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            status == 'draft' ? Icons.edit_document : Icons.rocket_launch_rounded,
                            size: 80,
                            color: AppColors.textMuted.withOpacity(0.2),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No ${status} tests found',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 18, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    );
                  }

                  return AnimatedPage(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 110, 24, 24),
                      itemCount: tests.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final test = tests[index];
                        return _buildTestCard(context, test, supabase);
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildTestCard(BuildContext context, Test test, SupabaseService supabase) {
    final accentColor = status == 'draft' ? AppColors.secondary : AppColors.success;

    return AppCard(
      onTap: status == 'draft' ? () async {
        final questions = await supabase.getTestQuestions(test.id);
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QuestionPreviewScreen(test: test, questions: questions),
            ),
          );
        }
      } : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  status == 'draft' ? Icons.edit_note_rounded : Icons.check_circle_rounded,
                  color: accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${test.subject}: ${test.topic}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Class ${test.studentClass} • ${test.duration} mins',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (test.testCode != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Text('Test ID: ', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                  Text(test.testCode!, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: test.testCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ID copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
