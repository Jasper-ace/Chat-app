import 'package:flutter/material.dart';
import '../models/user_model.dart';

class EnhancedUserProfileScreen extends StatefulWidget {
  final UserModel user;
  final String currentUserType;

  const EnhancedUserProfileScreen({
    super.key,
    required this.user,
    required this.currentUserType,
  });

  @override
  State<EnhancedUserProfileScreen> createState() =>
      _EnhancedUserProfileScreenState();
}

class _EnhancedUserProfileScreenState extends State<EnhancedUserProfileScreen> {
  bool _isBlocked = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Custom App Bar with Profile Header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: widget.user.avatar != null
                          ? NetworkImage(widget.user.avatar!)
                          : null,
                      child: widget.user.avatar == null
                          ? Text(
                              widget.user.name.isNotEmpty
                                  ? widget.user.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(color: Colors.white),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showMoreOptions(context),
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Profile Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Profile Modal Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Close button
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, color: Colors.grey),
                            ),
                          ),

                          // Profile Picture
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: widget.user.avatar != null
                                ? NetworkImage(widget.user.avatar!)
                                : null,
                            child: widget.user.avatar == null
                                ? Text(
                                    widget.user.name.isNotEmpty
                                        ? widget.user.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(fontSize: 32),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // Name
                          Text(
                            widget.user.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // User Type Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: widget.user.userType == 'tradie'
                                  ? const Color(0xFF4A90E2)
                                  : const Color(0xFF34C759),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.user.userType == 'tradie'
                                  ? 'tradie'
                                  : 'homeowner',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Rating
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.user.userType == 'tradie'
                                    ? '4.8'
                                    : '4.9',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.user.userType == 'tradie'
                                    ? '(127 reviews)'
                                    : '(23 reviews)',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // About Section
                          _buildSection(
                            'About',
                            widget.user.userType == 'tradie'
                                ? 'Licensed plumber with 15+ years experience. Specializing in residential and commercial plumbing repairs, installations, and emergency services.'
                                : 'Homeowner looking for reliable tradies for kitchen renovation project. Value quality workmanship and clear communication.',
                          ),
                          const SizedBox(height: 24),

                          // Contact Information
                          _buildSection('Contact Information', null),
                          const SizedBox(height: 12),
                          _buildContactInfo(
                            Icons.location_on,
                            widget.user.userType == 'tradie'
                                ? 'Sydney, NSW'
                                : 'Melbourne, VIC',
                          ),
                          _buildContactInfo(
                            Icons.phone,
                            widget.user.userType == 'tradie'
                                ? '+61 412 345 678'
                                : '+61 423 567 890',
                          ),
                          _buildContactInfo(
                            Icons.email,
                            widget.user.userType == 'tradie'
                                ? 'mike.j@plumbing.com.au'
                                : 'sarah.williams@email.com',
                          ),
                          _buildContactInfo(
                            Icons.calendar_today,
                            widget.user.userType == 'tradie'
                                ? 'Joined March 2023'
                                : 'Joined January 2024',
                          ),
                          const SizedBox(height: 24),

                          // Job History (for tradies)
                          if (widget.user.userType == 'tradie') ...[
                            _buildSection('Job History', null),
                            const SizedBox(height: 12),
                            _buildJobHistoryItem(
                              'Kitchen Sink Repair',
                              'In progress',
                              'This week',
                              '\$150',
                              const Color(0xFF4A90E2),
                            ),
                            _buildJobHistoryItem(
                              'Bathroom Pipe Replacement',
                              'Completed',
                              '2 weeks ago',
                              '\$450',
                              const Color(0xFF34C759),
                            ),
                          ] else ...[
                            // Job History for homeowners
                            _buildSection('Job History', null),
                            const SizedBox(height: 12),
                            _buildJobHistoryItem(
                              'Kitchen Renovation',
                              'Pending',
                              'This week',
                              '\$8,500',
                              Colors.orange,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String? content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        if (content != null) ...[
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContactInfo(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildJobHistoryItem(
    String title,
    String status,
    String time,
    String price,
    Color statusColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.work, size: 20, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        status.toLowerCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            price,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.report, color: Colors.orange),
              title: const Text('Report User'),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(context);
              },
            ),
            ListTile(
              leading: Icon(
                _isBlocked ? Icons.person_add : Icons.block,
                color: _isBlocked ? Colors.green : Colors.red,
              ),
              title: Text(_isBlocked ? 'Unblock User' : 'Block User'),
              onTap: () {
                Navigator.pop(context);
                _toggleBlock();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ReportUserDialog(),
    );
  }

  void _toggleBlock() {
    setState(() {
      _isBlocked = !_isBlocked;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isBlocked ? 'User blocked' : 'User unblocked'),
        backgroundColor: _isBlocked ? Colors.red : Colors.green,
      ),
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
