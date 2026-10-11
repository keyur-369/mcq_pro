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
  String _selectedRole = 'student'; // 'student', 'teacher', 'admin'
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

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService().login(email, password);
      final userId = response.user?.id;

      if (userId != null) {
        var profile = await SupabaseService().getUserProfile(userId);

        // Auto-heal: If user exists in Auth but missing from public.users
        if (profile == null) {
          try {
            final authUser = response.user!;
            final metaRole = authUser.userMetadata?['role']?.toString().toLowerCase() ?? _selectedRole;
            await SupabaseService().supabase.from('users').upsert({
              'id': userId,
              'email': email,
              'name': authUser.userMetadata?['name']?.toString() ?? email.split('@').first,
              'role': metaRole,
              'is_active': true,
              'must_change_password': false,
            });
            profile = await SupabaseService().getUserProfile(userId);
          } catch (e) {
            debugPrint('Could not auto-create profile row: $e');
          }
        }

        if (profile == null) {
          throw 'User profile not found in database. Please run the seed_admin.sql script in Supabase.';
        }

        if (!profile.isActive) {
          await SupabaseService().logout();
          throw 'This account has been deactivated. Please contact the administrator.';
        }

        final actualRole = profile.role.toLowerCase().trim();
        final expectedRole = _selectedRole.toLowerCase().trim();
        if (actualRole != expectedRole) {
          await SupabaseService().logout();
          throw 'You selected "$_selectedRole", but this account is registered as "${profile.role}". Please select "${profile.role}" above to sign in.';
        }

        if (profile.mustChangePassword) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => ChangePasswordScreen(user: profile!)),
            );
          }
          return;
        }

        if (mounted) {
          Widget destination;
          if (actualRole == 'admin') {
            destination = const AdminDashboard();
          } else if (actualRole == 'teacher') {
            destination = const TeacherDashboard();
          } else {
            destination = const StudentDashboard();
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => destination),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString().replaceAll('Exception:', '').trim();
        if (msg.contains('invalid_credentials') || msg.contains('Invalid login credentials')) {
          msg = 'Invalid email or password. Please verify your login credentials or check with the administrator.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: AnimatedPage(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.primaryGradient,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Welcome Back',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select your role and sign in to continue',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // Three-Role Selector Card
                  AppCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // 3-way Role Toggle
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.cardLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              _buildRoleTab('Student', 'student'),
                              _buildRoleTab('Teacher', 'teacher'),
                              _buildRoleTab('Admin', 'admin'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'Email address',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading
                                ? const SpinKitThreeBounce(
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : Text('Sign In as ${_selectedRole.toUpperCase()}'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_selectedRole == 'student')
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
                            text: "New student? ",
                            style: TextStyle(color: AppColors.textSecondary, fontFamily: GoogleFonts.outfit().fontFamily),
                            children: const [
                              TextSpan(
                                text: "Register Here",
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _selectedRole == 'teacher'
                              ? 'Teacher accounts are issued and managed by Main Admin.'
                              : 'Admin accounts are securely provisioned during deployment.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
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

  Widget _buildRoleTab(String label, String roleKey) {
    final isSelected = _selectedRole == roleKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = roleKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
