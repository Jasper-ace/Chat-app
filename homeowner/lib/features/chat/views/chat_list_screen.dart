import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/services/homeowner_api_auth_service.dart';
import '../services/chat_api_service.dart';
import '../repositories/chat_repository_realtime.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen>
    with SingleTickerProviderStateMixin {
  final _authService = HomeownerApiAuthService();
  final _chatService = ChatApiService();
  final _chatRepository = ChatRepository();
  final _searchController = TextEditingController();
  late TabController _tabController;

  List<Map<String, dynamic>> _allChats = [];
  List<Map<String, dynamic>> _filteredChats = [];
  List<Map<String, dynamic>> _allUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int? _currentUserId;
  final Map<String, bool> _typingStatus = {}; // threadId -> isTyping

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  void _listenToTypingStatus(String threadId, int tradieId) {
    final typingRef = FirebaseDatabase.instance.ref(
      'threads/$threadId/typing/${tradieId}_tradie',
    );

    typingRef.onValue.listen((event) {
      if (mounted && event.snapshot.exists) {
        final isTyping = event.snapshot.value as bool? ?? false;
        setState(() {
          _typingStatus[threadId] = isTyping;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final userId = await _authService.getUserId();
      if (userId != null) {
        _currentUserId = userId;

        // Load users
        final users = await _chatService.getAllTradies();

        setState(() {
          _allUsers = users;
        });

        // Listen to threads from Firebase
        _chatRepository.getThreads(userId: userId, userType: 'homeowner').listen(
          (threads) {
            print('📋 Received ${threads.length} threads from Firebase');

            // Convert threads to chat format and match with user names
            final chats = threads
                .where((thread) {
                  // Filter out threads with invalid tradie_id
                  final tradieId = thread['tradie_id'];
                  return tradieId != null && tradieId != 0;
                })
                .map((thread) {
                  final tradieId = thread['tradie_id'];
                  final tradie = _allUsers.firstWhere(
                    (u) => u['id'] == tradieId,
                    orElse: () => {},
                  );

                  // Construct full name from first_name, middle_name, last_name
                  String fullName = 'Tradie #$tradieId';
                  if (tradie.isNotEmpty) {
                    final firstName = tradie['first_name'] ?? '';
                    final middleName = tradie['middle_name'] ?? '';
                    final lastName = tradie['last_name'] ?? '';
                    fullName = [
                      firstName,
                      middleName,
                      lastName,
                    ].where((s) => s.isNotEmpty).join(' ').trim();
                    if (fullName.isEmpty) fullName = 'Tradie #$tradieId';
                  }

                  return {
                    'id': thread['id'],
                    'name': fullName,
                    'email': tradie['email'] ?? '',
                    'business_name': tradie['business_name'] ?? '',
                    'lastMessage': thread['last_message'] ?? '',
                    'time': thread['last_message_time'],
                    'unreadCount': 0,
                    'is_pinned': false,
                    'is_archived': false,
                    'is_muted': false,
                    'is_favorite': false,
                    'tradie_id': tradieId,
                  };
                })
                .toList();

            setState(() {
              _allChats = chats;
              _filterChats();
              _isLoading = false;
            });

            // Listen to typing status for each chat
            for (final chat in chats) {
              _listenToTypingStatus(chat['id'], chat['tradie_id']);
            }
          },
        );
      } else {
        setState(() {
          _allChats = [];
          _allUsers = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _allChats = [];
        _allUsers = [];
        _isLoading = false;
      });
    }
  }

  void _filterChats() {
    if (_searchQuery.isEmpty) {
      _filteredChats = _allChats;
    } else {
      _filteredChats = _allChats.where((chat) {
        final name = (chat['name'] ?? '').toLowerCase();
        final lastMessage = (chat['lastMessage'] ?? '').toLowerCase();
        final email = (chat['email'] ?? '').toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) ||
            lastMessage.contains(query) ||
            email.contains(query);
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentChats = _filteredChats
        .where((c) => !(c['is_archived'] ?? false))
        .toList();
    final archivedChats = _filteredChats
        .where((c) => c['is_archived'] ?? false)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          'Messages',
          style: AppTextStyles.appBarTitle.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            // Search bar
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.all(AppDimensions.paddingMedium),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _filterChats();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by name, email, or message',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _filterChats();
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingMedium,
                    vertical: AppDimensions.paddingSmall,
                  ),
                ),
              ),
            ),
            // Tabs
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.onSurfaceVariant,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(
                    text:
                        'Recent (${recentChats.length + (_allChats.isEmpty ? _allUsers.length : 0)})',
                  ),
                  Tab(text: 'Archived (${archivedChats.length})'),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Container(
                color: Colors.white,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildRecentTab(recentChats),
                          _buildArchivedTab(archivedChats),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/chat/new'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildRecentTab(List<Map<String, dynamic>> chats) {
    print(
      '📋 Building recent tab with ${chats.length} chats and ${_allUsers.length} users',
    );

    if (chats.isEmpty && _allUsers.isEmpty) {
      return _buildEmptyState();
    }

    if (chats.isEmpty) {
      print('📋 Showing user list (no chats yet)');
      return _buildUserList();
    }

    print('📋 Showing ${chats.length} chats');
    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) => _buildChatItem(chats[index]),
    );
  }

  Widget _buildArchivedTab(List<Map<String, dynamic>> chats) {
    if (chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.archive_outlined,
              size: 80,
              color: AppColors.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No archived chats',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) => _buildChatItem(chats[index]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 100,
            color: AppColors.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No tradies available',
            style: AppTextStyles.headlineSmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return ListView.builder(
      itemCount: _allUsers.length,
      itemBuilder: (context, index) => _buildUserItem(_allUsers[index]),
    );
  }

  Widget _buildUserItem(Map<String, dynamic> user) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMedium,
        vertical: AppDimensions.paddingSmall,
      ),
      leading: _buildAvatar(user['name'] ?? 'T', isOnline: true),
      title: Text(user['name'] ?? 'Unknown', style: AppTextStyles.titleMedium),
      subtitle: Text(
        user['business_name'] ?? 'Tradie',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _handleUserTap(user),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    final hasUnread = chat['unreadCount'] != null && chat['unreadCount'] > 0;
    final isPinned = chat['is_pinned'] ?? false;

    return Dismissible(
      key: Key(chat['id'].toString()),
      background: _buildSwipeBackground(Colors.blue, Icons.push_pin, 'Pin'),
      secondaryBackground: _buildSwipeBackground(
        Colors.orange,
        Icons.archive,
        'Archive',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _togglePin(chat);
        } else {
          await _toggleArchive(chat);
        }
        return false;
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMedium,
          vertical: AppDimensions.paddingSmall,
        ),
        leading: _buildAvatar(chat['name'] ?? 'T', isOnline: true),
        title: Row(
          children: [
            if (isPinned)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.push_pin, size: 14, color: Colors.grey),
              ),
            Expanded(
              child: Text(
                chat['name'] ?? 'Unknown',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (hasUnread)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: _typingStatus[chat['id']] == true
            ? Row(
                children: [
                  Text(
                    'Typing',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 20,
                    height: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildTypingDot(0),
                        _buildTypingDot(1),
                        _buildTypingDot(2),
                      ],
                    ),
                  ),
                ],
              )
            : Text(
                chat['lastMessage'] ?? 'No messages yet',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTime(chat['time']),
              style: AppTextStyles.bodySmall.copyWith(
                color: hasUnread
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            if (hasUnread) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${chat['unreadCount']}',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ],
          ],
        ),
        onTap: () {
          print('🔵 Tapped on chat: ${chat['id']}');
          context.go(
            '/chat/${chat['id']}',
            extra: {
              'otherUserName': chat['name'] ?? 'User',
              'otherUserId': (chat['tradie_id'] ?? 0).toString(),
              'otherUserType': 'tradie',
            },
          );
        },
        onLongPress: () {
          print('🟢 Long pressed on chat: ${chat['id']}');
          _showChatOptions(chat);
        },
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        final delay = index * 0.2;
        final animValue = ((value + delay) % 1.0);
        final opacity = animValue < 0.5 ? (animValue * 2) : (2 - animValue * 2);

        return Opacity(
          opacity: opacity.clamp(0.3, 1.0),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {
        // Restart animation
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildAvatar(String name, {bool isOnline = false}) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.primary,
          child: Text(
            name.substring(0, 1).toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSwipeBackground(Color color, IconData icon, String label) {
    return Container(
      color: color,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showChatOptions(Map<String, dynamic> chat) {
    final isPinned = chat['is_pinned'] ?? false;
    final isArchived = chat['is_archived'] ?? false;
    final isMuted = chat['is_muted'] ?? false;
    final isFavorite = chat['is_favorite'] ?? false;
    final hasUnread = chat['unreadCount'] != null && chat['unreadCount'] > 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Text(
                        (chat['name'] ?? 'U').substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chat['name'] ?? 'Unknown',
                            style: AppTextStyles.titleMedium,
                          ),
                          Text(
                            'Chat options',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                ),
                title: Text(isPinned ? 'Unpin conversation' : 'Pin to top'),
                onTap: () {
                  Navigator.pop(context);
                  _togglePin(chat);
                },
              ),
              ListTile(
                leading: Icon(isFavorite ? Icons.star : Icons.star_outline),
                title: Text(
                  isFavorite ? 'Remove from favorites' : 'Add to favorites',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleFavorite(chat);
                },
              ),
              ListTile(
                leading: Icon(
                  hasUnread ? Icons.mark_chat_read : Icons.mark_chat_unread,
                ),
                title: Text(hasUnread ? 'Mark as read' : 'Mark as unread'),
                onTap: () {
                  Navigator.pop(context);
                  hasUnread ? _markAsRead(chat) : _markAsUnread(chat);
                },
              ),
              ListTile(
                leading: Icon(
                  isMuted
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                ),
                title: Text(
                  isMuted ? 'Unmute notifications' : 'Mute notifications',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleMute(chat);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('View details'),
                onTap: () {
                  Navigator.pop(context);
                  _viewDetails(chat);
                },
              ),
              ListTile(
                leading: Icon(
                  isArchived ? Icons.unarchive : Icons.archive_outlined,
                ),
                title: Text(
                  isArchived
                      ? 'Unarchive conversation'
                      : 'Archive conversation',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleArchive(chat);
                },
              ),
              ListTile(
                leading: const Icon(Icons.clear_all),
                title: const Text('Clear chat'),
                subtitle: const Text(
                  'Remove all messages',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _clearChat(chat);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.orange),
                title: const Text(
                  'Block user',
                  style: TextStyle(color: Colors.orange),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _blockUser(chat);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete conversation',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteChat(chat);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _togglePin(Map<String, dynamic> chat) async {
    setState(() {
      chat['is_pinned'] = !(chat['is_pinned'] ?? false);
      _allChats.sort((a, b) {
        final aPinned = a['is_pinned'] ?? false;
        final bPinned = b['is_pinned'] ?? false;
        if (aPinned && !bPinned) return -1;
        if (!aPinned && bPinned) return 1;
        return 0;
      });
      _filterChats();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(chat['is_pinned'] ? 'Chat pinned' : 'Chat unpinned'),
      ),
    );
  }

  Future<void> _toggleFavorite(Map<String, dynamic> chat) async {
    setState(() {
      chat['is_favorite'] = !(chat['is_favorite'] ?? false);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          chat['is_favorite'] ? 'Added to favorites' : 'Removed from favorites',
        ),
      ),
    );
  }

  Future<void> _markAsRead(Map<String, dynamic> chat) async {
    setState(() {
      chat['unreadCount'] = 0;
    });
  }

  Future<void> _markAsUnread(Map<String, dynamic> chat) async {
    setState(() {
      chat['unreadCount'] = 1;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Marked as unread')));
  }

  Future<void> _toggleMute(Map<String, dynamic> chat) async {
    setState(() {
      chat['is_muted'] = !(chat['is_muted'] ?? false);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          chat['is_muted'] ? 'Notifications muted' : 'Notifications unmuted',
        ),
      ),
    );
  }

  void _viewDetails(Map<String, dynamic> chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(chat['name'] ?? 'Chat Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${chat['email'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Last message: ${chat['time'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Pinned: ${chat['is_pinned'] ?? false ? 'Yes' : 'No'}'),
            Text('Muted: ${chat['is_muted'] ?? false ? 'Yes' : 'No'}'),
            Text('Favorite: ${chat['is_favorite'] ?? false ? 'Yes' : 'No'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleArchive(Map<String, dynamic> chat) async {
    setState(() {
      chat['is_archived'] = !(chat['is_archived'] ?? false);
      _filterChats();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          chat['is_archived'] ? 'Chat archived' : 'Chat unarchived',
        ),
      ),
    );
  }

  Future<void> _clearChat(Map<String, dynamic> chat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text(
          'This will remove all messages but keep the conversation. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        chat['lastMessage'] = '';
        chat['unreadCount'] = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chat cleared')));
      }
    }
  }

  Future<void> _blockUser(Map<String, dynamic> chat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block user?'),
        content: Text(
          'Are you sure you want to block ${chat['name']}? They will not be able to send you messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // TODO: Implement block via API
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${chat['name']} has been blocked')),
        );
      }
    }
  }

  Future<void> _deleteChat(Map<String, dynamic> chat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: const Text(
          'This will permanently delete this conversation. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _allChats.remove(chat);
        _filterChats();
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Conversation deleted')));
      }
    }
  }

  Future<void> _handleUserTap(Map<String, dynamic> user) async {
    try {
      final userId = await _authService.getUserId();
      if (userId == null) return;

      // Don't create thread yet - just navigate to chat screen
      // Thread will be created when first message is sent
      final tempChatId = 'new_${userId}_${user['id']}';

      if (mounted) {
        context.go(
          '/chat/$tempChatId',
          extra: {
            'otherUserName': user['name'] ?? 'Tradie',
            'otherUserId': user['id'].toString(),
            'otherUserType': 'tradie',
          },
        );
      }
    } catch (e) {
      // Handle error
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        // Today - show time in 12-hour format
        final hour = date.hour == 0
            ? 12
            : (date.hour > 12 ? date.hour - 12 : date.hour);
        final period = date.hour >= 12 ? 'PM' : 'AM';
        return '${hour.toString()}:${date.minute.toString().padLeft(2, '0')} $period';
      } else if (difference.inDays == 1) {
        // Yesterday
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        // This week - show day name
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[date.weekday - 1];
      } else if (difference.inDays < 365) {
        // This year - show date
        return '${date.day}/${date.month}';
      } else {
        // Older - show full date
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return '';
    }
  }
}
