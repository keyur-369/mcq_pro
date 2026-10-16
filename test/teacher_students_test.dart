import 'package:flutter_test/flutter_test.dart';
import 'package:mcq_test_app/models/app_user.dart';
import 'package:mcq_test_app/models/teacher_assignment.dart';

void main() {
  group('Teacher Students Directory Filtering & Scope', () {
    final assignment1 = TeacherAssignment(
      id: 'a1',
      teacherId: 't1',
      institution: 'Sharda Mandir',
      standard: '11',
      division: 'A',
      medium: 'English',
      subject: 'Physics',
    );

    final assignment2 = TeacherAssignment(
      id: 'a2',
      teacherId: 't1',
      institution: 'Sharda Mandir',
      standard: '12',
      division: 'B',
      medium: 'English',
      subject: 'Biology',
    );

    final assignments = [assignment1, assignment2];

    final student1 = AppUser(
      id: 's1',
      role: 'student',
      email: 'aarav@school.org',
      name: 'Aarav Patel',
      institution: 'Sharda Mandir',
      studentClass: '11',
      division: 'A',
      medium: 'English',
      rollNo: '01',
      studentGroup: 'Science',
      isActive: true,
    );

    final student2 = AppUser(
      id: 's2',
      role: 'student',
      email: 'diya@school.org',
      name: 'Diya Shah',
      institution: 'Sharda Mandir',
      studentClass: '12',
      division: 'B',
      medium: 'English',
      rollNo: '02',
      studentGroup: 'Biology',
      isActive: true,
    );

    // Different language/division
    final student3 = AppUser(
      id: 's3',
      role: 'student',
      email: 'rohan@school.org',
      name: 'Rohan Joshi',
      institution: 'Sharda Mandir',
      studentClass: '11',
      division: 'B',
      medium: 'Gujarati',
      rollNo: '03',
      studentGroup: 'General',
      isActive: false,
    );

    // Different institution
    final student4 = AppUser(
      id: 's4',
      role: 'student',
      email: 'neha@tuition.org',
      name: 'Neha Mehta',
      institution: 'Tuition ACC',
      studentClass: '11',
      division: 'A',
      medium: 'English',
      rollNo: '04',
      studentGroup: 'Science',
      isActive: true,
    );

    // Maths group student (does not take assignment2's Biology)
    final student5 = AppUser(
      id: 's5',
      role: 'student',
      email: 'karan@school.org',
      name: 'Karan Dave',
      institution: 'Sharda Mandir',
      studentClass: '12',
      division: 'B',
      medium: 'English',
      rollNo: '05',
      studentGroup: 'Maths',
      isActive: true,
    );

    final allStudents = [student1, student2, student3, student4, student5];

    bool matchesAssignment(AppUser s, TeacherAssignment a) {
      final aInst = a.institution.trim().toLowerCase();
      final sInst = (s.institution ?? 'Sharda Mandir').trim().toLowerCase();
      if (aInst.isNotEmpty && sInst.isNotEmpty && aInst != sInst) return false;

      final aStd = a.standard.trim();
      final sStd = (s.studentClass ?? '').trim();
      if (aStd != sStd) return false;

      final aDiv = a.division.trim().toUpperCase();
      final sDiv = (s.division ?? '').trim().toUpperCase();
      if (aDiv != 'ALL' && aDiv != sDiv) return false;

      final aMed = a.medium.trim().toLowerCase();
      final sMed = (s.medium ?? 'English').trim().toLowerCase();
      if (aMed.isNotEmpty && sMed.isNotEmpty && aMed != 'both' && aMed != 'all' && aMed != sMed) {
        return false;
      }

      final sub = a.subject.trim().toLowerCase();
      final grp = (s.studentGroup ?? '').trim().toLowerCase();
      final isPhysics = sub == 'physics' || sub == 'physical';
      final isChemistry = sub == 'chemistry';
      final isBiology = sub == 'biology' || sub == 'bio';
      final isMath = sub == 'math' || sub == 'maths' || sub == 'mathematics';

      if (isPhysics || isChemistry) return true;
      if (isBiology) return grp.isEmpty || grp == 'biology' || grp == 'bio' || grp == 'b' || grp == 'science';
      if (isMath) return grp == 'math' || grp == 'maths' || grp == 'a';
      return true;
    }

    bool isStudentUnderTeacher(AppUser s, List<TeacherAssignment> list) {
      if (list.isEmpty) return false;
      return list.any((a) => matchesAssignment(s, a));
    }

    test('matches student by institution, standard, division, language, and subject', () {
      expect(isStudentUnderTeacher(student1, assignments), isTrue); // Std 11-A English Physics
      expect(isStudentUnderTeacher(student2, assignments), isTrue); // Std 12-B English Biology
      expect(isStudentUnderTeacher(student3, assignments), isFalse); // Gujarati & Div B
      expect(isStudentUnderTeacher(student4, assignments), isFalse); // Different institution
      expect(isStudentUnderTeacher(student5, assignments), isFalse); // Maths group cannot take Biology
    });

    test('Physics and Chemistry default subjects match both Biology and Math students', () {
      final physicsStd12 = TeacherAssignment(
        id: 'p12',
        teacherId: 't1',
        institution: 'Sharda Mandir',
        standard: '12',
        division: 'B',
        medium: 'English',
        subject: 'Physics',
      );

      final chemistryStd12 = TeacherAssignment(
        id: 'c12',
        teacherId: 't1',
        institution: 'Sharda Mandir',
        standard: '12',
        division: 'B',
        medium: 'English',
        subject: 'Chemistry',
      );

      // Both student2 (Biology) and student5 (Maths) must match Physics and Chemistry
      expect(isStudentUnderTeacher(student2, [physicsStd12]), isTrue);
      expect(isStudentUnderTeacher(student5, [physicsStd12]), isTrue);
      expect(isStudentUnderTeacher(student2, [chemistryStd12]), isTrue);
      expect(isStudentUnderTeacher(student5, [chemistryStd12]), isTrue);
    });

    test('returns empty when teacher has no assignments (triggers simple message)', () {
      final noAssignmentStudents = allStudents.where((s) => isStudentUnderTeacher(s, [])).toList();
      expect(noAssignmentStudents.isEmpty, isTrue);
    });

    test('returns empty when teacher assignments match 0 students', () {
      final dummyAssignment = TeacherAssignment(
        id: 'dummy',
        teacherId: 't99',
        institution: 'NonExistent',
        standard: '9',
        division: 'Z',
        medium: 'French',
        subject: 'History',
      );
      final emptyStudents = allStudents.where((s) => isStudentUnderTeacher(s, [dummyAssignment])).toList();
      expect(emptyStudents.isEmpty, isTrue);
    });
  });
}
