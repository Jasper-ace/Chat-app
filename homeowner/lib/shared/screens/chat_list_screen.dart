import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../services/conversation_state_service.dart';

import '../models/user_model.dart';

import 'chat_screen.dart';
import 'settings/help_support_screen.dart';

class ChatListScreen extends StatefulWidget {
  final String currentUserType;
  final int currentUserId;

  const ChatListScreen({
    super.key,
    required this.currentUserType,
    required this.currentUserId,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final ChatService _chatService = ChatService();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late TabController _tabController;
  bool _showRecentMessages = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Preferences loaded via stream now
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    // Add lifecycle observer for smart refresh
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh the chat list when app resumes
      if (mounted) {
        setState(() {
          // This will trigger a rebuild and refresh the FutureBuilders
        });
      }
    }
  }

  // Stream for real-time user preferences updates
  Stream<Map<String, dynamic>> _getUserPreferencesStream() {
    return ConversationStateService.getUserPreferencesStream();
  }

  // Get unread message count stream for real-time updates
  Stream<int> _getUnreadMessageCountStream(UserModel user) async* {
    if (user.autoId == null) {
      yield 0;
      return;
    }

    // Determine tradie and homeowner IDs
    int tradieId, homeownerId;
    if (widget.currentUserType == 'tradie') {
      tradieId = widget.currentUserId;
      homeownerId = user.autoId!;
    } else {
      tradieId = user.autoId!;
      homeownerId = widget.currentUserId;
    }

    // Listen to thread changes
    await for (final threadQuery
        in FirebaseFirestore.instance
            .collection('threads')
            .where('tradie_id', isEqualTo: tradieId)
            .where('homeowner_id', isEqualTo: homeownerId)
            .limit(1)
            .snapshots()) {
      if (threadQuery.docs.isEmpty) {
        yield 0;
        continue;
      }

      final threadDoc = threadQuery.docs.first;

      // Listen to unread messages count
      await for (final messagesQuery
          in FirebaseFirestore.instance
              .collection('threads')
              .doc(threadDoc.id)
              .collection('messages')
              .where('sender_id', isNotEqualTo: widget.currentUserId)
              .where('read', isEqualTo: false)
              .snapshots()) {
        yield messagesQuery.docs.length;
        break; // Only yield once per thread update
      }
    }
  }

  // Get last message stream for real-time updates
  Stream<Map<String, dynamic>?> _getLastMessageStream(UserModel user) async* {
    if (user.autoId == null) {
      yield null;
      return;
    }

    // Determine tradie and homeowner IDs
    int tradieId, homeownerId;
    if (widget.currentUserType == 'tradie') {
      tradieId = widget.currentUserId;
      homeownerId = user.autoId!;
    } else {
      tradieId = user.autoId!;
      homeownerId = widget.currentUserId;
    }

    // Listen to thread changes
    await for (final threadQuery
        in FirebaseFirestore.instance
            .collection('threads')
            .where('tradie_id', isEqualTo: tradieId)
            .where('homeowner_id', isEqualTo: homeownerId)
            .limit(1)
            .snapshots()) {
      if (threadQuery.docs.isEmpty) {
        yield null;
        continue;
      }

      final threadDoc = threadQuery.docs.first;

      // Listen to messages in this thread
      await for (final messagesQuery
          in FirebaseFirestore.instance
              .collection('threads')
              .doc(threadDoc.id)
              .collection('messages')
              .orderBy('date', descending: true)
              .limit(1)
              .snapshots()) {
        if (messagesQuery.docs.isEmpty) {
          final threadData = threadDoc.data();
          yield {
            'content': threadData['last_message'] ?? '',
            'senderName': '',
            'timestamp': threadData['last_message_time'],
          };
        } else {
          final lastMessage = messagesQuery.docs.first.data();
          yield {
            'content': lastMessage['content'] ?? '',
            'senderName': '',
            'timestamp': lastMessage['date'],
          };
        }
        break; // Only yield once per thread update
      }
    }
  }

  // Format timestamp for display
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // Today - show time
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // This week - show day name
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dateTime.weekday - 1];
    } else {
      // Older - show date
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Messages',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HelpSupportScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Blue header section with search
          Container(
            color: const Color(0xFF4A90E2),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search Messages',
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey[500]),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                ),
              ),
            ),
          ),

          // Tabs section
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              onTap: (index) {
                setState(() {
                  _showRecentMessages = index == 0;
                });
              },
              tabs: const [
                Tab(text: 'Recent message'),
                Tab(text: 'Archived'),
              ],
              labelColor: const Color(0xFF4A90E2),
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: const Color(0xFF4A90E2),
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),

          // Users list with search and filtering
          Expanded(
            child: StreamBuilder<Map<String, dynamic>>(
              stream: _getUserPreferencesStream(),
              builder: (context, prefsSnapshot) {
                // Use stream data directly instead of local variable
                final userPreferences = prefsSnapshot.hasData
                    ? prefsSnapshot.data!
                    : {
                        'pinnedConversations': <String>[],
                        'archivedConversations': <String>[],
                        'blockedUsers': <String>[],
                        'mutedConversations': <String>[],
                        'unreadConversations': <String>[],
                      };

                return StreamBuilder<QuerySnapshot>(
                  stream: _searchQuery.isNotEmpty
                      ? _chatService.searchUsers(
                          widget.currentUserType,
                          _searchQuery,
                        )
                      : _chatService.getAvailableUsers(widget.currentUserType),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
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
                            Text(
                              'Error loading users',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${snapshot.error}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty
                                  ? Icons.search_off
                                  : Icons.people_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No results found for "$_searchQuery"'
                                  : 'No ${widget.currentUserType == 'homeowner' ? 'tradies' : 'homeowners'} available',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Try a different search term'
                                  : 'Check back later for new users',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    List<UserModel> users = snapshot.data!.docs
                        .map((doc) => UserModel.fromFirestore(doc))
                        .toList();

                    print(
                      '🔍 DEBUG: Loaded ${users.length} users from Firestore',
                    );
                    for (int i = 0; i < users.length; i++) {
                      final user = users[i];
                      print(
                        '   User $i: ${user.name} (ID: ${user.id}, autoId: ${user.autoId}, type: ${user.userType})',
                      );
                    }

                    // Filter users based on current tab and search
                    // Note: We'll handle archived filtering in the FutureBuilder for each user tile

                    // Sort users by name for now (pinning will be handled in UI)
                    users.sort((a, b) => a.name.compareTo(b.name));
                    print('   Users sorted by name');

                    if (users.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _showRecentMessages
                                  ? Icons.chat_bubble_outline
                                  : Icons.archive,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _showRecentMessages
                                  ? 'No recent conversations'
                                  : 'No archived conversations',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _showRecentMessages
                                  ? 'Start a conversation with someone'
                                  : 'Archived conversations will appear here',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        try {
                          final user = users[index];

                          // Pass userPreferences to _buildUserTile
                          return _buildUserTile(user, userPreferences);
                        } catch (e) {
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.error,
                                color: Colors.red,
                              ),
                              title: Text('Error loading user at index $index'),
                              subtitle: Text('Error: $e'),
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Build user tile with last message
  Widget _buildUserTile(UserModel user, Map<String, dynamic> userPreferences) {
    final isBlocked = _isUserBlocked(user.id, userPreferences);
    print('   Is blocked: $isBlocked');

    return FutureBuilder<Map<String, bool>>(
      future: _getConversationStates(user),
      builder: (context, statesSnapshot) {
        final states =
            statesSnapshot.data ??
            {
              'isPinned': false,
              'isArchived': false,
              'isMuted': false,
              'isUnread': false,
            };

        final isPinned = states['isPinned'] ?? false;
        final isArchived = states['isArchived'] ?? false;
        final isMuted = states['isMuted'] ?? false;
        final isUnread = states['isUnread'] ?? false;

        // Filter based on current tab
        if (_showRecentMessages && isArchived) {
          return const SizedBox.shrink();
        }
        if (!_showRecentMessages && !isArchived) {
          return const SizedBox.shrink();
        }

        // Filter based on search
        final matchesSearch =
            _searchQuery.isEmpty ||
            user.name.toLowerCase().contains(_searchQuery) ||
            (user.tradeType?.toLowerCase().contains(_searchQuery) ?? false);

        if (!matchesSearch) {
          return const SizedBox.shrink();
        }

        return _buildUserTileContent(
          user,
          isPinned,
          isArchived,
          isMuted,
          isUnread,
          isBlocked,
          userPreferences, // Pass userPreferences here for onLongPress
        );
      },
    );
  }

  Future<Map<String, bool>> _getConversationStates(UserModel user) async {
    try {
      print(
        '🔍 DEBUG: Getting conversation states for user ${user.name} (autoId: ${user.autoId})',
      );
      final results = await Future.wait([
        _isConversationPinned(user),
        _isConversationArchived(user),
        _isConversationMuted(user),
        _isConversationUnread(user),
      ]);

      final states = {
        'isPinned': results[0],
        'isArchived': results[1],
        'isMuted': results[2],
        'isUnread': results[3],
      };

      print('   Conversation states: $states');
      return states;
    } catch (e) {
      print('   ❌ Error getting conversation states: $e');
      return {
        'isPinned': false,
        'isArchived': false,
        'isMuted': false,
        'isUnread': false,
      };
    }
  }

  Widget _buildUserTileContent(
    UserModel user,
    bool isPinned,
    bool isArchived,
    bool isMuted,
    bool isUnread,
    bool isBlocked,
    Map<String, dynamic> userPreferences,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isPinned ? Colors.blue[50] : null,
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: isBlocked
                  ? Colors.red[400]
                  : Theme.of(context).primaryColor,
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Unread count badge
            StreamBuilder<int>(
              stream: _getUnreadMessageCountStream(user),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                if (unreadCount > 0) {
                  return Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        title: Row(
          children: [
            if (isPinned)
              Icon(Icons.push_pin, size: 16, color: Colors.blue[600]),
            if (isPinned) const SizedBox(width: 4),
            Expanded(
              child: Text(
                user.name.isNotEmpty ? user.name : 'Unknown User',
                style: TextStyle(
                  fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                  color: isBlocked ? Colors.grey[600] : null,
                ),
              ),
            ),
            if (isMuted)
              Icon(Icons.volume_off, size: 16, color: Colors.grey[600]),
            if (isArchived)
              Icon(Icons.archive, size: 16, color: Colors.grey[600]),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.userType == 'tradie' && user.tradeType != null)
              Text(
                user.tradeType!,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            StreamBuilder<Map<String, dynamic>?>(
              stream: _getLastMessageStream(user),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Text(
                    'Loading...',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  );
                }

                if (snapshot.hasData && snapshot.data != null) {
                  final lastMessage = snapshot.data!;
                  final content = lastMessage['content'] as String? ?? '';
                  final timestamp = lastMessage['timestamp'];

                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          content.isNotEmpty
                              ? 'Last message: $content'
                              : 'No messages yet',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                            fontWeight: isUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timestamp != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatTimestamp(timestamp),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                          ),
                        ),
                      ],
                      if (isBlocked) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Blocked',
                          style: TextStyle(
                            color: Colors.red[600],
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  );
                }

                // No messages yet - check for unread count
                return StreamBuilder<int>(
                  stream: _getUnreadMessageCountStream(user),
                  builder: (context, unreadSnapshot) {
                    final unreadCount = unreadSnapshot.data ?? 0;

                    return Row(
                      children: [
                        if (unreadCount > 0) ...[
                          Text(
                            'You have ',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            ' unread message${unreadCount > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                        ] else ...[
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                              fontWeight: isUnread
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                        if (isBlocked) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Blocked',
                            style: TextStyle(
                              color: Colors.red[600],
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
        trailing: Icon(
          Icons.chat_bubble_outline,
          color: isBlocked ? Colors.grey[400] : Theme.of(context).primaryColor,
        ),
        onTap: () {
          print('   User ID: ${user.id}');
          print('   User autoId: ${user.autoId}');
          print('   User name: ${user.name}');
          print('   User type: ${user.userType}');
          print('   Is blocked: $isBlocked');
          print('   Current user type: ${widget.currentUserType}');
          print('   Current user ID: ${widget.currentUserId}');

          if (isBlocked) {
            print('   ❌ User is blocked, showing snackbar');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('This user is blocked'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            // Allow navigation to blocked users - they can still view the conversation
            print(
              '   ℹ️ User is blocked, but allowing navigation to conversation',
            );
          }

          // Try to navigate regardless of autoId for debugging
          try {
            print('   ✅ Attempting to navigate to chat screen');

            // Mark as read when opening chat (if autoId is available)
            if (user.autoId != null) {
              print('   📝 Marking conversation as read');
              try {
                final otherUserId =
                    user.autoId!; // Use autoId directly, not parse user.id
                final otherUserType = widget.currentUserType == 'homeowner'
                    ? 'tradie'
                    : 'homeowner';

                ConversationStateService.markAsRead(
                  currentUserId: widget.currentUserId,
                  currentUserType: widget.currentUserType,
                  otherUserId: otherUserId,
                  otherUserType: otherUserType,
                );
                print('   ✅ Conversation marked as read');
              } catch (e) {
                print('   ⚠️ Error marking as read: $e');
              }
            } else {
              print('   ⚠️ autoId is null, skipping mark as read');
            }

            print('   🚀 Navigating to ChatScreen');
            Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      otherUser: user,
                      currentUserType: widget.currentUserType,
                      currentUserId: widget.currentUserId,
                    ),
                  ),
                )
                .then((_) {
                  print('   ↩️ Returned from ChatScreen');
                })
                .catchError((error) {
                  print('   ❌ Navigation error: $error');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Navigation error: $error'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                });
          } catch (e) {
            print('   ❌ Error in onTap: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error opening chat: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        onLongPress: () {
          _showConversationOptions(context, user, userPreferences);
        },
      ),
    );
  }

  // Helper methods to check conversation states using thread IDs
  Future<bool> _isConversationPinned(UserModel user) async {
    try {
      print(
        '🔍 DEBUG: Checking if conversation is pinned for user ${user.name} (autoId: ${user.autoId})',
      );

      if (user.autoId == null) {
        print('   ⚠️ User autoId is null, returning false');
        return false;
      }

      final otherUserId = user.autoId!;
      final otherUserType = widget.currentUserType == 'homeowner'
          ? 'tradie'
          : 'homeowner';

      print('   Using otherUserId: $otherUserId');
      print('   Determined otherUserType: $otherUserType');

      final result = await ConversationStateService.isConversationPinned(
        currentUserId: widget.currentUserId,
        currentUserType: widget.currentUserType,
        otherUserId: otherUserId,
        otherUserType: otherUserType,
      );

      print('   Is pinned result: $result');
      return result;
    } catch (e) {
      print('   ❌ Error checking pinned status: $e');
      return false;
    }
  }

  Future<bool> _isConversationArchived(UserModel user) async {
    try {
      if (user.autoId == null) {
        print('   ⚠️ User autoId is null for archived check, returning false');
        return false;
      }

      final otherUserId = user.autoId!;
      final otherUserType = widget.currentUserType == 'homeowner'
          ? 'tradie'
          : 'homeowner';

      return await ConversationStateService.isConversationArchived(
        currentUserId: widget.currentUserId,
        currentUserType: widget.currentUserType,
        otherUserId: otherUserId,
        otherUserType: otherUserType,
      );
    } catch (e) {
      print('   ❌ Error checking archived status: $e');
      return false;
    }
  }

  Future<bool> _isConversationMuted(UserModel user) async {
    try {
      if (user.autoId == null) {
        print('   ⚠️ User autoId is null for muted check, returning false');
        return false;
      }

      final otherUserId = user.autoId!;
      final otherUserType = widget.currentUserType == 'homeowner'
          ? 'tradie'
          : 'homeowner';

      return await ConversationStateService.isConversationMuted(
        currentUserId: widget.currentUserId,
        currentUserType: widget.currentUserType,
        otherUserId: otherUserId,
        otherUserType: otherUserType,
      );
    } catch (e) {
      print('   ❌ Error checking muted status: $e');
      return false;
    }
  }

  Future<bool> _isConversationUnread(UserModel user) async {
    try {
      if (user.autoId == null) {
        print('   ⚠️ User autoId is null for unread check, returning false');
        return false;
      }

      final otherUserId = user.autoId!;
      final otherUserType = widget.currentUserType == 'homeowner'
          ? 'tradie'
          : 'homeowner';

      return await ConversationStateService.isConversationUnread(
        currentUserId: widget.currentUserId,
        currentUserType: widget.currentUserType,
        otherUserId: otherUserId,
        otherUserType: otherUserType,
      );
    } catch (e) {
      print('   ❌ Error checking unread status: $e');
      return false;
    }
  }

  bool _isUserBlocked(String userId, Map<String, dynamic> preferences) {
    // Note: Assuming userId is the user.id field (String) used in the blockedUsers list
    final blockedList = List<String>.from(preferences['blockedUsers'] ?? []);
    return blockedList.contains(userId);
  }

  // Show conversation options dialog
  void _showConversationOptions(
    BuildContext context,
    UserModel user,
    Map<String, dynamic> userPreferences,
  ) {
    // Use the passed preferences for the initial blocked state
    final isBlocked = _isUserBlocked(user.id, userPreferences);

    // Get conversation states asynchronously
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FutureBuilder<Map<String, bool>>(
        future: _getConversationStates(user),
        builder: (context, statesSnapshot) {
          final states =
              statesSnapshot.data ??
              {
                'isPinned': false,
                'isArchived': false,
                'isMuted': false,
                'isUnread': false,
              };

          final isPinned = states['isPinned'] ?? false;
          final isArchived = states['isArchived'] ?? false;
          final isMuted = states['isMuted'] ?? false;

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name.isNotEmpty ? user.name : 'Unknown User',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (user.userType == 'tradie' &&
                                user.tradeType != null)
                              Text(
                                user.tradeType!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),

                // Options
                _buildOptionTile(
                  icon: isPinned ? Icons.push_pin : Icons.push_pin,
                  title: isPinned ? 'Unpin' : 'Pin',
                  onTap: () async {
                    print('   Current state: isPinned = $isPinned');
                    Navigator.pop(context);
                    try {
                      if (user.autoId == null) {
                        print('   ❌ User autoId is null, cannot pin/unpin');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('User ID not available'),
                            ),
                          );
                        }
                        return;
                      }

                      final otherUserId = user.autoId!;
                      final otherUserType =
                          widget.currentUserType == 'homeowner'
                          ? 'tradie'
                          : 'homeowner';

                      print('   Using otherUserId: $otherUserId');
                      print('   Determined otherUserType: $otherUserType');

                      if (isPinned) {
                        print('   Attempting to unpin conversation');
                        await ConversationStateService.unpinConversation(
                          currentUserId: widget.currentUserId,
                          currentUserType: widget.currentUserType,
                          otherUserId: otherUserId,
                          otherUserType: otherUserType,
                        );
                        if (mounted) {
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.showSnackBar(
                            SnackBar(content: Text('${user.name} unpinned')),
                          );
                        }
                      } else {
                        await ConversationStateService.pinConversation(
                          currentUserId: widget.currentUserId,
                          currentUserType: widget.currentUserType,
                          otherUserId: otherUserId,
                          otherUserType: otherUserType,
                        );
                        if (mounted) {
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.showSnackBar(
                            SnackBar(content: Text('${user.name} pinned')),
                          );
                        }
                      }
                      // Preferences update automatically via stream
                    } catch (e) {
                      if (mounted) {
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                ),

                _buildOptionTile(
                  icon: isArchived ? Icons.unarchive : Icons.archive,
                  title: isArchived ? 'Unarchive' : 'Archive',
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      if (user.autoId == null) {
                        print(
                          '   ❌ User autoId is null, cannot archive/unarchive',
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('User ID not available'),
                            ),
                          );
                        }
                        return;
                      }

                      final otherUserId = user.autoId!;
                      final otherUserType =
                          widget.currentUserType == 'homeowner'
                          ? 'tradie'
                          : 'homeowner';

                      if (isArchived) {
                        await ConversationStateService.unarchiveConversation(
                          currentUserId: widget.currentUserId,
                          currentUserType: widget.currentUserType,
                          otherUserId: otherUserId,
                          otherUserType: otherUserType,
                        );
                        if (mounted) {
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.showSnackBar(
                            SnackBar(content: Text('${user.name} unarchived')),
                          );
                        }
                      } else {
                        await ConversationStateService.archiveConversation(
                          currentUserId: widget.currentUserId,
                          currentUserType: widget.currentUserType,
                          otherUserId: otherUserId,
                          otherUserType: otherUserType,
                        );
                        if (mounted) {
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.showSnackBar(
                            SnackBar(content: Text('${user.name} archived')),
                          );
                        }
                      }
                      // Preferences update automatically via stream
                    } catch (e) {
                      if (mounted) {
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                ),

                _buildOptionTile(
                  icon: isBlocked ? Icons.block : Icons.block,
                  title: isBlocked ? 'Unblock' : 'Block',
                  color: isBlocked ? Colors.green : Colors.red,
                  onTap: () async {
                    Navigator.pop(context);

                    if (!isBlocked) {
                      // Show confirmation dialog for blocking
                      final shouldBlock = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Block User'),
                          content: Text(
                            'Are you sure you want to block ${user.name}? You won\'t receive messages from them.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Block'),
                            ),
                          ],
                        ),
                      );

                      if (shouldBlock != true) return;
                    }

                    try {
                      if (isBlocked) {
                        await ConversationStateService.unblockUser(user.id);
                        if (mounted) {
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.showSnackBar(
                            SnackBar(content: Text('${user.name} unblocked')),
                          );
                        }
                      } else {
                        await ConversationStateService.blockUser(
                          user.id,
                          user.userType,
                        );
                        if (mounted) {
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.showSnackBar(
                            SnackBar(content: Text('${user.name} blocked')),
                          );
                        }
                      }
                      // Preferences update automatically via stream
                    } catch (e) {
                      if (mounted) {
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                ),

                _buildOptionTile(
                  icon: isMuted ? Icons.volume_up : Icons.volume_off,
                  title: isMuted ? 'Unmute' : 'Mute',
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      if (user.autoId == null) {
                        print('   ❌ User autoId is null, cannot mute/unmute');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('User ID not available'),
                            ),
                          );
                        }
                        return;
                      }

                      final otherUserId = user.autoId!;
                      final otherUserType =
                          widget.currentUserType == 'homeowner'
                          ? 'tradie'
                          : 'homeowner';

                      if (isMuted) {
                        await ConversationStateService.unmuteConversation(
                          currentUserId: widget.currentUserId,
                          currentUserType: widget.currentUserType,
                          otherUserId: otherUserId,
                          otherUserType: otherUserType,
                        );
                        if (mounted) {
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.showSnackBar(
                            SnackBar(content: Text('${user.name} unmuted')),
                          );
                        }
                      } else {
                        await ConversationStateService.muteConversation(
                          currentUserId: widget.currentUserId,
                          currentUserType: widget.currentUserType,
                          otherUserId: otherUserId,
                          otherUserType: otherUserType,
                        );
                        if (mounted) {
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.showSnackBar(
                            SnackBar(content: Text('${user.name} muted')),
                          );
                        }
                      }
                      // Preferences update automatically via stream
                    } catch (e) {
                      if (mounted) {
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                ),

                _buildOptionTile(
                  icon: Icons.mark_as_unread,
                  title: 'Mark as unread',
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      if (user.autoId == null) {
                        print(
                          '   ❌ User autoId is null, cannot mark as unread',
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('User ID not available'),
                            ),
                          );
                        }
                        return;
                      }

                      final otherUserId = user.autoId!;
                      final otherUserType =
                          widget.currentUserType == 'homeowner'
                          ? 'tradie'
                          : 'homeowner';

                      await ConversationStateService.markAsUnread(
                        currentUserId: widget.currentUserId,
                        currentUserType: widget.currentUserType,
                        otherUserId: otherUserId,
                        otherUserType: otherUserType,
                      );
                      if (mounted) {
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('${user.name} marked as unread'),
                          ),
                        );
                      }
                      // Preferences update automatically via stream
                    } catch (e) {
                      if (mounted) {
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.grey[700]),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? Colors.grey[800],
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
