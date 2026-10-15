import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/utils/academic_year_utils.dart';
import 'package:mcq_test_app/core/widgets/animated_page.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/models/app_user.dart';

class AdminCreateTeacherScreen extends StatefulWidget {
  final AppUser? teacher;
  const AdminCreateTeacherScreen({super.key, this.teacher});

  @override
  State<AdminCreateTeacherScreen> createState() => _AdminCreateTeacherScreenState();
}

class _AdminCreateTeacherScreenState extends State<AdminCreateTeacherScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final Set<String> _selectedStandards = {'11', '12'};
  final Set<String> _selectedDivisions = {};
  final Set<String> _selectedMediums = {'English'};
  final Set<String> _selectedSubjects = {'Physics', 'Chemistry'};

  String? _selectedInstitution;
  late List<String> _availableAcademicYears;
  String _selectedAcademicYear = '2026-2027';
  bool _isLoading = false;
  bool _isLoadingScopes = false;

  bool get isEditing => widget.teacher != null;

  @override
  void initState() {
    super.initState();
    _availableAcademicYears = AcademicYearUtils.getDynamicAcademicYears(
      extraYear: widget.teacher?.academicYear,
    );

    if (isEditing) {
      _nameController.text = widget.teacher!.name ?? '';
      _emailController.text = widget.teacher!.email;
      _passwordController.text = widget.teacher!.temporaryPassword ?? '';

      final inst = (widget.teacher!.institution ?? '').trim();
      if (inst.toLowerCase().contains('acc')) {
        _selectedInstitution = 'Tuition ACC';
      } else if (inst.isNotEmpty) {
        _selectedInstitution = 'Sharda Mandir';
      }

      if (widget.teacher!.academicYear != null && widget.teacher!.academicYear!.isNotEmpty) {
        _selectedAcademicYear = widget.teacher!.academicYear!;
        if (!_availableAcademicYears.contains(_selectedAcademicYear)) {
          _availableAcademicYears.add(_selectedAcademicYear);
          _availableAcademicYears.sort();
        }
      }

      _loadTeacherAssignments();
    } else {
      if (_availableAcademicYears.contains('2026-2027')) {
        _selectedAcademicYear = '2026-2027';
      } else {
        _selectedAcademicYear = AcademicYearUtils.getCurrentAcademicYear();
      }
      _generateRandomPassword();
    }
  }

  Future<void> _pickAcademicYearFromCalendar() async {
    final now = DateTime.now();
    int initialYear = now.year;
    final match = RegExp(r'^(\d{4})').firstMatch(_selectedAcademicYear);
    if (match != null) {
      final parsed = int.tryParse(match.group(1)!);
      if (parsed != null && parsed >= 2020 && parsed <= 2045) {
        initialYear = parsed;
      }
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(initialYear, 6),
      firstDate: DateTime(2020),
      lastDate: DateTime(2045),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select Start Year of Academic Session',
    );

    if (pickedDate != null) {
      final formatted = AcademicYearUtils.formatFromStartYear(pickedDate.year);
      setState(() {
        if (!_availableAcademicYears.contains(formatted)) {
          _availableAcademicYears.add(formatted);
          _availableAcademicYears.sort();
        }
        _selectedAcademicYear = formatted;
      });
    }
  }

  Future<void> _showCustomYearDialog() async {
    final controller = TextEditingController(text: AcademicYearUtils.getCurrentAcademicYear());
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Academic Year / Batch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter academic session batch (e.g. 2028-2029 or 2029-2030):',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Academic Year',
                hintText: 'YYYY-YYYY',
                prefixIcon: Icon(Icons.school_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx, text);
              }
            },
            child: const Text('Add & Select'),
          ),
        ],
      ),
    );

    if (res != null && res.isNotEmpty) {
      setState(() {
        if (!_availableAcademicYears.contains(res)) {
          _availableAcademicYears.add(res);
          _availableAcademicYears.sort();
        }
        _selectedAcademicYear = res;
      });
    }
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

  Future<void> _loadTeacherAssignments() async {
    if (widget.teacher == null) return;
    setState(() => _isLoadingScopes = true);
    try {
      final assignments = await SupabaseService().getTeacherAssignments(widget.teacher!.id);
      if (assignments.isNotEmpty && mounted) {
        setState(() {
          _selectedStandards.clear();
          _selectedDivisions.clear();
          _selectedMediums.clear();
          _selectedSubjects.clear();

          for (final a in assignments) {
            if (a.standard.isNotEmpty) _selectedStandards.add(a.standard);
            if (a.division.isNotEmpty) _selectedDivisions.add(a.division);
            if (a.medium.isNotEmpty) _selectedMediums.add(a.medium);
            if (a.subject.isNotEmpty) _selectedSubjects.add(a.subject);
          }

          if (assignments.first.institution.isNotEmpty) {
            final aInst = assignments.first.institution.toLowerCase();
            _selectedInstitution = aInst.contains('acc') ? 'Tuition ACC' : 'Sharda Mandir';
          }
          if (assignments.first.academicYear.isNotEmpty) {
            _selectedAcademicYear = assignments.first.academicYear;
            if (!_availableAcademicYears.contains(_selectedAcademicYear)) {
              _availableAcademicYears.add(_selectedAcademicYear);
              _availableAcademicYears.sort();
            }
          }

          if (_selectedMediums.contains('Gujarati') && _selectedMediums.contains('English')) {
            _selectedMediums.clear();
            _selectedMediums.add('Both');
          }

          // Clean up divisions according to institution to ensure no invalid cross-combinations
          if (_selectedInstitution == 'Sharda Mandir') {
            _selectedDivisions.removeWhere((d) => !['A', 'B', 'C'].contains(d.toUpperCase()));
          } else if (_selectedInstitution == 'Tuition ACC') {
            _selectedDivisions.removeWhere((d) => d.toUpperCase() != 'ACC');
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading teacher assignments: $e');
    } finally {
      if (mounted) setState(() => _isLoadingScopes = false);
    }
  }

  List<Map<String, String>> get _divisionOptions {
    if (_selectedInstitution == 'Sharda Mandir') {
      return const [
        {'val': 'A', 'label': 'Div A'},
        {'val': 'B', 'label': 'Div B'},
        {'val': 'C', 'label': 'Div C'},
      ];
    } else if (_selectedInstitution == 'Tuition ACC') {
      return const [
        {'val': 'ACC', 'label': 'ACC'},
      ];
    }
    return const [];
  }

  void _saveTeacher() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the teacher\'s name')),
      );
      return;
    }

    if (!isEditing && (email.isEmpty || password.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required account details')),
      );
      return;
    }

    if (_selectedInstitution == null || _selectedInstitution!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an Institution')),
      );
      return;
    }

    if (_selectedStandards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one Standard')),
      );
      return;
    }

    if (_selectedDivisions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one Division / Group')),
      );
      return;
    }

    // Frontend validation to prevent invalid institution-division combinations
    final isAcc = _selectedInstitution!.toLowerCase().contains('acc');
    if (isAcc) {
      final invalid = _selectedDivisions.where((d) => d.toUpperCase() != 'ACC').toList();
      if (invalid.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid divisions for Tuition ACC. Only ACC is allowed.')),
        );
        return;
      }
    } else {
      final invalid = _selectedDivisions.where((d) => !['A', 'B', 'C'].contains(d.toUpperCase())).toList();
      if (invalid.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid divisions for Sharda Mandir. Only Div A, Div B, Div C are allowed.')),
        );
        return;
      }
    }

    if (_selectedMediums.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one Medium')),
      );
      return;
    }

    if (_selectedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one Subject')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (isEditing) {
        await SupabaseService().updateTeacher(
          teacherId: widget.teacher!.id,
          name: name,
          standards: _selectedStandards.toList(),
          divisions: _selectedDivisions.toList(),
          mediums: _selectedMediums.toList(),
          subjects: _selectedSubjects.toList(),
          institution: _selectedInstitution!,
          academicYear: _selectedAcademicYear,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Teacher scope updated successfully!'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        await SupabaseService().createTeacher(
          name: name,
          email: email,
          temporaryPassword: password,
          standards: _selectedStandards.toList(),
          divisions: _selectedDivisions.toList(),
          mediums: _selectedMediums.toList(),
          subjects: _selectedSubjects.toList(),
          institution: _selectedInstitution!,
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
                  Expanded(
                    child: Text('Teacher Created!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
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
        title: Text(isEditing ? 'Edit Teacher & Scope' : 'Add Teacher & Scope'),
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
                        Text(
                          isEditing ? 'Teacher Account Info' : 'Teacher Account Details',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                          enabled: !isEditing,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Login Email / ID',
                            hintText: 'e.g. teacher.patel@school.org',
                            helperText: isEditing
                                ? 'Login ID cannot be modified once registered'
                                : 'Must be a unique email address not already registered',
                            prefixIcon: const Icon(Icons.alternate_email_rounded),
                          ),
                        ),
                        if (!isEditing) ...[
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
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Assign Teaching Scopes',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            if (_isLoadingScopes)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Teacher will ONLY have access to tests and students matching assigned scopes.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 18),

                        // 1. Standards (Classes) — selectable chips
                        const Text('Standards (Classes)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: ['11', '12'].map((std) {
                            final isSel = _selectedStandards.contains(std);
                            return FilterChip(
                              showCheckmark: false,
                              label: Text('Standard $std'),
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
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

                        // 2. Institution — Sharda mandir and Tuition ACC selectable chips
                        const Text('Institution', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              showCheckmark: false,
                              label: const Text('Sharda mandir'),
                              labelStyle: TextStyle(
                                color: _selectedInstitution == 'Sharda Mandir'
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              selected: _selectedInstitution == 'Sharda Mandir',
                              onSelected: (val) {
                                setState(() {
                                  if (_selectedInstitution != 'Sharda Mandir') {
                                    _selectedInstitution = 'Sharda Mandir';
                                    _selectedDivisions.clear();
                                  }
                                });
                              },
                            ),
                            ChoiceChip(
                              showCheckmark: false,
                              label: const Text('Tuition ACC'),
                              labelStyle: TextStyle(
                                color: _selectedInstitution == 'Tuition ACC'
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              selected: _selectedInstitution == 'Tuition ACC',
                              onSelected: (val) {
                                setState(() {
                                  if (_selectedInstitution != 'Tuition ACC') {
                                    _selectedInstitution = 'Tuition ACC';
                                    _selectedDivisions.clear();
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 3. Academic Year — dynamic dropdown with calendar picker
                        const Text('Academic Year', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _availableAcademicYears.contains(_selectedAcademicYear)
                                    ? _selectedAcademicYear
                                    : _availableAcademicYears.first,
                                dropdownColor: AppColors.surface,
                                iconEnabledColor: AppColors.primary,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                items: [
                                  ..._availableAcademicYears.map((e) => DropdownMenuItem(
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
                                      )),
                                  const DropdownMenuItem(
                                    value: '__custom__',
                                    child: Row(
                                      children: [
                                        Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.primary),
                                        SizedBox(width: 8),
                                        Text(
                                          '+ Custom Batch / Year...',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val == '__custom__') {
                                    _showCustomYearDialog();
                                  } else if (val != null) {
                                    setState(() => _selectedAcademicYear = val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _pickAcademicYearFromCalendar,
                              icon: const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                              tooltip: 'Pick Academic Year from Calendar',
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.cardLight,
                                padding: const EdgeInsets.all(12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: AppColors.border),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 4. Divisions / Groups — dynamic selectable chips
                        const Text('Divisions / Groups', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        if (_selectedInstitution == null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.cardLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.touch_app_outlined, size: 18, color: AppColors.textMuted),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Please select an institution above to choose divisions',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            children: _divisionOptions.map((div) {
                              final isSel = _selectedDivisions.contains(div['val']);
                              return FilterChip(
                                showCheckmark: false,
                                label: Text(div['label']!),
                                labelStyle: TextStyle(
                                  color: isSel ? Colors.white : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                selected: isSel,
                                onSelected: (val) {
                                  setState(() {
                                    if (val) {
                                      _selectedDivisions.add(div['val']!);
                                    } else {
                                      _selectedDivisions.remove(div['val']!);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 16),

                        // 5. Mediums — Gujarati, English, Both (Gujarati & English) selectable chips
                        const Text('Mediums', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: ['Gujarati', 'English', 'Both'].map((med) {
                            final isSel = _selectedMediums.contains(med);
                            return FilterChip(
                              showCheckmark: false,
                              label: Text(med == 'Both' ? 'Both (Gujarati & English)' : med),
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
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

                        // 6. Assigned Subjects — Physics, Chemistry, Biology, Math selectable chips
                        const Text('Assigned Subjects', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: ['Physics', 'Chemistry', 'Biology', 'Math'].map((sub) {
                            final isSel = _selectedSubjects.contains(sub);
                            return FilterChip(
                              showCheckmark: false,
                              label: Text(sub),
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveTeacher,
                      icon: _isLoading
                          ? const SizedBox.shrink()
                          : Icon(isEditing ? Icons.save_rounded : Icons.person_add_alt_1_rounded),
                      label: _isLoading
                          ? const SpinKitThreeBounce(color: Colors.white, size: 20)
                          : Text(
                              isEditing ? 'Update Teacher & Scope' : 'Create Teacher & Assign Permissions',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
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
