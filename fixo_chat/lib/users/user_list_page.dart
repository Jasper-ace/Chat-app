import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../chat/chat_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../login_page.dart';

class UserListPage extends StatefulWidget {
  final String currentUserId;
  final String currentUserRole;

  const UserListPage({super.key, 
    required this.currentUserId,
    required this.currentUserRole,
  });

  @override
  _UserListPageState createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<QuerySnapshot>? _messageListener;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _listenForMessages();
  }

  @override
  void dispose() {
    _messageListener?.cancel();
    super.dispose();
  }

  /// 🔔 Listen for incoming messages
  void _listenForMessages() {
    _messageListener = _firestore
        .collection('messages')
        .where('receiverId', isEqualTo: widget.currentUserId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var messageData = change.doc.data() as Map<String, dynamic>;
          String senderId = messageData['senderId'];
          String messageText = messageData['message'] ?? '';
          _showInAppNotification(senderId, messageText);
        }
      }
    });
  }

  /// 📱 In-app notification (snackbar)
  void _showInAppNotification(String senderId, String messageText) async {
    try {
      DocumentSnapshot senderDoc =
          await _firestore.collection('users').doc(senderId).get();
      String senderName = senderDoc['name'] ??
          '${senderDoc['first_name'] ?? ''} ${senderDoc['last_name'] ?? ''}';

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$senderName sent: $messageText'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('Notification error: $e');
    }
  }

  /// 🧭 Query for the opposite user type (tradie <-> homeowner)
  Stream<QuerySnapshot> getOtherUsers() {
    String targetRole =
        widget.currentUserRole == 'tradie' ? 'homeowner' : 'tradie';

    return _firestore
        .collection('users')
        .where('role', isEqualTo: targetRole)
        .snapshots();
  }

  /// 🔓 Logout
  void logout() async {
    await _auth.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
      (route) => false,
    );
  }

  /// 🕒 Get latest message per user (both directions)
  Future<Map<String, dynamic>?> getLastMessage(String userId) async {
    var messages = await _firestore
        .collection('messages')
        .where('participants', arrayContains: widget.currentUserId)
        .orderBy('timestamp', descending: true)
        .get();

    // Filter manually for conversation between current user and this user
    var conversation = messages.docs.where((msg) {
      var data = msg.data();
      return (data['senderId'] == widget.currentUserId &&
              data['receiverId'] == userId) ||
          (data['senderId'] == userId &&
              data['receiverId'] == widget.currentUserId);
    }).toList();

    if (conversation.isEmpty) return null;
    return conversation.first.data();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        title: const Text(
          "Messages",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: logout,
          )
        ],
      ),
      body: Column(
        children: [
          // 🔍 Search
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.blueAccent,
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value),
              decoration: InputDecoration(
                hintText: "Search Messages",
                hintStyle: TextStyle(color: Colors.grey[700]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[700]),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none),
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.only(top: 10, left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Recent message",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // 🧾 User list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getOtherUsers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var users = snapshot.data!.docs.where((u) {
                  var data = u.data() as Map<String, dynamic>;
                  String name = (data['name'] ??
                          '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}')
                      .toString()
                      .toLowerCase();
                  return name.contains(searchQuery.toLowerCase());
                }).toList();

                if (users.isEmpty) {
                  return const Center(child: Text("No users available"));
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    var user = users[index];
                    var data = user.data() as Map<String, dynamic>;

                    String displayName = data['name'] ??
                        '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}';
                    String avatarUrl = data['avatar'] ??
                        'https://cdn-icons-png.flaticon.com/512/149/149071.png';

                    return FutureBuilder<Map<String, dynamic>?>(
                      future: getLastMessage(user.id),
                      builder: (context, msgSnapshot) {
                        if (!msgSnapshot.hasData) {
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(avatarUrl),
                              radius: 25,
                            ),
                            title: Text(
                              displayName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text("No messages yet"),
                            trailing: const Icon(Icons.chevron_right,
                                color: Colors.grey),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatPage(
                                    receiverId: user.id,
                                    receiverName: displayName,
                                  ),
                                ),
                              );
                            },
                          );
                        }

                        var lastMsg = msgSnapshot.data!;
                        String lastMessage = lastMsg['message'] ?? '';
                        bool isRead = lastMsg['read'] ?? false;
                        Timestamp timestamp = lastMsg['timestamp'];
                        DateTime date = timestamp.toDate();
                        String timeAgo = _getTimeAgo(date);

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(avatarUrl),
                            radius: 25,
                          ),
                          title: Text(
                            displayName,
                            style: TextStyle(
                              fontWeight: isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                timeAgo,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 4),
                              const Icon(Icons.chevron_right,
                                  color: Colors.grey, size: 20),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatPage(
                                  receiverId: user.id,
                                  receiverName: displayName,
                                ),
                              ),
                            );
                          },
                        );
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

  String _getTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }
}
