import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/animated_page.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';
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

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Prevent multiple submissions
    if (_isLoading) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
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
        final metaRole = authUser.userMetadata?['role']?.toString().toLowerCase().trim();
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
        // Admin Login -> Existing Admin Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
      } else if (role == 'teacher') {
        // Teacher Login:
        // First-time teacher login requires password change before dashboard access
        if (profile.mustChangePassword) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => ChangePasswordScreen(user: profile!)),
          );
        } else {
          // Returning teacher login -> Direct to Teacher Dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => TeacherDashboard(user: profile)),
          );
        }
      } else if (role == 'student') {
        // Student Login -> Existing Student Dashboard
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
        String msg = e.toString().replaceAll('Exception:', '').trim();
        if (msg.contains('invalid_credentials') ||
            msg.contains('Invalid login credentials') ||
            msg.contains('invalid-credentials')) {
          msg = 'Invalid email or password. Please verify your credentials or check with the administrator.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(msg)),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                const Text('Reset Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your registered email address. We will send you instructions to reset your password.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Enter your email address',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final email = resetEmailController.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid email address'),
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
                              content: Text('Password reset link sent! Please check your email inbox.'),
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
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Send Link'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: AnimatedPage(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // App Logo and Branding
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: AppColors.primaryGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.35),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.school_rounded,
                              color: Colors.white,
                              size: 44,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'MCQ Pro',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'AI Quiz & Test Platform',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Unified Login Card (No Role Selector)
                    AppCard(
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sign In',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Enter your credentials to access your account',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 24),

                          // Email Address Field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              hintText: 'name@example.com',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter your email address';
                              }
                              if (!val.contains('@') || !val.contains('.')) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Password Field with Show/Hide Toggle
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  size: 20,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                          const SizedBox(height: 10),

                          // Forgot Password Option
                          // Align(
                          //   alignment: Alignment.centerRight,
                          //   child: TextButton(
                          //     onPressed: _showForgotPasswordDialog,
                          //     style: TextButton.styleFrom(
                          //       padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          //       visualDensity: VisualDensity.compact,
                          //     ),
                          //     child: const Text(
                          //       'Forgot Password?',
                          //       style: TextStyle(
                          //         color: AppColors.primary,
                          //         fontSize: 13,
                          //         fontWeight: FontWeight.w600,
                          //       ),
                          //     ),
                          //   ),
                          // ),

                          const SizedBox(height: 16),

                          // Single Login Button with Loading Indicator
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const SpinKitThreeBounce(
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Dedicated New Student Registration Link
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SignupScreen()),
                          );
                        },
                        child: RichText(
                          text: TextSpan(
                            text: 'New Student? ',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              fontFamily: GoogleFonts.outfit().fontFamily,
                            ),
                            children: const [
                              TextSpan(
                                text: 'Register Here',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Reassuring Security / Role Note
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Admins, Teachers, and Students can sign in directly.\nYour role and dashboard will be loaded automatically.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            height: 1.4,
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
    );
  }
}
