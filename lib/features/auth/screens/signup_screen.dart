import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/animated_page.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  String _selectedClass = '11';
  String _selectedDivision = 'A';
  String _selectedMedium = 'English';
  String _selectedGroup = 'Biology';
  String _selectedInstitution = 'Sharda Mandir';
  String _selectedAcademicYear = '2026-2027';

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  List<String> _getDivisionsForClass(String std) {
    if (std == '12') {
      return ['A', 'B', 'C'];
    } else {
      return ['A', 'B', 'AB', 'Science'];
    }
  }

  void _signup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await SupabaseService().signupStudent(
        email: email,
        password: password,
        name: name,
        studentClass: _selectedClass,
        division: _selectedDivision,
        medium: _selectedMedium,
        studentGroup: _selectedGroup,
        institution: _selectedInstitution,
        academicYear: _selectedAcademicYear,
      );

      final studentId = res.user?.id;
      String allocatedRollNo = 'Allocated';
      if (studentId != null) {
        final profile = await SupabaseService().getUserProfile(studentId);
        allocatedRollNo = profile?.rollNo ?? 'Allocated';
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success),
                SizedBox(width: 8),
                Text('Enrollment Complete!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome, $name! Your account has been created.'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.badge_rounded, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Assigned Roll Number: $allocatedRollNo',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('Standard: $_selectedClass - Division: $_selectedDivision (${_selectedMedium} Medium)'),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(context); // Return to login
                },
                child: const Text('Proceed to Login'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signup failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableDivisions = _getDivisionsForClass(_selectedClass);
    if (!availableDivisions.contains(_selectedDivision)) {
      _selectedDivision = availableDivisions.first;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AppGradientBackground(
        child: SafeArea(
          child: AnimatedPage(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'Student Registration',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enroll with your class and get an automatic roll number',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            hintText: 'Full Name',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'Email address',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Class & Division Row
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _selectedClass,
                                dropdownColor: AppColors.surface,
                                iconEnabledColor: AppColors.primary,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Standard',
                                  labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                  prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 24),
                                  prefixIcon: Padding(
                                    padding: EdgeInsets.only(left: 8, right: 6),
                                    child: Icon(Icons.school_outlined, size: 18, color: AppColors.primary),
                                  ),
                                ),
                                items: ['11', '12']
                                    .map((e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(
                                            'Std $e',
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedClass = val!;
                                    _selectedDivision = _getDivisionsForClass(val).first;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _selectedDivision,
                                dropdownColor: AppColors.surface,
                                iconEnabledColor: AppColors.primary,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Division',
                                  labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                  prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 24),
                                  prefixIcon: Padding(
                                    padding: EdgeInsets.only(left: 8, right: 6),
                                    child: Icon(Icons.groups_outlined, size: 18, color: AppColors.primary),
                                  ),
                                ),
                                items: availableDivisions
                                    .map((e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(
                                            'Div $e',
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (val) => setState(() => _selectedDivision = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Medium & Subject Group Row
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _selectedMedium,
                                dropdownColor: AppColors.surface,
                                iconEnabledColor: AppColors.primary,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Medium',
                                  labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                  prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 24),
                                  prefixIcon: Padding(
                                    padding: EdgeInsets.only(left: 8, right: 6),
                                    child: Icon(Icons.language_rounded, size: 18, color: AppColors.primary),
                                  ),
                                ),
                                items: ['English', 'Gujarati']
                                    .map((e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(
                                            e,
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (val) => setState(() => _selectedMedium = val!),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _selectedGroup,
                                dropdownColor: AppColors.surface,
                                iconEnabledColor: AppColors.primary,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Group',
                                  labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                  prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 24),
                                  prefixIcon: Padding(
                                    padding: EdgeInsets.only(left: 8, right: 6),
                                    child: Icon(Icons.science_outlined, size: 18, color: AppColors.primary),
                                  ),
                                ),
                                items: ['Biology', 'Maths']
                                    .map((e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(
                                            e,
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (val) => setState(() => _selectedGroup = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Institution
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedInstitution,
                          dropdownColor: AppColors.surface,
                          iconEnabledColor: AppColors.primary,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Institution',
                            labelStyle: TextStyle(color: AppColors.textSecondary),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            prefixIconConstraints: BoxConstraints(minWidth: 40, minHeight: 24),
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: 10, right: 8),
                              child: Icon(Icons.account_balance_outlined, size: 20, color: AppColors.primary),
                            ),
                          ),
                          items: ['Sharda Mandir', 'Tuition ACC']
                              .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (val) => setState(() => _selectedInstitution = val!),
                        ),
                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your official Roll Number will be generated automatically upon registration.',
                                  style: TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signup,
                            child: _isLoading
                                ? const SpinKitThreeBounce(color: Colors.white, size: 20)
                                : const Text('Complete Registration'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: RichText(
                        text: TextSpan(
                          text: "Already registered? ",
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontFamily: GoogleFonts.outfit().fontFamily,
                          ),
                          children: const [
                            TextSpan(
                              text: "Sign In",
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
    );
  }
}
