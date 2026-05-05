import 'package:flutter/material.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';
import 'package:mcq_test_app/core/widgets/app_section_title.dart';
import 'package:mcq_test_app/features/student/screens/test_taking_screen.dart';
import 'package:mcq_test_app/features/student/screens/result_screen.dart';
import 'package:mcq_test_app/features/auth/screens/login_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final TextEditingController _testIdController = TextEditingController();
  bool _isJoiningById = false;

  @override
  void dispose() {
    _testIdController.dispose();
    super.dispose();
  }

  Future<void> _joinTestById({
    required BuildContext context,
    required int studentClass,
    required String studentDivision,
  }) async {
    final enteredCode = _testIdController.text.trim();
    if (enteredCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter test ID')),
      );
      return;
    }

    setState(() => _isJoiningById = true);
    final supabase = SupabaseService();

    try {
      final test = await supabase.getPublishedTestByCode(enteredCode);
      if (!mounted) return;

      if (test == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid test ID or test not published')),
        );
        return;
      }

      if (test.studentClass != studentClass.toString()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This test is not for your class')),
        );
        return;
      }

      if (test.division != null && test.division != studentDivision) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This test is not for your division')),
        );
        return;
      }

      final alreadyAttempted = await supabase.hasAttemptedTest(test.id);
      if (!mounted) return;
      if (alreadyAttempted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already attempted this test')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TestTakingScreen(test: test)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to join test: $e')),
      );
    } finally {
      if (mounted) setState(() => _isJoiningById = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabase = SupabaseService();
    final user = supabase.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(
            onPressed: () async {
              await supabase.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: user == null 
          ? const Center(child: Text('Please login'))
          : FutureBuilder<Map<String, dynamic>?>(
              future: supabase.getUserProfile(user.id),
              builder: (context, profileSnapshot) {
                if (profileSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final profile = profileSnapshot.data;
                final studentClass = profile?['class'] ?? 11;
                final studentDiv = profile?['division'] ?? 'A';
                final studentGroup = profile?['student_group'] ?? 'No Group';

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildWelcomeHeader(
                      context,
                      profile?['name'] ?? profile?['email']?.split('@')[0] ?? 'Student',
                      studentClass,
                      studentDiv,
                      studentGroup,
                    ),
                    const SizedBox(height: 20),
                    _buildHistorySummary(),
                    const SizedBox(height: 20),
                    _buildJoinWithTestIdCard(
                      context: context,
                      studentClass: studentClass,
                      studentDivision: studentDiv,
                    ),
                    const SizedBox(height: 24),
                    const AppSectionTitle(title: 'Attempted Tests'),
                    const SizedBox(height: 16),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: supabase.getStudentHistory(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: Text('Error: ${snapshot.error}')),
                          );
                        }

                        final attempts = snapshot.data ?? [];

                        if (attempts.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text('No attempted tests yet.'),
                            ),
                          );
                        }

                        return Column(
                          children: attempts
                              .map((attempt) => _buildAttemptCard(attempt))
                              .toList(),
                        );
                      },
                    ),
                  ],
                );
              }
            ),
    );
  }

  Widget _buildJoinWithTestIdCard({
    required BuildContext context,
    required int studentClass,
    required String studentDivision,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Join Test with ID',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask your teacher for the Test ID and enter it here.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _testIdController,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(
                    hintText: 'e.g. a1b2c3',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isJoiningById
                      ? null
                      : () => _joinTestById(
                            context: context,
                            studentClass: studentClass,
                            studentDivision: studentDivision,
                          ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(72, 48),
                  ),
                  child: _isJoiningById
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Join'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(
    BuildContext context,
    String name,
    int className,
    String division,
    String group,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, $name',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          'Class $className | Division $division | $group',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildHistorySummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Overall Progress', style: TextStyle(color: Colors.white70)),
              Text('85%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          Icon(Icons.auto_graph, size: 48, color: Colors.white54),
        ],
      ),
    );
  }

  Widget _buildAttemptCard(Map<String, dynamic> attempt) {
    final testData = attempt['tests'] as Map<String, dynamic>?;
    final subject = (testData?['subject'] ?? 'Unknown').toString();
    final topic = (testData?['topic'] ?? 'Untitled').toString();
    final duration = testData?['duration']?.toString() ?? '-';
    final level = (testData?['level'] ?? '').toString().toUpperCase();
    final score = attempt['score']?.toString() ?? '0';
    final submittedAtRaw = attempt['submitted_at']?.toString();
    final submittedOn = submittedAtRaw == null || submittedAtRaw.isEmpty
        ? '-'
        : submittedAtRaw.split('T').first;

    final attemptId = attempt['id']?.toString();
    final testId = testData?['id']?.toString();
    final parsedScore = int.tryParse(score) ?? 0;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      onTap: (attemptId == null || testId == null)
          ? null
          : () => _openResultPreview(
                context,
                attemptId: attemptId,
                testId: testId,
                score: parsedScore,
              ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$subject: $topic',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Score: $score',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('Duration: $duration mins'),
                const SizedBox(height: 4),
                Text('Submitted: $submittedOn'),
                const SizedBox(height: 4),
                const Text(
                  'Tap card to review answers',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildLevelBadge(level),
        ],
      ),
    );
  }

  Future<void> _openResultPreview(
    BuildContext context, {
    required String attemptId,
    required String testId,
    required int score,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final supabase = SupabaseService();
      final questions = await supabase.getTestQuestions(testId);
      final selectedAnswers = await supabase.getAttemptAnswers(attemptId);

      if (!context.mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            score: score,
            total: questions.length,
            questions: questions,
            selectedAnswers: selectedAnswers,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load test details: $e')),
      );
    }
  }

  Widget _buildLevelBadge(String level) {
    Color color = AppColors.boardGreen;
    if (level == 'NEET') color = AppColors.orange;
    if (level == 'JEE') color = AppColors.jeeRed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        level,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
