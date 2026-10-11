import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/animated_page.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';

class AdminCreateTeacherScreen extends StatefulWidget {
  const AdminCreateTeacherScreen({super.key});

  @override
  State<AdminCreateTeacherScreen> createState() => _AdminCreateTeacherScreenState();
}

class _AdminCreateTeacherScreenState extends State<AdminCreateTeacherScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final Set<String> _selectedStandards = {'11', '12'};
  final Set<String> _selectedDivisions = {'A', 'B'};
  final Set<String> _selectedMediums = {'English'};
  final Set<String> _selectedSubjects = {'Physics', 'Chemistry'};

  String _selectedInstitution = 'Sharda Mandir';
  String _selectedAcademicYear = '2026-2027';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generateRandomPassword();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _generateRandomPassword() {
    // Use clear alphanumeric characters (no confusing symbols like #, !, @)
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    final pass = List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join();
    _passwordController.text = pass;
  }

  void _createTeacher() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (_selectedStandards.isEmpty || _selectedDivisions.isEmpty || _selectedMediums.isEmpty || _selectedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one standard, division, medium, and subject')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService().createTeacher(
        name: name,
        email: email,
        temporaryPassword: password,
        standards: _selectedStandards.toList(),
        divisions: _selectedDivisions.toList(),
        mediums: _selectedMediums.toList(),
        subjects: _selectedSubjects.toList(),
        institution: _selectedInstitution,
        academicYear: _selectedAcademicYear,
      );

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
                SizedBox(width: 10),
                Text('Teacher Created!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Teacher $name has been registered successfully.', style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              email,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.key_rounded, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectableText(
                              password,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.primary,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The teacher will use this temporary password for first-time login, and will be prompted to create a new password.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            actions: [
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: 'Email: $email\nTemporary Password: $password'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied login credentials to clipboard!'),
                      backgroundColor: AppColors.success,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy Credentials'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errStr = e.toString().replaceAll('Exception:', '').trim();
        if (errStr.contains('user_already_exists') ||
            errStr.contains('already registered') ||
            errStr.contains('already exists')) {
          errStr = 'Email "$email" is already registered in Supabase. Please use a different/unique email address for this teacher.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errStr),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
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
      appBar: AppBar(
        title: const Text('Add Teacher & Scope'),
      ),
      body: AppGradientBackground(
        child: SafeArea(
          child: AnimatedPage(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Teacher Account Details',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Login Email / ID',
                            hintText: 'e.g. teacher.patel@school.org',
                            helperText: 'Must be a unique email address not already registered',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _passwordController,
                                decoration: const InputDecoration(
                                  labelText: 'Temporary Password',
                                  prefixIcon: Icon(Icons.key_rounded),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () {
                                final pw = _passwordController.text;
                                if (pw.isNotEmpty) {
                                  Clipboard.setData(ClipboardData(text: pw));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Password copied to clipboard'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.copy_rounded, size: 20),
                              tooltip: 'Copy Password',
                            ),
                            IconButton(
                              onPressed: _generateRandomPassword,
                              icon: const Icon(Icons.refresh_rounded),
                              tooltip: 'Regenerate Password',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Teaching Scope Assignment Card
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assign Teaching Scopes',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Teacher will ONLY have access to tests and students matching assigned scopes.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 18),

                        // Standards
                        const Text('Standards (Classes)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: ['11', '12'].map((std) {
                            final isSel = _selectedStandards.contains(std);
                            return FilterChip(
                              label: Text('Standard $std'),
                              selected: isSel,
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedStandards.add(std);
                                  } else {
                                    _selectedStandards.remove(std);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Divisions
                        const Text('Divisions / Groups', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: ['A', 'B', 'C', 'AB', 'Science'].map((div) {
                            final isSel = _selectedDivisions.contains(div);
                            return FilterChip(
                              label: Text('Div $div'),
                              selected: isSel,
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedDivisions.add(div);
                                  } else {
                                    _selectedDivisions.remove(div);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Mediums
                        const Text('Mediums', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: ['Gujarati', 'English', 'Both'].map((med) {
                            final isSel = _selectedMediums.contains(med);
                            return FilterChip(
                              label: Text(med == 'Both' ? 'Both (Gujarati & English)' : med),
                              selected: isSel,
                              onSelected: (val) {
                                setState(() {
                                  if (med == 'Both') {
                                    if (val) {
                                      _selectedMediums.clear();
                                      _selectedMediums.add('Both');
                                    } else {
                                      _selectedMediums.remove('Both');
                                    }
                                  } else {
                                    _selectedMediums.remove('Both');
                                    if (val) {
                                      _selectedMediums.add(med);
                                    } else {
                                      _selectedMediums.remove(med);
                                    }
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Subjects
                        const Text('Assigned Subjects', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: ['Physics', 'Chemistry', 'Biology', 'Math'].map((sub) {
                            final isSel = _selectedSubjects.contains(sub);
                            return FilterChip(
                              label: Text(sub),
                              selected: isSel,
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedSubjects.add(sub);
                                  } else {
                                    _selectedSubjects.remove(sub);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Institution & Academic Year
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
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
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _selectedAcademicYear,
                                dropdownColor: AppColors.surface,
                                iconEnabledColor: AppColors.primary,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Academic Year',
                                  labelStyle: TextStyle(color: AppColors.textSecondary),
                                ),
                                items: ['2026-2027', '2027-2028']
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
                                onChanged: (val) => setState(() => _selectedAcademicYear = val!),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _createTeacher,
                      icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.person_add_alt_1_rounded),
                      label: _isLoading
                          ? const SpinKitThreeBounce(color: Colors.white, size: 20)
                          : const Text('Create Teacher & Assign Permissions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
