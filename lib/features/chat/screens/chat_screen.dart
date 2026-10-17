import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/models/chat_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String? conversationId;
  final String teacherId;
  final String studentId;
  final String otherUserName;
  final String otherUserRole; // 'teacher' or 'student'
  final String? otherUserSubtitle;
  final String? otherUserEmail;

  const ChatScreen({
    super.key,
    this.conversationId,
    required this.teacherId,
    required this.studentId,
    required this.otherUserName,
    required this.otherUserRole,
    this.otherUserSubtitle,
    this.otherUserEmail,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final SupabaseService _supabase = SupabaseService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _conversationId;
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSending = false;

  RealtimeChannel? _realtimeChannel;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.currentUser?.id;
    _conversationId = widget.conversationId;
    _initChat();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Resolve or create conversation ID
      if (_conversationId == null || _conversationId!.isEmpty) {
        _conversationId = await _supabase.getOrCreateConversation(
          teacherId: widget.teacherId,
          studentId: widget.studentId,
        );
      }

      // 2. Fetch history
      final msgs = await _supabase.getConversationMessages(_conversationId!);

      if (mounted) {
        setState(() {
          _messages = msgs;
          _isLoading = false;
        });

        // 3. Mark incoming as read
        _markRead();

        // 4. Scroll to bottom
        _scrollToBottom(animated: false);

        // 5. Setup realtime subscription
        _setupRealtime();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _setupRealtime() {
    if (_conversationId == null || _conversationId!.isEmpty) return;

    _realtimeChannel?.unsubscribe();
    _realtimeChannel = _supabase.subscribeToConversationMessages(
      conversationId: _conversationId!,
      onInsert: (newMsg) {
        if (!mounted) return;
        setState(() {
          // Deduplicate if already present or matches optimistic message
          final existingIdx = _messages.indexWhere((m) =>
              m.id == newMsg.id ||
              (m.isSending && m.senderId == newMsg.senderId && m.messageText == newMsg.messageText));

          if (existingIdx != -1) {
            _messages[existingIdx] = newMsg;
          } else {
            _messages.add(newMsg);
          }
        });

        if (newMsg.senderId != _currentUserId) {
          _markRead();
        }
        _scrollToBottom(animated: true);
      },
      onUpdate: (updatedMsg) {
        if (!mounted) return;
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == updatedMsg.id);
          if (idx != -1) {
            _messages[idx] = updatedMsg;
          }
        });
      },
    );
  }

  void _markRead() {
    if (_conversationId != null && _conversationId!.isNotEmpty) {
      _supabase.markMessagesAsRead(_conversationId!);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendMessage([String? retryText]) async {
    final text = retryText ?? _textController.text.trim();
    if (text.isEmpty) return;

    if (retryText == null) {
      _textController.clear();
    }

    if (_conversationId == null || _conversationId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Initializing conversation, please wait...')),
      );
      return;
    }

    final localId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = ChatMessage(
      id: localId,
      conversationId: _conversationId!,
      senderId: _currentUserId ?? '',
      messageText: text,
      createdAt: DateTime.now(),
      isSending: true,
    );

    setState(() {
      _messages.add(tempMsg);
      _isSending = true;
    });
    _scrollToBottom(animated: true);

    try {
      final sent = await _supabase.sendMessage(
        conversationId: _conversationId!,
        messageText: text,
      );

      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == localId);
          if (idx != -1) {
            _messages[idx] = sent;
          }
          _isSending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == localId);
          if (idx != -1) {
            _messages[idx] = tempMsg.copyWith(isSending: false, sendError: true);
          }
          _isSending = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: AppColors.error,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _sendMessage(text),
            ),
          ),
        );
      }
    }
  }

  String get _initials {
    final parts = widget.otherUserName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return widget.otherUserRole == 'teacher' ? 'T' : 'S';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isTeacherPartner = widget.otherUserRole == 'teacher';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isTeacherPartner),
              Expanded(
                child: _buildBody(),
              ),
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isTeacherPartner) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.65),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.6),
            width: 1,
          ),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: AppColors.textPrimary,
                splashRadius: 22,
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isTeacherPartner ? AppColors.primaryGradient : [AppColors.secondary, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.otherUserName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isTeacherPartner
                                ? AppColors.primary.withOpacity(0.12)
                                : AppColors.secondary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isTeacherPartner ? 'Teacher' : 'Student',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isTeacherPartner ? AppColors.primary : AppColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.otherUserSubtitle ??
                          (isTeacherPartner ? 'Assigned Faculty' : 'Enrolled Student'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _initChat,
                icon: const Icon(Icons.refresh_rounded, size: 21),
                color: AppColors.primary,
                splashRadius: 22,
                tooltip: 'Refresh chat',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 14),
            Text(
              'Connecting to secure chat...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Unable to Load Chat',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _initChat,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleAppBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.15),
                      AppColors.primary.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Start a Conversation',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.otherUserRole == 'teacher'
                    ? 'Ask questions or clear doubts directly with ${widget.otherUserName}. Your conversation is 100% private.'
                    : 'Send a message or reply directly to ${widget.otherUserName}. Your conversation is 100% private.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 14, color: AppColors.success),
                    SizedBox(width: 6),
                    Text(
                      'End-to-end private between you two',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMine = message.isMine(_currentUserId ?? '');

        // Show date header if first or date changed from previous
        bool showDateDivider = false;
        if (index == 0) {
          showDateDivider = true;
        } else {
          final prevDate = _messages[index - 1].createdAt.toLocal();
          final currDate = message.createdAt.toLocal();
          if (prevDate.year != currDate.year ||
              prevDate.month != currDate.month ||
              prevDate.day != currDate.day) {
            showDateDivider = true;
          }
        }

        return Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showDateDivider) _buildDateDivider(message.createdAt),
            _buildMessageBubble(message, isMine),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildDateDivider(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    String label;
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      label = 'Today';
    } else if (now.difference(local).inDays == 1) {
      label = 'Yesterday';
    } else {
      label = '${local.day}/${local.month}/${local.year}';
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.65),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.6)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMine) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.78,
      ),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              gradient: isMine
                  ? const LinearGradient(
                      colors: AppColors.primaryGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.92),
                        Colors.white.withOpacity(0.82),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMine ? 18 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 18),
              ),
              boxShadow: [
                BoxShadow(
                  color: isMine
                      ? AppColors.primary.withOpacity(0.20)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: isMine ? Colors.transparent : Colors.white.withOpacity(0.8),
                width: 1,
              ),
            ),
            child: Text(
              msg.messageText,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.35,
                color: isMine ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg.formattedTime,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  if (msg.isSending)
                    const SizedBox(
                      width: 11,
                      height: 11,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.textMuted),
                    )
                  else if (msg.sendError)
                    GestureDetector(
                      onTap: () => _sendMessage(msg.messageText),
                      child: const Row(
                        children: [
                          Icon(Icons.error_outline_rounded, size: 12, color: AppColors.error),
                          SizedBox(width: 2),
                          Text('Retry', style: TextStyle(fontSize: 10, color: AppColors.error)),
                        ],
                      ),
                    )
                  else if (msg.isRead)
                    const Icon(Icons.done_all_rounded, size: 14, color: AppColors.primary)
                  else
                    const Icon(Icons.done_rounded, size: 13, color: AppColors.textMuted),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 8, 14, MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.70),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.65),
            width: 1,
          ),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppColors.border.withOpacity(0.7),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _textController,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: AppColors.primaryGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isSending ? null : () => _sendMessage(),
                    borderRadius: BorderRadius.circular(22),
                    child: Center(
                      child: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoundedRectangleAppBorder extends RoundedRectangleBorder {
  const RoundedRectangleAppBorder({super.borderRadius});
}
