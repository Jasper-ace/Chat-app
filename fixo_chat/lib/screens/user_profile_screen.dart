import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/user_profile_model.dart';
import '../services/chat_service.dart';

class UserProfileScreen extends StatefulWidget {
  final UserModel user;
  final String currentUserType;

  const UserProfileScreen({
    super.key,
    required this.user,
    required this.currentUserType,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final ChatService _chatService = ChatService();
  bool _isBlocked = false;
  bool _isLoading = true;
  UserProfileModel? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      // Try to get enhanced profile from userProfiles collection
      final profileDoc = await FirebaseFirestore.instance
          .collection('userProfiles')
          .doc(widget.user.id)
          .get();

      if (profileDoc.exists) {
        _userProfile = UserProfileModel.fromFirestore(profileDoc);
      }

      // Check if user is blocked (get current user's blocked list)
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        final currentUserProfile = await FirebaseFirestore.instance
            .collection('userProfiles')
            .doc(currentUserId)
            .get();

        if (currentUserProfile.exists) {
          final data = currentUserProfile.data() as Map<String, dynamic>;
          final blockedUsers = List<String>.from(data['blockedUsers'] ?? []);
          _isBlocked = blockedUsers.contains(widget.user.id);
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

  Future<void> _toggleBlockUser() async {
    try {
      if (_isBlocked) {
        await _chatService.unblockUser(widget.user.id);
        setState(() {
          _isBlocked = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.user.displayName} has been unblocked'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await _chatService.blockUser(widget.user.id);
        setState(() {
          _isBlocked = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.user.displayName} has been blocked'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _reportUser() async {
    final TextEditingController reasonController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Report ${widget.user.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'e.g., Inappropriate behavior',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Provide more details...',
              ),
              maxLines: 3,
            ),
          ],
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
                  reportedUserId: widget.user.id,
                  reason: reasonController.text,
                  description: descriptionController.text,
                );
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report submitted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error submitting report: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Colors.blueAccent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user.displayName),
        backgroundColor: Colors.blueAccent,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'block':
                  _toggleBlockUser();
                  break;
                case 'report':
                  _reportUser();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(
                      _isBlocked ? Icons.person_add : Icons.block,
                      color: _isBlocked ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isBlocked ? 'Unblock User' : 'Block User',
                      style: TextStyle(
                        color: _isBlocked ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.report, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Report User', style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: widget.user.avatar != null
                        ? NetworkImage(widget.user.avatar!)
                        : const NetworkImage(
                            'https://cdn-icons-png.flaticon.com/512/149/149071.png',
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.user.displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.user.userType.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_userProfile?.isVerified == true) ...[
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, color: Colors.blue, size: 20),
                        SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Basic Information
            _buildSection('Basic Information', [
              _buildInfoRow('Email', widget.user.email),
              if (widget.user.phone != null)
                _buildInfoRow('Phone', widget.user.phone!),
              if (widget.user.tradeType != null)
                _buildInfoRow('Trade Type', widget.user.tradeType!),
            ]),

            // Enhanced Profile Information (if available)
            if (_userProfile != null) ...[
              const SizedBox(height: 24),
              _buildSection('Professional Information', [
                if (_userProfile!.ratings > 0)
                  _buildInfoRow('Rating', _userProfile!.formattedRating),
                _buildInfoRow('Status', _userProfile!.statusText),
                _buildInfoRow(
                  'Completed Jobs',
                  '${_userProfile!.completedJobsCount}',
                ),
              ]),
            ],

            // Bio Section
            if (widget.user.bio != null && widget.user.bio!.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSection('About', [
                Text(widget.user.bio!, style: const TextStyle(fontSize: 16)),
              ]),
            ],

            // Job History (if available)
            if (_userProfile?.jobHistory.isNotEmpty == true) ...[
              const SizedBox(height: 24),
              _buildSection(
                'Recent Jobs',
                _userProfile!.jobHistory.take(3).map((job) {
                  return Card(
                    child: ListTile(
                      title: Text(job.title),
                      subtitle: Text(job.description),
                      trailing: job.rating != null
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                Text('${job.rating}'),
                              ],
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 32),

            // Action Buttons
            if (!_isBlocked) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text('Start Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.block, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'This user is blocked',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}
