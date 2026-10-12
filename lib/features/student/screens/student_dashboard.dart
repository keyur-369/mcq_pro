import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/features/auth/screens/login_screen.dart';
import 'package:mcq_test_app/features/student/screens/history_screen.dart';
import 'package:mcq_test_app/features/student/screens/result_screen.dart';
import 'package:mcq_test_app/features/student/screens/test_taking_screen.dart';
import 'package:mcq_test_app/models/app_user.dart';
import 'package:mcq_test_app/models/test.dart';

/// Reusable liquid-glass surface (blur + translucent gradient + bright rim).
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final double blur;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.onTap,
    this.blur = 18,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.62),
                      Colors.white.withOpacity(0.28),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.70),
                    width: 1.2,
                  ),
                ),
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
  List<Map<String, dynamic>> _recentAttempts = [];
  bool _isHistoryLoading = true;
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
    // 2. Fetch recent history in background
    _loadDashboardData();
  }

  @override
  void dispose() {
    _testIdController.dispose();
    super.dispose();
  }

  // ───────────────────────── LOGIC (unchanged) ─────────────────────────

  Future<void> _loadDashboardData({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isHistoryLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final currentUser = _supabase.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(() {
            _isHistoryLoading = false;
            _errorMessage = 'User session expired. Please log in again.';
          });
        }
        return;
      }

      AppUser? profile = _user ?? widget.user;
      if (profile == null) {
        profile = await _supabase.getUserProfile(currentUser.id);
        profile ??= _supabase.getFallbackUserProfileFromAuth(currentUser);
      } else {
        _supabase
            .getUserProfile(currentUser.id)
            .then((p) {
              if (p != null && mounted) {
                setState(() => _user = p);
              }
            })
            .catchError((_) {});
      }

      if (profile != null) {
        _supabase.ensureStudentEnrollment(profile).catchError((_) {});
      }

      final history = await _supabase.getStudentHistory();

      if (mounted) {
        setState(() {
          _user = profile;
          _recentAttempts = history;
          _isHistoryLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading student dashboard: $e');
      if (mounted) {
        setState(() {
          _isHistoryLoading = false;
          _errorMessage = 'Could not load data: $e';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter test code')));
      return;
    }

    setState(() => _isJoiningById = true);

    try {
      final test = await _supabase.getPublishedTestByCode(enteredCode);
      if (!mounted) return;

      if (test == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid test code or test is not published'),
          ),
        );
        return;
      }

      final testDigit = RegExp(r'\d+').firstMatch(test.studentClass)?.group(0);
      final studentDigit = RegExp(r'\d+').firstMatch(studentClass)?.group(0);
      final isClassMatch = (testDigit != null && studentDigit != null)
          ? (testDigit == studentDigit)
          : (test.studentClass.trim().toLowerCase() ==
                studentClass.trim().toLowerCase());

      if (!isClassMatch) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'This test is for Std ${test.studentClass}, but you are in Std $studentClass',
            ),
          ),
        );
        return;
      }

      final testDiv = test.division?.trim().toUpperCase() ?? '';
      final studentDivClean = studentDivision.trim().toUpperCase();
      if (testDiv.isNotEmpty &&
          testDiv != 'ALL' &&
          testDiv != 'BOTH' &&
          testDiv != studentDivClean) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'This test is for Division $testDiv, but you are in Division $studentDivision',
            ),
          ),
        );
        return;
      }

      final alreadyAttempted = await _supabase.hasAttemptedTest(test.id);
      if (!mounted) return;
      if (alreadyAttempted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already submitted this test.'),
          ),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TestTakingScreen(test: test)),
      );

      _testIdController.clear();
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

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // soft color blobs so the glass has something to refract
              Positioned(
                top: -40,
                right: -60,
                child: _blob(AppColors.primary.withOpacity(0.22), 220),
              ),
              Positioned(
                top: 320,
                left: -90,
                child: _blob(AppColors.primary.withOpacity(0.14), 240),
              ),
              _buildBodyContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildBodyContent() {
    final currentUser = _supabase.currentUser;
    final user = _user;

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
        : (currentUser?.userMetadata?['institution']?.toString() ??
              'Sharda Mandir');

    return RefreshIndicator(
      onRefresh: () => _loadDashboardData(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          _buildHeader(
            name,
            className: studentClass,
            division: studentDiv,
            medium: studentMedium,
            rollNo: studentRoll,
            institution: studentInst,
          ),
          const SizedBox(height: 16),

          if (_errorMessage != null) ...[
            _buildErrorBanner(),
            const SizedBox(height: 16),
          ],

          _buildStatsRow(),
          const SizedBox(height: 16),

          _buildJoinWithTestIdCard(
            context: context,
            studentClass: studentClass,
            studentDivision: studentDiv,
          ),
          const SizedBox(height: 26),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
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
          const SizedBox(height: 6),

          if (_isHistoryLoading)
            _buildLoadingCard()
          else if (_recentAttempts.isEmpty)
            _buildEmptyCard()
          else
            Column(
              children: [
                for (int i = 0; i < _recentAttempts.take(5).length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _buildAttemptCard(_recentAttempts[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }

  // ── Header (top glass bar + hero card) ──
  Widget _buildHeader(
    String name, {
    required String className,
    required String division,
    required String medium,
    required String rollNo,
    required String institution,
  }) {
    final cleanName = name.trim().isNotEmpty ? name.trim() : 'Student';
    final initial = cleanName[0].toUpperCase();
    final cleanClass = className.trim().isNotEmpty ? className.trim() : '11';
    final cleanDiv = division.trim().isNotEmpty ? division.trim() : 'A';
    final cleanMedium = medium.trim().isNotEmpty ? medium.trim() : 'English';
    final cleanRoll = rollNo.trim().isNotEmpty ? rollNo.trim() : 'Allocated';
    final cleanInst = institution.trim().isNotEmpty
        ? institution.trim()
        : 'Sharda Mandir';

    void showProfile() {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: _GlassCard(
            radius: 26,
            blur: 24,
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _avatar(initial, 26),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        cleanName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _profileRow(Icons.school_rounded, 'Institution', cleanInst),
                _profileRow(
                  Icons.class_rounded,
                  'Class',
                  'Std $cleanClass-$cleanDiv',
                ),
                _profileRow(Icons.translate_rounded, 'Medium', cleanMedium),
                _profileRow(Icons.badge_rounded, 'Roll No', cleanRoll),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Top glass bar
        _GlassCard(
          radius: 26,
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              _avatar(initial, 22),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MCQ Pro',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Student Console',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _topIconButton(Icons.person_rounded, showProfile),
              const SizedBox(width: 8),
              _topIconButton(Icons.logout_rounded, _logout),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Hero card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary.withOpacity(0.85), AppColors.primary],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.30),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                Positioned(
                  top: -40,
                  right: -34,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.10),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -44,
                  right: 40,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                      border: Border.all(color: Colors.white.withOpacity(0.14)),
                    ),
                  ),
                ),
                Positioned(
                  top: 22,
                  right: 28,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 42,
                    color: Colors.white.withOpacity(0.55),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white,
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_greeting()} 👋',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    cleanName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 23,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _heroChip(Icons.school_rounded, cleanInst),
                                  _heroChip(Icons.class_rounded, 'Std $cleanClass-$cleanDiv'),
                                  _heroChip(Icons.translate_rounded, cleanMedium),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'ROLL NO',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    cleanRoll,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
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
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String initial, double radius) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary.withOpacity(0.8), AppColors.primary],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.30),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _topIconButton(IconData icon, VoidCallback onTap) {
    return _GlassCard(
      radius: 16,
      blur: 12,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, color: AppColors.primary, size: 21),
      ),
    );
  }

  Widget _profileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats ──
  Widget _buildStatsRow() {
    final scores = _recentAttempts
        .map((a) => int.tryParse(a['score']?.toString() ?? '') ?? 0)
        .toList();
    final total = scores.length;
    final best = scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b);
    final avg = scores.isEmpty
        ? 0
        : (scores.reduce((a, b) => a + b) / scores.length).round();

    return Row(
      children: [
        Expanded(
          child: _statTile(
            Icons.assignment_turned_in_rounded,
            '$total',
            'Tests',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statTile(Icons.trending_up_rounded, '$avg', 'Avg Score'),
        ),
        const SizedBox(width: 10),
        Expanded(child: _statTile(Icons.emoji_events_rounded, '$best', 'Best')),
      ],
    );
  }

  Widget _statTile(IconData icon, String value, String label) {
    return _GlassCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 6),
          Text(
            _isHistoryLoading ? '–' : value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Join card ──
  Widget _buildJoinWithTestIdCard({
    required BuildContext context,
    required String studentClass,
    required String studentDivision,
  }) {
    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.vpn_key_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Join a Test',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Enter the code shared by your teacher',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _testIdController,
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. ab12cd',
                    hintStyle: const TextStyle(
                      fontWeight: FontWeight.normal,
                      letterSpacing: 0,
                      color: AppColors.textMuted,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.55),
                    prefixIcon: const Icon(
                      Icons.pin_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.6,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onSubmitted: (_) {
                    if (!_isJoiningById) {
                      _joinTestById(
                        context: context,
                        studentClass: studentClass,
                        studentDivision: studentDivision,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 88,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(88, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Join',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── States ──
  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage ?? '',
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              size: 18,
              color: AppColors.error,
            ),
            onPressed: () => _loadDashboardData(showLoading: true),
            tooltip: 'Retry',
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return const _GlassCard(
      padding: EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
    );
  }

  Widget _buildEmptyCard() {
    return const _GlassCard(
      padding: EdgeInsets.all(26),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 40,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 10),
            Text(
              'No tests attempted yet.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              'Enter a test code from your teacher above to start.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttemptCard(Map<String, dynamic> attempt) {
    Map<String, dynamic>? testData;
    final rawTests = attempt['tests'];
    if (rawTests is Map<String, dynamic>) {
      testData = rawTests;
    } else if (rawTests is List &&
        rawTests.isNotEmpty &&
        rawTests.first is Map<String, dynamic>) {
      testData = rawTests.first as Map<String, dynamic>;
    }

    final subject = (testData?['subject'] ?? 'Unknown').toString();
    final topic = (testData?['topic'] ?? 'Untitled').toString();
    final score = attempt['score']?.toString() ?? '0';

    final attemptId = attempt['id']?.toString() ?? '';
    final testId = testData?['id']?.toString() ?? '';
    final parsedScore = int.tryParse(score) ?? 0;

    return _GlassCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
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
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.assignment_turned_in_rounded,
              color: AppColors.primary,
              size: 22,
            ),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tap to review answers',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$score pts',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 4),
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
        SnackBar(
          content: Text('Failed to load test details: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
