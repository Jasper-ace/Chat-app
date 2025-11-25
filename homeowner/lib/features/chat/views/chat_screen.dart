import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../services/chat_api_service.dart';
import '../../auth/services/homeowner_api_auth_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String otherUserName;
  final String otherUserId;
  final String otherUserType;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
    required this.otherUserId,
    required this.otherUserType,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _authService = HomeownerApiAuthService();
  final _chatService = ChatApiService();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    print('🔥🔥🔥 ChatScreen initialized with chatId: ${widget.chatId}');
    print('🔥🔥🔥 Other user: ${widget.otherUserName}');
    _initChat();
  }

  Future<void> _initChat() async {
    _currentUserId = (await _authService.getUserId())?.toString();
    print('🔥🔥🔥 Current user ID: $_currentUserId');
    _listenToMessages();
  }

  void _listenToMessages() {
    print('🔥🔥🔥 Listening to Firebase path: threads/${widget.chatId}');
    print('🔥🔥🔥 Chat ID received: ${widget.chatId}');

    // Listen to the specific thread
    final messagesRef = FirebaseDatabase.instance.ref(
      'threads/${widget.chatId}',
    );

    messagesRef.onValue.listen(
      (event) {
        print('🔥 Firebase event received');
        print('🔥 Snapshot exists: ${event.snapshot.exists}');
        print('🔥 Snapshot value type: ${event.snapshot.value.runtimeType}');

        if (event.snapshot.value != null) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          final messages = <Map<String, dynamic>>[];

          print('🔥 Thread data keys: ${data.keys.toList()}');
          print('🔥 Full thread data: $data');

          // Check if messages node exists
          if (data.containsKey('messages')) {
            final messagesData = data['messages'] as Map<dynamic, dynamic>;
            print(
              '🔥 Messages node found with ${messagesData.length} messages',
            );
            print('🔥 Messages data: $messagesData');

            messagesData.forEach((key, value) {
              print(
                '🔥 Processing message key: $key, value type: ${value.runtimeType}',
              );
              if (value is Map) {
                final message = Map<String, dynamic>.from(value as Map);
                message['id'] = key;
                messages.add(message);
                print(
                  '🔥 Added message: $key with content: ${message['content']}',
                );
              }
            });
          } else {
            print('🔥 No messages node found in thread data');
            print('🔥 Available keys: ${data.keys.toList()}');
          }

          // Sort by date
          messages.sort((a, b) {
            final aTime = a['date'] ?? 0;
            final bTime = b['date'] ?? 0;
            return aTime.compareTo(bTime);
          });

          print('🔥 Total messages for this chat: ${messages.length}');
          if (messages.isNotEmpty) {
            print('🔥 First message: ${messages.first}');
          }

          setState(() {
            _messages = messages;
            _isLoading = false;
          });

          // Scroll to bottom
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        } else {
          print('🔥 Snapshot value is null');
          setState(() {
            _messages = [];
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        print('❌ Firebase listener error: $error');
        setState(() {
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    setState(() => _isSending = true);

    try {
      final userId = await _authService.getUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _chatService.sendMessage(
        chatId: widget.chatId,
        senderId: userId.toString(),
        senderType: 'homeowner',
        receiverId: widget.otherUserId,
        receiverType: widget.otherUserType,
        message: messageText,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/chats'),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              child: Text(
                widget.otherUserName.substring(0, 1).toUpperCase(),
                style: TextStyle(color: AppColors.primary, fontSize: 18),
              ),
            ),
            const SizedBox(width: AppDimensions.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Offline',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? _buildEmptyState()
                : _buildMessageList(),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: AppColors.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Text(
            'No messages yet',
            style: AppTextStyles.headlineSmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing8),
          Text(
            'Start the conversation!',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        // Check both sender_id AND sender_type
        final isMe =
            message['sender_id'].toString() == _currentUserId &&
            message['sender_type'] == 'homeowner';
        return _buildMessageBubble(message, isMe);
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.spacing8),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMedium,
          vertical: AppDimensions.paddingSmall,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message['content']?.toString() ?? '',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isMe ? Colors.white : AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message['date']),
              style: AppTextStyles.bodySmall.copyWith(
                color: isMe
                    ? Colors.white.withOpacity(0.7)
                    : AppColors.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMedium,
        vertical: AppDimensions.paddingSmall,
      ),
      decoration: BoxDecoration(color: Colors.grey[100]),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.attach_file, color: AppColors.primary),
            onPressed: () {
              // Handle attachment
            },
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Type your message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ),
          IconButton(
            icon: const Text('😊', style: TextStyle(fontSize: 24)),
            onPressed: () {
              // Handle emoji picker
            },
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: _isSending
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
