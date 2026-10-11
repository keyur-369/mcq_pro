class PerformanceAggregate {
  final String id;
  final String? studentId;
  final String? studentName;
  final String? rollNo;
  final String standard;
  final String division;
  final String medium;
  final String subject;
  final String? topic;
  final String? testId;
  final String? testCode;
  final int score;
  final int totalMarks;
  final double percentage;
  final bool isPassed;
  final DateTime submittedAt;

  PerformanceAggregate({
    required this.id,
    this.studentId,
    this.studentName,
    this.rollNo,
    required this.standard,
    required this.division,
    required this.medium,
    required this.subject,
    this.topic,
    this.testId,
    this.testCode,
    required this.score,
    required this.totalMarks,
    required this.percentage,
    this.isPassed = true,
    required this.submittedAt,
  });

  factory PerformanceAggregate.fromMap(Map<String, dynamic> map) {
    return PerformanceAggregate(
      id: map['id'] ?? '',
      studentId: map['student_id'],
      studentName: map['student_name'],
      rollNo: map['roll_no']?.toString(),
      standard: map['standard']?.toString() ?? '',
      division: map['division'] ?? '',
      medium: map['medium'] ?? '',
      subject: map['subject'] ?? '',
      topic: map['topic'],
      testId: map['test_id'],
      testCode: map['test_code'],
      score: map['score'] ?? 0,
      totalMarks: map['total_marks'] ?? 10,
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
      isPassed: map['is_passed'] ?? true,
      submittedAt: DateTime.parse(map['submitted_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'roll_no': rollNo,
      'standard': standard,
      'division': division,
      'medium': medium,
      'subject': subject,
      'topic': topic,
      'test_id': testId,
      'test_code': testCode,
      'score': score,
      'total_marks': totalMarks,
      'percentage': percentage,
      'is_passed': isPassed,
      'submitted_at': submittedAt.toIso8601String(),
    };
  }
}
