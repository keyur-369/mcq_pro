import 'package:flutter_test/flutter_test.dart';
import 'package:mcq_test_app/models/app_user.dart';
import 'package:mcq_test_app/models/teacher_assignment.dart';
import 'package:mcq_test_app/models/test.dart';

void main() {
  group('Teacher Profile Data & Scope Aggregation', () {
    final teacher = AppUser(
      id: 'teacher-101',
      role: 'teacher',
      email: 'dr.sharma@shardamandir.org',
      name: 'Dr. Sharma',
      institution: 'Sharda Mandir',
      academicYear: '2026-2027',
      isActive: true,
      mustChangePassword: false,
    );

    final assignments = [
      TeacherAssignment(
        id: 'asg-1',
        teacherId: 'teacher-101',
        institution: 'Sharda Mandir',
        academicYear: '2026-2027',
        standard: '11',
        division: 'A',
        medium: 'English',
        subject: 'Physics',
      ),
      TeacherAssignment(
        id: 'asg-2',
        teacherId: 'teacher-101',
        institution: 'Sharda Mandir',
        academicYear: '2026-2027',
        standard: '12',
        division: 'A',
        medium: 'English',
        subject: 'Physics',
      ),
      TeacherAssignment(
        id: 'asg-3',
        teacherId: 'teacher-101',
        institution: 'Sharda Mandir',
        academicYear: '2026-2027',
        standard: '12',
        division: 'B',
        medium: 'Gujarati',
        subject: 'Chemistry',
      ),
    ];

    final tests = [
      Test(
        id: 'test-1',
        teacherId: 'teacher-101',
        studentClass: '11',
        medium: 'English',
        subject: 'Physics',
        topic: 'Kinematics',
        level: 'Medium',
        duration: 30,
        status: TestStatus.published,
      ),
      Test(
        id: 'test-2',
        teacherId: 'teacher-101',
        studentClass: '12',
        medium: 'English',
        subject: 'Physics',
        topic: 'Electrostatics',
        level: 'Hard',
        duration: 45,
        status: TestStatus.draft,
      ),
    ];

    test('correctly aggregates unique subjects and standards taught', () {
      final uniqueSubjects = assignments.map((a) => a.subject).toSet();
      expect(uniqueSubjects.length, equals(2));
      expect(uniqueSubjects, containsAll(['Physics', 'Chemistry']));

      final uniqueStandards = assignments.map((a) => a.standard).toSet();
      expect(uniqueStandards.length, equals(2));
      expect(uniqueStandards, containsAll(['11', '12']));
    });

    test('counts published vs draft tests accurately', () {
      final published = tests.where((t) => t.status == TestStatus.published).length;
      final draft = tests.where((t) => t.status == TestStatus.draft).length;
      expect(published, equals(1));
      expect(draft, equals(1));
      expect(tests.length, equals(2));
    });

    test('verifies teacher identity and security metadata', () {
      expect(teacher.isTeacher, isTrue);
      expect(teacher.name, equals('Dr. Sharma'));
      expect(teacher.institution, equals('Sharda Mandir'));
      expect(teacher.isActive, isTrue);
      expect(teacher.mustChangePassword, isFalse);
    });
  });
}
