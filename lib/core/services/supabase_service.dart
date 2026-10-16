import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mcq_test_app/models/app_user.dart';
import 'package:mcq_test_app/models/test.dart';
import 'package:mcq_test_app/models/question.dart';
import 'package:mcq_test_app/models/api_key.dart';
import 'package:mcq_test_app/models/teacher_assignment.dart';
import 'package:mcq_test_app/models/academic_configuration.dart';
import 'package:mcq_test_app/models/test_backup.dart';
import 'package:mcq_test_app/models/performance_aggregate.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get supabase => Supabase.instance.client;

  static const String supabaseUrl = 'https://hlygfkobyemsjgjuqdhi.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhseWdma29ieWVtc2pnanVxZGhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcwMzg3NDksImV4cCI6MjA5MjYxNDc0OX0.gYl44Ki2p0WQCUl0hWdvbNIaNzI17xmnp5JnlHsluZk';

  // Backend API Base URL (Default to local server or configured host)
  static const String backendBaseUrl = 'http://localhost:3000';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  // ── Auth ───────────────────────────────────────────────────────────────────
  User? get currentUser => supabase.auth.currentUser;

  Future<AuthResponse> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    AuthResponse? response;
    dynamic firstError;

    // 1. Standard signInWithPassword attempt
    try {
      response = await supabase.auth.signInWithPassword(
        email: cleanEmail,
        password: cleanPassword,
      );
    } catch (e) {
      firstError = e;
      debugPrint('Initial signInWithPassword failed: $e. Checking auto-sync...');

      // If error is schema scan failure (NULL tokens in auth.users) or server error, attempt auto-repair
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('database error querying schema') ||
          errStr.contains('unexpected_failure') ||
          errStr.contains('statuscode: 500') ||
          errStr.contains('converting null to string')) {
        try {
          debugPrint('Attempting auto-repair via repair_auth_users RPC...');
          await supabase.rpc('repair_auth_users');
          // Retry login immediately after repair
          response = await supabase.auth.signInWithPassword(
            email: cleanEmail,
            password: cleanPassword,
          );
        } catch (repairErr) {
          debugPrint('repair_auth_users attempt failed: $repairErr');
        }
      }
    }

    // 2. Fallback: Check teacher_temp_login RPC and handle prefix variances (#)
    if (response == null || response.user == null) {
      final passwordsToTry = <String>[];
      if (cleanPassword.startsWith('#')) {
        passwordsToTry.add(cleanPassword.substring(1));
      }
      passwordsToTry.add(cleanPassword);
      if (!cleanPassword.startsWith('#')) {
        passwordsToTry.add('#$cleanPassword');
      }

      for (final pw in passwordsToTry) {
        // A. Try direct signInWithPassword with normalized password
        try {
          response = await supabase.auth.signInWithPassword(
            email: cleanEmail,
            password: pw,
          );
          if (response.user != null) break;
        } catch (_) {}

        // B. Try teacher_temp_login RPC to auto-heal / sync temporary password
        try {
          final synced = await supabase.rpc('teacher_temp_login', params: {
            'p_email': cleanEmail,
            'p_password': pw,
          });
          if (synced == true) {
            response = await supabase.auth.signInWithPassword(
              email: cleanEmail,
              password: pw,
            );
            if (response.user != null) break;
          }
        } catch (_) {}
      }
    }

    if (response == null || response.user == null) {
      throw firstError ?? 'Invalid email or password. Please verify your login credentials or check with the administrator.';
    }

    final profile = await getUserProfile(response.user!.id);
    if (profile != null && !profile.isActive) {
      await logout();
      throw 'Your account has been deactivated. Please contact the administrator.';
    }

    return response;
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      throw 'Please enter your email address.';
    }
    await supabase.auth.resetPasswordForEmail(cleanEmail);
  }

  Future<void> updatePassword(String newPassword) async {
    final user = currentUser;
    if (user == null) throw 'Not logged in';

    try {
      await supabase.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      // If the user confirms or keeps the password provisioned by the admin,
      // Supabase returns 'same_password'. We accept it and clear must_change_password.
      if (e.code == 'same_password' ||
          e.message.toLowerCase().contains('different from the old password') ||
          e.message.toLowerCase().contains('same_password')) {
        debugPrint('Password already matches Supabase Auth credential. Clearing must_change_password flag.');
      } else {
        rethrow;
      }
    } catch (e) {
      final str = e.toString().toLowerCase();
      if (str.contains('same_password') || str.contains('different from the old password')) {
        debugPrint('Password already matches Supabase Auth credential. Clearing must_change_password flag.');
      } else {
        rethrow;
      }
    }

    // Update public.users to clear must_change_password flag
    try {
      await supabase.from('users').update({
        'must_change_password': false,
        'temporary_password': null,
      }).eq('id', user.id);
    } catch (dbErr) {
      // If temporary_password column is not present in public.users, update only must_change_password
      try {
        await supabase.from('users').update({
          'must_change_password': false,
        }).eq('id', user.id);
      } catch (err2) {
        debugPrint('Could not update must_change_password: $err2');
      }
    }
  }

  Future<AppUser?> getUserProfile(String userId) async {
    try {
      final response = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (response == null) return null;
      return AppUser.fromMap(response);
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  // ── Student Registration & Atomic Enrollment ──────────────────────────────
  Future<AuthResponse> signupStudent({
    required String email,
    required String password,
    required String name,
    required String studentClass,
    required String division,
    required String medium,
    String? studentGroup,
    String institution = 'Sharda Mandir',
    String academicYear = '2026-2027',
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final effectiveGroup = (studentGroup != null && studentGroup.trim().isNotEmpty)
        ? studentGroup.trim()
        : 'Biology';
    final response = await supabase.auth.signUp(
      email: cleanEmail,
      password: password,
      data: {
        'role': 'student',
        'name': name.trim(),
        'class': int.tryParse(studentClass),
        'division': division,
        'medium': medium,
        'student_group': effectiveGroup,
        'institution': institution,
        'academic_year': academicYear,
      },
    );

    final user = response.user;
    if (user != null) {
      try {
        // 1. Allocate roll number atomically via RPC or Backend API
        String allocatedRollNo;
        try {
          final rpcRes = await supabase.rpc('allocate_student_roll_no', params: {
            'p_institution': institution,
            'p_academic_year': academicYear,
            'p_standard': studentClass,
            'p_division': division,
          });
          allocatedRollNo = rpcRes.toString();
        } catch (_) {
          // Fallback: Query max roll number
          final countRes = await supabase
              .from('student_enrollments')
              .select('roll_no')
              .eq('institution', institution)
              .eq('academic_year', academicYear)
              .eq('standard', studentClass)
              .eq('division', division);
          int max = 0;
          for (var row in (countRes as List)) {
            final n = int.tryParse(row['roll_no'].toString()) ?? 0;
            if (n > max) max = n;
          }
          allocatedRollNo = (max + 1).toString();
        }

        // 2. Save profile in public.users
        await supabase.from('users').upsert({
          'id': user.id,
          'role': 'student',
          'email': cleanEmail,
          'name': name.trim(),
          'class': int.tryParse(studentClass),
          'division': division,
          'medium': medium,
          'roll_no': allocatedRollNo,
          'student_group': effectiveGroup,
          'institution': institution,
          'academic_year': academicYear,
          'is_active': true,
          'must_change_password': false,
        });

        // 3. Save enrollment in public.student_enrollments
        await supabase.from('student_enrollments').upsert({
          'student_id': user.id,
          'institution': institution,
          'academic_year': academicYear,
          'standard': studentClass,
          'division': division,
          'medium': medium,
          'student_group': effectiveGroup,
          'roll_no': allocatedRollNo,
        });
      } catch (profileErr) {
        // If email confirmation is enabled, public table inserts might await email verification
        debugPrint('Profile row insertion deferred (email confirmation may be required): $profileErr');
      }
    }

    return response;
  }

  /// Automatically creates missing public.users and student_enrollments
  /// when a verified student logs in after email verification.
  /// Strictly restricted to role = 'student' for security.
  Future<void> completeStudentProfileIfMissing(User authUser) async {
    final meta = authUser.userMetadata;
    if (meta == null) return;
    final role = meta['role']?.toString().toLowerCase().trim();
    if (role != 'student') return; // Security boundary: only students can be auto-completed

    final userId = authUser.id;
    final existing = await getUserProfile(userId);
    if (existing != null) return;

    final email = authUser.email ?? '';
    final name = meta['name']?.toString() ?? email.split('@').first;
    final studentClass = meta['class']?.toString() ?? '11';
    final division = meta['division']?.toString() ?? 'A';
    final medium = meta['medium']?.toString() ?? 'English';
    final studentGroup = meta['student_group']?.toString();
    final effectiveGroup = (studentGroup != null && studentGroup.trim().isNotEmpty)
        ? studentGroup.trim()
        : 'Biology';
    final institution = meta['institution']?.toString() ?? 'Sharda Mandir';
    final academicYear = meta['academic_year']?.toString() ?? '2026-2027';

    // 1. Allocate roll number
    String allocatedRollNo;
    try {
      final rpcRes = await supabase.rpc('allocate_student_roll_no', params: {
        'p_institution': institution,
        'p_academic_year': academicYear,
        'p_standard': studentClass,
        'p_division': division,
      });
      allocatedRollNo = rpcRes.toString();
    } catch (_) {
      final countRes = await supabase
          .from('student_enrollments')
          .select('roll_no')
          .eq('institution', institution)
          .eq('academic_year', academicYear)
          .eq('standard', studentClass)
          .eq('division', division);
      int max = 0;
      for (var row in (countRes as List)) {
        final n = int.tryParse(row['roll_no'].toString()) ?? 0;
        if (n > max) max = n;
      }
      allocatedRollNo = (max + 1).toString();
    }

    // 2. Save profile in public.users
    await supabase.from('users').upsert({
      'id': userId,
      'role': 'student',
      'email': email.trim().toLowerCase(),
      'name': name.trim(),
      'class': int.tryParse(studentClass),
      'division': division,
      'medium': medium,
      'roll_no': allocatedRollNo,
      'student_group': effectiveGroup,
      'institution': institution,
      'academic_year': academicYear,
      'is_active': true,
      'must_change_password': false,
    });

    // 3. Save enrollment in public.student_enrollments
    await supabase.from('student_enrollments').upsert({
      'student_id': userId,
      'institution': institution,
      'academic_year': academicYear,
      'standard': studentClass,
      'division': division,
      'medium': medium,
      'student_group': effectiveGroup,
      'roll_no': allocatedRollNo,
    });
  }

  /// Extracts user profile details directly from Supabase Auth metadata
  /// as a resilient fallback if the database row is still provisioning or inaccessible.
  AppUser getFallbackUserProfileFromAuth(User authUser) {
    final meta = authUser.userMetadata ?? {};
    final email = authUser.email ?? '';
    final name = meta['name']?.toString() ?? email.split('@').first;
    final role = meta['role']?.toString().toLowerCase().trim() ?? 'student';
    final studentClass = meta['class']?.toString() ?? '11';
    final division = meta['division']?.toString() ?? 'A';
    final medium = meta['medium']?.toString() ?? 'English';
    final studentGroup = meta['student_group']?.toString();
    final institution = meta['institution']?.toString() ?? 'Sharda Mandir';
    final academicYear = meta['academic_year']?.toString() ?? '2026-2027';

    return AppUser(
      id: authUser.id,
      role: role,
      email: email,
      name: name,
      studentClass: studentClass,
      division: division,
      rollNo: meta['roll_no']?.toString() ?? 'Allocated',
      studentGroup: studentGroup,
      medium: medium,
      institution: institution,
      academicYear: academicYear,
      isActive: true,
    );
  }

  Future<void> ensureStudentEnrollment(AppUser user) async {
    if (!user.isStudent) return;
    try {
      final existing = await supabase
          .from('student_enrollments')
          .select('id')
          .eq('student_id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 3), onTimeout: () => null);

      if (existing == null) {
        String assignedRoll = (user.rollNo != null && user.rollNo!.isNotEmpty && user.rollNo != 'Allocated')
            ? user.rollNo!
            : '';

        if (assignedRoll.isEmpty) {
          try {
            final maxRes = await supabase
                .from('student_enrollments')
                .select('roll_no')
                .eq('institution', user.institution ?? 'Sharda Mandir')
                .eq('academic_year', user.academicYear ?? '2026-2027')
                .eq('standard', user.studentClass ?? '11')
                .eq('division', user.division ?? 'A')
                .order('roll_no', ascending: false)
                .limit(1)
                .maybeSingle();
            final lastRoll = int.tryParse(maxRes?['roll_no']?.toString() ?? '') ?? 0;
            assignedRoll = (lastRoll + 1).toString();
          } catch (_) {
            assignedRoll = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
          }
        }

        try {
          await supabase.from('student_enrollments').insert({
            'student_id': user.id,
            'institution': user.institution ?? 'Sharda Mandir',
            'academic_year': user.academicYear ?? '2026-2027',
            'standard': user.studentClass ?? '11',
            'division': user.division ?? 'A',
            'medium': user.medium ?? 'English',
            'student_group': user.studentGroup,
            'roll_no': assignedRoll,
          }).timeout(const Duration(seconds: 3));
        } catch (_) {
          // If conflict still occurs on roll_no, retry once with a unique discriminator
          final uniqueRoll = '${user.rollNo ?? "1"}_${DateTime.now().millisecondsSinceEpoch % 10000}';
          await supabase.from('student_enrollments').insert({
            'student_id': user.id,
            'institution': user.institution ?? 'Sharda Mandir',
            'academic_year': user.academicYear ?? '2026-2027',
            'standard': user.studentClass ?? '11',
            'division': user.division ?? 'A',
            'medium': user.medium ?? 'English',
            'student_group': user.studentGroup,
            'roll_no': uniqueRoll,
          }).timeout(const Duration(seconds: 3));
        }
      }
    } catch (e) {
      debugPrint('Notice: student enrollment ensured: $e');
    }
  }

  // ── Main Admin: Student Management ────────────────────────────────────────
  Future<List<AppUser>> getAllStudents() async {
    try {
      dynamic response;
      try {
        response = await supabase
            .from('users')
            .select()
            .eq('role', 'student')
            .order('roll_no', ascending: true);
      } catch (err1) {
        debugPrint('Direct eq student query error: $err1, trying client-side filtered select');
        try {
          final allUsers = await supabase.from('users').select();
          response = (allUsers as List).where((u) {
            final r = (u['role'] ?? '').toString().toLowerCase().trim();
            return r == 'student';
          }).toList();
        } catch (err2) {
          debugPrint('All users select error: $err2');
          rethrow;
        }
      }
      final list = (response as List? ?? []);
      return list.map((e) {
        try {
          return AppUser.fromMap(Map<String, dynamic>.from(e));
        } catch (err) {
          debugPrint('Error parsing student row: $err');
          return null;
        }
      }).whereType<AppUser>().toList();
    } catch (e) {
      debugPrint('Error getting all students: $e');
      rethrow;
    }
  }

  Future<void> setStudentStatus(String studentId, bool isActive) async {
    await supabase.from('users').update({
      'is_active': isActive,
    }).eq('id', studentId);
  }

  // ── Main Admin: Password Vault & User Credential Management ───────────────
  Future<List<AppUser>> getAllUsers() async {
    try {
      final response = await supabase
          .from('users')
          .select()
          .order('name', ascending: true);
      final list = (response as List? ?? []);
      return list.map((e) {
        try {
          return AppUser.fromMap(Map<String, dynamic>.from(e));
        } catch (_) {
          return null;
        }
      }).whereType<AppUser>().toList();
    } catch (e) {
      debugPrint('Error getting all users for vault: $e');
      rethrow;
    }
  }

  Future<void> adminSetUserPassword({
    required String userId,
    required String email,
    required String newPassword,
    bool mustChangePassword = true,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPw = newPassword.trim();

    // 1. Try atomic PostgreSQL RPC function
    try {
      await supabase.rpc('admin_set_user_password', params: {
        'p_user_id': userId,
        'p_email': cleanEmail,
        'p_new_password': cleanPw,
        'p_must_change': mustChangePassword,
      });
      debugPrint('✅ Password set via admin_set_user_password RPC for: $cleanEmail');
      return;
    } catch (rpcErr) {
      debugPrint('admin_set_user_password RPC error, trying fallback: $rpcErr');
    }

    // 2. Fallback: Try admin_reset_teacher_password RPC
    try {
      await supabase.rpc('admin_reset_teacher_password', params: {
        'p_teacher_id': userId,
        'p_new_password': cleanPw,
      });
    } catch (_) {}

    // 3. Fallback: Update public.users
    try {
      await supabase.from('users').update({
        'temporary_password': cleanPw,
        'must_change_password': mustChangePassword,
        'is_active': true,
      }).eq('id', userId);
    } catch (_) {
      try {
        await supabase.from('users').update({
          'must_change_password': mustChangePassword,
          'is_active': true,
        }).eq('id', userId);
      } catch (err) {
        debugPrint('Could not update user password flag: $err');
      }
    }
  }

  // ── Main Admin: Teacher Management & Assignments ──────────────────────────
  Future<List<AppUser>> getAllTeachers() async {
    try {
      dynamic response;
      try {
        response = await supabase
            .from('users')
            .select()
            .eq('role', 'teacher');
      } catch (err1) {
        debugPrint('Direct eq teacher query error: $err1, trying client-side filtered select');
        try {
          final allUsers = await supabase.from('users').select();
          response = (allUsers as List).where((u) {
            final r = (u['role'] ?? '').toString().toLowerCase().trim();
            return r == 'teacher';
          }).toList();
        } catch (err2) {
          debugPrint('All users select error: $err2');
          rethrow;
        }
      }
      final list = (response as List? ?? []);
      return list.map((e) {
        try {
          return AppUser.fromMap(Map<String, dynamic>.from(e));
        } catch (err) {
          debugPrint('Error parsing teacher row: $err');
          return null;
        }
      }).whereType<AppUser>().toList();
    } catch (e) {
      debugPrint('Error getting all teachers: $e');
      rethrow;
    }
  }

  Future<List<TeacherAssignment>> getTeacherAssignments(String teacherId) async {
    try {
      final response = await supabase
          .from('teacher_assignments')
          .select()
          .eq('teacher_id', teacherId);
      return (response as List).map((e) => TeacherAssignment.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error fetching teacher assignments: $e');
      return [];
    }
  }

  Future<void> createTeacher({
    required String name,
    required String email,
    required String temporaryPassword,
    required List<String> standards,
    required List<String> divisions,
    required List<String> mediums, // ['Gujarati', 'English'] or ['Both']
    required List<String> subjects,
    String institution = 'Sharda Mandir',
    String academicYear = '2026-2027',
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // Backend validation for institution-division compatibility
    final normInst = institution.trim().toLowerCase();
    final isAcc = normInst.contains('acc');
    final canonicalInstitution = isAcc ? 'Tuition ACC' : 'Sharda Mandir';

    if (isAcc) {
      for (final d in divisions) {
        if (d.trim().toUpperCase() != 'ACC') {
          throw 'Invalid division "$d" for Tuition ACC. Only "ACC" is allowed.';
        }
      }
    } else {
      for (final d in divisions) {
        final upper = d.trim().toUpperCase();
        if (upper != 'A' && upper != 'B' && upper != 'C') {
          throw 'Invalid division "$d" for Sharda Mandir. Only "A", "B", and "C" are allowed.';
        }
      }
    }

    // 1. Try hitting the backend API first
    try {
      final url = Uri.parse('$backendBaseUrl/api/admin/teachers');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': cleanEmail,
          'password': temporaryPassword,
          'standards': standards,
          'divisions': divisions,
          'mediums': mediums,
          'subjects': subjects,
          'institution': institution,
          'academicYear': academicYear,
        }),
      ).timeout(const Duration(seconds: 2));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return;
      }
    } catch (err) {
      debugPrint('Backend server call skipped or failed, falling back to direct DB: $err');
    }

    // 1. Try atomic PostgreSQL RPC function (Pre-confirms email, updates password directly in auth.users!)
    String? teacherId;
    try {
      final rpcRes = await supabase.rpc('admin_create_teacher', params: {
        'p_email': cleanEmail,
        'p_password': temporaryPassword,
        'p_name': name,
        'p_institution': institution,
        'p_academic_year': academicYear,
      });
      if (rpcRes != null) {
        teacherId = rpcRes.toString();
        debugPrint('✅ Teacher account created/updated via admin_create_teacher RPC: $teacherId');
      }
    } catch (rpcErr) {
      debugPrint('admin_create_teacher RPC error or not installed: $rpcErr');
    }

    // 2. Direct HTTP Fallback if RPC is not yet installed in Supabase
    if (teacherId == null) {
      try {
        final signupUrl = Uri.parse('$supabaseUrl/auth/v1/signup');
        final signupRes = await http.post(
          signupUrl,
          headers: {
            'apikey': supabaseAnonKey,
            'Authorization': 'Bearer $supabaseAnonKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'email': cleanEmail,
            'password': temporaryPassword,
            'data': {'role': 'teacher', 'name': name},
          }),
        );

        final resBody = jsonDecode(signupRes.body);

        if (signupRes.statusCode == 200 || signupRes.statusCode == 201) {
          teacherId = resBody['id'] ?? resBody['user']?['id'];
        } else {
          final errorMsg = (resBody['msg'] ??
                  resBody['message'] ??
                  resBody['error_description'] ??
                  '')
              .toString();
          final errorCode =
              (resBody['code'] ?? resBody['error'] ?? '').toString();

          if (errorCode == 'user_already_exists' ||
              errorMsg.toLowerCase().contains('already registered') ||
              errorMsg.toLowerCase().contains('already exists')) {
            // User already registered in Auth. Check if their profile exists in public.users
            final existingUser = await supabase
                .from('users')
                .select('id, role')
                .eq('email', cleanEmail)
                .maybeSingle();

            if (existingUser != null) {
              teacherId = existingUser['id']?.toString();
            } else {
              throw 'Email "$cleanEmail" is already registered in Supabase Auth. Please use a unique new email for this teacher (e.g. teacher_${DateTime.now().millisecondsSinceEpoch % 1000}@school.com) or run supabase/admin_teacher_auth_setup.sql in Supabase SQL editor.';
            }
          } else {
            throw errorMsg.isNotEmpty
                ? errorMsg
                : 'Failed to create teacher account (Code: ${signupRes.statusCode})';
          }
        }
      } catch (authErr) {
        if (authErr is String) rethrow;
        debugPrint('Direct HTTP teacher registration error: $authErr');
        rethrow;
      }
    }

    if (teacherId == null) {
      throw 'Could not create or locate teacher authentication user';
    }

    // 3. Upsert into public.users
    await supabase.from('users').upsert({
      'id': teacherId,
      'role': 'teacher',
      'email': cleanEmail,
      'name': name,
      'is_active': true,
      'must_change_password': true,
      'temporary_password': temporaryPassword,
      'institution': institution,
      'academic_year': academicYear,
    });

    // Auto-repair tokens to ensure teacher can log in immediately
    try {
      await supabase.rpc('repair_auth_users');
    } catch (_) {}

    // Handle "Both" medium shortcut
    List<String> targetMediums = List.from(mediums);
    if (targetMediums.contains('Both')) {
      targetMediums = ['Gujarati', 'English'];
    }

    // 4. Replace assignments for this teacher
    try {
      await supabase
          .from('teacher_assignments')
          .delete()
          .eq('teacher_id', teacherId);
    } catch (_) {}

    final assignments = <Map<String, dynamic>>[];
    for (var std in standards) {
      for (var div in divisions) {
        for (var med in targetMediums) {
          for (var sub in subjects) {
            assignments.add({
              'teacher_id': teacherId,
              'institution': institution,
              'academic_year': academicYear,
              'standard': std,
              'division': div,
              'medium': med,
              'subject': sub,
            });
          }
        }
      }
    }

    if (assignments.isNotEmpty) {
      await supabase.from('teacher_assignments').insert(assignments);
    }
  }

  Future<void> updateTeacher({
    required String teacherId,
    required String name,
    required List<String> standards,
    required List<String> divisions,
    required List<String> mediums,
    required List<String> subjects,
    String institution = 'Sharda Mandir',
    String academicYear = '2026-2027',
  }) async {
    // Backend validation for institution-division compatibility
    final normInst = institution.trim().toLowerCase();
    final isAcc = normInst.contains('acc');
    final canonicalInstitution = isAcc ? 'Tuition ACC' : 'Sharda Mandir';

    if (isAcc) {
      for (final d in divisions) {
        if (d.trim().toUpperCase() != 'ACC') {
          throw 'Invalid division "$d" for Tuition ACC. Only "ACC" is allowed.';
        }
      }
    } else {
      for (final d in divisions) {
        final upper = d.trim().toUpperCase();
        if (upper != 'A' && upper != 'B' && upper != 'C') {
          throw 'Invalid division "$d" for Sharda Mandir. Only "A", "B", and "C" are allowed.';
        }
      }
    }

    // 1. Update user profile in public.users
    await supabase.from('users').update({
      'name': name.trim(),
      'institution': canonicalInstitution,
      'academic_year': academicYear,
    }).eq('id', teacherId);

    // 2. Handle mediums shortcut
    List<String> targetMediums = List.from(mediums);
    if (targetMediums.contains('Both')) {
      targetMediums = ['Gujarati', 'English'];
    }

    // 3. Atomically replace assignments
    await supabase
        .from('teacher_assignments')
        .delete()
        .eq('teacher_id', teacherId);

    final assignments = <Map<String, dynamic>>[];
    for (var std in standards) {
      for (var div in divisions) {
        for (var med in targetMediums) {
          for (var sub in subjects) {
            assignments.add({
              'teacher_id': teacherId,
              'institution': canonicalInstitution,
              'academic_year': academicYear,
              'standard': std,
              'division': div,
              'medium': med,
              'subject': sub,
            });
          }
        }
      }
    }

    if (assignments.isNotEmpty) {
      await supabase.from('teacher_assignments').insert(assignments);
    }
  }

  Future<void> resetTeacherPassword(String teacherId, String temporaryPassword) async {
    final cleanPw = temporaryPassword.trim();
    // 1. Try atomic PostgreSQL RPC function
    try {
      await supabase.rpc('admin_reset_teacher_password', params: {
        'p_teacher_id': teacherId,
        'p_new_password': cleanPw,
      });
      debugPrint('✅ Password reset via admin_reset_teacher_password RPC for: $teacherId');
      return;
    } catch (rpcErr) {
      debugPrint('admin_reset_teacher_password RPC error / not installed: $rpcErr');
    }

    // 2. Direct fallback
    await supabase.from('users').update({
      'temporary_password': cleanPw,
      'must_change_password': true,
      'is_active': true,
    }).eq('id', teacherId);

    try {
      await supabase.rpc('repair_auth_users');
    } catch (_) {}
  }

  Future<void> setTeacherStatus(String teacherId, bool isActive) async {
    await supabase.from('users').update({
      'is_active': isActive,
    }).eq('id', teacherId);
  }

  // ── Academic Configurations ───────────────────────────────────────────────
  Future<List<AcademicConfiguration>> getAcademicConfigurations() async {
    try {
      final response = await supabase
          .from('academic_configurations')
          .select()
          .eq('is_active', true);
      return (response as List).map((e) => AcademicConfiguration.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error getting academic configurations: $e');
      return [];
    }
  }

  // ── Tests & Question Management ───────────────────────────────────────────
  Future<String> createTest(Test test) async {
    final response = await supabase.from('tests').insert(test.toMap()).select().single();
    return response['id'];
  }

  Future<void> updateTest(String testId, TestStatus status) async {
    await supabase.from('tests').update({
      'status': status.name,
    }).eq('id', testId);

    // If published, trigger background Drive backup
    if (status == TestStatus.published) {
      triggerTestBackup(testId);
    }
  }

  Future<void> saveQuestions(List<Question> questions) async {
    final maps = questions.map((q) => q.toMap()).toList();
    await supabase.from('questions').insert(maps);
  }

  Future<List<Test>> getTeacherTests(String teacherId) async {
    final response = await supabase
        .from('tests')
        .select()
        .eq('teacher_id', teacherId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => Test.fromMap(e)).toList();
  }

  Future<List<Test>> getAvailableTests({
    required String studentClass,
    required String division,
    required String medium,
    String? studentGroup,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) return [];

    try {
      // 1. Get attempted test IDs for this student (isolated so failure doesn't block available tests)
      Set<String> attemptedTestIds = {};
      try {
        final attemptsResponse = await supabase
            .from('attempts')
            .select('test_id')
            .eq('student_id', userId)
            .timeout(const Duration(seconds: 4));

        attemptedTestIds = (attemptsResponse as List)
            .map((e) => (e['test_id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toSet();
      } catch (attemptsErr) {
        debugPrint('Notice: could not load attempted test IDs: $attemptsErr');
      }

      // 2. Fetch published tests (with fallback and timeout)
      List<dynamic> responseList = [];
      try {
        final response = await supabase
            .from('tests')
            .select()
            .eq('status', 'published')
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 5));
        responseList = response as List;
      } catch (err1) {
        debugPrint('Direct published tests query error: $err1');
        try {
          final fallback = await supabase
              .from('tests')
              .select()
              .order('created_at', ascending: false)
              .timeout(const Duration(seconds: 5));
          responseList = (fallback as List)
              .where((t) => (t['status'] ?? '').toString().toLowerCase().trim() == 'published')
              .toList();
        } catch (err2) {
          debugPrint('Fallback tests query error: $err2');
          return [];
        }
      }

      final allTests = responseList.map((e) {
        try {
          return Test.fromMap(Map<String, dynamic>.from(e));
        } catch (err) {
          debugPrint('Error parsing test item: $err');
          return null;
        }
      }).whereType<Test>().toList();

      final studentClassNum = RegExp(r'\d+').firstMatch(studentClass)?.group(0);
      final sDivClean = division.trim().toUpperCase();
      final sMedClean = medium.trim().toLowerCase();

      return allTests.where((test) {
        // Exclude already attempted tests
        if (attemptedTestIds.contains(test.id)) return false;

        // Match Class / Standard (digit-based or string comparison)
        final testClassNum = RegExp(r'\d+').firstMatch(test.studentClass)?.group(0);
        if (studentClassNum != null && testClassNum != null) {
          if (studentClassNum != testClassNum) return false;
        } else if (test.studentClass.trim().toLowerCase() != studentClass.trim().toLowerCase()) {
          return false;
        }

        // Match Medium ('Both' or 'All' applies to all mediums)
        final tMed = test.medium.trim().toLowerCase();
        if (tMed.isNotEmpty && sMedClean.isNotEmpty && tMed != 'both' && tMed != 'all') {
          if (tMed != sMedClean) return false;
        }

        // Match Division if specified ('All' or 'Both' applies to all divisions)
        if (test.division != null && test.division!.trim().isNotEmpty) {
          final tDiv = test.division!.trim().toUpperCase();
          if (tDiv != 'ALL' && tDiv != 'BOTH' && sDivClean.isNotEmpty && tDiv != sDivClean) {
            return false;
          }
        }

        // Group filtering (Maths / Biology)
        final subjLower = test.subject.trim().toLowerCase();
        if (subjLower.contains('math') && studentGroup != null && studentGroup.isNotEmpty && !studentGroup.toLowerCase().contains('math')) {
          return false;
        }
        if (subjLower.contains('bio') && studentGroup != null && studentGroup.isNotEmpty && !studentGroup.toLowerCase().contains('bio')) {
          return false;
        }

        return true;
      }).toList();
    } catch (e) {
      debugPrint('Error getting available tests: $e');
      return [];
    }
  }

  Future<Test?> getPublishedTestByCode(String testCode) async {
    final normalizedCode = testCode.trim().toLowerCase();
    if (normalizedCode.isEmpty) return null;

    try {
      final response = await supabase
          .from('tests')
          .select()
          .ilike('test_code', normalizedCode)
          .eq('status', 'published')
          .maybeSingle();

      if (response == null) return null;
      return Test.fromMap(response);
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasAttemptedTest(String testId) async {
    final userId = currentUser?.id;
    if (userId == null) return false;

    final response = await supabase
        .from('attempts')
        .select('id')
        .eq('student_id', userId)
        .eq('test_id', testId)
        .limit(1);

    return (response as List).isNotEmpty;
  }

  // ── Attempts & Submissions ────────────────────────────────────────────────
  Future<String> submitAttempt({
    required String testId,
    required int score,
    required Map<String, String> selectedAnswers,
  }) async {
    final userId = currentUser!.id;

    // 1. Save attempt
    final attemptResponse = await supabase.from('attempts').insert({
      'student_id': userId,
      'test_id': testId,
      'score': score,
    }).select().single();

    final attemptId = attemptResponse['id'] as String;

    // 2. Save answers
    final List<Map<String, dynamic>> answersList = [];
    selectedAnswers.forEach((qId, val) {
      answersList.add({
        'attempt_id': attemptId,
        'question_id': qId,
        'selected_answer': val,
      });
    });

    if (answersList.isNotEmpty) {
      await supabase.from('answers').insert(answersList);
    }

    // 3. Trigger asynchronous Google Drive backup for this attempt
    triggerAttemptBackup(attemptId);

    return attemptId;
  }

  Future<List<Question>> getTestQuestions(String testId) async {
    final response = await supabase.from('questions').select().eq('test_id', testId);
    return (response as List).map((e) => Question.fromMap(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getStudentHistory() async {
    final user = currentUser;
    if (user == null) return [];
    try {
      final response = await supabase
          .from('attempts')
          .select('*, tests(*)')
          .eq('student_id', user.id)
          .order('submitted_at', ascending: false)
          .timeout(const Duration(seconds: 5), onTimeout: () => []);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error getting student history: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTeacherTestAttempts() async {
    final teacherId = currentUser!.id;
    final response = await supabase
        .from('attempts')
        .select('*, tests!inner(*), users!student_id(email, name, class, division, roll_no, student_group)')
        .eq('tests.teacher_id', teacherId)
        .order('submitted_at', ascending: false);

    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<List<Map<String, dynamic>>> getTeacherTestAttemptsForStudent(String studentId) async {
    final teacherId = currentUser?.id;
    if (teacherId == null) return [];
    try {
      final response = await supabase
          .from('attempts')
          .select('*, tests!inner(*), users!student_id(email, name, class, division, roll_no, student_group)')
          .eq('tests.teacher_id', teacherId)
          .eq('student_id', studentId)
          .order('submitted_at', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error getting student attempts for teacher: $e');
      return [];
    }
  }

  Future<Map<String, String>> getAttemptAnswers(String attemptId) async {
    final response = await supabase
        .from('answers')
        .select('question_id, selected_answer')
        .eq('attempt_id', attemptId);

    final map = <String, String>{};
    for (var row in (response as List)) {
      map[row['question_id'] as String] = row['selected_answer'] as String;
    }
    return map;
  }

  // ── Growth Analytics & Retention Aggregates ───────────────────────────────
  Future<List<PerformanceAggregate>> getStudentGrowthHistory(String studentId) async {
    try {
      final response = await supabase
          .from('student_performance_aggregates')
          .select()
          .eq('student_id', studentId)
          .order('submitted_at', ascending: true);

      return (response as List).map((e) => PerformanceAggregate.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error getting student growth history: $e');
      return [];
    }
  }

  // ── Google Drive Backup Triggers & Statuses ───────────────────────────────
  Future<void> triggerTestBackup(String testId) async {
    try {
      final url = Uri.parse('$backendBaseUrl/api/backups/test/$testId');
      http.post(url).catchError((_) => http.Response('', 500));
    } catch (_) {}
  }

  Future<void> triggerAttemptBackup(String attemptId) async {
    try {
      final url = Uri.parse('$backendBaseUrl/api/backups/attempt/$attemptId');
      http.post(url).catchError((_) => http.Response('', 500));
    } catch (_) {}
  }

  Future<List<TestBackup>> getTestBackups() async {
    try {
      final response = await supabase
          .from('test_backups')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      return (response as List).map((e) => TestBackup.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error getting test backups: $e');
      return [];
    }
  }

  Future<bool> retryBackup(String backupId, String type) async {
    try {
      final url = Uri.parse('$backendBaseUrl/api/backups/retry/$backupId');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'type': type}),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── API Keys ──────────────────────────────────────────────────────────────
  /// Fetches only active API keys (used by Teachers for test generation).
  Future<List<ApiKey>> getApiKeys() async {
    try {
      final response = await supabase
          .from('gemini_api_keys')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List).map((e) => ApiKey.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error fetching API keys: $e');
      return [];
    }
  }

  /// Fetches all API keys including inactive ones (for Admin dashboard).
  Future<List<ApiKey>> getAllApiKeysForAdmin() async {
    try {
      final response = await supabase
          .from('gemini_api_keys')
          .select()
          .order('created_at', ascending: false);

      return (response as List).map((e) => ApiKey.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error fetching all API keys for admin: $e');
      return [];
    }
  }

  /// Adds a new Gemini API key (Admin only).
  Future<void> addApiKey(String name, String key, {bool isActive = true}) async {
    await supabase.from('gemini_api_keys').insert({
      'name': name.trim(),
      'api_key': key.trim(),
      'is_active': isActive,
      'tokens_used': 0,
    });
  }

  /// Updates an existing Gemini API key details (Admin only).
  Future<void> updateApiKey({
    required String id,
    required String name,
    required String key,
    required bool isActive,
  }) async {
    await supabase.from('gemini_api_keys').update({
      'name': name.trim(),
      'api_key': key.trim(),
      'is_active': isActive,
    }).eq('id', id);
  }

  /// Toggles active status of an API key (Admin only).
  Future<void> toggleApiKeyStatus(String id, bool isActive) async {
    await supabase
        .from('gemini_api_keys')
        .update({'is_active': isActive})
        .eq('id', id);
  }

  /// Deletes a Gemini API key (Admin only).
  Future<void> deleteApiKey(String id) async {
    await supabase.from('gemini_api_keys').delete().eq('id', id);
  }

  /// Increments token usage counter (supports both RPC and direct table update).
  Future<void> incrementTokenUsage(String keyId, int tokens) async {
    try {
      // Try security-definer RPC function first
      await supabase.rpc('increment_gemini_token_usage', params: {
        'p_key_id': keyId,
        'p_tokens': tokens,
      });
    } catch (_) {
      // Fallback to direct table update if RPC is not yet created
      try {
        final response = await supabase
            .from('gemini_api_keys')
            .select('tokens_used')
            .eq('id', keyId)
            .maybeSingle();

        if (response != null) {
          final currentTokens = response['tokens_used'] as int? ?? 0;
          await supabase
              .from('gemini_api_keys')
              .update({'tokens_used': currentTokens + tokens})
              .eq('id', keyId);
        }
      } catch (e) {
        debugPrint('Error incrementing tokens: $e');
      }
    }
  }
}
