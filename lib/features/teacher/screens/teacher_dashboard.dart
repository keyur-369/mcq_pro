import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/providers/api_key_provider.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/animated_page.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/features/auth/screens/login_screen.dart';
import 'package:mcq_test_app/features/teacher/screens/create_test_screen.dart';
import 'package:mcq_test_app/features/teacher/screens/teacher_profile_screen.dart';
import 'package:mcq_test_app/features/teacher/screens/teacher_results_screen.dart';
import 'package:mcq_test_app/features/teacher/screens/teacher_students_screen.dart';
import 'package:mcq_test_app/features/teacher/screens/teacher_tests_screen.dart';
import 'package:mcq_test_app/models/api_key.dart';
import 'package:mcq_test_app/models/app_user.dart';
import 'package:mcq_test_app/models/teacher_assignment.dart';
import 'package:mcq_test_app/models/test_backup.dart';

/// ---------------------------------------------------------------------------
/// Liquid glass primitive
/// Layers (bottom -> top):
///  1. soft tinted drop shadow
///  2. rim light (gradient border: bright top-left, faint bottom-right)
///  3. backdrop blur + translucent gradient fill
///  4. soft inner glow in the bottom-right corner
///  5. specular sheen along the top edge
/// ---------------------------------------------------------------------------
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? tint;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 18,
    this.blur = 20,
    this.tint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    final innerBr = BorderRadius.circular(radius - 1.2);
    final base = tint ?? Colors.white;
    final glow = tint ?? AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: glow.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          borderRadius: br,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.95),
              Colors.white.withOpacity(0.25),
              Colors.white.withOpacity(0.10),
              Colors.white.withOpacity(0.55),
            ],
            stops: const [0.0, 0.35, 0.65, 1.0],
          ),
        ),
        child: ClipRRect(
          borderRadius: innerBr,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          base.withOpacity(0.50),
                          base.withOpacity(0.16),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -30,
                  bottom: -30,
                  child: IgnorePointer(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            glow.withOpacity(0.15),
                            glow.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 44,
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
                    borderRadius: innerBr,
                    splashColor: Colors.white.withOpacity(0.25),
                    highlightColor: Colors.white.withOpacity(0.10),
                    child: Padding(padding: padding, child: child),
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

class TeacherDashboard extends ConsumerStatefulWidget {
  final AppUser? user;
  const TeacherDashboard({super.key, this.user});

  @override
  ConsumerState<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends ConsumerState<TeacherDashboard> {
  List<TeacherAssignment> _assignments = [];
  List<TestBackup> _backups = [];
  bool _isLoadingScope = true;
  String _teacherName = 'Teacher';

  @override
  void initState() {
    super.initState();
    if (widget.user?.name != null && widget.user!.name!.trim().isNotEmpty) {
      _teacherName = widget.user!.name!.trim();
    } else {
      final curUser = SupabaseService().currentUser;
      _teacherName =
          curUser?.userMetadata?['name']?.toString() ??
          curUser?.email?.split('@').first ??
          'Teacher';
    }
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    final user = SupabaseService().currentUser;
    if (user != null) {
      try {
        final profile = await SupabaseService().getUserProfile(user.id);
        final assignments = await SupabaseService().getTeacherAssignments(
          user.id,
        );
        final backups = await SupabaseService().getTestBackups();
        if (mounted) {
          setState(() {
            if (profile?.name != null && profile!.name!.trim().isNotEmpty) {
              _teacherName = profile.name!.trim();
            }
            _assignments = assignments;
            _backups = backups;
            _isLoadingScope = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingScope = false);
      }
    } else {
      if (mounted) setState(() => _isLoadingScope = false);
    }
  }

  Future<void> _logout() async {
    await SupabaseService().logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation helpers
  // ---------------------------------------------------------------------------
  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherProfileScreen(initialUser: widget.user),
      ),
    ).then((_) => _loadTeacherData());
  }

  void _openCreateTest() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateTestScreen()),
    ).then((_) => _loadTeacherData());
  }

  void _openStudents() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TeacherStudentsScreen()),
    );
  }

  void _openTests(String status) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TeacherTestsScreen(status: status)),
    );
  }

  void _openResults() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TeacherResultsScreen()),
    );
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _initials {
    final parts = _teacherName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'T';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final apiKeysAsync = ref.watch(apiKeysProvider);
    final selectedKey = ref.watch(selectedApiKeyProvider);

    return Scaffold(
      body: AppGradientBackground(
        child: Stack(
          children: [
            // Ambient colour blobs so the glass has something to refract.
            _ambientBlob(
              top: -60,
              left: -70,
              size: 260,
              color: AppColors.primary,
              opacity: 0.35,
            ),
            _ambientBlob(
              top: 300,
              right: -90,
              size: 260,
              color: AppColors.secondary,
              opacity: 0.28,
            ),
            _ambientBlob(
              bottom: 40,
              left: -80,
              size: 240,
              color: AppColors.accent,
              opacity: 0.28,
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: AnimatedPage(
                      child: RefreshIndicator(
                        onRefresh: _loadTeacherData,
                        color: AppColors.primary,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          children: [
                            _buildWelcomeBanner(),
                            const SizedBox(height: 12),
                            _buildStatsRow(),
                            const SizedBox(height: 18),
                            _buildSectionHeader(
                              title: 'AI Configuration',
                              subtitle: selectedKey == null
                                  ? 'No active AI key selected'
                                  : 'Active key: ${selectedKey.name}',
                            ),
                            const SizedBox(height: 10),
                            _buildApiKeySelector(
                              context,
                              ref,
                              apiKeysAsync,
                              selectedKey,
                            ),
                            const SizedBox(height: 18),
                            _buildSectionHeader(
                              title: 'Quick Actions',
                              subtitle: 'Create, manage and analyze tests',
                            ),
                            const SizedBox(height: 12),
                            _buildQuickActions(),
                            const SizedBox(height: 18),
                            _buildSectionHeader(
                              title: 'Cloud Backup',
                              subtitle: 'Google Drive archive of your tests',
                            ),
                            const SizedBox(height: 10),
                            _buildDriveBackupCard(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ambientBlob({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required Color color,
    required double opacity,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withOpacity(opacity), color.withOpacity(0.0)],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: GlassCard(
        radius: 20,
        blur: 20,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            // Avatar -> opens faculty profile
            GestureDetector(
              onTap: _openProfile,
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: AppColors.primaryGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.8)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'MCQ Pro',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'Teacher Console',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            _headerIconButton(
              icon: Icons.person_rounded,
              tooltip: 'Faculty Profile',
              color: AppColors.primary,
              onTap: _openProfile,
            ),
            const SizedBox(width: 6),
            _headerIconButton(
              icon: Icons.logout_rounded,
              tooltip: 'Logout',
              color: AppColors.textPrimary,
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GlassCard(
        radius: 12,
        blur: 12,
        padding: const EdgeInsets.all(7),
        onTap: onTap,
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Welcome banner
  // ---------------------------------------------------------------------------
  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.32),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(right: -24, top: -24, child: _glassOrb(110, 0.28, 0.04)),
            Positioned(
              right: 32,
              bottom: -20,
              child: _glassOrb(70, 0.20, 0.02),
            ),
            Positioned(
              left: -18,
              bottom: -28,
              child: _glassOrb(80, 0.14, 0.02),
            ),
            Positioned(
              right: 16,
              top: 14,
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white.withOpacity(0.45),
                size: 36,
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
                        Colors.white.withOpacity(0.22),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_greeting,',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(right: 50),
                    child: Text(
                      _teacherName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Create and manage AI-powered MCQ tests',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _bannerPill(
                        icon: Icons.person_outline_rounded,
                        label: 'Faculty Profile',
                        onTap: _openProfile,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannerPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool strong = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withOpacity(strong ? 0.30 : 0.20),
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(strong ? 0.65 : 0.45),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassOrb(double size, double a, double b) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(a), Colors.white.withOpacity(b)],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.32)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stats row
  // ---------------------------------------------------------------------------
  Widget _buildStatsRow() {
    final subjects = _assignments.map((a) => a.subject).toSet().length;
    final classes = _assignments
        .map((a) => '${a.standard}-${a.division}')
        .toSet()
        .length;
    final archived = _backups.where((b) => b.status == 'completed').length;

    return Row(
      children: [
        Expanded(
          child: _statTile(
            Icons.menu_book_rounded,
            _isLoadingScope ? '–' : '$subjects',
            'Subjects',
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            Icons.groups_rounded,
            _isLoadingScope ? '–' : '$classes',
            'Classes',
            AppColors.secondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            Icons.cloud_done_rounded,
            _isLoadingScope ? '–' : '$archived',
            'Archived',
            AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _statTile(IconData icon, String value, String label, Color color) {
    return GlassCard(
      radius: 16,
      blur: 16,
      tint: color,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBadge(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.75)),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  // ---------------------------------------------------------------------------
  // Section header
  // ---------------------------------------------------------------------------
  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.30),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Quick actions: one wide hero tile + 2x2 grid
  // ---------------------------------------------------------------------------
  Widget _buildQuickActions() {
    return Column(
      children: [
        _buildWideActionCard(
          title: 'Create Test',
          subtitle: 'Generate MCQs with AI in minutes',
          icon: Icons.add_circle_rounded,
          gradient: [AppColors.primary, AppColors.primaryLight],
          onTap: _openCreateTest,
        ),
        const SizedBox(height: 10),
        GridView.count(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.30,
          children: [
            _buildDashboardCard(
              title: 'My Students',
              subtitle: 'Directory & Roster',
              icon: Icons.people_alt_rounded,
              gradient: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              onTap: _openStudents,
            ),
            _buildDashboardCard(
              title: 'Published',
              subtitle: 'Live Tests',
              icon: Icons.rocket_launch_rounded,
              gradient: [AppColors.success, const Color(0xFF34D399)],
              onTap: () => _openTests('published'),
            ),
            _buildDashboardCard(
              title: 'Drafts',
              subtitle: 'In Progress',
              icon: Icons.edit_document,
              gradient: [AppColors.secondary, const Color(0xFFF472B6)],
              onTap: () => _openTests('draft'),
            ),
            _buildDashboardCard(
              title: 'Analytics',
              subtitle: 'Student Performance',
              icon: Icons.analytics_rounded,
              gradient: [AppColors.accent, const Color(0xFF67E8F9)],
              onTap: _openResults,
            ),
          ],
        ),
      ],
    );
  }

  Widget _gradientIcon(IconData icon, List<Color> gradient, double pad) {
    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.55)),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: pad > 8 ? 18 : 16),
    );
  }

  Widget _arrowChip() {
    return Container(
      padding: const EdgeInsets.all(4.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.45),
        border: Border.all(color: Colors.white.withOpacity(0.7)),
      ),
      child: const Icon(
        Icons.arrow_outward_rounded,
        size: 11,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildWideActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      onTap: onTap,
      tint: gradient.first,
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          _gradientIcon(icon, gradient, 9),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: -0.2,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _arrowChip(),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      onTap: onTap,
      tint: gradient.first,
      radius: 16,
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _gradientIcon(icon, gradient, 7),
              const Spacer(),
              _arrowChip(),
            ],
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: -0.2,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Drive backup
  // ---------------------------------------------------------------------------
  Widget _buildDriveBackupCard(BuildContext context) {
    final failedCount = _backups.where((b) => b.status == 'failed').length;
    final completedCount = _backups
        .where((b) => b.status == 'completed')
        .length;
    final statusColor = failedCount > 0 ? AppColors.error : AppColors.success;

    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      tint: failedCount > 0 ? AppColors.error : null,
      onTap: () => _showBackupStatusModal(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Icon(Icons.cloud_sync_rounded, color: statusColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Google Drive Backup Status',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  failedCount > 0
                      ? '$failedCount failed backup(s) • Tap to review and retry'
                      : '$completedCount tests safely archived in Google Drive',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: failedCount > 0
                        ? AppColors.error
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  void _showBackupStatusModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.74),
                    Colors.white.withOpacity(0.50),
                  ],
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.85),
                    width: 1.2,
                  ),
                ),
              ),
              child: StatefulBuilder(
                builder: (ctx, setModalState) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.textMuted.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(
                              Icons.add_to_drive_rounded,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Drive Backup Archive',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'All published tests and answer keys are archived in Google Drive under 7-day retention rules.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_backups.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'No backup records found yet',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ),
                          )
                        else
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: _backups.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              itemBuilder: (ctx, i) {
                                final b = _backups[i];
                                final isFailed = b.status == 'failed';
                                final isCompleted = b.status == 'completed';

                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    isCompleted
                                        ? Icons.check_circle_rounded
                                        : (isFailed
                                              ? Icons.error_rounded
                                              : Icons.hourglass_top_rounded),
                                    color: isCompleted
                                        ? AppColors.success
                                        : (isFailed
                                              ? AppColors.error
                                              : AppColors.secondary),
                                  ),
                                  title: Text(
                                    b.driveFileName ??
                                        'Test Backup #${b.testId.substring(0, 6)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Status: ${b.status.toUpperCase()} ${b.errorMessage != null ? "• ${b.errorMessage}" : ""}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isFailed
                                          ? AppColors.error
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                  trailing: isFailed
                                      ? TextButton.icon(
                                          onPressed: () async {
                                            final success =
                                                await SupabaseService()
                                                    .retryBackup(b.id, 'test');
                                            if (ctx.mounted) {
                                              ScaffoldMessenger.of(
                                                ctx,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    success
                                                        ? 'Retry initiated'
                                                        : 'Retry failed. Please contact Admin.',
                                                  ),
                                                  backgroundColor: success
                                                      ? AppColors.success
                                                      : AppColors.error,
                                                ),
                                              );
                                              await _loadTeacherData();
                                              setModalState(() {});
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.refresh_rounded,
                                            size: 14,
                                          ),
                                          label: const Text(
                                            'Retry',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        )
                                      : null,
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // AI key selector
  // ---------------------------------------------------------------------------
  Widget _buildApiKeySelector(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<ApiKey>> apiKeysAsync,
    ApiKey? selectedKey,
  ) {
    return apiKeysAsync.when(
      data: (keys) {
        if (selectedKey == null && keys.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(selectedApiKeyProvider.notifier).state = keys.first;
          });
        }

        return GlassCard(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _iconBadge(Icons.vpn_key_rounded, AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: keys.isEmpty
                    ? const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Provider',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'No keys configured by admin',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<ApiKey>(
                          value:
                              (selectedKey != null &&
                                  keys.contains(selectedKey))
                              ? selectedKey
                              : keys.first,
                          isExpanded: true,
                          itemHeight: null,
                          borderRadius: BorderRadius.circular(16),
                          dropdownColor: Colors.white.withOpacity(0.95),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                          ),
                          items: keys.map((key) {
                            return DropdownMenuItem<ApiKey>(
                              value: key,
                              child: Text(
                                key.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(selectedApiKeyProvider.notifier).state =
                                  val;
                            }
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}

