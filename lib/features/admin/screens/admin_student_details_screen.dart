import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/features/admin/widgets/student_progress_chart.dart';
import 'package:mcq_test_app/features/student/screens/result_screen.dart';
import 'package:mcq_test_app/models/app_user.dart';
import 'package:mcq_test_app/models/test.dart';

class AdminStudentDetailsScreen extends StatefulWidget {
  final AppUser student;
  final ValueChanged<bool>? onStatusChanged;
  final VoidCallback? onResetPassword;

  const AdminStudentDetailsScreen({
    super.key,
    required this.student,
    this.onStatusChanged,
    this.onResetPassword,
  });

  @override
  State<AdminStudentDetailsScreen> createState() => _AdminStudentDetailsScreenState();
}

class _AdminStudentDetailsScreenState extends State<AdminStudentDetailsScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseService _supabase = SupabaseService();
  late AppUser _student;
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _attempts = [];
  List<Test> _eligibleTests = [];
  List<Test> _pendingTests = [];
  List<ProgressPoint> _chartPoints = [];

  // Question counts cache for tests
  final Map<String, int> _testQuestionCounts = {};

  // Layout breakpoints
  static const double _wideBreakpoint = 980;
  static const double _tabletBreakpoint = 640;
  static const double _maxContentWidth = 1240;

  // Tab indexes (0 = Can Give, 1 = Given)
  static const int _tabCanGive = 0;
  static const int _tabGiven = 1;

  @override
  void initState() {
    super.initState();
    _student = widget.student;
    _tabController = TabController(length: 2, vsync: this);
    _loadAllStudentData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ═════════════════════════ LOGIC (unchanged) ═════════════════════════

  Future<void> _loadAllStudentData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch fresh student profile in case status or password changed
      final updatedProfile = await _supabase.getUserProfile(_student.id);
      if (updatedProfile != null && mounted) {
        _student = updatedProfile;
      }

      // 2. Fetch attempts
      final rawAttempts = await _supabase.getStudentAttemptsByStudentId(_student.id);

      // 3. Fetch eligible published tests for this student's class, div, medium, and group
      final eligible = await _supabase.getEligiblePublishedTestsForStudentProfile(
        studentClass: _student.studentClass ?? '11',
        division: _student.division ?? '',
        medium: _student.medium ?? 'English',
        studentGroup: _student.studentGroup,
      );

      // 4. Identify attempted test IDs
      final attemptedTestIds = <String>{};
      for (final att in rawAttempts) {
        final tId = att['test_id']?.toString() ?? '';
        if (tId.isNotEmpty) {
          attemptedTestIds.add(tId);
        }
      }

      // 5. Eligible tests that haven't been attempted yet (tests he can give)
      final pending = eligible.where((t) => !attemptedTestIds.contains(t.id)).toList();

      // Fetch exact question count for each attempted test in parallel
      await Future.wait(attemptedTestIds.map((tId) async {
        try {
          final qs = await _supabase.getTestQuestions(tId);
          _testQuestionCounts[tId] = qs.length;
        } catch (_) {}
      }));

      // 6. Build chart data points
      final List<ProgressPoint> points = [];
      for (final att in rawAttempts) {
        final testData = att['tests'];
        final score = att['score'] is int
            ? att['score'] as int
            : int.tryParse(att['score']?.toString() ?? '') ?? 0;
        final submittedAtStr = att['submitted_at']?.toString();
        final submittedAt = submittedAtStr != null
            ? DateTime.tryParse(submittedAtStr) ?? DateTime.now()
            : DateTime.now();

        String testTitle = 'MCQ Test';
        String testSubject = 'General';
        String testId = att['test_id']?.toString() ?? '';

        if (testData is Map<String, dynamic>) {
          testTitle = testData['topic']?.toString() ?? testTitle;
          testSubject = testData['subject']?.toString() ?? testSubject;
          testId = testData['id']?.toString() ?? testId;
        }

        // Try to estimate or get total questions
        int totalQuestions = score > 0 ? score : 10;
        // If we have questions count cached or default
        if (_testQuestionCounts.containsKey(testId)) {
          totalQuestions = _testQuestionCounts[testId]!;
        } else {
          // If score is e.g. 15, assume test is at least out of max(20, score) or 25
          totalQuestions = math.max(score, 20);
        }

        final double pct = totalQuestions > 0
            ? ((score / totalQuestions) * 100).clamp(0.0, 100.0)
            : 0.0;

        points.add(
          ProgressPoint(
            testId: testId,
            title: testTitle,
            subject: testSubject,
            score: score,
            totalQuestions: totalQuestions,
            percentage: pct,
            date: submittedAt,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _attempts = rawAttempts;
          _eligibleTests = eligible;
          _pendingTests = pending;
          _chartPoints = points;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading student details: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleStatus(bool newStatus) async {
    try {
      await _supabase.setStudentStatus(_student.id, newStatus);
      setState(() {
        _student = _student.copyWith(isActive: newStatus);
      });
      widget.onStatusChanged?.call(newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_student.name ?? _student.email} is now ${newStatus ? "Active" : "Disabled"}',
            ),
            backgroundColor: newStatus ? AppColors.success : AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update student status: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showResetPasswordDialog() {
    final passController = TextEditingController(text: 'Pass@1234');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset Password: ${_student.name ?? _student.email}'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter a temporary password. The student will be prompted to set a new password upon login:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: passController,
                        decoration: const InputDecoration(
                          labelText: 'Temporary Password',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                      tooltip: 'Copy',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: passController.text.trim()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Password copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final newPass = passController.text.trim();
              try {
                await _supabase.adminSetUserPassword(
                  userId: _student.id,
                  email: _student.email,
                  newPassword: newPass,
                  mustChangePassword: true,
                );
                Clipboard.setData(
                  ClipboardData(text: 'Email: ${_student.email}\nTemporary Password: $newPass'),
                );

                setState(() {
                  _student = _student.copyWith(mustChangePassword: true);
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Password reset! Copied ${_student.email} credentials.'),
                      backgroundColor: AppColors.success,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error resetting password: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Reset & Copy'),
          ),
        ],
      ),
    );
  }

  void _openAttemptReview(Map<String, dynamic> attempt) async {
    final attemptId = attempt['id']?.toString() ?? '';
    final testData = attempt['tests'];
    final testId = (testData is Map ? testData['id']?.toString() : null) ??
        attempt['test_id']?.toString() ??
        '';
    final score = (attempt['score'] is int)
        ? attempt['score'] as int
        : (int.tryParse(attempt['score']?.toString() ?? '') ?? 0);

    Test? testModel;
    if (testData is Map<String, dynamic>) {
      testModel = Test.fromMap(testData);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
    );

    try {
      final questions = await _supabase.getTestQuestions(testId);
      final selectedAnswers = await _supabase.getAttemptAnswers(attemptId);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            score: score,
            total: questions.length,
            questions: questions,
            selectedAnswers: selectedAnswers,
            test: testModel,
            studentName: _student.name,
            rollNumber: _student.rollNo,
            isTeacher: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load test questions: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ═════════════════════════ UI ═════════════════════════

  @override
  Widget build(BuildContext context) {
    final displayName = (_student.name != null && _student.name!.trim().isNotEmpty)
        ? _student.name!.trim()
        : 'Student';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadAllStudentData,
          ),
        ],
      ),
      body: AppGradientBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? _buildErrorView()
            : LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isWide = width >= _wideBreakpoint;
            final isMobile = width < _tabletBreakpoint;
            final hPad = isMobile ? 14.0 : 24.0;
            final gap = isMobile ? 14.0 : 18.0;

            final Widget content = isWide
                ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left rail: who is this student
                SizedBox(
                  width: 360,
                  child: Column(
                    children: [
                      _buildProfileCard(displayName, initial),
                      SizedBox(height: gap),
                      _buildAcademicInfoCard(),
                    ],
                  ),
                ),
                SizedBox(width: gap + 4),
                // Main column: what can he give + history
                Expanded(
                  child: Column(
                    children: [
                      _buildTestOverviewCard(isMobile: false),
                      SizedBox(height: gap),
                      _buildSectionCard(
                        icon: Icons.show_chart_rounded,
                        title: 'Performance Trend',
                        child: StudentProgressChart(dataPoints: _chartPoints),
                      ),
                      SizedBox(height: gap),
                      _buildTestsSection(),
                    ],
                  ),
                ),
              ],
            )
                : Column(
              children: [
                _buildProfileCard(displayName, initial),
                SizedBox(height: gap),
                _buildTestOverviewCard(isMobile: isMobile),
                SizedBox(height: gap),
                _buildTestsSection(),
                SizedBox(height: gap),
                _buildAcademicInfoCard(),
                SizedBox(height: gap),
                _buildSectionCard(
                  icon: Icons.show_chart_rounded,
                  title: 'Performance Trend',
                  child: StudentProgressChart(dataPoints: _chartPoints),
                ),
              ],
            );

            return RefreshIndicator(
              onRefresh: _loadAllStudentData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                    child: content,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ───────────────────────── Shared building blocks ─────────────────────────

  BoxDecoration _cardDecoration({double radius = 22}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, {Widget? trailing}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(icon, title),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Color _scoreColor(double pct) {
    if (pct >= 75) return AppColors.success;
    if (pct >= 40) return AppColors.warning;
    return AppColors.error;
  }

  // ───────────────────────── Profile Hero ─────────────────────────

  Widget _buildProfileCard(String displayName, String initial) {
    final active = _student.isActive;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.25),
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: active ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _student.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroChip(
                Icons.badge_outlined,
                'Roll #${_student.rollNo ?? "-"}',
                trailingIcon: Icons.edit_rounded,
                onTap: _showEditRollNumberDialog,
              ),
              _buildHeroChip(
                active ? Icons.check_circle_rounded : Icons.block_rounded,
                active ? 'Active' : 'Disabled',
              ),
              if (_student.mustChangePassword)
                _buildHeroChip(Icons.key_rounded, 'Temp password'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showResetPasswordDialog,
                  icon: const Icon(Icons.lock_reset_rounded, size: 18),
                  label: const Text('Reset Pass', maxLines: 1, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.7)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _toggleStatus(!active),
                  icon: Icon(
                    active ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                    size: 18,
                  ),
                  label: Text(active ? 'Disable' : 'Enable', maxLines: 1, overflow: TextOverflow.ellipsis),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: active ? AppColors.error : AppColors.success,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditRollNumberDialog() {
    final controller = TextEditingController(text: _student.rollNo ?? '');
    showDialog(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.badge_outlined, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Edit Roll Number', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assign a unique roll number for ${_student.name ?? "this student"}:',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.text,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Roll Number',
                      hintText: 'e.g. 1, 2, 42',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newRoll = controller.text.trim();
                          if (newRoll.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Roll number cannot be empty'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          try {
                            await _supabase.updateStudentRollNumber(_student.id, newRoll);
                            if (mounted) {
                              setState(() {
                                _student = _student.copyWith(rollNo: newRoll);
                              });
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Roll number updated to #$newRoll'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setDialogState(() => isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to update roll number: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeroChip(IconData icon, String text, {VoidCallback? onTap, IconData? trailingIcon}) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 4),
            Icon(trailingIcon, size: 12, color: Colors.white.withOpacity(0.85)),
          ],
        ],
      ),
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: chip,
      );
    }
    return chip;
  }

  // ───────────────────────── Academic Profile ─────────────────────────

  Widget _buildAcademicInfoCard() {
    final tiles = <Widget Function(double)>[
          (w) => _buildAcademicTile(w, Icons.class_rounded, 'Standard', 'Std ${_student.studentClass ?? "-"}'),
          (w) => _buildAcademicTile(w, Icons.groups_rounded, 'Division', 'Div ${_student.division ?? "-"}'),
          (w) => _buildAcademicTile(w, Icons.translate_rounded, 'Medium', '${_student.medium ?? "English"} Medium'),
      if (_student.studentGroup != null && _student.studentGroup!.isNotEmpty)
            (w) => _buildAcademicTile(w, Icons.science_outlined, 'Group', _student.studentGroup!),
      if (_student.institution != null && _student.institution!.isNotEmpty)
            (w) => _buildAcademicTile(w, Icons.account_balance_outlined, 'Tuition / School', _student.institution!),
      if (_student.academicYear != null && _student.academicYear!.isNotEmpty)
            (w) => _buildAcademicTile(w, Icons.event_note_rounded, 'Academic Year', _student.academicYear!),
    ];

    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.school_rounded, 'Academic Profile'),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              const spacing = 10.0;
              final cols = c.maxWidth >= 260 ? 2 : 1;
              final tileW = (c.maxWidth - spacing * (cols - 1)) / cols;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: tiles.map((t) => t(tileW)).toList(),
              );
            },
          ),
          if (_student.enrolledSubjects.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'ENROLLED SUBJECTS',
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _student.enrolledSubjects.map((sub) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAcademicTile(double width, IconData icon, String label, String value) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardLight.withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Test Availability (key admin view) ─────────────────────────

  Widget _buildTestOverviewCard({required bool isMobile}) {
    final given = _attempts.length;
    final canGive = _pendingTests.length;
    final total = _eligibleTests.length;
    final completion = total > 0 ? (given / total).clamp(0.0, 1.0) : 0.0;
    final completionPct = (completion * 100).round();

    final firstName = (_student.name ?? '').trim().split(' ').first;
    final who = firstName.isEmpty ? 'This student' : firstName;

    final String headline;
    final String sub;
    final Color headColor;
    if (total == 0) {
      headline = 'No tests published yet';
      sub = 'There are no published tests for Std ${_student.studentClass ?? "-"} '
          '${_student.division ?? ""} yet.';
      headColor = AppColors.textSecondary;
    } else if (canGive == 0) {
      headline = 'All caught up 🎉';
      sub = '$who has attempted all $total published tests for this class.';
      headColor = AppColors.success;
    } else {
      headline = '$canGive test${canGive == 1 ? "" : "s"} still to give';
      sub = '$who has attempted $given of $total tests available to Std '
          '${_student.studentClass ?? "-"}'
          '${(_student.division ?? "").isNotEmpty ? " • Div ${_student.division}" : ""}.';
      headColor = AppColors.warning;
    }

    // pending count per subject
    final Map<String, int> bySubject = {};
    for (final t in _pendingTests) {
      bySubject[t.subject] = (bySubject[t.subject] ?? 0) + 1;
    }

    final ring = SizedBox(
      width: isMobile ? 78 : 92,
      height: isMobile ? 78 : 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 8,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.border),
            ),
          ),
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: completion,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$completionPct%',
                style: TextStyle(
                  fontSize: isMobile ? 17 : 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const Text(
                'done',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      decoration: _cardDecoration(radius: 26),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.assessment_rounded, 'Test Availability'),
          const SizedBox(height: 16),
          Row(
            children: [
              ring,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 21,
                        fontWeight: FontWeight.w900,
                        color: headColor,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sub,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Stacked progress bar: given vs pending
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: total == 0
                  ? Container(color: AppColors.border)
                  : Row(
                children: [
                  if (given > 0)
                    Expanded(flex: given, child: Container(color: AppColors.primary)),
                  if (canGive > 0)
                    Expanded(flex: canGive, child: Container(color: AppColors.warning)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 3 tappable stat tiles
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Can Give',
                  value: '$canGive',
                  subtitle: 'Not attempted',
                  color: AppColors.warning,
                  icon: Icons.pending_actions_rounded,
                  onTap: () => _tabController.animateTo(_tabCanGive),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  title: 'Given',
                  value: '$given',
                  subtitle: 'Attempted',
                  color: AppColors.primary,
                  icon: Icons.check_circle_outline_rounded,
                  onTap: () => _tabController.animateTo(_tabGiven),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  title: 'Eligible',
                  value: '$total',
                  subtitle: 'Total for class',
                  color: AppColors.textSecondary,
                  icon: Icons.menu_book_rounded,
                ),
              ),
            ],
          ),

          if (bySubject.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'PENDING BY SUBJECT',
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: bySubject.entries.map((e) {
                return Container(
                  padding: const EdgeInsets.fromLTRB(10, 5, 5, 5),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.warning.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        e.key,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${e.value}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Tests Section (Can Give / Given) ─────────────────────────

  Widget _buildTestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTestsSegmentedControl(),
        const SizedBox(height: 12),
        _buildTabContent(),
      ],
    );
  }

  Widget _buildTestsSegmentedControl() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        Widget seg(int index, IconData icon, String label, int count, Color accent) {
          final selected = _tabController.index == index;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _tabController.animateTo(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: selected
                      ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 16, color: selected ? accent : AppColors.textMuted),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: selected ? accent : AppColors.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.cardLight,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              seg(_tabCanGive, Icons.pending_actions_rounded, 'Can Give',
                  _pendingTests.length, AppColors.warning),
              seg(_tabGiven, Icons.task_alt_rounded, 'Given', _attempts.length,
                  AppColors.primary),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabContent() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey(_tabController.index),
            child: _tabController.index == _tabCanGive
                ? _buildPendingTestsList()
                : _buildAttemptsList(),
          ),
        );
      },
    );
  }

  /// Lays children out in 1 or 2 columns depending on available width.
  Widget _buildAdaptiveGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, c) {
        const spacing = 10.0;
        final cols = c.maxWidth >= 700 ? 2 : 1;
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children.map((ch) => SizedBox(width: w, child: ch)).toList(),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── "Can Give" list (grouped by subject) ─────────────────────────

  Widget _buildPendingTestsList() {
    if (_pendingTests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.done_all_rounded,
        color: AppColors.success,
        title: 'All eligible tests attempted!',
        message: 'The student has attempted all published tests for their class and group.',
      );
    }

    final Map<String, List<Test>> grouped = {};
    for (final t in _pendingTests) {
      grouped.putIfAbsent(t.subject, () => []).add(t);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        entry.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${entry.value.length} pending',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildAdaptiveGrid(entry.value.map(_buildPendingTestCard).toList()),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPendingTestCard(Test test) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: AppColors.warning),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              test.topic,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Pending',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Std ${test.studentClass} • ${test.medium}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildSmallBadge(Icons.timer_outlined, '${test.duration} mins',
                              AppColors.textSecondary),
                          _buildSmallBadge(Icons.signal_cellular_alt_rounded, '${test.level}',
                              AppColors.textSecondary),
                          if (test.testCode != null)
                            _buildSmallBadge(Icons.tag_rounded, '${test.testCode}',
                                AppColors.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── "Given" list ─────────────────────────

  Widget _buildAttemptsList() {
    if (_attempts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.assignment_outlined,
        color: AppColors.textMuted,
        title: 'No tests attempted yet',
        message: 'Tests taken by this student will appear here with question review.',
      );
    }

    return _buildAdaptiveGrid(
      List.generate(_attempts.length, (i) => _buildAttemptCard(i)),
    );
  }

  Widget _buildAttemptCard(int index) {
    final att = _attempts[index];
    final testData = att['tests'];
    final score = (att['score'] is int)
        ? att['score'] as int
        : int.tryParse(att['score']?.toString() ?? '') ?? 0;
    final submittedAtStr = att['submitted_at']?.toString();
    final submittedAt = submittedAtStr != null ? DateTime.tryParse(submittedAtStr) : null;

    String topic = 'MCQ Test';
    String subject = 'General';
    String studentClass = _student.studentClass ?? '11';

    if (testData is Map<String, dynamic>) {
      topic = testData['topic']?.toString() ?? topic;
      subject = testData['subject']?.toString() ?? subject;
      studentClass = (testData['class'] ?? studentClass).toString();
    }

    // chart points are built in the same order as attempts
    final hasPoint = index < _chartPoints.length;
    final double pct = hasPoint ? _chartPoints[index].percentage : 0;
    final int totalQ = hasPoint ? _chartPoints[index].totalQuestions : 0;
    final color = _scoreColor(pct);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openAttemptReview(att),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 5,
                        valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.15)),
                      ),
                    ),
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: (pct / 100).clamp(0.0, 1.0),
                        strokeWidth: 5,
                        strokeCap: StrokeCap.round,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    Text(
                      '${pct.round()}%',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$subject • Std $studentClass',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (submittedAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(submittedAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      totalQ > 0 ? '$score/$totalQ' : '$score',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Review',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Error ─────────────────────────

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              const Text(
                'Could not load student details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '$_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadAllStudentData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}