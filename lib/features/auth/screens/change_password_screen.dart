import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/animated_page.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/features/admin/screens/admin_dashboard.dart';
import 'package:mcq_test_app/features/auth/screens/login_screen.dart';
import 'package:mcq_test_app/features/student/screens/student_dashboard.dart';
import 'package:mcq_test_app/features/teacher/screens/teacher_dashboard.dart';
import 'package:mcq_test_app/models/app_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChangePasswordScreen extends StatefulWidget {
  final AppUser user;
  const ChangePasswordScreen({super.key, required this.user});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Update password securely in Supabase Auth and clear must_change_password flag
      await SupabaseService().updatePassword(newPass);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Password updated successfully! Welcome to MCQ Pro.'),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // 2. Redirect to the appropriate dashboard
        Widget destination;
        if (widget.user.isAdmin) {
          destination = const AdminDashboard();
        } else if (widget.user.isTeacher) {
          destination = TeacherDashboard(user: widget.user);
        } else {
          destination = StudentDashboard(user: widget.user);
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => destination),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (e is AuthException) {
          msg = e.message;
        } else {
          msg = msg
              .replaceAll('AuthApiException(message:', '')
              .replaceAll('Exception:', '')
              .split(', statusCode:')
              .first
              .trim();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(msg)),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await SupabaseService().logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: AnimatedPage(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
                      ),
                      child: const Icon(Icons.lock_reset_rounded, size: 38, color: AppColors.primary),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Set New Password',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You are signing in with a temporary password.\nPlease choose a new secure password to continue.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 30),
                    AppCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          TextField(
                            controller: _newPasswordController,
                            obscureText: _obscureNew,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'New Password',
                              hintText: 'Enter new password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureNew = !_obscureNew),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirm,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _savePassword(),
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              hintText: 'Re-enter new password',
                              prefixIcon: const Icon(Icons.lock_clock_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _savePassword,
                              child: _isLoading
                                  ? const SpinKitThreeBounce(color: Colors.white, size: 20)
                                  : const Text('Save & Continue', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: _isLoading ? null : _logout,
                      icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.textSecondary),
                      label: const Text(
                        'Cancel & Sign Out',
                        style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
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
