import 'package:flutter/material.dart';
import '../screens/enhanced_user_profile_screen.dart';
import '../models/user_model.dart';

class ChatMenuWidget extends StatelessWidget {
  final UserModel otherUser;
  final String currentUserType;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;
  final VoidCallback? onBlock;
  final VoidCallback? onMute;

  const ChatMenuWidget({
    super.key,
    required this.otherUser,
    required this.currentUserType,
    this.onArchive,
    this.onDelete,
    this.onBlock,
    this.onMute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Menu Items
          _buildMenuItem(
            icon: Icons.person,
            title: 'View Profile',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EnhancedUserProfileScreen(
                    user: otherUser,
                    currentUserType: currentUserType,
                  ),
                ),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.notifications_off,
            title: 'Mute Notifications',
            onTap: () {
              Navigator.pop(context);
              onMute?.call();
            },
          ),
          _buildMenuItem(
            icon: Icons.archive,
            title: 'Archive Chat',
            onTap: () {
              Navigator.pop(context);
              onArchive?.call();
            },
          ),
          _buildMenuItem(
            icon: Icons.delete,
            title: 'Delete Chat',
            color: Colors.red,
            onTap: () {
              Navigator.pop(context);
              _showDeleteConfirmation(context);
            },
          ),
          _buildMenuItem(
            icon: Icons.report,
            title: 'Report User',
            color: Colors.orange,
            onTap: () {
              Navigator.pop(context);
              _showReportDialog(context);
            },
          ),
          _buildMenuItem(
            icon: Icons.block,
            title: 'Block User',
            color: Colors.red,
            onTap: () {
              Navigator.pop(context);
              _showBlockConfirmation(context);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.grey[700]),
      title: Text(
        title,
        style: TextStyle(color: color ?? Colors.black87, fontSize: 16),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Chat'),
        content: const Text(
          'Are you sure you want to delete this chat? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showBlockConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Block ${otherUser.name}'),
        content: Text(
          'Are you sure you want to block ${otherUser.name}? You won\'t receive messages from them anymore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onBlock?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ReportUserDialog(),
    );
  }
}

class ReportUserDialog extends StatefulWidget {
  const ReportUserDialog({super.key});

  @override
  State<ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends State<ReportUserDialog> {
  String _selectedReason = 'Inappropriate behavior';
  final TextEditingController _detailsController = TextEditingController();

  final List<String> _reportReasons = [
    'Inappropriate behavior',
    'Spam or scam',
    'Harassment',
    'Fake profile',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.report, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Report Mike Johnson',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              'Help us understand what\'s wrong. We\'ll review this report and take appropriate action.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Reason Selection
            const Text(
              'Reason for reporting',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            ..._reportReasons.map(
              (reason) => RadioListTile<String>(
                value: reason,
                groupValue: _selectedReason,
                onChanged: (value) {
                  setState(() {
                    _selectedReason = value!;
                  });
                },
                title: Text(reason, style: const TextStyle(fontSize: 14)),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),

            const SizedBox(height: 24),

            // Additional Details
            const Text(
              'Additional details (optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Provide more information about this report',
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF4A90E2)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Report submitted successfully'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Submit Report'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }
}
