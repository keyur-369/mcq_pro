import 'package:flutter_test/flutter_test.dart';
import 'package:mcq_test_app/models/app_user.dart';
import 'package:mcq_test_app/models/teacher_assignment.dart';
import 'package:mcq_test_app/models/student_enrollment.dart';
import 'package:mcq_test_app/models/test_backup.dart';
import 'package:mcq_test_app/models/performance_aggregate.dart';

void main() {
  group('AppUser Model & Three-Role Architecture', () {
    test('creates Admin user correctly from map', () {
      final user = AppUser.fromMap({
        'id': 'admin-uuid-1',
        'role': 'admin',
        'email': 'admin@mcqpro.com',
        'name': 'System Administrator',
        'institution': 'Sharda Mandir',
        'is_active': true,
        'must_change_password': false,
      });

      expect(user.isAdmin, isTrue);
      expect(user.isTeacher, isFalse);
      expect(user.isStudent, isFalse);
      expect(user.role, equals('admin'));
      expect(user.isActive, isTrue);
      expect(user.mustChangePassword, isFalse);
    });

    test('creates Teacher user with temporary password flag', () {
      final user = AppUser.fromMap({
        'id': 'teacher-uuid-1',
        'role': 'teacher',
        'email': 'teacher1@school.org',
        'name': 'Prof. Patel',
        'institution': 'Sharda Mandir',
        'is_active': true,
        'must_change_password': true,
      });

      expect(user.isTeacher, isTrue);
      expect(user.isAdmin, isFalse);
      expect(user.isStudent, isFalse);
      expect(user.mustChangePassword, isTrue);
    });

    test('creates Student user with roll number and medium', () {
      final user = AppUser.fromMap({
        'id': 'student-uuid-1',
        'role': 'student',
        'email': 'student@school.org',
        'name': 'Keyur Patel',
        'class': 12,
        'division': 'A',
        'medium': 'Gujarati',
        'roll_no': '001',
        'student_group': 'Science',
        'institution': 'Sharda Mandir',
      });

      expect(user.isStudent, isTrue);
      expect(user.rollNo, equals('001'));
      expect(user.medium, equals('Gujarati'));
      expect(user.studentClass, equals('12'));
      expect(user.division, equals('A'));
    });

    test('resiliently handles nullable values and boolean types for is_active', () {
      final t1 = AppUser.fromMap({
        'id': 't-1',
        'role': 'teacher',
        'email': 't1@school.org',
        'name': null,
        'is_active': 'true',
      });
      expect(t1.name, isNull);
      expect(t1.isActive, isTrue);

      final t2 = AppUser.fromMap({
        'id': 't-2',
        'role': 'teacher',
        'email': 't2@school.org',
        'is_active': 0,
      });
      expect(t2.isActive, isFalse);

      final t3 = AppUser.fromMap({
        'id': 't-3',
        'email': 't3@school.org',
      });
      expect(t3.role, equals('student'));
      expect(t3.isActive, isTrue);
    });

    test('correctly parses a list of 2 teacher records', () {
      final rawList = [
        {'id': 't-1', 'role': 'teacher', 'email': 't1@test.com', 'name': 'Teacher One', 'is_active': true},
        {'id': 't-2', 'role': 'teacher', 'email': 't2@test.com', 'name': 'Teacher Two', 'is_active': true},
      ];

      final teachers = rawList.map((e) => AppUser.fromMap(e)).toList();
      expect(teachers.length, equals(2));
      expect(teachers[0].name, equals('Teacher One'));
      expect(teachers[1].name, equals('Teacher Two'));
      expect(teachers.where((t) => t.isActive).length, equals(2));
    });
  });

  group('Teacher Assignments & Both Medium Normalization', () {
    test('TeacherAssignment serializes and deserializes correctly', () {
      final assignment = TeacherAssignment(
        id: 'asg-1',
        teacherId: 'teacher-123',
        institution: 'Sharda Mandir',
        academicYear: '2026-2027',
        standard: '12',
        division: 'A',
        medium: 'Gujarati',
        subject: 'Physics',
      );

      final map = assignment.toMap();
      expect(map['teacher_id'], equals('teacher-123'));
      expect(map['standard'], equals('12'));
      expect(map['medium'], equals('Gujarati'));
      expect(map['subject'], equals('Physics'));

      final reconstructed = TeacherAssignment.fromMap(map);
      expect(reconstructed.subject, equals('Physics'));
      expect(reconstructed.medium, equals('Gujarati'));
    });

    test('Both medium selection expands into Gujarati and English assignments', () {
      final selectedMediums = ['Both'];
      final normalizedMediums = <String>[];

      for (var m in selectedMediums) {
        if (m.toLowerCase() == 'both') {
          normalizedMediums.addAll(['Gujarati', 'English']);
        } else {
          normalizedMediums.add(m);
        }
      }

      expect(normalizedMediums, containsAll(['Gujarati', 'English']));
      expect(normalizedMediums.length, equals(2));
    });
  });

  group('Student Enrollment & Roll Number Constraints', () {
    test('StudentEnrollment model attributes validation', () {
      final enrollment = StudentEnrollment(
        id: 'enr-1',
        studentId: 'stud-1',
        institution: 'Sharda Mandir',
        academicYear: '2026-2027',
        standard: '11',
        division: 'B',
        medium: 'English',
        studentGroup: 'Maths',
        rollNo: '042',
      );

      final map = enrollment.toMap();
      expect(map['roll_no'], equals('042'));
      expect(map['standard'], equals('11'));
      expect(map['student_group'], equals('Maths'));
    });
  });

  group('TestBackup Status Tracking', () {
    test('TestBackup models success, failure, and retry counts', () {
      final backup = TestBackup.fromMap({
        'id': 'b-1',
        'test_id': 'test-abc',
        'drive_file_id': '1AbCdEfGhIjKlMnOpQrStUvWxYz',
        'drive_file_name': 'MCQPro_Test_PHY101_test-abc.pdf',
        'status': 'completed',
        'checksum': 'md5-checksum-123',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(backup.isCompleted, isTrue);
      expect(backup.isFailed, isFalse);
      expect(backup.driveFileId, equals('1AbCdEfGhIjKlMnOpQrStUvWxYz'));
    });

    test('TestBackup handles failure and error messages', () {
      final failedBackup = TestBackup.fromMap({
        'id': 'b-2',
        'test_id': 'test-xyz',
        'status': 'failed',
        'error_message': 'Google Drive API Quota Exceeded (403)',
        'retry_count': 2,
      });

      expect(failedBackup.isFailed, isTrue);
      expect(failedBackup.isCompleted, isFalse);
      expect(failedBackup.errorMessage, contains('Quota Exceeded'));
      expect(failedBackup.retryCount, equals(2));
    });
  });

  group('PerformanceAggregate for 30-Day Retention', () {
    test('Stores and calculates historical performance without raw attempt data', () {
      final aggregate = PerformanceAggregate(
        id: 'agg-1',
        studentId: 'stud-1',
        testId: 'test-1',
        score: 18,
        totalMarks: 20,
        percentage: 90.0,
        subject: 'Physics',
        topic: 'Electrostatics',
        standard: '12',
        division: 'A',
        medium: 'Gujarati',
        submittedAt: DateTime(2026, 9, 15),
      );

      expect(aggregate.percentage, equals(90.0));
      expect(aggregate.score, equals(18));
      expect(aggregate.totalMarks, equals(20));

      final map = aggregate.toMap();
      final fromMap = PerformanceAggregate.fromMap(map);
      expect(fromMap.percentage, equals(90.0));
      expect(fromMap.topic, equals('Electrostatics'));
    });
  });

  group('Single Role-Based Login Architecture & Routing', () {
    test('Admin user routes to AdminDashboard with active status check', () {
      final admin = AppUser.fromMap({
        'id': 'admin-id-1',
        'role': 'admin',
        'email': 'admin@mcqpro.com',
        'is_active': true,
        'must_change_password': false,
      });

      expect(admin.role, equals('admin'));
      expect(admin.isAdmin, isTrue);
      expect(admin.isActive, isTrue);

      // Simulates router logic
      String resolveRoute(AppUser user) {
        if (!user.isActive) return 'deactivated';
        if (user.isAdmin) return 'admin_dashboard';
        if (user.isTeacher) {
          return user.mustChangePassword ? 'set_password_screen' : 'teacher_dashboard';
        }
        if (user.isStudent) return 'student_dashboard';
        return 'unauthorized';
      }

      expect(resolveRoute(admin), equals('admin_dashboard'));
    });

    test('First-time teacher is routed to set_password_screen, then returning teacher to teacher_dashboard', () {
      final firstTimeTeacher = AppUser.fromMap({
        'id': 'teacher-id-1',
        'role': 'teacher',
        'email': 'teacher@mcqpro.com',
        'is_active': true,
        'must_change_password': true,
      });

      String resolveRoute(AppUser user) {
        if (!user.isActive) return 'deactivated';
        if (user.isAdmin) return 'admin_dashboard';
        if (user.isTeacher) {
          return user.mustChangePassword ? 'set_password_screen' : 'teacher_dashboard';
        }
        if (user.isStudent) return 'student_dashboard';
        return 'unauthorized';
      }

      expect(resolveRoute(firstTimeTeacher), equals('set_password_screen'));

      // After password change, must_change_password becomes false
      final returningTeacher = AppUser.fromMap({
        'id': 'teacher-id-1',
        'role': 'teacher',
        'email': 'teacher@mcqpro.com',
        'is_active': true,
        'must_change_password': false,
      });

      expect(resolveRoute(returningTeacher), equals('teacher_dashboard'));
    });

    test('Student user routes directly to student_dashboard', () {
      final student = AppUser.fromMap({
        'id': 'student-id-1',
        'role': 'student',
        'email': 'student@school.org',
        'is_active': true,
        'must_change_password': false,
      });

      String resolveRoute(AppUser user) {
        if (!user.isActive) return 'deactivated';
        if (user.isAdmin) return 'admin_dashboard';
        if (user.isTeacher) {
          return user.mustChangePassword ? 'set_password_screen' : 'teacher_dashboard';
        }
        if (user.isStudent) return 'student_dashboard';
        return 'unauthorized';
      }

      expect(resolveRoute(student), equals('student_dashboard'));
    });

    test('Inactive user is denied access regardless of role', () {
      final deactivatedTeacher = AppUser.fromMap({
        'id': 'teacher-inactive',
        'role': 'teacher',
        'email': 'bad_teacher@school.org',
        'is_active': false,
        'must_change_password': false,
      });

      String resolveRoute(AppUser user) {
        if (!user.isActive) return 'deactivated';
        if (user.isAdmin) return 'admin_dashboard';
        if (user.isTeacher) {
          return user.mustChangePassword ? 'set_password_screen' : 'teacher_dashboard';
        }
        if (user.isStudent) return 'student_dashboard';
        return 'unauthorized';
      }

      expect(resolveRoute(deactivatedTeacher), equals('deactivated'));
    });

    test('Unrecognized or invalid role is denied access', () {
      final invalidUser = AppUser.fromMap({
        'id': 'unknown-id',
        'role': 'guest',
        'email': 'guest@unknown.org',
        'is_active': true,
      });

      String resolveRoute(AppUser user) {
        if (!user.isActive) return 'deactivated';
        if (user.isAdmin) return 'admin_dashboard';
        if (user.isTeacher) {
          return user.mustChangePassword ? 'set_password_screen' : 'teacher_dashboard';
        }
        if (user.isStudent) return 'student_dashboard';
        return 'unauthorized';
      }

      expect(resolveRoute(invalidUser), equals('unauthorized'));
    });

    test('Student default compulsory subjects and stream elective subjects', () {
      final bioStudent = AppUser.fromMap({
        'id': 's-bio',
        'role': 'student',
        'email': 'bio@mcq.com',
        'student_group': 'Biology',
      });

      expect(bioStudent.enrolledSubjects, equals(['Physics', 'Chemistry', 'Biology']));
      expect(bioStudent.takesSubject('Physics'), isTrue);
      expect(bioStudent.takesSubject('Chemistry'), isTrue);
      expect(bioStudent.takesSubject('Biology'), isTrue);
      expect(bioStudent.takesSubject('Math'), isFalse);

      final mathStudent = AppUser.fromMap({
        'id': 's-math',
        'role': 'student',
        'email': 'math@mcq.com',
        'student_group': 'Math',
      });

      expect(mathStudent.enrolledSubjects, equals(['Physics', 'Chemistry', 'Math']));
      expect(mathStudent.takesSubject('Physics'), isTrue);
      expect(mathStudent.takesSubject('Chemistry'), isTrue);
      expect(mathStudent.takesSubject('Math'), isTrue);
      expect(mathStudent.takesSubject('Maths'), isTrue);
      expect(mathStudent.takesSubject('Biology'), isFalse);
    });
  });
}

