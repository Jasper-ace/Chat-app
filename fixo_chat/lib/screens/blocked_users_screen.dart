import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final ChatService _chatService = ChatService();
  List<String> _blockedUserIds = [];
  final Map<String, UserModel> _userDetails = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Get blocked users list
      final profileDoc = await FirebaseFirestore.instance
          .collection('userProfiles')
          .doc(currentUserId)
          .get();

      if (profileDoc.exists) {
        final data = profileDoc.data() as Map<String, dynamic>;
        final blockedUsers = List<String>.from(data['blockedUsers'] ?? []);

        setState(() {
          _blockedUserIds = blockedUsers;
        });

        // Load user details for each blocked user
        for (String userId in blockedUsers) {
          await _loadUserDetails(userId);
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserDetails(String userId) async {
    try {
      // Try homeowners first
      var userDoc = await FirebaseFirestore.instance
          .collection('homeowners')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          _userDetails[userId] = UserModel.fromFirestore(userDoc);
        });
        return;
      }

      // Try tradies
      userDoc = await FirebaseFirestore.instance
          .collection('tradies')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          _userDetails[userId] = UserModel.fromFirestore(userDoc);
        });
      }
    } catch (e) {
      print('Error loading user details: $e');
    }
  }

  Future<void> _unblockUser(String userId) async {
    try {
      await _chatService.unblockUser(userId);

      setState(() {
        _blockedUserIds.remove(userId);
        _userDetails.remove(userId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User has been unblocked'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error unblocking user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUserIds.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No blocked users',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Users you block will appear here',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _blockedUserIds.length,
              itemBuilder: (context, index) {
                final userId = _blockedUserIds[index];
                final user = _userDetails[userId];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user?.avatar != null
                          ? NetworkImage(user!.avatar!)
                          : const NetworkImage(
                              'https://cdn-icons-png.flaticon.com/512/149/149071.png',
                            ),
                      radius: 25,
                    ),
                    title: Text(
                      user?.displayName ?? 'Unknown User',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (user != null) ...[
                          Text(
                            user.userType.toUpperCase(),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (user.tradeType != null)
                            Text(
                              user.tradeType!,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                              ),
                            ),
                        ] else ...[
                          Text(
                            'User ID: $userId',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => _showUnblockDialog(userId, user),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Unblock'),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showUnblockDialog(String userId, UserModel? user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unblock ${user?.displayName ?? 'User'}?'),
        content: Text(
          'Are you sure you want to unblock ${user?.displayName ?? 'this user'}? '
          'You will be able to send and receive messages again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _unblockUser(userId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
  }
}
