import 'package:flutter/material.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/animated_page.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/core/widgets/app_section_title.dart';
import 'package:mcq_test_app/features/auth/screens/login_screen.dart';
import 'package:mcq_test_app/features/student/screens/result_screen.dart';
import 'package:mcq_test_app/features/student/screens/test_taking_screen.dart';

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
        title: const Text('Dashboard'),
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
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppGradientBackground(
        child: user == null
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

                  return AnimatedPage(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 110, 24, 24),
                      children: [
                        _buildWelcomeHeader(
                          context,
                          profile?['name'] ?? profile?['email']?.split('@')[0] ?? 'Student',
                          studentClass,
                          studentDiv,
                          studentGroup,
                        ),
                        const SizedBox(height: 24),
                        _buildJoinWithTestIdCard(
                          context: context,
                          studentClass: studentClass,
                          studentDivision: studentDiv,
                        ),
                        const SizedBox(height: 32),
                        const AppSectionTitle(title: 'Recent Activity'),
                        const SizedBox(height: 16),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: supabase.getStudentHistory(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            if (snapshot.hasError) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Center(child: Text('Error: ${snapshot.error}')),
                              );
                            }

                            final attempts = snapshot.data ?? [];
                            if (attempts.isEmpty) {
                              return AppCard(
                                child: Column(
                                  children: [
                                    Icon(Icons.assignment_turned_in_outlined, 
                                      size: 48, color: AppColors.textMuted),
                                    const SizedBox(height: 12),
                                    Text('No attempted tests yet', 
                                      style: TextStyle(color: AppColors.textSecondary)),
                                  ],
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: attempts.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
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

  Widget _buildJoinWithTestIdCard({
    required BuildContext context,
    required int studentClass,
    required String studentDivision,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.vpn_key_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Join New Test', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _testIdController,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(
                    hintText: 'Enter test code',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isJoiningById
                      ? null
                      : () => _joinTestById(
                            context: context,
                            studentClass: studentClass,
                            studentDivision: studentDivision,
                          ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    minimumSize: const Size(80, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary,
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hey, $name 👋',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Class $className • Div $division • $group',
                    style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready for a challenge?',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Complete your tests to track your academic progress.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Image.network(
                'https://cdn-icons-png.flaticon.com/512/4207/4207247.png',
                width: 60,
                height: 60,
                errorBuilder: (_, __, ___) => const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 48),
              ),
            ],
          ),
        ),
      ],
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
    final submittedOn = submittedAtRaw == null || submittedAtRaw.isEmpty ? '-' : submittedAtRaw.split('T').first;

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
              ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.description_outlined,
              color: level == 'JEE' ? AppColors.error : (level == 'NEET' ? AppColors.warning : AppColors.success),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$subject: $topic', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Submitted on $submittedOn', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$score%', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 4),
              _buildLevelBadge(level),
            ],
          ),
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
        SnackBar(content: Text('Failed to load test details: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Widget _buildLevelBadge(String level) {
    Color color = AppColors.success;
    if (level == 'NEET') color = AppColors.warning;
    if (level == 'JEE') color = AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        level,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
