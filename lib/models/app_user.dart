class AppUser {
  final String id;
  final String role; // 'teacher' or 'student'
  final String email;
  final String? studentClass; // '11' or '12'
  final String? division;
  final String? rollNo;

  AppUser({
    required this.id,
    required this.role,
    required this.email,
    this.studentClass,
    this.division,
    this.rollNo,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'],
      role: map['role'],
      email: map['email'],
      studentClass: map['class'],
      division: map['division'],
      rollNo: map['roll_no'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role,
      'email': email,
      'class': studentClass,
      'division': division,
      'roll_no': rollNo,
    };
  }
}
