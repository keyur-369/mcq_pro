class TeacherAssignment {
  final String id;
  final String teacherId;
  final String institution;
  final String academicYear;
  final String standard;
  final String division;
  final String medium; // 'Gujarati' or 'English'
  final String subject;
  final DateTime? createdAt;

  TeacherAssignment({
    this.id = '',
    required this.teacherId,
    this.institution = 'Sharda Mandir',
    this.academicYear = '2026-2027',
    required this.standard,
    required this.division,
    required this.medium,
    required this.subject,
    this.createdAt,
  });

  factory TeacherAssignment.fromMap(Map<String, dynamic> map) {
    return TeacherAssignment(
      id: map['id'] ?? '',
      teacherId: map['teacher_id'] ?? '',
      institution: map['institution'] ?? 'Sharda Mandir',
      academicYear: map['academic_year'] ?? '2026-2027',
      standard: map['standard']?.toString() ?? '',
      division: map['division'] ?? '',
      medium: map['medium'] ?? 'English',
      subject: map['subject'] ?? '',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'teacher_id': teacherId,
      'institution': institution,
      'academic_year': academicYear,
      'standard': standard,
      'division': division,
      'medium': medium,
      'subject': subject,
    };
  }
}
