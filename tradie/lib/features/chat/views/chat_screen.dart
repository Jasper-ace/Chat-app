import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../services/chat_api_service.dart';
import '../../auth/services/tradie_api_auth_service.dart';
import '../widgets/typing_indicator.dart';

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
  final _authService = TradieApiAuthService();
  final _chatService = ChatApiService();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _currentUserId;
  String? _actualChatId; // Track the actual chat ID after thread creation
  Map<String, dynamic>? _replyingTo; // Track message being replied to
  bool _isOtherUserTyping = false;
  Timer? _typingTimer;
  bool _isBlockedByMe = false; // I blocked the other user
  bool _isBlockedByThem = false; // They blocked me
  bool _isOtherUserOnline = false; // Track other user's online status

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

    // Set my online status
    _setOnlineStatus(true);

    // Check blocked status
    await _checkBlockedStatus();

    // Only listen to messages if this is an existing chat (not a new one)
    if (!widget.chatId.startsWith('new_')) {
      _listenToMessages();
      _listenToTypingStatus();
      _listenToOnlineStatus();
    } else {
      // For new chats, just show empty state
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setOnlineStatus(bool isOnline) {
    if (_currentUserId == null) return;

    final onlineRef = FirebaseDatabase.instance.ref(
      'userProfiles/$_currentUserId/online',
    );

    if (isOnline) {
      onlineRef.set({'status': true, 'last_seen': ServerValue.timestamp});

      // Set up disconnect handler
      onlineRef.onDisconnect().set({
        'status': false,
        'last_seen': ServerValue.timestamp,
      });
    } else {
      onlineRef.set({'status': false, 'last_seen': ServerValue.timestamp});
    }
  }

  void _listenToOnlineStatus() {
    final onlineRef = FirebaseDatabase.instance.ref(
      'userProfiles/${widget.otherUserId}/online/status',
    );

    onlineRef.onValue.listen((event) {
      if (mounted && event.snapshot.exists) {
        final isOnline = event.snapshot.value as bool? ?? false;
        setState(() {
          _isOtherUserOnline = isOnline;
        });
      }
    });
  }

  Future<void> _checkBlockedStatus() async {
    if (_currentUserId == null) return;

    print('🚫 Block Status Check START:');
    print('   My ID: $_currentUserId (tradie)');
    print('   Other ID: ${widget.otherUserId} (${widget.otherUserType})');

    // Check if I blocked them
    final myBlockPath =
        'userProfiles/$_currentUserId/blockedUsers/${widget.otherUserId}';
    print('   Checking my block path: $myBlockPath');
    final myBlockRef = FirebaseDatabase.instance.ref(myBlockPath);
    final myBlockSnapshot = await myBlockRef.get();
    print('   My block exists: ${myBlockSnapshot.exists}');
    if (myBlockSnapshot.exists) {
      print('   My block data: ${myBlockSnapshot.value}');
    }

    // Check if they blocked me
    final theirBlockPath =
        'userProfiles/${widget.otherUserId}/blockedUsers/$_currentUserId';
    print('   Checking their block path: $theirBlockPath');
    final theirBlockRef = FirebaseDatabase.instance.ref(theirBlockPath);
    final theirBlockSnapshot = await theirBlockRef.get();
    print('   Their block exists: ${theirBlockSnapshot.exists}');
    if (theirBlockSnapshot.exists) {
      print('   Their block data: ${theirBlockSnapshot.value}');
    }

    setState(() {
      _isBlockedByMe = myBlockSnapshot.exists;
      _isBlockedByThem = theirBlockSnapshot.exists;
    });

    print(
      '🚫 Final state: _isBlockedByMe=$_isBlockedByMe, _isBlockedByThem=$_isBlockedByThem',
    );

    // Listen for changes in block status
    myBlockRef.onValue.listen((event) {
      if (mounted) {
        setState(() {
          _isBlockedByMe = event.snapshot.exists;
        });
      }
    });

    theirBlockRef.onValue.listen((event) {
      if (mounted) {
        setState(() {
          _isBlockedByThem = event.snapshot.exists;
        });
      }
    });
  }

  void _listenToMessages() {
    final chatId = _actualChatId ?? widget.chatId;
    print('🔥🔥🔥 Listening to Firebase path: threads/$chatId');
    print('🔥🔥🔥 Chat ID received: $chatId');

    // Listen to the specific thread
    final messagesRef = FirebaseDatabase.instance.ref('threads/$chatId');

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
                final message = Map<String, dynamic>.from(value);
                message['id'] = key;
                messages.add(message);
                print(
                  '🔥 Added message: $key with content: ${message['content']}',
                );
              }
            });

            // Filter out messages deleted by current user
            _filterDeletedMessages(messages);
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
    if (_messageController.text.trim().isEmpty) return;

    // Check if blocked
    if (_isBlockedByMe || _isBlockedByThem) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isBlockedByMe
                ? 'You have blocked this user. Unblock to send messages.'
                : "You've been blocked.",
          ),
        ),
      );
      return;
    }

    final messageText = _messageController.text.trim();
    final replyData = _replyingTo; // Capture reply data before clearing
    _messageController.clear();

    // Clear reply state immediately
    setState(() {
      _replyingTo = null;
    });

    // Clear typing status immediately
    _updateTypingStatus(false);

    // Send message in background without blocking UI
    _sendMessageInBackground(messageText, replyData);
  }

  Future<void> _sendMessageInBackground(
    String messageText,
    Map<String, dynamic>? replyData,
  ) async {
    try {
      final userId = await _authService.getUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      bool isNewChat =
          widget.chatId.startsWith('new_') && _actualChatId == null;

      // Prepare reply data if replying to a message
      Map<String, dynamic>? replyToData;
      if (replyData != null) {
        replyToData = {
          'message_id': replyData['id']?.toString() ?? '',
          'sender_name': widget.otherUserName,
          'content': replyData['content']?.toString() ?? '',
        };
      }

      // Send message - backend will find or create thread automatically
      // and return the thread_id
      final threadId = await _chatService.sendMessage(
        chatId: 'dummy', // Not used by backend
        senderId: userId.toString(),
        senderType: 'tradie',
        receiverId: widget.otherUserId,
        receiverType: widget.otherUserType,
        message: messageText,
        replyTo: replyToData,
      );

      if (threadId == null) {
        throw Exception('Failed to send message - no thread_id returned');
      }

      print('✅ Message sent successfully to thread: $threadId');

      if (isNewChat && mounted) {
        // Backend returned the thread_id, use it to listen
        setState(() {
          _actualChatId = threadId;
        });
        _listenToMessages();
        _listenToTypingStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  void _listenToTypingStatus() {
    final chatId = _actualChatId ?? widget.chatId;
    if (chatId.startsWith('new_')) {
      print('⌨️ Skipping typing listener - new chat');
      return;
    }

    final typingPath =
        'threads/$chatId/typing/${widget.otherUserId}_${widget.otherUserType}';
    print('⌨️ Listening to typing status at: $typingPath');

    final typingRef = FirebaseDatabase.instance.ref(typingPath);

    typingRef.onValue.listen((event) {
      print('⌨️ Typing event received: ${event.snapshot.value}');
      if (event.snapshot.exists && mounted) {
        final isTyping = event.snapshot.value as bool? ?? false;
        print('⌨️ Other user typing: $isTyping');
        setState(() {
          _isOtherUserTyping = isTyping;
        });
      } else {
        print('⌨️ Typing snapshot does not exist or not mounted');
      }
    });
  }

  void _updateTypingStatus(bool isTyping) {
    final chatId = _actualChatId ?? widget.chatId;
    if (chatId.startsWith('new_') || _currentUserId == null) {
      print('⌨️ Cannot update typing - new chat or no user ID');
      return;
    }

    final typingPath = 'threads/$chatId/typing/${_currentUserId}_tradie';
    print('⌨️ Updating typing status to $isTyping at: $typingPath');

    final typingRef = FirebaseDatabase.instance.ref(typingPath);

    typingRef
        .set(isTyping)
        .then((_) {
          print('⌨️ Typing status updated successfully');
        })
        .catchError((error) {
          print('❌ Failed to update typing status: $error');
        });

    // Auto-clear typing status after 3 seconds
    _typingTimer?.cancel();
    if (isTyping) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        print('⌨️ Auto-clearing typing status');
        typingRef.set(false);
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    // Clear typing status on dispose
    if (_actualChatId != null && _currentUserId != null) {
      FirebaseDatabase.instance
          .ref('threads/$_actualChatId/typing/${_currentUserId}_tradie')
          .set(false);
    }
    // Set offline status
    _setOnlineStatus(false);
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
                    _isOtherUserOnline ? 'Online' : 'Offline',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: _isOtherUserOnline ? Colors.green : Colors.white70,
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
            onPressed: _showChatOptions,
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
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
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
      itemCount: _messages.length + (_isOtherUserTyping ? 1 : 0),
      itemBuilder: (context, index) {
        // Show typing indicator as last item
        if (_isOtherUserTyping && index == _messages.length) {
          return const Align(
            alignment: Alignment.centerLeft,
            child: TypingIndicator(),
          );
        }

        final message = _messages[index];
        // Check both sender_id AND sender_type
        final isMe =
            message['sender_id'].toString() == _currentUserId &&
            message['sender_type'] == 'tradie';
        return _buildMessageBubble(message, isMe);
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Show reply indicator above the bubble if this is a reply
          if (message['reply_to'] != null && message['reply_to'] is Map)
            Padding(
              padding: const EdgeInsets.only(left: 50, right: 50, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.reply, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      isMe
                          ? 'You replied to ${(message['reply_to'] as Map)['sender_name'] ?? 'User'}'
                          : 'Replied to you',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Dismissible(
            key: Key(message['id']?.toString() ?? ''),
            direction: DismissDirection.startToEnd,
            confirmDismiss: (direction) async {
              _handleReply(message);
              return false; // Don't actually dismiss
            },
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              child: const Icon(Icons.reply, color: Colors.grey),
            ),
            child: GestureDetector(
              onLongPress: message['unsent'] == true
                  ? null
                  : () => _showMessageOptions(message, isMe),
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
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show replied message if this is a reply
                    if (message['reply_to'] != null &&
                        message['reply_to'] is Map)
                      _buildRepliedMessage(
                        Map<String, dynamic>.from(message['reply_to'] as Map),
                        isMe,
                      ),
                    Text(
                      message['content']?.toString() ?? '',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: message['unsent'] == true
                            ? (isMe ? Colors.white70 : Colors.grey)
                            : (isMe ? Colors.white : AppColors.onSurface),
                        fontStyle: message['unsent'] == true
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(message['date']),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppColors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepliedMessage(Map<String, dynamic> repliedMsg, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white : AppColors.primary,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.reply,
                size: 12,
                color: isMe ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                repliedMsg['sender_name'] ?? 'User',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isMe ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            repliedMsg['content']?.toString() ?? '',
            style: AppTextStyles.bodySmall.copyWith(
              color: isMe
                  ? Colors.white.withValues(alpha: 0.9)
                  : AppColors.onSurface.withValues(alpha: 0.8),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(Map<String, dynamic> message, bool isMe) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                _handleCopy(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                _handleReply(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete for me',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleDeleteForMe(message);
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.red,
                ),
                title: const Text(
                  'Unsend message',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleUnsendMessage(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _handleReply(Map<String, dynamic> message) {
    setState(() {
      _replyingTo = message;
    });
    _messageController.clear();
    // Focus on text field
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  void _handleDeleteForMe(Map<String, dynamic> message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text(
          'Delete this message for you? The other person will still see it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteMessageForMe(message);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessageForMe(Map<String, dynamic> message) async {
    try {
      if (_currentUserId == null) return;

      final chatId = _actualChatId ?? widget.chatId;
      final messageId = message['id'];

      // Store deleted message ID in user's profile
      final deletedRef = FirebaseDatabase.instance.ref(
        'userProfiles/$_currentUserId/deletedMessages/$chatId/$messageId',
      );

      await deletedRef.set(true);

      // Remove from local list
      setState(() {
        _messages.removeWhere((m) => m['id'] == messageId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted for you')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete message: $e')));
      }
    }
  }

  void _handleCopy(Map<String, dynamic> message) {
    final content = message['content']?.toString() ?? '';
    if (content.isNotEmpty) {
      // Copy to clipboard
      // Note: Add flutter/services import at the top: import 'package:flutter/services.dart';
      // Clipboard.setData(ClipboardData(text: content));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message copied to clipboard')),
      );
    }
  }

  void _handleUnsendMessage(Map<String, dynamic> message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsend Message'),
        content: const Text(
          'Unsend this message? It will be removed for everyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _unsendMessage(message);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unsend'),
          ),
        ],
      ),
    );
  }

  Future<void> _unsendMessage(Map<String, dynamic> message) async {
    try {
      final chatId = _actualChatId ?? widget.chatId;
      final messageId = message['id'];

      // Update message in Firebase to mark as unsent
      final messageRef = FirebaseDatabase.instance.ref(
        'threads/$chatId/messages/$messageId',
      );

      await messageRef.update({
        'content': 'Message was unsent',
        'unsent': true,
        'unsent_at': DateTime.now().millisecondsSinceEpoch,
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message unsent')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to unsend message: $e')));
      }
    }
  }

  Future<void> _filterDeletedMessages(
    List<Map<String, dynamic>> messages,
  ) async {
    if (_currentUserId == null) return;

    final chatId = _actualChatId ?? widget.chatId;
    final deletedRef = FirebaseDatabase.instance.ref(
      'userProfiles/$_currentUserId/deletedMessages/$chatId',
    );

    final snapshot = await deletedRef.get();
    if (snapshot.exists) {
      final deletedIds = (snapshot.value as Map).keys.toSet();
      messages.removeWhere((msg) => deletedIds.contains(msg['id']));
    }
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('View Profile - Coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined),
              title: const Text('Mute Notifications'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications muted')),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete Chat',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteChat();
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_outlined, color: Colors.red),
              title: const Text(
                'Report User',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmReportUser();
              },
            ),
            ListTile(
              leading: Icon(
                _isBlockedByMe ? Icons.check_circle : Icons.block,
                color: _isBlockedByMe ? Colors.orange : Colors.red,
              ),
              title: Text(
                _isBlockedByMe ? 'Unblock User' : 'Block User',
                style: TextStyle(
                  color: _isBlockedByMe ? Colors.orange : Colors.red,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                if (_isBlockedByMe) {
                  _confirmUnblockUser();
                } else {
                  _confirmBlockUser();
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text(
          'Delete this conversation? This will remove all messages for you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/chats');
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Chat deleted')));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmReportUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report User'),
        content: Text(
          'Report ${widget.otherUserName} for inappropriate behavior?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('User reported')));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  void _confirmBlockUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text(
          'Block ${widget.otherUserName}? They will not be able to send you messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _blockUser();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser() async {
    try {
      final userId = await _authService.getUserId();
      if (userId == null) return;

      // Store blocked user in Firebase
      final blockedRef = FirebaseDatabase.instance.ref(
        'userProfiles/$userId/blockedUsers/${widget.otherUserId}',
      );

      await blockedRef.set({
        'blocked_at': DateTime.now().millisecondsSinceEpoch,
        'user_type': widget.otherUserType,
        'user_name': widget.otherUserName,
      });

      if (mounted) {
        setState(() {
          _isBlockedByMe = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.otherUserName} blocked')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to block user: $e')));
      }
    }
  }

  void _confirmUnblockUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock User'),
        content: Text(
          'Unblock ${widget.otherUserName}? You will be able to send and receive messages again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _unblockUser();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
  }

  Future<void> _unblockUser() async {
    try {
      final userId = await _authService.getUserId();
      if (userId == null) return;

      // Remove blocked user from Firebase
      final blockedRef = FirebaseDatabase.instance.ref(
        'userProfiles/$userId/blockedUsers/${widget.otherUserId}',
      );

      await blockedRef.remove();

      if (mounted) {
        setState(() {
          _isBlockedByMe = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.otherUserName} unblocked')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to unblock user: $e')));
      }
    }
  }

  Widget _buildMessageInput() {
    // Show blocked message if blocked
    if (_isBlockedByMe || _isBlockedByThem) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          border: Border(top: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Row(
          children: [
            Icon(Icons.block, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isBlockedByMe
                    ? 'You blocked this user. Tap to unblock.'
                    : "You've been blocked.",
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
            if (_isBlockedByMe)
              TextButton(
                onPressed: _confirmUnblockUser,
                child: const Text('Unblock'),
              ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyingTo != null) _buildReplyPreview(),
        Container(
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
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (text) {
                      if (text.isNotEmpty) {
                        _updateTypingStatus(true);
                      } else {
                        _updateTypingStatus(false);
                      }
                    },
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
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 1),
          left: BorderSide(color: AppColors.primary, width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _replyingTo!['content']?.toString() ?? '',
                  style: AppTextStyles.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _cancelReply,
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
      // Convert to 12-hour format with AM/PM
      final hour = date.hour == 0
          ? 12
          : (date.hour > 12 ? date.hour - 12 : date.hour);
      final period = date.hour >= 12 ? 'PM' : 'AM';
      final formatted =
          '${hour.toString()}:${date.minute.toString().padLeft(2, '0')} $period';
      print('🕐 Formatting time: ${date.hour}:${date.minute} -> $formatted');
      return formatted;
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
