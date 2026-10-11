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
    TestStatus parseStatus(dynamic val) {
      if (val == null) return TestStatus.published;
      final str = val.toString().toLowerCase();
      if (str == 'draft') return TestStatus.draft;
      return TestStatus.published;
    }

    int parseDuration(dynamic val) {
      if (val is int) return val;
      return int.tryParse(val?.toString() ?? '') ?? 30;
    }

    return Test(
      id: map['id']?.toString() ?? '',
      testCode: map['test_code']?.toString(),
      teacherId: map['teacher_id']?.toString() ?? '',
      studentClass: (map['class'] ?? '11').toString(),
      division: map['division']?.toString(),
      medium: map['medium']?.toString() ?? 'English',
      subject: map['subject']?.toString() ?? 'General',
      topic: map['topic']?.toString() ?? 'Untitled',
      level: map['level']?.toString() ?? 'Medium',
      duration: parseDuration(map['duration']),
      status: parseStatus(map['status']),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
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
