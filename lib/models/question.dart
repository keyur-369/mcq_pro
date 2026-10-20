class Question {
  final String id;
  final String testId;
  final String questionText;
  final String? imageUrl; // Diagram, reaction mechanism, or chemical structure image (URL or base64 data)
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctAnswer; // 'A', 'B', 'C', 'D'
  final String explanation;

  Question({
    this.id = '',
    required this.testId,
    required this.questionText,
    this.imageUrl,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctAnswer,
    required this.explanation,
  });

  List<String> get options => [optionA, optionB, optionC, optionD];

  Question copyWith({
    String? id,
    String? testId,
    String? questionText,
    String? imageUrl,
    String? optionA,
    String? optionB,
    String? optionC,
    String? optionD,
    String? correctAnswer,
    String? explanation,
  }) {
    return Question(
      id: id ?? this.id,
      testId: testId ?? this.testId,
      questionText: questionText ?? this.questionText,
      imageUrl: imageUrl ?? this.imageUrl,
      optionA: optionA ?? this.optionA,
      optionB: optionB ?? this.optionB,
      optionC: optionC ?? this.optionC,
      optionD: optionD ?? this.optionD,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      explanation: explanation ?? this.explanation,
    );
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    String rawQuestion = map['question']?.toString() ?? '';
    String? img = map['image_url']?.toString();

    // If no direct column, check if an image tag was embedded: [IMAGE: ...]
    if (img == null || img.isEmpty) {
      final imgRegex = RegExp(r'\[IMAGE:\s*(.*?)\]', dotAll: true);
      final match = imgRegex.firstMatch(rawQuestion);
      if (match != null) {
        img = match.group(1)?.trim();
        rawQuestion = rawQuestion.replaceAll(match.group(0)!, '').trim();
      }
    }

    return Question(
      id: map['id']?.toString() ?? '',
      testId: map['test_id']?.toString() ?? '',
      questionText: rawQuestion,
      imageUrl: img,
      optionA: map['option_a']?.toString() ?? '',
      optionB: map['option_b']?.toString() ?? '',
      optionC: map['option_c']?.toString() ?? '',
      optionD: map['option_d']?.toString() ?? '',
      correctAnswer: map['correct_answer']?.toString() ?? 'A',
      explanation: map['explanation']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap({bool separateImageColumn = false}) {
    String finalQuestion = questionText;
    if (imageUrl != null && imageUrl!.trim().isNotEmpty && !separateImageColumn) {
      finalQuestion = '$questionText\n[IMAGE: ${imageUrl!.trim()}]';
    }

    final data = <String, dynamic>{
      'test_id': testId,
      'question': finalQuestion,
      'option_a': optionA,
      'option_b': optionB,
      'option_c': optionC,
      'option_d': optionD,
      'correct_answer': correctAnswer,
      'explanation': explanation,
    };

    if (separateImageColumn && imageUrl != null) {
      data['image_url'] = imageUrl;
    }

    return data;
  }
}

