import 'package:flutter/material.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/core/widgets/app_section_title.dart';
import 'package:mcq_test_app/features/auth/screens/login_screen.dart';
import 'package:mcq_test_app/features/student/screens/history_screen.dart';
import 'package:mcq_test_app/features/student/screens/result_screen.dart';
import 'package:mcq_test_app/features/student/screens/test_taking_screen.dart';
import 'package:mcq_test_app/models/app_user.dart';
import 'package:mcq_test_app/models/test.dart';

class StudentDashboard extends StatefulWidget {
  final AppUser? user;
  const StudentDashboard({super.key, this.user});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final TextEditingController _testIdController = TextEditingController();
  final SupabaseService _supabase = SupabaseService();

  AppUser? _user;
  List<Test> _availableTests = [];
  List<Map<String, dynamic>> _recentAttempts = [];
  bool _isTestsLoading = true;
  bool _isJoiningById = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 1. Immediately hydrate student profile synchronously so UI renders on frame 1
    _user = widget.user;
    final currentAuth = _supabase.currentUser;
    if (_user == null && currentAuth != null) {
      _user = _supabase.getFallbackUserProfileFromAuth(currentAuth);
    }
    // 2. Fetch live tests & recent history in background
    _loadDashboardData();
  }

  @override
  void dispose() {
    _testIdController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isTestsLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final currentUser = _supabase.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(() {
            _isTestsLoading = false;
            _errorMessage = 'User session expired. Please log in again.';
          });
        }
        return;
      }

      // 1. Resolve student profile with fallback
      AppUser? profile = _user ?? widget.user;
      if (profile == null) {
        profile = await _supabase.getUserProfile(currentUser.id);
        profile ??= _supabase.getFallbackUserProfileFromAuth(currentUser);
      } else {
        // Refresh profile in background asynchronously
        _supabase.getUserProfile(currentUser.id).then((p) {
          if (p != null && mounted) {
            setState(() => _user = p);
          }
        }).catchError((_) {});
      }

      // 2. Ensure student enrollment entry exists non-blocking in background
      if (profile != null) {
        _supabase.ensureStudentEnrollment(profile).catchError((_) {});
      }

      // 3. Extract filtering parameters safely without any force unwrapping
      final pClass = profile?.studentClass?.trim();
      final studentClass = (pClass != null && pClass.isNotEmpty)
          ? pClass
          : (currentUser.userMetadata?['class']?.toString() ?? '11');

      final pDiv = profile?.division?.trim();
      final division = (pDiv != null && pDiv.isNotEmpty)
          ? pDiv
          : (currentUser.userMetadata?['division']?.toString() ?? 'A');

      final pMed = profile?.medium?.trim();
      final medium = (pMed != null && pMed.isNotEmpty)
          ? pMed
          : (currentUser.userMetadata?['medium']?.toString() ?? 'English');

      final studentGroup = profile?.studentGroup ?? currentUser.userMetadata?['student_group']?.toString();

      // 4. Fetch available tests and recent test attempts concurrently
      final testsFuture = _supabase.getAvailableTests(
        studentClass: studentClass,
        division: division,
        medium: medium,
        studentGroup: studentGroup,
      );

      final historyFuture = _supabase.getStudentHistory();

      final results = await Future.wait([testsFuture, historyFuture]);

      if (mounted) {
        setState(() {
          _user = profile;
          _availableTests = results[0] as List<Test>;
          _recentAttempts = results[1] as List<Map<String, dynamic>>;
          _isTestsLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading student dashboard: $e');
      if (mounted) {
        setState(() {
          _isTestsLoading = false;
          _errorMessage = 'Could not load tests: $e';
        });
      }
    }
  }

  Future<void> _joinTestById({
    required BuildContext context,
    required String studentClass,
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

    try {
      final test = await _supabase.getPublishedTestByCode(enteredCode);
      if (!mounted) return;

      if (test == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid test code or test is not published')),
        );
        return;
      }

      final testDigit = RegExp(r'\d+').firstMatch(test.studentClass)?.group(0);
      final studentDigit = RegExp(r'\d+').firstMatch(studentClass)?.group(0);
      final isClassMatch = (testDigit != null && studentDigit != null)
          ? (testDigit == studentDigit)
          : (test.studentClass.trim().toLowerCase() == studentClass.trim().toLowerCase());

      if (!isClassMatch) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('This test is for Std ${test.studentClass}, but you are in Std $studentClass')),
        );
        return;
      }

      final testDiv = test.division?.trim().toUpperCase() ?? '';
      final studentDivClean = studentDivision.trim().toUpperCase();
      if (testDiv.isNotEmpty && testDiv != 'ALL' && testDiv != 'BOTH' && testDiv != studentDivClean) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('This test is for Division $testDiv, but you are in Division $studentDivision')),
        );
        return;
      }

      final alreadyAttempted = await _supabase.hasAttemptedTest(test.id);
      if (!mounted) return;
      if (alreadyAttempted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have already submitted this test.')),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TestTakingScreen(test: test)),
      );

      // Refresh tests when coming back
      if (mounted) {
        _loadDashboardData(showLoading: false);
      }
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

  Future<void> _logout() async {
    await _supabase.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'MCQ Pro',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
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
            onPressed: () => _loadDashboardData(showLoading: false),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Tests',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log Out',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AppGradientBackground(
        child: SafeArea(
          child: _buildBodyContent(),
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    final currentUser = _supabase.currentUser;
    final user = _user;

    // Safely extract all profile attributes without a single dangerous ! operator
    String name = 'Student';
    final profileName = user?.name?.trim();
    if (profileName != null && profileName.isNotEmpty) {
      name = profileName;
    } else {
      final metaName = currentUser?.userMetadata?['name']?.toString()?.trim();
      if (metaName != null && metaName.isNotEmpty) {
        name = metaName;
      } else {
        final email = (user?.email ?? currentUser?.email ?? '').trim();
        if (email.contains('@')) {
          name = email.split('@').first;
        } else if (email.isNotEmpty) {
          name = email;
        }
      }
    }

    final userClass = user?.studentClass?.trim();
    final studentClass = (userClass != null && userClass.isNotEmpty)
        ? userClass
        : (currentUser?.userMetadata?['class']?.toString() ?? '11');

    final userDiv = user?.division?.trim();
    final studentDiv = (userDiv != null && userDiv.isNotEmpty)
        ? userDiv
        : (currentUser?.userMetadata?['division']?.toString() ?? 'A');

    final userMed = user?.medium?.trim();
    final studentMedium = (userMed != null && userMed.isNotEmpty)
        ? userMed
        : (currentUser?.userMetadata?['medium']?.toString() ?? 'English');

    final userRoll = user?.rollNo?.trim();
    final studentRoll = (userRoll != null && userRoll.isNotEmpty)
        ? userRoll
        : (currentUser?.userMetadata?['roll_no']?.toString() ?? 'Allocated');

    final userInst = user?.institution?.trim();
    final studentInst = (userInst != null && userInst.isNotEmpty)
        ? userInst
        : (currentUser?.userMetadata?['institution']?.toString() ?? 'Sharda Mandir');

    return RefreshIndicator(
      onRefresh: () => _loadDashboardData(showLoading: false),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          // If there is an error message, show a lightweight dismissible alert banner
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage ?? '',
                        style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.error),
                      onPressed: () => _loadDashboardData(showLoading: true),
                      tooltip: 'Retry',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),

          // Student Welcome & Profile Header (renders immediately)
          _buildWelcomeHeader(
            context,
            name: name,
            className: studentClass,
            division: studentDiv,
            medium: studentMedium,
            rollNo: studentRoll,
            institution: studentInst,
          ),
          const SizedBox(height: 20),

          // Join test with code card (renders immediately)
          _buildJoinWithTestIdCard(
            context: context,
            studentClass: studentClass,
            studentDivision: studentDiv,
          ),
          const SizedBox(height: 24),

          // Available Tests Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const AppSectionTitle(title: 'Eligible Tests'),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isTestsLoading ? '...' : '${_availableTests.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _loadDashboardData(showLoading: true),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Available Tests List: localized loading, empty state, or list items
          if (_isTestsLoading)
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                    const SizedBox(width: 14),
                    Flexible(
                      child: Text(
                        'Checking for tests in Std $studentClass-$studentDiv ($studentMedium)...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_availableTests.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(22),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.assignment_turned_in_outlined, size: 44, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      'No pending tests for Std $studentClass-$studentDiv ($studentMedium).',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'New tests published by your teachers will appear here.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < _availableTests.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _buildTestCard(_availableTests[i]),
                ],
              ],
            ),
          const SizedBox(height: 28),

          // Recent Activity / Growth Section Header
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
          const SizedBox(height: 10),

          // Recent Attempts List: localized loading, empty state, or list items
          if (_isTestsLoading)
            const AppCard(
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Loading recent attempts...',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else if (_recentAttempts.isEmpty)
            const AppCard(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No test attempts yet. Completed tests will appear here.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < _recentAttempts.take(3).length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _buildAttemptCard(_recentAttempts[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTestCard(Test test) {
    final duration = test.duration > 0 ? '${test.duration} min' : '30 min';
    final level = test.level.trim().isNotEmpty ? test.level.trim().toUpperCase() : 'MEDIUM';
    final medium = test.medium.trim().isNotEmpty ? test.medium.trim() : 'English';
    final subject = test.subject.trim().isNotEmpty ? test.subject.trim() : 'General';
    final topic = test.topic.trim().isNotEmpty ? test.topic.trim() : 'Untitled';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1.5,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: AppColors.primarySoft,
          child: const Icon(Icons.quiz_rounded, color: AppColors.primary),
        ),
        title: Text(
          '$subject: $topic',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            '$duration  •  $level  •  $medium',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TestTakingScreen(test: test)),
            );
            if (mounted) {
              _loadDashboardData(showLoading: false);
            }
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(68, 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Start'),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(
    BuildContext context, {
    required String name,
    required String className,
    required String division,
    required String medium,
    required String rollNo,
    required String institution,
  }) {
    final cleanName = name.trim().isNotEmpty ? name.trim() : 'Student';
    final initial = cleanName.isNotEmpty ? cleanName[0].toUpperCase() : 'S';
    final cleanClass = className.trim().isNotEmpty ? className.trim() : '11';
    final cleanDiv = division.trim().isNotEmpty ? division.trim() : 'A';
    final cleanMedium = medium.trim().isNotEmpty ? medium.trim() : 'English';
    final cleanRoll = rollNo.trim().isNotEmpty ? rollNo.trim() : 'Allocated';
    final cleanInst = institution.trim().isNotEmpty ? institution.trim() : 'Sharda Mandir';

    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.primary,
          child: Text(
            initial,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hey, $cleanName 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 3),
              Text(
                '$cleanInst • Std $cleanClass-$cleanDiv ($cleanMedium)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: 12),
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
              Text(cleanRoll, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJoinWithTestIdCard({
    required BuildContext context,
    required String studentClass,
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
              Text('Enter Test Code', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                width: 86,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(86, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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
    // Safely extract joined test details whether PostgREST returns a Map or List
    Map<String, dynamic>? testData;
    final rawTests = attempt['tests'];
    if (rawTests is Map<String, dynamic>) {
      testData = rawTests;
    } else if (rawTests is List && rawTests.isNotEmpty && rawTests.first is Map<String, dynamic>) {
      testData = rawTests.first as Map<String, dynamic>;
    }

    final subject = (testData?['subject'] ?? 'Unknown').toString();
    final topic = (testData?['topic'] ?? 'Untitled').toString();
    final score = attempt['score']?.toString() ?? '0';

    final attemptId = attempt['id']?.toString() ?? '';
    final testId = testData?['id']?.toString() ?? '';
    final parsedScore = int.tryParse(score) ?? 0;

    return AppCard(
      onTap: (attemptId.isEmpty || testId.isEmpty)
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
                Text(
                  '$subject: $topic',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
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
      final questions = await _supabase.getTestQuestions(testId);
      final selectedAnswers = await _supabase.getAttemptAnswers(attemptId);

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
