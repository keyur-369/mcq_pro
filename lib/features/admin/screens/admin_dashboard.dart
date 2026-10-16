import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/features/admin/screens/admin_create_teacher_screen.dart';
import 'package:mcq_test_app/features/admin/screens/admin_gemini_keys_screen.dart';
import 'package:mcq_test_app/features/admin/screens/admin_password_vault_screen.dart';
import 'package:mcq_test_app/features/admin/tabs/admin_analytics_tab.dart';
import 'package:mcq_test_app/features/admin/tabs/admin_audit_tab.dart';
import 'package:mcq_test_app/features/admin/tabs/admin_backups_tab.dart';
import 'package:mcq_test_app/features/admin/tabs/admin_students_tab.dart';
import 'package:mcq_test_app/features/admin/tabs/admin_teachers_tab.dart';
import 'package:mcq_test_app/features/auth/screens/login_screen.dart';
import 'package:mcq_test_app/models/app_user.dart';
import 'package:mcq_test_app/models/test_backup.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _spinController;
  // Drives the liquid blobs + glass sheen (loops forever)
  late AnimationController _glassController;
  final _supabase = SupabaseService();

  List<AppUser> _teachers = [];
  String? _teachersError;
  List<AppUser> _students = [];
  String? _studentsError;
  List<TestBackup> _backups = [];
  Map<String, dynamic> _stats = {
    'totalStudents': 0,
    'activeTeachers': 0,
    'publishedTests': 0,
    'totalAttempts': 0,
    'averageScore': 0.0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      // Rebuild FAB when tab changes
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _glassController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _spinController.dispose();
    _glassController.dispose();
    super.dispose();
  }

  // ───────────────────────── Logic (unchanged) ─────────────────────────

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    _spinController.repeat();

    List<AppUser> teachers = [];
    String? teacherError;
    List<AppUser> students = [];
    String? studentError;
    List<TestBackup> backups = [];
    int studentCount = 0;
    int testCount = 0;
    int attemptCount = 0;
    double avgScore = 0.0;

    // 1. Load Teachers
    try {
      teachers = await _supabase.getAllTeachers();
      debugPrint('🔍 [ADMIN DASHBOARD] Loaded teachers: ${teachers.length}');
    } catch (e, stack) {
      teacherError = e.toString();
      debugPrint('❌ [ADMIN DASHBOARD] Error loading teachers: $e\n$stack');
    }

    // 2. Load Students
    try {
      students = await _supabase.getAllStudents();
      studentCount = students.length;
      debugPrint('🔍 [ADMIN DASHBOARD] Loaded students: ${students.length}');
    } catch (e, stack) {
      studentError = e.toString();
      debugPrint('❌ [ADMIN DASHBOARD] Error loading students: $e\n$stack');
    }

    // 3. Load Google Drive Backups
    try {
      backups = await _supabase.getTestBackups();
    } catch (e) {
      debugPrint('Error loading backups: $e');
    }

    // 4. Load Published Tests Count
    try {
      final testsRes = await _supabase.supabase
          .from('tests')
          .select('id')
          .eq('status', 'published');
      testCount = (testsRes as List).length;
    } catch (e) {
      debugPrint('Error loading tests count: $e');
    }

    // 5. Load Total Attempts & Average Score
    try {
      final attemptsRes = await _supabase.supabase
          .from('attempts')
          .select('score');
      final attemptsList = attemptsRes as List;
      attemptCount = attemptsList.length;
      int totalScore = 0;
      for (var a in attemptsList) {
        totalScore += (a['score'] as int? ?? 0);
      }
      avgScore = attemptsList.isNotEmpty
          ? (totalScore / attemptsList.length)
          : 0.0;
    } catch (e) {
      debugPrint('Error loading attempts: $e');
    }

    if (mounted) {
      _spinController.stop();
      _spinController.reset();
      setState(() {
        _teachers = teachers;
        _teachersError = teacherError;
        _students = students;
        _studentsError = studentError;
        _backups = backups;
        _stats = {
          'totalStudents': studentCount,
          'activeTeachers': teachers.where((t) => t.isActive).length,
          'publishedTests': testCount,
          'totalAttempts': attemptCount,
          'averageScore': double.parse(avgScore.toStringAsFixed(1)),
        };
        _isLoading = false;
      });
    }
  }

  void _navigateToAddTeacher() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminCreateTeacherScreen()),
    );
    if (created == true) {
      _loadDashboardData();
    }
  }

  void _openPasswordVault() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminPasswordVaultScreen()),
    );
  }

  void _openGeminiKeys() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminGeminiKeysScreen()),
    );
  }

  void _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Sign Out',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out of the admin panel?',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    'Log Out',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm == true) {
      final nav = Navigator.of(context);
      await _supabase.logout();
      if (mounted) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: AppGradientBackground(
                // NEVER unmount TabBarView - this prevents blank white screens!
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    AdminAnalyticsTab(
                      stats: _stats,
                      onRefresh: _loadDashboardData,
                    ),
                    AdminTeachersTab(
                      teachers: _teachers,
                      isLoading: _isLoading,
                      errorMessage: _teachersError,
                      onRefresh: _loadDashboardData,
                    ),
                    AdminStudentsTab(
                      students: _students,
                      isLoading: _isLoading,
                      errorMessage: _studentsError,
                      onRefresh: _loadDashboardData,
                    ),
                    AdminBackupsTab(
                      backups: _backups,
                      onRefresh: _loadDashboardData,
                    ),
                    const AdminAuditTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: _tabController.index == 1
              ? FloatingActionButton.extended(
                  key: const ValueKey('fab-add-teacher'),
                  onPressed: _navigateToAddTeacher,
                  icon: const Icon(Icons.person_add_rounded),
                  label: const Text('Add Teacher'),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                )
              : const SizedBox.shrink(key: ValueKey('fab-none')),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _LiquidGlass(
        animation: _glassController,
        radius: 24,
        blur: 16,
        tint: AppColors.surface,
        tintStrength: 1.6,
        borderColor: AppColors.primary.withOpacity(0.18),
        padding: const EdgeInsets.all(4),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          physics: const BouncingScrollPhysics(),
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withOpacity(0.95),
                Color.lerp(
                  AppColors.primary,
                  Colors.black,
                  0.2,
                )!.withOpacity(0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 3),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          tabs: const [
            _PillTab(icon: Icons.analytics_rounded, label: 'Analytics'),
            _PillTab(icon: Icons.people_alt_rounded, label: 'Teachers'),
            _PillTab(icon: Icons.school_rounded, label: 'Students'),
            _PillTab(icon: Icons.cloud_sync_rounded, label: 'Drive Backups'),
            _PillTab(icon: Icons.history_edu_rounded, label: 'Audit History'),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final darker = Color.lerp(AppColors.primary, Colors.black, 0.3)!;
    const headerRadius = BorderRadius.vertical(bottom: Radius.circular(28));

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * -24),
          child: child,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: headerRadius,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: headerRadius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, darker],
              ),
            ),
            child: Stack(
              children: [
                // Liquid blobs drifting behind the glass
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _glassController,
                      builder: (context, _) {
                        final t = _glassController.value * 2 * math.pi;
                        return Stack(
                          children: [
                            _blob(
                              Alignment(math.cos(t) * 0.9, math.sin(t) * 0.6),
                              110,
                              Colors.white.withOpacity(0.22),
                            ),
                            _blob(
                              Alignment(
                                math.sin(t * 1.3 + 1) * 0.9,
                                math.cos(t * 0.8) * 0.7,
                              ),
                              90,
                              Colors.cyanAccent.withOpacity(0.18),
                            ),
                            _blob(
                              Alignment(
                                math.cos(t * 0.7 + 2) * 0.8,
                                math.sin(t * 1.1 + 3) * 0.8,
                              ),
                              100,
                              Colors.pinkAccent.withOpacity(0.14),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                        child: Row(
                          children: [
                            _LiquidGlass(
                              animation: _glassController,
                              radius: 14,
                              blur: 12,
                              tint: Colors.white,
                              padding: const EdgeInsets.all(9),
                              child: const Icon(
                                Icons.admin_panel_settings_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MCQ Pro',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      height: 1.1,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Admin Console',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Refresh All Data',
                              onPressed: _isLoading ? null : _loadDashboardData,
                              icon: RotationTransition(
                                turns: _spinController,
                                child: const Icon(
                                  Icons.refresh_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Sign Out',
                              onPressed: _signOut,
                              icon: const Icon(
                                Icons.logout_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Quick actions
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _QuickAction(
                              animation: _glassController,
                              icon: Icons.person_add_rounded,
                              label: 'Add Teacher',
                              onTap: _navigateToAddTeacher,
                            ),
                            const SizedBox(width: 10),
                            _QuickAction(
                              animation: _glassController,
                              icon: Icons.vpn_key_rounded,
                              label: 'Password Vault',
                              onTap: _openPasswordVault,
                            ),
                            const SizedBox(width: 10),
                            _QuickAction(
                              animation: _glassController,
                              icon: Icons.auto_awesome_rounded,
                              label: 'Gemini Keys',
                              onTap: _openGeminiKeys,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Loading bar
                      if (_isLoading)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(60, 2, 60, 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              valueColor: const AlwaysStoppedAnimation(
                                Colors.white,
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _blob(Alignment alignment, double size, Color color) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
        ),
      ),
    );
  }
}

// ───────────────────────── Liquid glass ─────────────────────────

/// Frosted glass surface: backdrop blur + translucent gradient fill +
/// bright rim + a soft light sheen that slowly sweeps across.
class _LiquidGlass extends StatelessWidget {
  final Animation<double> animation;
  final double radius;
  final double blur;
  final Color tint;
  final double tintStrength;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final Widget child;

  const _LiquidGlass({
    required this.animation,
    required this.child,
    this.radius = 20,
    this.blur = 14,
    this.tint = Colors.white,
    this.tintStrength = 1.0,
    this.borderColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: br,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tint.withOpacity((0.30 * tintStrength).clamp(0.0, 1.0)),
                tint.withOpacity((0.10 * tintStrength).clamp(0.0, 1.0)),
              ],
            ),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.35),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // Moving sheen
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) {
                      final p = animation.value * 3 - 1; // -1 → 2
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-1 + p * 2, -1),
                            end: Alignment(1 + p * 2, 1),
                            colors: [
                              Colors.white.withOpacity(0),
                              Colors.white.withOpacity(0.22),
                              Colors.white.withOpacity(0),
                            ],
                            stops: const [0.35, 0.5, 0.65],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Top highlight (glass edge reflection)
              Positioned(
                left: radius * 0.6,
                right: radius * 0.6,
                top: 0,
                height: 1.2,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0),
                          Colors.white.withOpacity(0.7),
                          Colors.white.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(padding: padding ?? EdgeInsets.zero, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Small widgets ─────────────────────────

class _PillTab extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PillTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 5),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatefulWidget {
  final Animation<double> animation;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.animation,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 140),
          child: _LiquidGlass(
            animation: widget.animation,
            radius: 20,
            blur: 12,
            tint: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
