import 'dart:convert';
import 'package:mcq_test_app/models/test.dart';

/// Data structure representing an interactive test card embedded in chat messages.
class ChatTestCardData {
  final String testId;
  final String? testCode;
  final String subject;
  final String topic;
  final int duration;
  final String studentClass;
  final String? division;
  final String medium;
  final String level;
  final String teacherId;

  const ChatTestCardData({
    required this.testId,
    this.testCode,
    required this.subject,
    required this.topic,
    required this.duration,
    required this.studentClass,
    this.division,
    this.medium = 'English',
    this.level = 'Medium',
    this.teacherId = '',
  });

  static const String prefix = '[TEST_CARD:';
  static const String suffix = ']';

  /// Determines if a chat message contains an interactive test card payload
  static bool isTestCard(String text) {
    return text.contains(prefix) && text.contains(suffix);
  }

  /// Parses test card data from a chat message text
  static ChatTestCardData? tryParse(String text) {
    try {
      final startIndex = text.indexOf(prefix);
      final endIndex = text.lastIndexOf(suffix);
      if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) {
        return null;
      }
      final jsonStr = text.substring(startIndex + prefix.length, endIndex);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ChatTestCardData.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  factory ChatTestCardData.fromMap(Map<String, dynamic> map) {
    return ChatTestCardData(
      testId: map['testId']?.toString() ?? '',
      testCode: map['testCode']?.toString(),
      subject: map['subject']?.toString() ?? 'General',
      topic: map['topic']?.toString() ?? 'Untitled',
      duration: int.tryParse(map['duration']?.toString() ?? '') ?? 30,
      studentClass: map['studentClass']?.toString() ?? '11',
      division: map['division']?.toString(),
      medium: map['medium']?.toString() ?? 'English',
      level: map['level']?.toString() ?? 'Medium',
      teacherId: map['teacherId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'testId': testId,
      if (testCode != null && testCode!.isNotEmpty) 'testCode': testCode,
      'subject': subject,
      'topic': topic,
      'duration': duration,
      'studentClass': studentClass,
      if (division != null && division!.isNotEmpty) 'division': division,
      'medium': medium,
      'level': level,
      'teacherId': teacherId,
    };
  }

  factory ChatTestCardData.fromTest(Test test) {
    return ChatTestCardData(
      testId: test.id,
      testCode: test.testCode,
      subject: test.subject,
      topic: test.topic,
      duration: test.duration,
      studentClass: test.studentClass,
      division: test.division,
      medium: test.medium,
      level: test.level,
      teacherId: test.teacherId,
    );
  }

  Test toTest() {
    return Test(
      id: testId,
      testCode: testCode,
      teacherId: teacherId,
      studentClass: studentClass,
      division: division,
      medium: medium,
      subject: subject,
      topic: topic,
      level: level,
      duration: duration,
      status: TestStatus.published,
    );
  }

  /// Generates the message string containing a clean announcement header and the JSON payload
  String toMessageText() {
    final divStr = (division != null &&
            division!.trim().isNotEmpty &&
            division!.toUpperCase() != 'ALL' &&
            division!.toUpperCase() != 'BOTH')
        ? '-$division'
        : '';
    final codeStr =
        (testCode != null && testCode!.isNotEmpty) ? ' (Code: $testCode)' : '';
    final summary =
        '📝 Test Assignment: $subject - $topic • Std $studentClass$divStr$codeStr';
    final payload = jsonEncode(toMap());
    return '$summary\n$prefix$payload$suffix';
  }

  /// Extracts human-readable announcement text without the JSON payload
  static String getDisplayText(String messageText) {
    if (!isTestCard(messageText)) return messageText;
    final lines = messageText.split('\n');
    final firstNonPayload = lines.firstWhere(
      (l) => !l.startsWith(prefix) && l.trim().isNotEmpty,
      orElse: () => '📝 Interactive Test Card',
    );
    return firstNonPayload.trim();
  }
}
