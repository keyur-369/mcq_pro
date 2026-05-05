class Attempt {
  final String id;
  final String studentId;
  final String testId;
  final int score;
  final DateTime submittedAt;

  Attempt({
    required this.id,
    required this.studentId,
    required this.testId,
    required this.score,
    required this.submittedAt,
  });

  factory Attempt.fromMap(Map<String, dynamic> map) {
    return Attempt(
      id: map['id'],
      studentId: map['student_id'],
      testId: map['test_id'],
      score: map['score'],
      submittedAt: DateTime.parse(map['submitted_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'student_id': studentId,
      'test_id': testId,
      'score': score,
      'submitted_at': submittedAt.toIso8601String(),
    };
  }
}
