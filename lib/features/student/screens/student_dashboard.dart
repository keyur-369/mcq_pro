import 'package:flutter/material.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/animated_page.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/core/widgets/app_section_title.dart';
import 'package:mcq_test_app/features/auth/screens/login_screen.dart';
import 'package:mcq_test_app/features/student/screens/history_screen.dart';
import 'package:mcq_test_app/features/student/screens/result_screen.dart';
import 'package:mcq_test_app/features/student/screens/test_taking_screen.dart';
import 'package:mcq_test_app/models/test.dart';

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
        const SnackBar(content: Text('Please enter test code')),
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
          const SnackBar(content: Text('Invalid test code or test is not published')),
        );
        return;
      }
      if (test.studentClass != studentClass.toString()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This test is not for your standard')),
        );
        return;
      }
      if (test.division != null && test.division!.isNotEmpty && test.division != studentDivision) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This test is not for your division')),
        );
        return;
      }

      final alreadyAttempted = await supabase.hasAttemptedTest(test.id);
      if (!mounted) return;
      if (alreadyAttempted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have already submitted this test.')),
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
        SnackBar(
          content: Text('Unable to join test: $e'),
          backgroundColor: AppColors.error,
        ),
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('MCQ Pro', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Test History',
          ),
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
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log Out',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppGradientBackground(
        child: user == null
            ? const Center(child: Text('Please login'))
            : FutureBuilder<Map<String, dynamic>?>(
                future: supabase.supabase.from('users').select().eq('id', user.id).maybeSingle(),
                builder: (context, profileSnapshot) {
                  if (profileSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final profile = profileSnapshot.data;
                  final studentClass = profile?['class'] ?? 11;
                  final studentDiv = profile?['division'] ?? 'A';
                  final studentMedium = profile?['medium'] ?? 'English';
                  final studentRoll = profile?['roll_no']?.toString() ?? 'Allocated';
                  final studentGroup = profile?['student_group'] ?? 'General';
                  final studentInst = profile?['institution'] ?? 'Sharda Mandir';

                  return AnimatedPage(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 100, 20, 24),
                      children: [
                        _buildWelcomeHeader(
                          context,
                          name: profile?['name'] ?? profile?['email']?.split('@')[0] ?? 'Student',
                          className: studentClass,
                          division: studentDiv,
                          medium: studentMedium,
                          rollNo: studentRoll,
                          institution: studentInst,
                        ),
                        const SizedBox(height: 20),

                        // Join test with code card
                        _buildJoinWithTestIdCard(
                          context: context,
                          studentClass: studentClass,
                          studentDivision: studentDiv,
                        ),
                        const SizedBox(height: 24),

                        // Available Tests Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const AppSectionTitle(title: 'Eligible Tests'),
                            TextButton.icon(
                              onPressed: () => setState(() {}),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Refresh'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<List<Test>>(
                          future: supabase.getAvailableTests(
                            studentClass: studentClass.toString(),
                            division: studentDiv,
                            medium: studentMedium,
                            studentGroup: studentGroup,
                          ),
                          builder: (context, testSnap) {
                            if (testSnap.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final tests = testSnap.data ?? [];
                            if (tests.isEmpty) {
                              return const AppCard(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.assignment_turned_in_outlined, size: 40, color: AppColors.textMuted),
                                      SizedBox(height: 10),
                                      Text(
                                        'No new tests pending for your class and medium.',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: tests.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final test = tests[index];
                                return Card(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 2,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.primarySoft,
                                      child: const Icon(Icons.quiz_rounded, color: AppColors.primary),
                                    ),
                                    title: Text(
                                      '${test.subject}: ${test.topic}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    subtitle: Text(
                                      'Duration: ${test.duration} min  •  Level: ${test.level.toUpperCase()}  •  ${test.medium}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                    trailing: ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => TestTakingScreen(test: test)),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: const Text('Start'),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 28),

                        // Recent Activity / Growth Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const AppSectionTitle(title: 'Recent Activity'),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                                );
                              },
                              child: const Text('View All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: supabase.getStudentHistory(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final attempts = snapshot.data ?? [];
                            if (attempts.isEmpty) {
                              return const AppCard(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: Text('No test attempts yet.', style: TextStyle(color: AppColors.textSecondary)),
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: attempts.take(3).length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) => _buildAttemptCard(attempts[index]),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildWelcomeHeader(
    BuildContext context, {
    required String name,
    required dynamic className,
    required String division,
    required String medium,
    required String rollNo,
    required String institution,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primary,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'S',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hey, $name 👋',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$institution • Std $className-$division ($medium)',
                    style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ],
              ),
            ),
            // Verified Roll Number Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text('ROLL NO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  Text(rollNo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildJoinWithTestIdCard({
    required BuildContext context,
    required int studentClass,
    required String studentDivision,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 10),
              Text('Enter Test Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _testIdController,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(
                    hintText: 'e.g. ab12cd',
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                  child: _isJoiningById
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
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

  Widget _buildAttemptCard(Map<String, dynamic> attempt) {
    final testData = attempt['tests'] as Map<String, dynamic>?;
    final subject = (testData?['subject'] ?? 'Unknown').toString();
    final topic = (testData?['topic'] ?? 'Untitled').toString();
    final score = attempt['score']?.toString() ?? '0';

    final attemptId = attempt['id']?.toString();
    final testId = testData?['id']?.toString();
    final parsedScore = int.tryParse(score) ?? 0;

    return AppCard(
      onTap: (attemptId == null || testId == null)
          ? null
          : () => _openResultPreview(
                context,
                attemptId: attemptId,
                testId: testId,
                score: parsedScore,
                test: testData != null ? Test.fromMap(testData) : null,
              ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment_turned_in_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$subject: $topic', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 3),
                Text('Score: $score pts', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Future<void> _openResultPreview(
    BuildContext context, {
    required String attemptId,
    required String testId,
    required int score,
    Test? test,
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
            test: test,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load test details: $e'), backgroundColor: AppColors.error),
      );
    }
  }
}
