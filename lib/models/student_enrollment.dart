class StudentEnrollment {
  final String id;
  final String studentId;
  final String institution;
  final String academicYear;
  final String standard;
  final String division;
  final String medium;
  final String? studentGroup;
  final String rollNo;
  final DateTime? enrolledAt;

  StudentEnrollment({
    this.id = '',
    required this.studentId,
    this.institution = 'Sharda Mandir',
    this.academicYear = '2026-2027',
    required this.standard,
    required this.division,
    this.medium = 'English',
    this.studentGroup,
    required this.rollNo,
    this.enrolledAt,
  });

  factory StudentEnrollment.fromMap(Map<String, dynamic> map) {
    return StudentEnrollment(
      id: map['id'] ?? '',
      studentId: map['student_id'] ?? '',
      institution: map['institution'] ?? 'Sharda Mandir',
      academicYear: map['academic_year'] ?? '2026-2027',
      standard: map['standard']?.toString() ?? '',
      division: map['division'] ?? '',
      medium: map['medium'] ?? 'English',
      studentGroup: map['student_group'],
      rollNo: map['roll_no']?.toString() ?? '',
      enrolledAt: map['enrolled_at'] != null ? DateTime.parse(map['enrolled_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'student_id': studentId,
      'institution': institution,
      'academic_year': academicYear,
      'standard': standard,
      'division': division,
      'medium': medium,
      'student_group': studentGroup,
      'roll_no': rollNo,
    };
  }
}
