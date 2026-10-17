class AssignedTeacher {
  final String teacherId;
  final String name;
  final String email;
  final List<String> subjects;

  AssignedTeacher({
    required this.teacherId,
    required this.name,
    required this.email,
    required this.subjects,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'T';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String get subjectsText {
    if (subjects.isEmpty) return 'Faculty';
    return subjects.join(' • ');
  }

  factory AssignedTeacher.fromMap(Map<String, dynamic> map) {
    List<String> subList = [];
    final rawSub = map['subjects'];
    if (rawSub is List) {
      subList = rawSub.map((e) => e.toString()).toList();
    } else if (rawSub is String && rawSub.isNotEmpty) {
      subList = [rawSub];
    }

    return AssignedTeacher(
      teacherId: map['teacher_id']?.toString() ?? map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Teacher',
      email: map['email']?.toString() ?? '',
      subjects: subList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacher_id': teacherId,
      'name': name,
      'email': email,
      'subjects': subjects,
    };
  }
}
