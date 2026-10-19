import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/features/chat/widgets/chat_test_card.dart';
import 'package:mcq_test_app/models/app_user.dart';
import 'package:mcq_test_app/models/chat_message.dart';
import 'package:mcq_test_app/models/chat_test_card.dart';
import 'package:mcq_test_app/models/test.dart';
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
  AppUser? _studentProfile;

  bool get _isTeacher =>
      (_currentUserId != null && _currentUserId == widget.teacherId) ||
      widget.otherUserRole == 'student';

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

      // 3. Load student profile if viewing as student for eligibility checking
      if (!_isTeacher && _currentUserId != null) {
        try {
          _studentProfile = await _supabase.getUserProfile(_currentUserId!);
        } catch (_) {}
      }

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
    final isTestCard = ChatTestCardData.isTestCard(msg.messageText);
    final cardData = isTestCard ? ChatTestCardData.tryParse(msg.messageText) : null;

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * (cardData != null ? 0.88 : 0.78),
      ),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (cardData != null)
            ChatTestCard(
              data: cardData,
              isMine: isMine,
              isTeacher: _isTeacher,
              studentProfile: _studentProfile,
            )
          else
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

  void _showShareTestModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ShareTestModal(
        teacherId: _currentUserId ?? widget.teacherId,
        studentName: widget.otherUserName,
        onSelectTest: (test) {
          Navigator.pop(ctx);
          final cardData = ChatTestCardData.fromTest(test);
          _sendMessage(cardData.toMessageText());
        },
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
              if (_isTeacher) ...[
                Tooltip(
                  message: 'Share Test Card',
                  child: Container(
                    margin: const EdgeInsets.only(right: 8, bottom: 2),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showShareTestModal,
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.9),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.quiz_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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

class _ShareTestModal extends StatefulWidget {
  final String teacherId;
  final String studentName;
  final void Function(Test test) onSelectTest;

  const _ShareTestModal({
    required this.teacherId,
    required this.studentName,
    required this.onSelectTest,
  });

  @override
  State<_ShareTestModal> createState() => _ShareTestModalState();
}

class _ShareTestModalState extends State<_ShareTestModal> {
  final SupabaseService _supabase = SupabaseService();
  List<Test> _tests = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  Future<void> _loadTests() async {
    setState(() => _isLoading = true);
    try {
      final allTests = await _supabase.getTeacherTests(widget.teacherId);
      final published = allTests.where((t) => t.status == TestStatus.published).toList();
      if (mounted) {
        setState(() {
          _tests = published;
          _isLoading = false;
        });
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.8),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.primaryGradient,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.quiz_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Share Test Card',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Send an interactive test card to ${widget.studentName}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Tests list
              Flexible(
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _errorMessage != null
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'Error: $_errorMessage',
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ),
                          )
                        : _tests.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(36),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.quiz_outlined,
                                      size: 52,
                                      color: AppColors.textMuted.withOpacity(0.4),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No published tests found',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Create and publish a test first from your dashboard.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                shrinkWrap: true,
                                itemCount: _tests.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (ctx, index) {
                                  final test = _tests[index];
                                  final divStr = (test.division != null &&
                                          test.division!.isNotEmpty &&
                                          test.division!.toUpperCase() != 'ALL')
                                      ? '-${test.division}'
                                      : '';
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.primary.withOpacity(0.18),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      leading: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.assignment_outlined,
                                          color: AppColors.primary,
                                          size: 22,
                                        ),
                                      ),
                                      title: Text(
                                        test.subject,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 2),
                                          Text(
                                            test.topic,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: AppColors.textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'Std ${test.studentClass}$divStr',
                                                  style: const TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primaryDark,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '⏱️ ${test.duration}m',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textMuted,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (test.testCode != null) ...[
                                                const SizedBox(width: 6),
                                                Text(
                                                  '• ${test.testCode}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.textMuted,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing: ElevatedButton.icon(
                                        onPressed: () => widget.onSelectTest(test),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        icon: const Icon(Icons.send_rounded, size: 14),
                                        label: const Text(
                                          'Send',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
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

