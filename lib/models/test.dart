enum TestStatus { draft, published }

class Test {
  final String id;
  final String? testCode;
  final String teacherId;
  final String studentClass;
  final String? division;
  final String medium;
  final String subject;
  final String topic;
  final String level;
  final int duration;
  final TestStatus status;
  final DateTime? createdAt;

  Test({
    this.id = '',
    this.testCode,
    required this.teacherId,
    required this.studentClass,
    this.division,
    required this.medium,
    required this.subject,
    required this.topic,
    required this.level,
    required this.duration,
    required this.status,
    this.createdAt,
  });

  factory Test.fromMap(Map<String, dynamic> map) {
    return Test(
      id: map['id'],
      testCode: map['test_code'],
      teacherId: map['teacher_id'],
      studentClass: map['class'].toString(),
      division: map['division'],
      medium: map['medium'],
      subject: map['subject'],
      topic: map['topic'],
      level: map['level'],
      duration: map['duration'],
      status: TestStatus.values.firstWhere((e) => e.name == map['status']),
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'test_code': testCode,
      'teacher_id': teacherId,
      'class': studentClass,
      'division': division,
      'medium': medium,
      'subject': subject,
      'topic': topic,
      'level': level,
      'duration': duration,
      'status': status.name,
    };
  }
}
