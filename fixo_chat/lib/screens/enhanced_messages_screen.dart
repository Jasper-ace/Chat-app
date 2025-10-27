import 'package:flutter/material.dart';
import 'notification_settings_screen.dart';

class EnhancedMessagesScreen extends StatefulWidget {
  const EnhancedMessagesScreen({super.key});

  @override
  State<EnhancedMessagesScreen> createState() => _EnhancedMessagesScreenState();
}

class _EnhancedMessagesScreenState extends State<EnhancedMessagesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4A90E2),
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Messages',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const NotificationSettingsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Search Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search Messages',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _isSearching = value.isNotEmpty;
                  });
                },
              ),
            ),

            const SizedBox(height: 20),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                ),
                labelColor: const Color(0xFF4A90E2),
                unselectedLabelColor: Colors.white,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Recent message'),
                  Tab(text: 'Archived'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Messages Content
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildRecentMessages(), _buildArchivedMessages()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentMessages() {
    final messages = [
      MessageItem(
        name: 'Mike Johnson',
        userType: 'Tradie',
        message: 'I can come by tomorrow at 2pm to check the plumbing',
        time: '10:30 AM',
        unreadCount: 2,
        isOnline: true,
        avatar:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
      ),
      MessageItem(
        name: 'Sarah Williams',
        userType: 'Customer Service',
        message: 'Thanks for the quote! When can you start?',
        time: '9:15 AM',
        unreadCount: 0,
        isOnline: false,
        avatar:
            'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=150',
      ),
      MessageItem(
        name: 'Emma Davis',
        userType: 'Customer Service',
        message:
            'Do you have availability this week for a bathroom renovation?',
        time: 'Yesterday',
        unreadCount: 0,
        isOnline: false,
        avatar:
            'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150',
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _buildMessageTile(message);
      },
    );
  }

  Widget _buildArchivedMessages() {
    final archivedMessages = [
      MessageItem(
        name: 'Dave Thompson',
        userType: 'Tradie',
        message:
            'I\'ve finished the electrical work. All tested and working perfectly!',
        time: 'Yesterday',
        unreadCount: 1,
        isOnline: false,
        avatar:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150',
      ),
      MessageItem(
        name: 'Chris Anderson',
        userType: 'Tradie',
        message: 'All done! The deck looks great.',
        time: 'Monday',
        unreadCount: 0,
        isOnline: false,
        avatar:
            'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: archivedMessages.length,
      itemBuilder: (context, index) {
        final message = archivedMessages[index];
        return _buildMessageTile(message);
      },
    );
  }

  Widget _buildMessageTile(MessageItem message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage(message.avatar),
            ),
            if (message.isOnline)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                message.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              message.time,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: message.userType == 'Tradie'
                        ? const Color(0xFF4A90E2)
                        : const Color(0xFF34C759),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    message.userType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  ' • ${message.time}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message.message,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: message.unreadCount > 0
            ? Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${message.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          // Navigate to chat screen
        },
      ),
    );
  }
}

class MessageItem {
  final String name;
  final String userType;
  final String message;
  final String time;
  final int unreadCount;
  final bool isOnline;
  final String avatar;

  MessageItem({
    required this.name,
    required this.userType,
    required this.message,
    required this.time,
    required this.unreadCount,
    required this.isOnline,
    required this.avatar,
  });
}
