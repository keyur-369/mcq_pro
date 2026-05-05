import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
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
      appBar: AppBar(
        title: Text(status == 'draft' ? 'My Drafts' : 'Published Tests'),
      ),
      body: user == null
          ? const Center(child: Text('Please login'))
          : FutureBuilder<List<Test>>(
              future: supabase.getTeacherTests(user.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final allTests = snapshot.data ?? [];
                final tests = allTests.where((t) => t.status.name == status).toList();

                if (tests.isEmpty) {
                  final onSurface = Theme.of(context).colorScheme.onSurface;
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          status == 'draft' ? Icons.edit_note : Icons.cloud_done,
                          size: 64,
                          color: onSurface.withValues(alpha: 0.25),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No ${status}s found',
                          style: TextStyle(color: onSurface.withValues(alpha: 0.55)),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tests.length,
                  itemBuilder: (context, index) {
                    final test = tests[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text('${test.subject}: ${test.topic}'),
                        subtitle: Row(
                          children: [
                            Text('ID: ${test.testCode ?? 'N/A'}'),
                            if (test.testCode != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: test.testCode!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('ID copied!')),
                                    );
                                  },
                                  child: const Icon(Icons.copy, size: 14, color: AppColors.purple),
                                ),
                              ),
                            const Text(' | Class '),
                            Text(test.studentClass),
                            Text(' | ${test.duration} mins'),
                          ],
                        ),
                        trailing: Icon(
                          status == 'draft' ? Icons.chevron_right : Icons.check_circle,
                          color: status == 'draft' ? AppColors.orange : AppColors.boardGreen,
                        ),
                        onTap: () async {
                          if (status == 'draft') {
                            final questions = await supabase.getTestQuestions(test.id);
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => QuestionPreviewScreen(
                                    test: test,
                                    questions: questions,
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
