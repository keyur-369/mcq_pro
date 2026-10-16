class AppUser {
  final String id;
  final String role; // 'admin', 'teacher', 'student'
  final String email;
  final String? name;
  final String? studentClass; // '11' or '12'
  final String? division;
  final String? rollNo;
  final String? studentGroup;
  final String? medium;
  final String? institution;
  final String? academicYear;
  final bool isActive;
  final bool mustChangePassword;
  final String? temporaryPassword;

  AppUser({
    required this.id,
    required this.role,
    required this.email,
    this.name,
    this.studentClass,
    this.division,
    this.rollNo,
    this.studentGroup,
    this.medium,
    this.institution,
    this.academicYear,
    this.isActive = true,
    this.mustChangePassword = false,
    this.temporaryPassword,
  });

  bool get isAdmin => role == 'admin';
  bool get isTeacher => role == 'teacher';
  bool get isStudent => role == 'student';

  /// Default compulsory subjects for all science students
  static const List<String> defaultCompulsorySubjects = ['Physics', 'Chemistry'];

  /// Full list of enrolled subjects for this student:
  /// Includes compulsory subjects (Physics, Chemistry) + elective stream based on studentGroup (Biology or Math)
  List<String> get enrolledSubjects {
    final grp = (studentGroup ?? '').trim().toLowerCase();
    final list = List<String>.from(defaultCompulsorySubjects);
    if (grp.contains('bio') || grp == 'b') {
      list.add('Biology');
    } else if (grp.contains('math') || grp == 'a') {
      list.add('Math');
    } else {
      // Default to Biology if unspecified
      list.add('Biology');
    }
    return list;
  }

  /// Checks if this student takes a specific subject (e.g. 'Physics', 'Chemistry', 'Biology', 'Math')
  bool takesSubject(String subject) {
    final sub = subject.trim().toLowerCase();
    final grp = (studentGroup ?? '').trim().toLowerCase();

    // Physics and Chemistry are default/compulsory for all students
    if (sub == 'physics' || sub == 'physical' || sub == 'chemistry') {
      return true;
    }
    if (sub == 'biology' || sub == 'bio') {
      return grp.isEmpty || grp == 'biology' || grp == 'bio' || grp == 'b';
    }
    if (sub == 'math' || sub == 'maths' || sub == 'mathematics') {
      return grp == 'math' || grp == 'maths' || grp == 'a';
    }
    return false;
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    bool parseBool(dynamic val, bool defaultVal) {
      if (val == null) return defaultVal;
      if (val is bool) return val;
      if (val is num) return val != 0;
      final str = val.toString().toLowerCase().trim();
      if (str == 'true' || str == 't' || str == '1') return true;
      if (str == 'false' || str == 'f' || str == '0') return false;
      return defaultVal;
    }

    return AppUser(
      id: map['id']?.toString() ?? '',
      role: map['role']?.toString() ?? 'student',
      email: map['email']?.toString() ?? '',
      name: map['name']?.toString(),
      studentClass: map['class']?.toString(),
      division: map['division']?.toString(),
      rollNo: map['roll_no']?.toString(),
      studentGroup: map['student_group']?.toString(),
      medium: map['medium']?.toString(),
      institution: map['institution']?.toString(),
      academicYear: map['academic_year']?.toString(),
      isActive: parseBool(map['is_active'] ?? map['isActive'], true),
      mustChangePassword: parseBool(map['must_change_password'] ?? map['mustChangePassword'], false),
      temporaryPassword: map['temporary_password']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role,
      'email': email,
      'name': name,
      'class': studentClass != null ? int.tryParse(studentClass!) : null,
      'division': division,
      'roll_no': rollNo,
      'student_group': studentGroup,
      'medium': medium,
      'institution': institution,
      'academic_year': academicYear,
      'is_active': isActive,
      'must_change_password': mustChangePassword,
      'temporary_password': temporaryPassword,
    };
  }
}
