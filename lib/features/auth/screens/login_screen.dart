import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/features/admin/screens/admin_dashboard.dart';
import 'package:mcq_test_app/features/auth/screens/change_password_screen.dart';
import 'package:mcq_test_app/features/auth/screens/signup_screen.dart';
import 'package:mcq_test_app/features/student/screens/student_dashboard.dart';
import 'package:mcq_test_app/features/teacher/screens/teacher_dashboard.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _buttonPressed = false;

  late final AnimationController _entranceCtrl;
  late final AnimationController _shakeCtrl;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _entranceCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────── LOGIC (unchanged) ─────────────────────────

  Future<void> _login() async {
    // Prevent multiple submissions
    if (_isLoading) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      _shakeCtrl.forward(from: 0);
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);

    try {
      // 1. Authenticate with Supabase Auth
      final response = await SupabaseService().login(email, password);
      final userId = response.user?.id;

      if (userId == null) {
        throw 'Authentication failed: User ID not returned by server.';
      }

      // 2. Retrieve user's trusted profile from public.users using authenticated Supabase user ID
      var profile = await SupabaseService().getUserProfile(userId);

      // Auto-heal / complete profile if student signed up with email confirmation enabled
      if (profile == null && response.user != null) {
        final authUser = response.user!;
        final metaRole = authUser.userMetadata?['role']
            ?.toString()
            .toLowerCase()
            .trim();
        if (metaRole == 'student') {
          try {
            await SupabaseService().completeStudentProfileIfMissing(authUser);
            profile = await SupabaseService().getUserProfile(userId);
          } catch (e) {
            debugPrint('Could not complete student profile: $e');
          }
        }
      }

      // 3. Security verification: Profile must exist in trusted database table
      if (profile == null) {
        await SupabaseService().logout();
        throw 'User profile not found in database. Please contact the administrator.';
      }

      // 4. Security verification: Account must be active
      if (!profile.isActive) {
        await SupabaseService().logout();
        throw 'This account has been deactivated. Please contact the administrator.';
      }

      // 5. Determine user role from trusted database profile and route automatically
      final role = profile.role.toLowerCase().trim();

      if (!mounted) return;

      if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
      } else if (role == 'teacher') {
        // First-time teacher login requires password change before dashboard access
        if (profile.mustChangePassword) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ChangePasswordScreen(user: profile!),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => TeacherDashboard(user: profile)),
          );
        }
      } else if (role == 'student') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => StudentDashboard(user: profile)),
        );
      } else {
        // Invalid or unassigned role: reject and sign out
        await SupabaseService().logout();
        throw 'Unrecognized user role ("${profile.role}"). Access denied.';
      }
    } catch (e) {
      if (mounted) {
        _shakeCtrl.forward(from: 0);
        String msg = e.toString().replaceAll('Exception:', '').trim();
        if (msg.contains('invalid_credentials') ||
            msg.contains('Invalid login credentials') ||
            msg.contains('invalid-credentials')) {
          msg =
              'Invalid email or password. Please verify your credentials or check with the administrator.';
        } else if (msg.contains('Database error querying schema') ||
            msg.contains('unexpected_failure')) {
          msg =
              'Supabase database error querying schema. Please run the updated supabase/admin_teacher_auth_setup.sql in your Supabase SQL Editor.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(msg)),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }



  // ───────────────────────── UI COMPONENTS ─────────────────────────

  Widget _stagger({
    required double begin,
    required double end,
    required Widget child,
    double dy = 24,
  }) {
    final anim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, c) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - anim.value) * dy),
          child: c,
        ),
      ),
      child: child,
    );
  }

  Widget _buildHeaderImage(Size size) {
    final headerHeight = (size.height * 0.36).clamp(240.0, 340.0);
    return Container(
      height: headerHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
        child: Image.asset(
          'asset/images/login_hero.png',
          width: double.infinity,
          height: headerHeight,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: headerHeight,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF3B33BD),
                    Color(0xFF5B4DFF),
                    Color(0xFF7C3AED),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.school_rounded,
                  size: 64,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    bool isFocused = false,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: const Color(0xFF94A3B8),
      ),
      filled: true,
      fillColor: isFocused
          ? const Color(0xFFF1F3FF)
          : const Color(0xFFF4F6FB),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 16, right: 12),
        child: Icon(
          icon,
          size: 22,
          color: isFocused
              ? const Color(0xFF5B4DFF)
              : const Color(0xFF64748B),
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 48),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.grey.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.grey.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF5B4DFF),
          width: 1.6,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1.6,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final disabled = _isLoading;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _buttonPressed = true),
      onTapCancel: () => setState(() => _buttonPressed = false),
      onTapUp: (_) => setState(() => _buttonPressed = false),
      onTap: disabled ? null : _login,
      child: AnimatedScale(
        scale: _buttonPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: disabled
                  ? [
                      const Color(0xFF5B4DFF).withValues(alpha: 0.6),
                      const Color(0xFF7C5CFC).withValues(alpha: 0.6),
                    ]
                  : [
                      const Color(0xFF4338CA),
                      const Color(0xFF5B4DFF),
                      const Color(0xFF6C57F6),
                    ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5B4DFF).withValues(
                  alpha: disabled ? 0.15 : (_buttonPressed ? 0.20 : 0.38),
                ),
                blurRadius: _buttonPressed ? 8 : 20,
                offset: Offset(0, _buttonPressed ? 3 : 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _isLoading
                ? const SpinKitThreeBounce(
                    key: ValueKey('loading'),
                    color: Colors.white,
                    size: 20,
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Log In',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── BUILD ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Stack(
                children: [
                  // ── Full-height background: pure white with gentle ambient lavender warmth at the bottom ──
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white,
                              Colors.white,
                              Colors.white,
                              const Color(0xFFFBFBFF),
                              const Color(0xFFF1F0FD).withValues(alpha: 0.6),
                            ],
                            stops: const [0.0, 0.45, 0.70, 0.88, 1.0],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Soft lavender circular shapes positioned strictly at the bottom edge ──
                  Positioned(
                    bottom: -90,
                    right: -60,
                    child: IgnorePointer(
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEDE9FE).withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -120,
                    left: -70,
                    child: IgnorePointer(
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE0E7FF).withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ),

                  // ── Main Content Column stretched across full viewport height ──
                  IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top Hero Image (extends to top edge)
                        _stagger(
                          begin: 0.0,
                          end: 0.45,
                          dy: 12,
                          child: _buildHeaderImage(size),
                        ),

                        const SizedBox(height: 26),

                        // Form & Content Area
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 26),
                                child: Form(
                                  key: _formKey,
                                  child: AnimatedBuilder(
                                    animation: _shakeCtrl,
                                    builder: (_, child) {
                                      final t = _shakeCtrl.value;
                                      final dx =
                                          math.sin(t * math.pi * 5) * 10 * (1 - t);
                                      return Transform.translate(
                                        offset: Offset(dx, 0),
                                        child: child,
                                      );
                                    },
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // ── Header Title & Subtitle ──
                                        _stagger(
                                          begin: 0.15,
                                          end: 0.55,
                                          dy: 16,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Welcome Back',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 29,
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(0xFF1E2434),
                                                  letterSpacing: -0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Log in to continue learning',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: const Color(0xFF64748B),
                                                  letterSpacing: 0.1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(height: 26),

                                        // ── Email Input ──
                                        _stagger(
                                          begin: 0.25,
                                          end: 0.65,
                                          dy: 18,
                                          child: TextFormField(
                                            controller: _emailController,
                                            focusNode: _emailFocus,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            textInputAction:
                                                TextInputAction.next,
                                            style: GoogleFonts.outfit(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF1E2434),
                                            ),
                                            onFieldSubmitted: (_) =>
                                                _passwordFocus.requestFocus(),
                                            decoration: _inputDecoration(
                                              hint: 'Email address',
                                              icon: Icons.mail_outline_rounded,
                                              isFocused: _emailFocus.hasFocus,
                                            ),
                                            validator: (val) {
                                              if (val == null ||
                                                  val.trim().isEmpty) {
                                                return 'Please enter your email address';
                                              }
                                              if (!val.contains('@') ||
                                                  !val.contains('.')) {
                                                return 'Please enter a valid email address';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),

                                        const SizedBox(height: 16),

                                        // ── Password Input ──
                                        _stagger(
                                          begin: 0.35,
                                          end: 0.75,
                                          dy: 20,
                                          child: TextFormField(
                                            controller: _passwordController,
                                            focusNode: _passwordFocus,
                                            obscureText: _obscurePassword,
                                            textInputAction:
                                                TextInputAction.done,
                                            style: GoogleFonts.outfit(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF1E2434),
                                            ),
                                            onFieldSubmitted: (_) => _login(),
                                            decoration: _inputDecoration(
                                              hint: 'Password',
                                              icon: Icons.lock_outline_rounded,
                                              isFocused:
                                                  _passwordFocus.hasFocus,
                                              suffix: IconButton(
                                                icon: AnimatedSwitcher(
                                                  duration: const Duration(
                                                    milliseconds: 200,
                                                  ),
                                                  transitionBuilder: (c, a) =>
                                                      ScaleTransition(
                                                    scale: a,
                                                    child: c,
                                                  ),
                                                  child: Icon(
                                                    _obscurePassword
                                                        ? Icons
                                                            .visibility_off_outlined
                                                        : Icons
                                                            .visibility_outlined,
                                                    key: ValueKey(
                                                        _obscurePassword),
                                                    size: 20,
                                                    color:
                                                        const Color(0xFF64748B),
                                                  ),
                                                ),
                                                onPressed: () => setState(
                                                  () => _obscurePassword =
                                                      !_obscurePassword,
                                                ),
                                              ),
                                            ),
                                            validator: (val) {
                                              if (val == null || val.isEmpty) {
                                                return 'Please enter your password';
                                              }
                                              if (val.length < 6) {
                                                return 'Password must be at least 6 characters';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),

                                        const SizedBox(height: 24),

                                        // ── Log In Button ──
                                        _stagger(
                                          begin: 0.45,
                                          end: 0.85,
                                          dy: 20,
                                          child: _buildSubmitButton(),
                                        ),

                                        const SizedBox(height: 24),

                                        // ── Create Account Link ──
                                        _stagger(
                                          begin: 0.55,
                                          end: 0.95,
                                          dy: 16,
                                          child: Center(
                                            child: GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  PageRouteBuilder(
                                                    transitionDuration:
                                                        const Duration(
                                                      milliseconds: 400,
                                                    ),
                                                    pageBuilder:
                                                        (context, _, _) =>
                                                            const SignupScreen(),
                                                    transitionsBuilder:
                                                        (context, anim, _,
                                                            child) {
                                                      final curved =
                                                          CurvedAnimation(
                                                        parent: anim,
                                                        curve: Curves
                                                            .easeOutCubic,
                                                      );
                                                      return FadeTransition(
                                                        opacity: curved,
                                                        child: SlideTransition(
                                                          position:
                                                              Tween<Offset>(
                                                            begin: const Offset(
                                                                0, 0.06),
                                                            end: Offset.zero,
                                                          ).animate(curved),
                                                          child: child,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                );
                                              },
                                              child: RichText(
                                                text: TextSpan(
                                                  text: 'New to MCQ Pro? ',
                                                  style: GoogleFonts.outfit(
                                                    color:
                                                        const Color(0xFF64748B),
                                                    fontSize: 14.5,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  children: [
                                                    TextSpan(
                                                      text: 'Create Account',
                                                      style: GoogleFonts.outfit(
                                                        color:
                                                            const Color(0xFF4338CA),
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 40),
                                      ],
                                    ),
                                  ),
                                ),
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
        },
      ),
    );
  }
}
