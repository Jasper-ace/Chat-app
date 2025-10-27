import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../services/user_presence_service.dart';
import '../models/user_model.dart';

import 'chat_screen.dart';
import 'notification_settings_screen.dart';

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

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final UserPresenceService _presenceService = UserPresenceService();
  String searchQuery = '';

  String _getTimeString(UserModel user) {
    // Mock time - in real app, get from last message timestamp
    final times = ['10:30 AM', '9:15 AM', 'Yesterday', 'Monday'];
    return times[user.id.hashCode % times.length];
  }

  String _getLastMessage(UserModel user) {
    // Mock messages - in real app, get from last message
    final messages = [
      'I can come by tomorrow at 2pm to check the plumbing',
      'Thanks for the quote! When can you start?',
      'Do you have availability this week for a bathroom',
      'I\'ve finished the electrical work. All tested and',
    ];
    return messages[user.id.hashCode % messages.length];
  }

  bool _hasUnreadMessages(UserModel user) {
    // Mock unread status - in real app, check actual unread count
    return user.id.hashCode % 3 == 0; // Every 3rd user has unread messages
  }

  int _getUnreadCount(UserModel user) {
    // Mock unread count - in real app, get actual count
    return (user.id.hashCode % 3) + 1;
  }

  void _showNotificationSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationSettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A90E2),
        elevation: 0,
        title: const Text(
          "Messages",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () => _showNotificationSettings(),
            icon: const Icon(Icons.settings, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF4A90E2),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value),
              decoration: InputDecoration(
                hintText: "Search Messages",
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Tab bar for Recent/Archived
          Container(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF4A90E2), width: 2),
                      ),
                    ),
                    child: const Text(
                      'Recent message',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF4A90E2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Archived',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // User list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: searchQuery.isEmpty
                  ? _chatService.getAvailableUsers(widget.currentUserType)
                  : _chatService.searchUsers(
                      widget.currentUserType,
                      searchQuery,
                    ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("No users available for chat"),
                  );
                }

                final users = snapshot.data!.docs
                    .map((doc) => UserModel.fromFirestore(doc))
                    .where((user) {
                      if (searchQuery.isEmpty) return true;
                      return user.name.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      );
                    })
                    .toList();

                if (users.isEmpty) {
                  return const Center(child: Text("No users found"));
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey[200]!,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundImage: user.avatar != null
                                  ? NetworkImage(user.avatar!)
                                  : const NetworkImage(
                                      'https://cdn-icons-png.flaticon.com/512/149/149071.png',
                                    ),
                              radius: 28,
                            ),
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: StreamBuilder<Map<String, dynamic>>(
                                stream: _presenceService.getUserPresence(
                                  user.id,
                                ),
                                builder: (context, presenceSnapshot) {
                                  final isOnline =
                                      presenceSnapshot.data?['isOnline'] ??
                                      false;
                                  return Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: isOnline
                                          ? Colors.green
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                user.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Text(
                              _getTimeString(user),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _getLastMessage(user),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_hasUnreadMessages(user))
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  _getUnreadCount(user).toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
                          size: 20,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                otherUser: user,
                                currentUserType: widget.currentUserType,
                                currentUserId: widget.currentUserId,
                              ),
                            ),
                          );
                        },
                      ),
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
}
