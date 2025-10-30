import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../services/unified_thread_service.dart';
import '../services/current_user_service.dart';
import '../services/message_status_service.dart';
import '../services/thread_message_service.dart';
import '../services/conversation_state_service.dart';

import '../models/user_model.dart';
import '../models/message_model.dart';

class ChatScreen extends StatefulWidget {
  final UserModel otherUser;
  final String currentUserType; // Should be 'tradie' for this screen
  final int currentUserId;

  const ChatScreen({
    super.key,
    required this.otherUser,
    required this.currentUserType,
    required this.currentUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final UnifiedThreadService _threadService = UnifiedThreadService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int? _actualCurrentUserId;
  MessageModel? _replyToMessage;
  bool _isUserBlocked = false;

  @override
  void initState() {
    super.initState();
    _initializeCurrentUserId();
    _checkBlockStatus();
    _listenToBlockingStatus();
    _markConversationAsRead();
  }

  // --- Utility & Thread ID Logic (New/Modified for unified thread) ---

  Future<void> _initializeCurrentUserId() async {
    try {
      final autoId = await CurrentUserService.getCurrentUserAutoId();
      if (mounted) {
        setState(() {
          _actualCurrentUserId = autoId;
        });
      }
    } catch (e) {
      print('Error getting current user ID: $e');
    }
  }

  int get currentUserIdAsInt {
    return _actualCurrentUserId ?? widget.currentUserId;
  }

  // --- Message Sending & Receiving ---

  Stream<QuerySnapshot> _getMessagesStream() {
    if (widget.otherUser.autoId != null && currentUserIdAsInt != 0) {
      print('🔍 TRADIE: Getting messages stream');
      print('   Current User ID: $currentUserIdAsInt');
      print('   Other User ID: ${widget.otherUser.autoId}');
      print('   Current User Type: ${widget.currentUserType}');
      print('   Other User Type: ${widget.otherUser.userType}');

      // Let the UnifiedThreadService find/create the correct thread
      // DO NOT pass a custom threadId - let it use its own logic
      return _threadService
          .getMessages(
            currentUserId: currentUserIdAsInt,
            currentUserType: widget.currentUserType,
            otherUserId: widget.otherUser.autoId!,
            otherUserType: widget.otherUser.userType,
            // Remove threadId parameter - let service handle it
          )
          .handleError((error) {
            print('Error in messages stream: $error');
          });
    } else {
      return _chatService.getMessages(widget.otherUser.id).handleError((error) {
        print('Error in messages stream (Legacy): $error');
      });
    }
  }

  void _markConversationAsRead() {
    try {
      ConversationStateService.markAsRead(widget.otherUser.id);
    } catch (e) {
      print('Error marking conversation as read: $e');
    }
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    if (_isUserBlocked) return;

    final messageToSend = message;

    _messageController.clear();
    _clearReply();

    try {
      if (widget.otherUser.autoId != null && currentUserIdAsInt != 0) {
        print('📤 TRADIE: Sending message via unified thread service');
        print('   Current User ID: $currentUserIdAsInt');
        print('   Other User ID: ${widget.otherUser.autoId}');
        print('   Message: "$messageToSend"');

        // Let the UnifiedThreadService handle thread creation/finding
        // DO NOT pass a custom threadId - let it use its own logic
        await _threadService.sendMessage(
          senderId: currentUserIdAsInt,
          senderType: widget.currentUserType,
          receiverId: widget.otherUser.autoId!,
          receiverType: widget.otherUser.userType,
          content: messageToSend,
          // Remove threadId parameter - let service handle it
        );

        print('✅ TRADIE: Message sent successfully');
      } else {
        // Fallback for old system or missing autoId
        print('📤 TRADIE: Using fallback chat service (missing autoId)');
        await _chatService.sendMessage(
          receiverId: widget.otherUser.id,
          message: messageToSend,
          senderUserType: widget.currentUserType,
          receiverUserType: widget.otherUser.userType,
        );
        print('✅ TRADIE: Fallback message sent');
      }

      print('✅ Message sent successfully');
      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('❌ Error sending message: $e');

      // If sending failed, restore the message to input
      if (mounted) {
        _messageController.text = messageToSend;
        // Reply context already cleared
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  // --- Blocking Logic ---

  Future<void> _checkBlockStatus() async {
    try {
      final isBlocked = await ConversationStateService.isUserBlocked(
        widget.otherUser.id,
      );
      if (mounted) {
        setState(() {
          _isUserBlocked = isBlocked;
        });
      }
    } catch (e) {
      print('❌ Error checking block status: $e');
    }
  }

  void _listenToBlockingStatus() {
    // Listen to real-time blocking status changes
    ConversationStateService.getUserPreferencesStream()
        .listen((preferences) {
          if (mounted) {
            final blockedUsers = List<String>.from(
              preferences['blockedUsers'] ?? [],
            );
            final isBlocked = blockedUsers.contains(widget.otherUser.id);

            if (_isUserBlocked != isBlocked) {
              setState(() {
                _isUserBlocked = isBlocked;
              });

              // Show feedback when blocking status changes
              if (isBlocked) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${widget.otherUser.name} has been blocked'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${widget.otherUser.name} has been unblocked',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            }
          }
        })
        .onError((error) {
          print('Error listening to blocking status: $error');
        });
  }

  void _toggleBlockUser() async {
    try {
      if (_isUserBlocked) {
        // Unblock user
        await ConversationStateService.unblockUser(widget.otherUser.id);
        if (mounted) {
          setState(() {
            _isUserBlocked = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.otherUser.name} has been unblocked'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Block user - show confirmation
        final shouldBlock = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Block User'),
            content: Text(
              'Are you sure you want to block ${widget.otherUser.name}? You won\'t be able to send or receive messages from them.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Block'),
              ),
            ],
          ),
        );

        if (shouldBlock == true) {
          await ConversationStateService.blockUser(
            widget.otherUser.id,
            widget.otherUser.userType,
          );
          if (mounted) {
            setState(() {
              _isUserBlocked = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${widget.otherUser.name} has been blocked'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // --- UI Build Methods ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[300],
                backgroundImage: widget.otherUser.name.isNotEmpty
                    ? null
                    : const AssetImage('assets/default_avatar.png'),
                child: widget.otherUser.name.isNotEmpty
                    ? Text(
                        widget.otherUser.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUser.name.isNotEmpty
                        ? widget.otherUser.name
                        : 'Unknown User',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _isUserBlocked ? 'Blocked' : 'Offline',
                    style: TextStyle(
                      fontSize: 14,
                      color: _isUserBlocked
                          ? Colors.red[300]
                          : Colors.white.withOpacity(0.8),
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
            onPressed: () {
              _showChatOptions();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              key: ValueKey(
                'messages_${widget.otherUser.id}_${widget.otherUser.autoId}',
              ),
              stream: _getMessagesStream(),
              builder: (context, snapshot) {
                // ... (Debug info omitted for brevity) ...

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading messages...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text('Error loading messages'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Text(
                            '${snapshot.error}',
                            style: const TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {}); // Refresh
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                final allMessages = snapshot.data!.docs
                    .map((doc) => MessageModel.fromFirestore(doc))
                    .toList();

                // Filter out messages deleted by current user
                final messages = allMessages.where((message) {
                  final messageDoc = snapshot.data!.docs.firstWhere(
                    (doc) => doc.id == message.id,
                  );
                  final messageData = messageDoc.data() as Map<String, dynamic>;

                  // Check if message is deleted for current user
                  final deletedFor =
                      messageData['deletedFor'] as List<dynamic>?;

                  if (deletedFor != null &&
                      deletedFor.contains(currentUserIdAsInt.toString())) {
                    return false; // Hide message deleted by current user
                  }

                  return true; // Show message
                }).toList()..sort((a, b) => b.date.compareTo(a.date));

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe =
                        message.senderId == currentUserIdAsInt ||
                        message.senderType == widget.currentUserType;

                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),

          // Reply preview (only show if not blocked)
          if (!_isUserBlocked && _replyToMessage != null) _buildReplyPreview(),

          // Blocked user warning or message input
          _isUserBlocked ? _buildBlockedUserWarning() : _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe) {
    // Check if this is a reply message
    final isReply = message.replyTo != null;
    final replyInfo = message.replyTo;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isMe) const Spacer(flex: 1),
              Flexible(
                flex: 3,
                child: GestureDetector(
                  onLongPress: () => _showMessageOptions(message, isMe),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? const Color(0xFF2C2C2C)
                          : const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: isMe
                            ? const Radius.circular(20)
                            : const Radius.circular(4),
                        bottomRight: isMe
                            ? const Radius.circular(4)
                            : const Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Reply preview if this is a reply
                        if (isReply && replyInfo != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border(
                                left: BorderSide(
                                  color: isMe
                                      ? Colors.white
                                      : const Color(0xFF4A90E2),
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  // Displaying the sender type of the replied message
                                  'Replying to ${replyInfo['sender_type']}',
                                  style: TextStyle(
                                    color: isMe
                                        ? Colors.white.withOpacity(0.7)
                                        : Colors.grey[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  replyInfo['content'] ?? '',
                                  style: TextStyle(
                                    color: isMe
                                        ? Colors.white.withOpacity(0.8)
                                        : Colors.grey[700],
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        // Main message content
                        Text(
                          message.content,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isMe) const Spacer(flex: 1),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.only(left: isMe ? 0 : 8, right: isMe ? 8 : 0),
            child: Row(
              mainAxisAlignment: isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatMessageTime(message.date),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  MessageStatusService.getStatusIcon(MessageStatus.read),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      // Today - show time
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    } else {
      // Other days - show date and time
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '${dateTime.day}/${dateTime.month} $displayHour:$minute $period';
    }
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(context);
                _showUserProfile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.volume_off),
              title: const Text('Mute Notifications'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement mute functionality
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive),
              title: const Text('Archive Chat'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement archive functionality
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Chat',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteChatDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.red),
              title: const Text(
                'Report User',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _showReportUserDialog();
              },
            ),
            ListTile(
              leading: Icon(
                _isUserBlocked ? Icons.block : Icons.block,
                color: Colors.red,
              ),
              title: Text(
                _isUserBlocked ? 'Unblock User' : 'Block User',
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleBlockUser();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(MessageModel message, bool isMe) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMe) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.push_pin),
                title: const Text('Pin'),
                onTap: () {
                  Navigator.pop(context);
                  _pinMessage(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete for me',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessageForMe(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.undo, color: Colors.red),
                title: const Text(
                  'Unsend',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _unsendMessage(message);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.push_pin),
                title: const Text('Pin'),
                onTap: () {
                  Navigator.pop(context);
                  _pinMessage(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete for me',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessageForMe(message);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                _copyMessage(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                _startReplyToMessage(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editMessage(MessageModel message) {
    final TextEditingController editController = TextEditingController(
      text: message.content,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            hintText: 'Edit your message...',
            border: OutlineInputBorder(),
          ),
          maxLines: null,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newContent = editController.text.trim();
              if (newContent.isNotEmpty && newContent != message.content) {
                try {
                  await ThreadMessageService.editMessage(
                    message.id,
                    newContent,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message edited')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to edit message: $e')),
                    );
                  }
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _pinMessage(MessageModel message) {
    // TODO: Implement pin message functionality
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Message pinned')));
  }

  void _deleteMessageForMe(MessageModel message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('This message will be deleted for you only.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ThreadMessageService.deleteMessageForMe(
                  message.id,
                  currentUserIdAsInt.toString(),
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete message: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _unsendMessage(MessageModel message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsend Message'),
        content: const Text(
          'This message will be removed for everyone in the chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ThreadMessageService.unsendMessage(message.id);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message unsent')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to unsend message: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Unsend'),
          ),
        ],
      ),
    );
  }

  void _copyMessage(MessageModel message) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied to clipboard')),
    );
  }

  void _startReplyToMessage(MessageModel message) {
    setState(() {
      _replyToMessage = message;
    });
    // Focus on the text field
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _clearReply() {
    setState(() {
      _replyToMessage = null;
    });
  }

  Widget _buildReplyPreview() {
    if (_replyToMessage == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(
          left: BorderSide(color: const Color(0xFF4A90E2), width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, color: const Color(0xFF4A90E2), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_replyToMessage!.senderType}',
                  style: TextStyle(
                    color: const Color(0xFF4A90E2),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyToMessage!.content,
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _clearReply,
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  void _showUserProfile() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Profile Picture and Basic Info
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: widget.otherUser.name.isNotEmpty
                            ? null
                            : const AssetImage('assets/default_avatar.png'),
                        child: widget.otherUser.name.isNotEmpty
                            ? Text(
                                widget.otherUser.name[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Name
                      Text(
                        widget.otherUser.name.isNotEmpty
                            ? widget.otherUser.name
                            : 'Unknown User',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // User Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: widget.otherUser.userType == 'tradie'
                              ? const Color(0xFF4A90E2)
                              : Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.otherUser.userType.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.orange,
                            size: 24,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '4.7',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(18 reviews)',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // About Section
                      _buildProfileSection(
                        'About',
                        widget.otherUser.userType == 'tradie'
                            ? 'Experienced professional specializing in ${widget.otherUser.tradeType ?? 'home renovation'}. Committed to delivering high-quality work with attention to detail and punctuality.'
                            : 'Looking for experienced professionals for home renovation projects. Appreciate punctuality, attention to detail, and quality workmanship.',
                      ),
                      const SizedBox(height: 24),

                      // Contact Information Section
                      _buildProfileSection(
                        'Contact Information',
                        null,
                        children: [
                          _buildContactInfo(Icons.location_on, 'Brisbane, QLD'),
                          _buildContactInfo(Icons.phone, '+61 434 789 012'),
                          _buildContactInfo(
                            Icons.email,
                            '${widget.otherUser.name.toLowerCase().replaceAll(' ', '.')}@email.com',
                          ),
                          _buildContactInfo(
                            Icons.calendar_today,
                            'Joined June 2023',
                          ),
                        ],
                      ),

                      // Job History Section (for tradies)
                      if (widget.otherUser.userType == 'tradie') ...[
                        const SizedBox(height: 24),
                        _buildProfileSection(
                          'Job History',
                          null,
                          children: [
                            _buildJobHistoryItem(
                              'Bathroom Renovation',
                              'pending',
                              'This week',
                              '\$6,200',
                              Icons.bathtub,
                            ),
                            const SizedBox(height: 12),
                            _buildJobHistoryItem(
                              'Kitchen Splashback Installation',
                              'completed',
                              'Last month',
                              '\$800',
                              Icons.kitchen,
                            ),
                            const SizedBox(height: 12),
                            _buildJobHistoryItem(
                              'Deck Construction',
                              'completed',
                              '2 months ago',
                              '\$3,500',
                              Icons.deck,
                            ),
                          ],
                        ),
                      ],

                      // Recent Projects Section (for homeowners)
                      if (widget.otherUser.userType == 'homeowner') ...[
                        const SizedBox(height: 24),
                        _buildProfileSection(
                          'Recent Projects',
                          null,
                          children: [
                            _buildProjectItem(
                              'Bathroom Renovation',
                              'In Progress',
                              'Started this week',
                              Icons.bathtub,
                            ),
                            const SizedBox(height: 12),
                            _buildProjectItem(
                              'Garden Landscaping',
                              'Completed',
                              'Last month',
                              Icons.grass,
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 30),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                // TODO: Implement call functionality
                              },
                              icon: const Icon(Icons.phone, size: 18),
                              label: const Text('Call'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                // TODO: Implement email functionality
                              },
                              icon: const Icon(Icons.email, size: 18),
                              label: const Text('Email'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4A90E2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(
    String title,
    String? description, {
    List<Widget>? children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        if (description != null) ...[
          Text(
            description,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
        if (children != null) ...children,
      ],
    );
  }

  Widget _buildContactInfo(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.grey[600]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobHistoryItem(
    String title,
    String status,
    String timeframe,
    String amount,
    IconData icon,
  ) {
    Color statusColor = status == 'completed' ? Colors.green : Colors.orange;
    String statusText = status == 'completed' ? 'Completed' : 'Pending';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF4A90E2), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeframe,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectItem(
    String title,
    String status,
    String timeframe,
    IconData icon,
  ) {
    Color statusColor = status == 'Completed' ? Colors.green : Colors.blue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeframe,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat?'),
        content: const Text(
          'This will permanently delete this conversation. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to chat list
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Chat deleted')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showReportUserDialog() {
    String selectedReason = 'Inappropriate behavior';
    final TextEditingController detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.report, color: Colors.orange),
              const SizedBox(width: 8),
              Text('Report ${widget.otherUser.name}'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Help us understand what\'s wrong.\nWe\'ll review this report and take\nappropriate action.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Reason for reporting',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...[
                  'Inappropriate behavior',
                  'Spam or scam',
                  'Harassment',
                  'Fake profile',
                  'Other',
                ].map(
                  (reason) => RadioListTile<String>(
                    title: Text(reason),
                    value: reason,
                    groupValue: selectedReason,
                    onChanged: (value) =>
                        setState(() => selectedReason = value!),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Additional details (optional)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsController,
                  decoration: const InputDecoration(
                    hintText: 'Provide more information about this report',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Report submitted. Thank you for helping keep our community safe.',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedUserWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border(top: BorderSide(color: Colors.red[200]!, width: 1)),
      ),
      child: Row(
        children: [
          Icon(Icons.block, color: Colors.red[600], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'You have blocked this user',
                  style: TextStyle(
                    color: Colors.red[800],
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You cannot send or receive messages.',
                  style: TextStyle(color: Colors.red[700], fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _toggleBlockUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.attach_file, color: Colors.grey[600]),
            onPressed: () {
              // TODO: Implement file attachment
            },
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: _replyToMessage != null
                      ? 'Reply to ${_replyToMessage!.senderType}...'
                      : 'Type your message...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          IconButton(
            icon: const Text('😊', style: TextStyle(fontSize: 20)),
            onPressed: () {
              // TODO: Implement emoji picker
            },
          ),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF4A90E2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
