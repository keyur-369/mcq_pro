import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
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
  late final AnimationController _floatCtrl;
  late final AnimationController _bgCtrl;
  late final AnimationController _shakeCtrl;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);
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
    _floatCtrl.dispose();
    _bgCtrl.dispose();
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

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Reset Password',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your registered email address. We will send you instructions to reset your password.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: _fieldDecoration(
                    hint: 'Enter your email address',
                    icon: Icons.alternate_email_rounded,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final email = resetEmailController.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter a valid email address',
                              ),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isSubmitting = true);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        try {
                          await SupabaseService().sendPasswordResetEmail(email);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Password reset link sent! Please check your email inbox.',
                              ),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (err) {
                          setDialogState(() => isSubmitting = false);
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('Failed to send reset link: $err'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Send Link'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ───────────────────────── UI HELPERS ─────────────────────────

  /// Fade + slide-up animation, staggered by [begin]/[end] (0.0 – 1.0).
  Widget _stagger({
    required double begin,
    required double end,
    required Widget child,
    double dy = 28,
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

  InputDecoration _fieldDecoration({
    String? label,
    required String hint,
    required IconData icon,
    bool focused = false,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: focused
          ? AppColors.primary.withOpacity(0.06)
          : Colors.grey.withOpacity(0.07),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      prefixIcon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          icon,
          key: ValueKey(focused),
          color: focused ? AppColors.primary : AppColors.textSecondary,
          size: 22,
        ),
      ),
      suffixIcon: suffix,
      floatingLabelStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
      border: border(Colors.transparent),
      enabledBorder: border(Colors.grey.withOpacity(0.18)),
      focusedBorder: border(AppColors.primary, 1.6),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error, 1.6),
    );
  }

  /// Soft blurred glowing circle used in the animated background.
  Widget _glowOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.28), color.withOpacity(0.0)],
        ),
      ),
    );
  }

  Widget _buildBackgroundOrbs(Size size) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_bgCtrl.value);
        return Stack(
          children: [
            Positioned(
              top: -90 + t * 50,
              right: -80 + t * 30,
              child: _glowOrb(300, AppColors.primary),
            ),
            Positioned(
              bottom: -110 + (1 - t) * 60,
              left: -90 + (1 - t) * 40,
              child: _glowOrb(340, AppColors.primaryGradient.last),
            ),
            Positioned(
              top: size.height * 0.38 + t * 30,
              left: -60 + t * 20,
              child: _glowOrb(160, AppColors.primary),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _floatCtrl,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_floatCtrl.value);
        return Transform.translate(
          offset: Offset(0, -7 * t),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // pulsing halo
              Container(
                width: 104 + 14 * t,
                height: 104 + 14 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.10 - 0.05 * t),
                ),
              ),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.primaryGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.30 + 0.12 * t),
                      blurRadius: 22 + 10 * t,
                      offset: Offset(0, 10 + 4 * t),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 46,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _featureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.primary.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInButton() {
    final disabled = _isLoading;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _buttonPressed = true),
      onTapCancel: () => setState(() => _buttonPressed = false),
      onTapUp: (_) => setState(() => _buttonPressed = false),
      onTap: disabled ? null : _login,
      child: AnimatedScale(
        scale: _buttonPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 54,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.primaryGradient
                  .map((c) => disabled ? c.withOpacity(0.75) : c)
                  .toList(),
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(disabled ? 0.12 : 0.35),
                blurRadius: _buttonPressed ? 8 : 18,
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
                : const Row(
                    key: ValueKey('label'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
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
    final theme = Theme.of(context);

    return Scaffold(
      body: AppGradientBackground(
        child: Stack(
          children: [
            _buildBackgroundOrbs(size),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 28,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // ── Branding ──
                          _stagger(
                            begin: 0.0,
                            end: 0.5,
                            dy: 20,
                            child: Column(
                              children: [
                                _buildLogo(),
                                const SizedBox(height: 20),
                                ShaderMask(
                                  shaderCallback: (rect) =>
                                      const LinearGradient(
                                        colors: AppColors.primaryGradient,
                                      ).createShader(rect),
                                  child: Text(
                                    'MCQ Pro',
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.8,
                                          color: Colors.white,
                                          fontSize: 34,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'AI Quiz & Test Platform',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    _featureChip(
                                      Icons.auto_awesome_rounded,
                                      'AI Quizzes',
                                    ),
                                    _featureChip(
                                      Icons.timer_outlined,
                                      'Timed Tests',
                                    ),
                                    _featureChip(
                                      Icons.insights_rounded,
                                      'Analytics',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),

                          // ── Login Card (with shake on error) ──
                          _stagger(
                            begin: 0.2,
                            end: 0.75,
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
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(26),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(
                                        0.10,
                                      ),
                                      blurRadius: 40,
                                      offset: const Offset(0, 18),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome back 👋',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.3,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Sign in to continue to your account',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Email
                                    TextFormField(
                                      controller: _emailController,
                                      focusNode: _emailFocus,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      onFieldSubmitted: (_) =>
                                          _passwordFocus.requestFocus(),
                                      decoration: _fieldDecoration(
                                        label: 'Email Address',
                                        hint: 'name@example.com',
                                        icon: Icons.alternate_email_rounded,
                                        focused: _emailFocus.hasFocus,
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return 'Please enter your email address';
                                        }
                                        if (!val.contains('@') ||
                                            !val.contains('.')) {
                                          return 'Please enter a valid email address';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    // Password
                                    TextFormField(
                                      controller: _passwordController,
                                      focusNode: _passwordFocus,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _login(),
                                      decoration: _fieldDecoration(
                                        label: 'Password',
                                        hint: 'Enter your password',
                                        icon: Icons.lock_outline_rounded,
                                        focused: _passwordFocus.hasFocus,
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
                                                  ? Icons.visibility_off_rounded
                                                  : Icons.visibility_rounded,
                                              key: ValueKey(_obscurePassword),
                                              size: 20,
                                              color: AppColors.textSecondary,
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

                                    const SizedBox(height: 14),

                                    _buildSignInButton(),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 26),

                          // ── Register link ──
                          _stagger(
                            begin: 0.45,
                            end: 0.9,
                            dy: 18,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    transitionDuration: const Duration(
                                      milliseconds: 400,
                                    ),
                                    pageBuilder: (_, __, ___) =>
                                        const SignupScreen(),
                                    transitionsBuilder: (_, anim, __, child) {
                                      final curved = CurvedAnimation(
                                        parent: anim,
                                        curve: Curves.easeOutCubic,
                                      );
                                      return FadeTransition(
                                        opacity: curved,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0, 0.06),
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
                                  text: 'New Student?  ',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14.5,
                                    fontFamily: GoogleFonts.outfit().fontFamily,
                                  ),
                                  children: const [
                                    TextSpan(
                                      text: 'Create an account',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
