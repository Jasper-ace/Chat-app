import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/chat_repository.dart';
import '../../../core/services/dual_storage_integration.dart';

class EnhancedChatWidget extends StatefulWidget {
  final String tradieFirebaseUid;
  final String tradieName;

  const EnhancedChatWidget({
    super.key,
    required this.tradieFirebaseUid,
    required this.tradieName,
  });

  @override
  _EnhancedChatWidgetState createState() => _EnhancedChatWidgetState();
}

class _EnhancedChatWidgetState extends State<EnhancedChatWidget> {
  final DualStorageIntegration _dualStorage = DualStorageIntegration();
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isUserBlocked = false;
  bool _isBlockedByUser = false;
  bool _isOnline = false;
  DateTime? _lastSeen;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when opening chat
    _markMessagesAsRead();
    // Check blocking status
    _checkBlockStatus();
    // Listen for blocking status changes
    _listenToBlockingStatus();
    // Listen for online status
    _listenToOnlineStatus();
    // Set my online status
    _updateMyOnlineStatus(true);
  }

  Future<void> _markMessagesAsRead() async {
    await _dualStorage.markMessagesAsRead(widget.tradieFirebaseUid);
  }

  Future<void> _checkBlockStatus() async {
    try {
      print(
        '🔍 HOMEOWNER: Checking block status for tradie: ${widget.tradieFirebaseUid}',
      );
      final blockStatus = await _chatService.getChatBlockStatus(
        widget.tradieFirebaseUid,
      );
      print('🔍 HOMEOWNER: Block status result: $blockStatus');
      if (mounted) {
        final newIsUserBlocked = blockStatus['userBlocked'] ?? false;
        final newIsBlockedByUser = blockStatus['blockedByUser'] ?? false;

        if (_isUserBlocked != newIsUserBlocked ||
            _isBlockedByUser != newIsBlockedByUser) {
          setState(() {
            _isUserBlocked = newIsUserBlocked;
            _isBlockedByUser = newIsBlockedByUser;
          });
          print(
            '🔄 HOMEOWNER: Blocking status CHANGED - isUserBlocked=$_isUserBlocked, isBlockedByUser=$_isBlockedByUser',
          );

          // Force UI refresh
          if (mounted) {
            setState(() {});
          }
        } else {
          print(
            '🔍 HOMEOWNER: Blocking status unchanged - isUserBlocked=$_isUserBlocked, isBlockedByUser=$_isBlockedByUser',
          );
        }
      }
    } catch (e) {
      print('Error checking block status: $e');
    }
  }

  // Refresh blocking status periodically and on focus
  void _refreshBlockingStatus() {
    _checkBlockStatus();
  }

  void _listenToOnlineStatus() {
    // Listen to tradie's online status
    FirebaseFirestore.instance
        .collection('userStatus')
        .doc(widget.tradieFirebaseUid)
        .snapshots()
        .listen((doc) {
          if (mounted && doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            final isOnline = data['isOnline'] ?? false;
            final lastSeen = data['lastSeen'] as Timestamp?;

            setState(() {
              _isOnline = isOnline;
              _lastSeen = lastSeen?.toDate();
            });
            print(
              '🟢 HOMEOWNER: Online status updated - isOnline=$isOnline, lastSeen=$_lastSeen',
            );
          }
        })
        .onError((error) {
          print('Error listening to online status: $error');
        });
  }

  String _getLastSeenText() {
    if (_lastSeen == null) return 'Offline';

    final now = DateTime.now();
    final difference = now.difference(_lastSeen!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _updateMyOnlineStatus(bool isOnline) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      print('🟢 HOMEOWNER: Updating my online status to: $isOnline');
      FirebaseFirestore.instance
          .collection('userStatus')
          .doc(currentUser.uid)
          .set({
            'isOnline': isOnline,
            'lastSeen': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .then((_) {
            print('✅ HOMEOWNER: Online status updated successfully');
          })
          .catchError((error) {
            print('❌ HOMEOWNER: Error updating online status: $error');
          });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    // Force check blocking status before sending
    await _checkBlockStatus();

    // Check if user is blocked or blocked by user
    if (_isUserBlocked || _isBlockedByUser) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isUserBlocked
                  ? 'You have blocked this user'
                  : 'This user has blocked you',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final message = _messageController.text.trim();
    _messageController.clear();

    try {
      // Send message using dual storage (saves to both Firebase and Laravel)
      final success = await _dualStorage.sendMessageToTradie(
        tradieFirebaseUid: widget.tradieFirebaseUid,
        message: message,
        metadata: {
          'sent_from': 'homeowner_app',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (!success) {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send message')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please log in to chat'));
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chat with ${widget.tradieName}'),
            if (_isUserBlocked || _isBlockedByUser)
              Text(
                'Blocked',
                style: TextStyle(fontSize: 12, color: Colors.red[300]),
              )
            else
              Text(
                _isOnline ? 'Online' : _getLastSeenText(),
                style: TextStyle(
                  fontSize: 12,
                  color: _isOnline ? Colors.green[300] : Colors.grey[300],
                ),
              ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.info), onPressed: _showChatInfo),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showChatOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list using Firebase real-time updates
          Expanded(
            child: StreamBuilder(
              key: ValueKey('messages_${widget.tradieFirebaseUid}'),
              stream: _chatService.getMessages(widget.tradieFirebaseUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text('Error loading messages: ${snapshot.error}'),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Start the conversation!'),
                  );
                }

                // Filter messages based on blocking status
                final allMessages = snapshot.data!.docs;
                List<QueryDocumentSnapshot> messages;

                print(
                  '🔍 HOMEOWNER: Filtering messages - isUserBlocked=$_isUserBlocked, isBlockedByUser=$_isBlockedByUser',
                );
                print(
                  '🔍 HOMEOWNER: Total messages before filter: ${allMessages.length}',
                );

                if (_isUserBlocked || _isBlockedByUser) {
                  // When blocked, only show messages from current user
                  messages = allMessages.where((doc) {
                    final messageData = doc.data() as Map<String, dynamic>;
                    final senderId = messageData['senderId'];
                    final isFromCurrentUser = senderId == currentUser.uid;
                    print(
                      '🔍 HOMEOWNER: Message from $senderId, isFromCurrentUser: $isFromCurrentUser',
                    );
                    return isFromCurrentUser;
                  }).toList();
                  print(
                    '🔍 HOMEOWNER: Messages after blocking filter: ${messages.length}',
                  );
                } else {
                  messages = allMessages;
                  print(
                    '🔍 HOMEOWNER: No blocking, showing all messages: ${messages.length}',
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData =
                        messages[index].data() as Map<String, dynamic>;
                    final isMe = messageData['senderId'] == currentUser.uid;

                    // Debug timestamp for each message
                    print(
                      '🕐 MESSAGE $index: ${messageData['message']} - timestamp: ${messageData['timestamp']} (${messageData['timestamp'].runtimeType})',
                    );

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 14,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  messageData['message'] ?? '',
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTimestamp(messageData['timestamp']),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isMe
                                        ? Colors.white70
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Blocked user warning or message input
          (_isUserBlocked || _isBlockedByUser)
              ? _buildBlockedUserWarning()
              : _buildMessageInput(),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) {
      print('⚠️ TIMESTAMP: Null timestamp received');
      return '';
    }

    try {
      DateTime dateTime;
      print(
        '🕐 TIMESTAMP: Raw timestamp: $timestamp (${timestamp.runtimeType})',
      );

      if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else if (timestamp.runtimeType.toString().contains('Timestamp')) {
        dateTime = timestamp.toDate();
      } else {
        print('⚠️ TIMESTAMP: Unknown timestamp type: ${timestamp.runtimeType}');
        return '';
      }

      print('🕐 TIMESTAMP: Parsed dateTime: $dateTime');

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

      if (messageDate == today) {
        // Today - show time
        final hour = dateTime.hour;
        final minute = dateTime.minute.toString().padLeft(2, '0');
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        final result = '$displayHour:$minute $period';
        print('🕐 TIMESTAMP: Formatted result: $result');
        return result;
      } else {
        // Other days - show date and time
        final hour = dateTime.hour;
        final minute = dateTime.minute.toString().padLeft(2, '0');
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        final result =
            '${dateTime.day}/${dateTime.month} $displayHour:$minute $period';
        print('🕐 TIMESTAMP: Formatted result: $result');
        return result;
      }
    } catch (e) {
      print('❌ TIMESTAMP: Error formatting timestamp: $e');
      return '';
    }
  }

  void _showChatInfo() async {
    // Get chat statistics from Laravel
    final stats = await _dualStorage.getChatStatistics();

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Chat Information'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chatting with: ${widget.tradieName}'),
              const SizedBox(height: 8),
              if (stats != null) ...[
                Text('Total chats: ${stats['total_chats'] ?? 0}'),
                Text('Messages sent: ${stats['total_messages_sent'] ?? 0}'),
                Text(
                  'Messages received: ${stats['total_messages_received'] ?? 0}',
                ),
                Text('Unread messages: ${stats['unread_messages'] ?? 0}'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
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
                  _isUserBlocked
                      ? 'You have blocked this user'
                      : 'This user has blocked you',
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
          if (_isUserBlocked) ...[
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _toggleBlockUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text('Unblock'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              maxLines: null,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send),
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
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
            ListTile(
              leading: const Icon(Icons.report, color: Colors.red),
              title: const Text(
                'Report User',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _toggleBlockUser() async {
    try {
      if (_isUserBlocked) {
        // Unblock user
        await _chatService.unblockUser(widget.tradieFirebaseUid);
        if (mounted) {
          setState(() {
            _isUserBlocked = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.tradieName} has been unblocked'),
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
              'Are you sure you want to block ${widget.tradieName}? You won\'t be able to send or receive messages from them.',
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
          await _chatService.blockUser(widget.tradieFirebaseUid);
          if (mounted) {
            setState(() {
              _isUserBlocked = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${widget.tradieName} has been blocked'),
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

  void _showReportDialog() {
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
              Text('Report ${widget.tradieName}'),
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
              onPressed: () async {
                try {
                  await _chatService.reportUser(
                    reportedUserId: widget.tradieFirebaseUid,
                    reason: selectedReason,
                    description: detailsController.text.trim(),
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Report submitted. Thank you for helping keep our community safe.',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to submit report: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _listenToBlockingStatus() {
    // Listen to tradie's userProfiles/userPreferences to detect when they block us
    FirebaseFirestore.instance
        .collection('userProfiles')
        .doc(widget.tradieFirebaseUid)
        .snapshots()
        .listen((doc) {
          if (mounted && doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            final blockedUsers = List<String>.from(data['blockedUsers'] ?? []);
            final currentUser = FirebaseAuth.instance.currentUser;

            if (currentUser != null) {
              final isBlockedByUser = blockedUsers.contains(currentUser.uid);

              if (_isBlockedByUser != isBlockedByUser) {
                setState(() {
                  _isBlockedByUser = isBlockedByUser;
                });

                print(
                  '🔄 HOMEOWNER: Blocking status changed - isBlockedByUser=$isBlockedByUser',
                );
              }
            }
          }
        })
        .onError((error) {
          print('Error listening to tradie blocking: $error');
        });

    // Also listen to userPreferences (tradie might use ConversationStateService)
    FirebaseFirestore.instance
        .collection('userPreferences')
        .doc(widget.tradieFirebaseUid)
        .snapshots()
        .listen((doc) {
          if (mounted && doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            final blockedUsers = List<String>.from(data['blockedUsers'] ?? []);
            final currentUser = FirebaseAuth.instance.currentUser;

            if (currentUser != null) {
              final isBlockedByUser = blockedUsers.contains(currentUser.uid);

              if (_isBlockedByUser != isBlockedByUser) {
                setState(() {
                  _isBlockedByUser = isBlockedByUser;
                });

                print(
                  '🔄 HOMEOWNER: Blocking status changed (prefs) - isBlockedByUser=$isBlockedByUser',
                );
              }
            }
          }
        })
        .onError((error) {
          print('Error listening to tradie blocking (prefs): $error');
        });

    // Also listen to blocked_users collection (tradie ConversationStateService)
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      FirebaseFirestore.instance
          .collection('blocked_users')
          .doc('${widget.tradieFirebaseUid}_${currentUser.uid}')
          .snapshots()
          .listen((doc) {
            if (mounted) {
              final isBlockedByUser =
                  doc.exists && (doc.data()?['is_active'] ?? false);

              if (_isBlockedByUser != isBlockedByUser) {
                setState(() {
                  _isBlockedByUser = isBlockedByUser;
                });

                print(
                  '🔄 HOMEOWNER: Blocking status changed (blocked_users) - isBlockedByUser=$isBlockedByUser',
                );
              }
            }
          })
          .onError((error) {
            print('Error listening to tradie blocking (blocked_users): $error');
          });
    }

    // Removed aggressive timers to prevent continuous refreshing
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _refreshBlockingStatus();
      } else {
        timer.cancel();
      }
    });

    // Also listen to messages stream to detect blocking changes
    _chatService.getMessages(widget.tradieFirebaseUid).listen((snapshot) {
      if (mounted) {
        // Check if we should be able to see these messages
        _refreshBlockingStatus();
      }
    });
  }

  @override
  void dispose() {
    _updateMyOnlineStatus(false);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
