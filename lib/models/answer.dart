class Answer {
  final String id;
  final String attemptId;
  final String questionId;
  final String selectedAnswer; // 'A', 'B', 'C', 'D'

  Answer({
    required this.id,
    required this.attemptId,
    required this.questionId,
    required this.selectedAnswer,
  });

  factory Answer.fromMap(Map<String, dynamic> map) {
    return Answer(
      id: map['id'],
      attemptId: map['attempt_id'],
      questionId: map['question_id'],
      selectedAnswer: map['selected_answer'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'attempt_id': attemptId,
      'question_id': questionId,
      'selected_answer': selectedAnswer,
    };
  }
}
