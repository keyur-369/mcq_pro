class AcademicConfiguration {
  final String id;
  final String institution;
  final String academicYear;
  final String standard;
  final String division;
  final String medium;
  final String subject;
  final String? groupName;
  final bool isActive;

  AcademicConfiguration({
    this.id = '',
    required this.institution,
    required this.academicYear,
    required this.standard,
    required this.division,
    required this.medium,
    required this.subject,
    this.groupName,
    this.isActive = true,
  });

  factory AcademicConfiguration.fromMap(Map<String, dynamic> map) {
    return AcademicConfiguration(
      id: map['id'] ?? '',
      institution: map['institution'] ?? '',
      academicYear: map['academic_year'] ?? '',
      standard: map['standard']?.toString() ?? '',
      division: map['division'] ?? '',
      medium: map['medium'] ?? '',
      subject: map['subject'] ?? '',
      groupName: map['group_name'],
      isActive: map['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'institution': institution,
      'academic_year': academicYear,
      'standard': standard,
      'division': division,
      'medium': medium,
      'subject': subject,
      'group_name': groupName,
      'is_active': isActive,
    };
  }
}
