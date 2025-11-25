import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/chat_repository_new.dart';
import '../../../core/services/auth_service.dart';

/// Simple Chat Example
/// Shows how to use the new Laravel + Firestore architecture
/// - Send messages through Laravel API
/// - Read messages from Firestore (real-time)
class SimpleChatExample extends StatefulWidget {
  final int otherUserId;
  final String otherUserName;
  final String otherUserType; // 'homeowner' or 'tradie'

  const SimpleChatExample({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserType,
  });

  @override
  State<SimpleChatExample> createState() => _SimpleChatExampleState();
}

class _SimpleChatExampleState extends State<SimpleChatExample> {
  final ChatRepository _chatRepo = ChatRepository();
  final TextEditingController _messageController = TextEditingController();

  int? _currentUserId;
  String? _currentUserType;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userId = await AuthService.getUserId();
    final userType = await AuthService.getUserType();

    setState(() {
      _currentUserId = userId;
      _currentUserType = userType;
      _isLoading = false;
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    if (_currentUserId == null || _currentUserType == null) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    // Send through Laravel API (Laravel writes to Firestore)
    final success = await _chatRepo.sendMessage(
      senderId: _currentUserId!,
      receiverId: widget.otherUserId,
      senderType: _currentUserType!,
      receiverType: widget.otherUserType,
      message: message,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to send message')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentUserId == null || _currentUserType == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(child: Text('Please log in to chat')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Chat with ${widget.otherUserName}')),
      body: Column(
        children: [
          // Messages list (read from Firestore - real-time)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatRepo.getMessages(
                currentUserId: _currentUserId!,
                currentUserType: _currentUserType!,
                otherUserId: widget.otherUserId,
                otherUserType: widget.otherUserType,
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
                    child: Text('No messages yet. Start the conversation!'),
                  );
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData =
                        messages[index].data() as Map<String, dynamic>;
                    final isMe = messageData['sender_id'] == _currentUserId;

                    return _buildMessageBubble(
                      message: messageData['content'] ?? '',
                      isMe: isMe,
                      timestamp: messageData['date'],
                    );
                  },
                );
              },
            ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
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
                    ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String message,
    required bool isMe,
    dynamic timestamp,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: isMe ? Theme.of(context).primaryColor : Colors.grey[300],
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: isMe ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else {
        return '';
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

      if (messageDate == today) {
        final hour = dateTime.hour;
        final minute = dateTime.minute.toString().padLeft(2, '0');
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$displayHour:$minute $period';
      } else {
        final hour = dateTime.hour;
        final minute = dateTime.minute.toString().padLeft(2, '0');
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '${dateTime.day}/${dateTime.month} $displayHour:$minute $period';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
