import 'package:intl/intl.dart';

class ChatConversation {
  final String id;
  final String studentId;
  final String teacherId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserEmail;
  final String otherUserRole; // 'student' or 'teacher'
  final String? studentClass;
  final String? studentDivision;
  final String? studentInstitution;
  final DateTime? lastMessageAt;
  final String? lastMessageText;
  final String? lastMessageSenderId;
  final int unreadCount;

  ChatConversation({
    required this.id,
    required this.studentId,
    required this.teacherId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserEmail,
    required this.otherUserRole,
    this.studentClass,
    this.studentDivision,
    this.studentInstitution,
    this.lastMessageAt,
    this.lastMessageText,
    this.lastMessageSenderId,
    this.unreadCount = 0,
  });

  bool get hasUnread => unreadCount > 0;

  String get initials {
    final parts = otherUserName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return otherUserRole == 'teacher' ? 'T' : 'S';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String get displaySubtitle {
    if (otherUserRole == 'student') {
      final std = (studentClass ?? '').trim();
      final div = (studentDivision ?? '').trim();
      final inst = (studentInstitution ?? '').trim();
      final parts = <String>[];
      if (std.isNotEmpty) parts.add('Std $std${div.isNotEmpty ? "-$div" : ""}');
      if (inst.isNotEmpty) parts.add(inst);
      return parts.isNotEmpty ? parts.join(' • ') : 'Student';
    } else {
      return 'Faculty';
    }
  }

  String get cleanLastMessageText {
    if (lastMessageText == null || lastMessageText!.isEmpty) return '';
    final text = lastMessageText!;
    if (text.contains('[TEST_CARD:')) {
      final line = text.split('\n').first;
      if (line.isNotEmpty && !line.startsWith('[TEST_CARD:')) {
        return line;
      }
      return '📝 Test Assignment';
    }
    return text;
  }

  String get formattedLastMessageTime {
    if (lastMessageAt == null) return '';
    final local = lastMessageAt!.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year && local.month == now.month && local.day == now.day;
    if (isToday) {
      return DateFormat('h:mm a').format(local);
    }
    final diffDays = now.difference(local).inDays;
    if (diffDays == 1 || (diffDays == 0 && !isToday)) {
      return 'Yesterday';
    }
    if (diffDays < 7) {
      return DateFormat('EEE').format(local);
    }
    return DateFormat('MMM d').format(local);
  }

  factory ChatConversation.fromMap(Map<String, dynamic> map, {String? currentUserId}) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    final id = map['id']?.toString() ?? map['conversation_id']?.toString() ?? '';
    final studentId = map['student_id']?.toString() ?? '';
    final teacherId = map['teacher_id']?.toString() ?? '';
    
    // Determine other user ID if not explicitly provided
    String otherId = map['other_user_id']?.toString() ?? '';
    if (otherId.isEmpty && currentUserId != null) {
      otherId = (currentUserId == studentId) ? teacherId : studentId;
    }

    final unread = int.tryParse(map['unread_count']?.toString() ?? '0') ?? 0;

    return ChatConversation(
      id: id,
      studentId: studentId,
      teacherId: teacherId,
      otherUserId: otherId,
      otherUserName: map['other_user_name']?.toString() ?? map['name']?.toString() ?? 'User',
      otherUserEmail: map['other_user_email']?.toString() ?? map['email']?.toString() ?? '',
      otherUserRole: map['other_user_role']?.toString() ?? (otherId == teacherId ? 'teacher' : 'student'),
      studentClass: map['student_class']?.toString() ?? map['class']?.toString(),
      studentDivision: map['student_division']?.toString() ?? map['division']?.toString(),
      studentInstitution: map['student_institution']?.toString() ?? map['institution']?.toString(),
      lastMessageAt: parseDate(map['last_message_at']),
      lastMessageText: map['last_message_text']?.toString(),
      lastMessageSenderId: map['last_message_sender_id']?.toString(),
      unreadCount: unread,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'teacher_id': teacherId,
      'other_user_id': otherUserId,
      'other_user_name': otherUserName,
      'other_user_email': otherUserEmail,
      'other_user_role': otherUserRole,
      'student_class': studentClass,
      'student_division': studentDivision,
      'student_institution': studentInstitution,
      'last_message_at': lastMessageAt?.toIso8601String(),
      'last_message_text': lastMessageText,
      'last_message_sender_id': lastMessageSenderId,
      'unread_count': unreadCount,
    };
  }

  ChatConversation copyWith({
    String? id,
    String? studentId,
    String? teacherId,
    String? otherUserId,
    String? otherUserName,
    String? otherUserEmail,
    String? otherUserRole,
    String? studentClass,
    String? studentDivision,
    String? studentInstitution,
    DateTime? lastMessageAt,
    String? lastMessageText,
    String? lastMessageSenderId,
    int? unreadCount,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      teacherId: teacherId ?? this.teacherId,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserEmail: otherUserEmail ?? this.otherUserEmail,
      otherUserRole: otherUserRole ?? this.otherUserRole,
      studentClass: studentClass ?? this.studentClass,
      studentDivision: studentDivision ?? this.studentDivision,
      studentInstitution: studentInstitution ?? this.studentInstitution,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
