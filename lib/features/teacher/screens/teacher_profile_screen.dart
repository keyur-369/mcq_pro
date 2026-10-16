import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/features/auth/screens/login_screen.dart';
import 'package:mcq_test_app/features/teacher/screens/teacher_students_screen.dart';
import 'package:mcq_test_app/features/teacher/screens/teacher_tests_screen.dart';
import 'package:mcq_test_app/models/app_user.dart';
import 'package:mcq_test_app/models/teacher_assignment.dart';
import 'package:mcq_test_app/models/test.dart';

/// ---------------------------------------------------------------------------
/// Liquid glass card for Teacher Profile Screen
/// ---------------------------------------------------------------------------
class _ProfileGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? tint;
  final VoidCallback? onTap;

  const _ProfileGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
    this.blur = 20,
    this.tint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    final base = tint ?? Colors.white;

    return Container(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: (tint ?? AppColors.primary).withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: br,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        base.withOpacity(0.42),
                        base.withOpacity(0.14),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.60),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 50,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.30),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: br,
                  splashColor: Colors.white.withOpacity(0.25),
                  highlightColor: Colors.white.withOpacity(0.10),
                  child: Padding(padding: padding, child: child),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TeacherProfileScreen extends StatefulWidget {
  final AppUser? initialUser;
  const TeacherProfileScreen({super.key, this.initialUser});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  final _supabase = SupabaseService();

  AppUser? _user;
  List<TeacherAssignment> _assignments = [];
  List<Test> _tests = [];
  int _studentCount = 0;
  int _attemptsCount = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    final curUser = _supabase.currentUser;
    if (curUser == null) {
      if (mounted) {
        setState(() {
          _errorMessage = 'User not logged in';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final profileFuture = _supabase.getUserProfile(curUser.id);
      final assignmentsFuture = _supabase.getTeacherAssignments(curUser.id);
      final testsFuture = _supabase.getTeacherTests(curUser.id);
      final attemptsFuture = _supabase.getTeacherTestAttempts();
      final studentsFuture = _supabase.getAllStudents();

      final results = await Future.wait([
        profileFuture,
        assignmentsFuture,
        testsFuture,
        attemptsFuture,
        studentsFuture,
      ]);

      final profile = results[0] as AppUser?;
      final assignments = results[1] as List<TeacherAssignment>;
      final tests = results[2] as List<Test>;
      final attempts = results[3] as List<Map<String, dynamic>>;
      final allStudents = results[4] as List<AppUser>;

      // Calculate students under this teacher
      int underTeacher = 0;
      if (assignments.isNotEmpty) {
        underTeacher = allStudents.where((s) {
          final sStd = (s.studentClass ?? '').trim();
          var sDiv = (s.division ?? '').trim().toUpperCase();
          if (sDiv.startsWith('DIV ')) sDiv = sDiv.substring(4).trim();
          final sInst = (s.institution ?? 'Sharda Mandir').trim().toLowerCase();
          final sMed = (s.medium ?? 'English').trim().toLowerCase();
          final isSAcc = sInst.contains('acc');

          return assignments.any((a) {
            final aStd = a.standard.trim();
            var aDiv = a.division.trim().toUpperCase();
            if (aDiv.startsWith('DIV ')) aDiv = aDiv.substring(4).trim();
            final aInst = a.institution.trim().toLowerCase();
            final aMed = a.medium.trim().toLowerCase();
            final isAAcc = aInst.contains('acc');

            // 1. Institution check
            if (isAAcc != isSAcc) return false;
            if (!isAAcc && aInst.isNotEmpty && sInst.isNotEmpty && aInst != sInst) return false;

            // 2. Standard check
            if (aStd != sStd) return false;

            // 3. Division check (Tuition ACC students belong to ACC; Sharda Mandir matches division)
            if (isAAcc && isSAcc) {
              // Both Tuition ACC - matches
            } else if (aDiv != 'ALL' && aDiv != sDiv) {
              return false;
            }

            // 4. Medium check
            if (aMed.isNotEmpty && sMed.isNotEmpty && aMed != 'both' && aMed != 'all' && aMed != sMed) {
              return false;
            }

            // 5. Subject & Group compatibility check
            final sub = a.subject.trim().toLowerCase();
            final grp = (s.studentGroup ?? '').trim().toLowerCase();
            final isPhysics = sub == 'physics' || sub == 'physical';
            final isChemistry = sub == 'chemistry';
            final isBiology = sub == 'biology' || sub == 'bio';
            final isMath = sub == 'math' || sub == 'maths' || sub == 'mathematics';

            if (isPhysics || isChemistry) return true;
            if (isBiology) return grp.isEmpty || grp == 'biology' || grp == 'bio' || grp == 'b' || grp == 'science';
            if (isMath) return grp == 'math' || grp == 'maths' || grp == 'a';

            return true;
          });
        }).length;
      }

      if (mounted) {
        setState(() {
          _user = profile ?? widget.initialUser;
          _assignments = assignments;
          _tests = tests;
          _attemptsCount = attempts.length;
          _studentCount = underTeacher;
          _errorMessage = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showChangePasswordDialog() {
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSaving = false;
    String? localError;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.lock_reset_rounded, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text(
                    'Change Password',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter your new password below.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: newPasswordCtrl,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            size: 18,
                          ),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordCtrl,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            size: 18,
                          ),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        localError!,
                        style: const TextStyle(color: AppColors.error, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final p1 = newPasswordCtrl.text.trim();
                          final p2 = confirmPasswordCtrl.text.trim();
                          if (p1.isEmpty) {
                            setDialogState(() => localError = 'Please enter a password');
                            return;
                          }
                          if (p1.length < 6) {
                            setDialogState(() => localError = 'Password must be at least 6 characters');
                            return;
                          }
                          if (p1 != p2) {
                            setDialogState(() => localError = 'Passwords do not match');
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                            localError = null;
                          });

                          try {
                            final user = _supabase.currentUser;
                            if (user != null) {
                              await _supabase.adminSetUserPassword(
                                userId: user.id,
                                email: user.email ?? '',
                                newPassword: p1,
                                mustChangePassword: false,
                              );
                            }
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Password updated successfully!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                              _loadProfileData();
                            }
                          } catch (err) {
                            setDialogState(() {
                              isSaving = false;
                              localError = 'Failed: $err';
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Update Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final curUser = _supabase.currentUser;
    final displayName = (_user?.name != null && _user!.name!.trim().isNotEmpty)
        ? _user!.name!.trim()
        : curUser?.userMetadata?['name']?.toString() ??
            curUser?.email?.split('@').first ??
            'Teacher';
    final email = _user?.email.isNotEmpty == true ? _user!.email : curUser?.email ?? 'teacher@school.org';
    final institution = _user?.institution ??
        (_assignments.isNotEmpty ? _assignments.first.institution : 'Sharda Mandir');
    final academicYear = _user?.academicYear ??
        (_assignments.isNotEmpty ? _assignments.first.academicYear : '2026-2027');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: _ProfileGlassCard(
              radius: 14,
              blur: 16,
              padding: const EdgeInsets.all(8),
              onTap: () => Navigator.pop(context),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        title: const Text(
          'Faculty Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _ProfileGlassCard(
              radius: 14,
              blur: 16,
              padding: const EdgeInsets.all(8),
              onTap: _loadProfileData,
              child: const Icon(
                Icons.refresh_rounded,
                size: 20,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      body: AppGradientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.5),
                      SizedBox(height: 16),
                      Text(
                        'Loading faculty profile...',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 50, color: AppColors.error),
                            const SizedBox(height: 14),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 14),
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              onPressed: _loadProfileData,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadProfileData,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                        children: [
                          // 1. Profile Hero Card
                          _buildProfileHeroCard(
                            displayName: displayName,
                            email: email,
                            institution: institution,
                            academicYear: academicYear,
                          ),
                          const SizedBox(height: 18),

                          // 2. Statistics Counter
                          _buildStatisticsBar(),
                          const SizedBox(height: 22),

                          // 3. Assigned Classes Section
                          _buildAssignedClassesSection(),
                          const SizedBox(height: 22),

                          // 4. Account & Security Details
                          _buildAccountSecurityCard(email),
                          const SizedBox(height: 26),

                          // 5. Action Buttons (View Students & Logout)
                          _buildBottomActionButtons(),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Profile Hero Card
  // ---------------------------------------------------------------------------
  Widget _buildProfileHeroCard({
    required String displayName,
    required String email,
    required String institution,
    required String academicYear,
  }) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'T';

    return _ProfileGlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 18),

              // Name and Email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.school_rounded, size: 13, color: AppColors.primary),
                          SizedBox(width: 5),
                          Text(
                            'Authorized Teacher',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),

          // Institution & Year Badges
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.60),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.85)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Institution',
                              style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              institution,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.60),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.85)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Academic Year',
                              style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              academicYear,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Statistics Bar
  // ---------------------------------------------------------------------------
  Widget _buildStatisticsBar() {
    final publishedTests = _tests.where((t) => t.status == TestStatus.published).length;
    final totalSubjects = _assignments.map((a) => a.subject).toSet().length;

    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            label: 'Assigned Classes',
            value: '${_assignments.length}',
            icon: Icons.meeting_room_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatItem(
            label: 'Subjects',
            value: '$totalSubjects',
            icon: Icons.menu_book_rounded,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatItem(
            label: 'Students',
            value: '$_studentCount',
            icon: Icons.people_alt_rounded,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatItem(
            label: 'Tests Created',
            value: '$publishedTests / ${_tests.length}',
            icon: Icons.quiz_rounded,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return _ProfileGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Assigned Classes Section
  // ---------------------------------------------------------------------------
  Widget _buildAssignedClassesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Assigned Classes & Subjects',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '${_assignments.length} Total',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_assignments.isEmpty)
          _ProfileGlassCard(
            padding: const EdgeInsets.all(20),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.assignment_late_outlined, size: 36, color: AppColors.textMuted),
                  SizedBox(height: 8),
                  Text(
                    'No Classes Assigned Yet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Please contact the main administrator to assign standards, divisions, and subjects to your profile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _assignments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final a = _assignments[index];
              return _buildAssignmentCard(a);
            },
          ),
      ],
    );
  }

  Widget _buildAssignmentCard(TeacherAssignment a) {
    Color subjectColor;
    IconData subjectIcon;

    final subLower = a.subject.toLowerCase();
    if (subLower.contains('physic')) {
      subjectColor = const Color(0xFF6366F1);
      subjectIcon = Icons.bolt_rounded;
    } else if (subLower.contains('chem')) {
      subjectColor = const Color(0xFFEC4899);
      subjectIcon = Icons.science_rounded;
    } else if (subLower.contains('bio')) {
      subjectColor = const Color(0xFF10B981);
      subjectIcon = Icons.eco_rounded;
    } else if (subLower.contains('math')) {
      subjectColor = const Color(0xFFF59E0B);
      subjectIcon = Icons.calculate_rounded;
    } else {
      subjectColor = AppColors.primary;
      subjectIcon = Icons.menu_book_rounded;
    }

    return _ProfileGlassCard(
      padding: const EdgeInsets.all(14),
      radius: 18,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: subjectColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: subjectColor.withOpacity(0.25)),
            ),
            child: Icon(subjectIcon, color: subjectColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        a.subject,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Std ${a.standard} • ${a.division}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildSmallTag(a.medium, Icons.translate_rounded),
                    _buildSmallTag(a.institution, Icons.account_balance_rounded),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'View Students in this Class',
            icon: const Icon(Icons.people_outline_rounded, size: 20, color: AppColors.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TeacherStudentsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSmallTag(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Account & Security Details Card
  // ---------------------------------------------------------------------------
  Widget _buildAccountSecurityCard(String email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Account & Credentials',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ProfileGlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              _buildDetailRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: email,
                action: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                  onPressed: () => _copyToClipboard(email, 'Email'),
                ),
              ),
              const Divider(height: 20),
              _buildDetailRow(
                icon: Icons.verified_user_outlined,
                label: 'Role Status',
                value: 'Teacher (Active)',
                valueColor: AppColors.success,
              ),
              const Divider(height: 20),
              _buildDetailRow(
                icon: Icons.lock_outline_rounded,
                label: 'Security',
                value: 'Password Protected',
                action: TextButton.icon(
                  onPressed: _showChangePasswordDialog,
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: const Text('Change', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    Widget? action,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 4),
          action,
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom Action Buttons
  // ---------------------------------------------------------------------------
  Widget _buildBottomActionButtons() {
    return Column(
      children: [
        // View Students Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeacherStudentsScreen()),
              );
            },
            icon: const Icon(Icons.people_alt_rounded),
            label: const Text(
              'View My Enrolled Students',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: AppColors.primary.withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Logout Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
            label: const Text(
              'Sign Out',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.error),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.error.withOpacity(0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }
}
