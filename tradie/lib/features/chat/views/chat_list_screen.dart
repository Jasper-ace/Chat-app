import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/services/tradie_api_auth_service.dart';
import '../services/chat_api_service.dart';
import '../repositories/chat_repository_realtime.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen>
    with SingleTickerProviderStateMixin {
  final _authService = TradieApiAuthService();
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

  void _listenToTypingStatus(String threadId, int homeownerId) {
    final typingRef = FirebaseDatabase.instance.ref(
      'threads/$threadId/typing/${homeownerId}_homeowner',
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
        final users = await _chatService.getAllHomeowners();

        setState(() {
          _allUsers = users;
        });

        // Listen to threads from Firebase
        _chatRepository.getThreads(userId: userId, userType: 'tradie').listen((
          threads,
        ) {
          print('📋 Received ${threads.length} threads from Firebase');

          // Convert threads to chat format and match with user names
          final chats = threads
              .where((thread) {
                // Filter out threads with invalid homeowner_id
                final homeownerId = thread['homeowner_id'];
                return homeownerId != null && homeownerId != 0;
              })
              .map((thread) {
                final homeownerId = thread['homeowner_id'];
                final homeowner = _allUsers.firstWhere(
                  (u) => u['id'] == homeownerId,
                  orElse: () => {},
                );

                // Construct full name from first_name, middle_name, last_name
                String fullName = 'Homeowner #$homeownerId';
                if (homeowner.isNotEmpty) {
                  final firstName = homeowner['first_name'] ?? '';
                  final middleName = homeowner['middle_name'] ?? '';
                  final lastName = homeowner['last_name'] ?? '';
                  fullName = [
                    firstName,
                    middleName,
                    lastName,
                  ].where((s) => s.isNotEmpty).join(' ').trim();
                  if (fullName.isEmpty) fullName = 'Homeowner #$homeownerId';
                }

                return {
                  'id': thread['id'],
                  'name': fullName,
                  'email': homeowner['email'] ?? '',
                  'lastMessage': thread['last_message'] ?? '',
                  'time': thread['last_message_time'],
                  'unreadCount': 0,
                  'is_pinned': false,
                  'is_archived': false,
                  'is_muted': false,
                  'is_favorite': false,
                  'homeowner_id': homeownerId,
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
            _listenToTypingStatus(chat['id'], chat['homeowner_id']);
          }
        });
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
    if (chats.isEmpty && _allUsers.isEmpty) {
      return _buildEmptyState();
    }

    if (chats.isEmpty) {
      return _buildUserList();
    }

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
        user['email'] ?? 'Homeowner',
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
          context.go(
            '/chat/${chat['id']}',
            extra: {
              'otherUserName': chat['name'] ?? 'User',
              'otherUserId': (chat['homeowner_id'] ?? 0).toString(),
              'otherUserType': 'homeowner',
            },
          );
        },
        onLongPress: () => _showChatOptions(chat),
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
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.push_pin),
              title: Text(chat['is_pinned'] == true ? 'Unpin' : 'Pin to top'),
              onTap: () {
                Navigator.pop(context);
                _togglePin(chat);
              },
            ),
            ListTile(
              leading: const Icon(Icons.mark_chat_unread),
              title: const Text('Mark as unread'),
              onTap: () {
                Navigator.pop(context);
                _markAsUnread(chat);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive),
              title: Text(
                chat['is_archived'] == true ? 'Unarchive' : 'Archive',
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleArchive(chat);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteChat(chat);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePin(Map<String, dynamic> chat) async {
    // TODO: Implement pin/unpin via API
    setState(() {
      chat['is_pinned'] = !(chat['is_pinned'] ?? false);
    });
  }

  Future<void> _toggleArchive(Map<String, dynamic> chat) async {
    // TODO: Implement archive/unarchive via API
    setState(() {
      chat['is_archived'] = !(chat['is_archived'] ?? false);
      _filterChats();
    });
  }

  Future<void> _markAsUnread(Map<String, dynamic> chat) async {
    // TODO: Implement mark as unread via API
    setState(() {
      chat['unreadCount'] = 1;
    });
  }

  Future<void> _deleteChat(Map<String, dynamic> chat) async {
    // TODO: Implement delete via API
    setState(() {
      _allChats.remove(chat);
      _filterChats();
    });
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
            'otherUserName': user['name'] ?? 'Homeowner',
            'otherUserId': user['id'].toString(),
            'otherUserType': 'homeowner',
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
