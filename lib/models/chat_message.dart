import 'package:intl/intl.dart';

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String messageText;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isSending;
  final bool sendError;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.messageText,
    required this.createdAt,
    this.readAt,
    this.isSending = false,
    this.sendError = false,
  });

  bool get isRead => readAt != null;

  bool isMine(String currentUserId) => senderId == currentUserId;

  String get formattedTime {
    final local = createdAt.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year && local.month == now.month && local.day == now.day;
    if (isToday) {
      return DateFormat('h:mm a').format(local);
    }
    return DateFormat('MMM d, h:mm a').format(local);
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    return ChatMessage(
      id: map['id']?.toString() ?? '',
      conversationId: map['conversation_id']?.toString() ?? '',
      senderId: map['sender_id']?.toString() ?? '',
      messageText: map['message_text']?.toString() ?? '',
      createdAt: parseDate(map['created_at']),
      readAt: map['read_at'] != null ? parseDate(map['read_at']) : null,
      isSending: false,
      sendError: false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'message_text': messageText,
      'created_at': createdAt.toIso8601String(),
      if (readAt != null) 'read_at': readAt!.toIso8601String(),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? messageText,
    DateTime? createdAt,
    DateTime? readAt,
    bool? isSending,
    bool? sendError,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      messageText: messageText ?? this.messageText,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      isSending: isSending ?? this.isSending,
      sendError: sendError ?? this.sendError,
    );
  }
}
