import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// Color used across the screens for consistency
const Color _primaryColor = Color(0xFF4A90E2);

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Notification Settings States
  bool _newMessages = true;
  bool _messagePreview = true;
  bool _messageSound = true;
  bool _statusChanges = true;
  bool _newJobRequests = true;
  bool _quotesEstimates = true;
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _doNotDisturb = false;

  // Privacy Settings States
  bool _showOnlineStatus = true;
  bool _showLastSeen = true;
  bool _showProfilePhoto = true;
  bool _showPhoneNumber = false;
  bool _readReceipts = true;
  bool _allowMessageRequests = true;
  bool _blockUnknownUsers = false;
  bool _shareUsageData = false;
  bool _personalizedAds = false;
  bool _locationSharing = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Shared Preferences & Utility Methods (Merged from Notification and Privacy) ---

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (mounted) {
      setState(() {
        // Notification settings
        _newMessages = prefs.getBool('notifications_new_messages') ?? true;
        _messagePreview =
            prefs.getBool('notifications_message_preview') ?? true;
        _messageSound = prefs.getBool('notifications_message_sound') ?? true;
        _statusChanges = prefs.getBool('notifications_status_changes') ?? true;
        _newJobRequests =
            prefs.getBool('notifications_new_job_requests') ?? true;
        _quotesEstimates =
            prefs.getBool('notifications_quotes_estimates') ?? true;
        _pushNotifications = prefs.getBool('notifications_push') ?? true;
        _emailNotifications = prefs.getBool('notifications_email') ?? false;
        _doNotDisturb = prefs.getBool('notifications_do_not_disturb') ?? false;

        // Privacy settings
        _showOnlineStatus =
            prefs.getBool('privacy_show_online_status') ?? true;
        _showLastSeen = prefs.getBool('privacy_show_last_seen') ?? true;
        _showProfilePhoto =
            prefs.getBool('privacy_show_profile_photo') ?? true;
        _showPhoneNumber = prefs.getBool('privacy_show_phone_number') ?? false;
        _readReceipts = prefs.getBool('privacy_read_receipts') ?? true;
        _allowMessageRequests =
            prefs.getBool('privacy_allow_message_requests') ?? true;
        _blockUnknownUsers =
            prefs.getBool('privacy_block_unknown_users') ?? false;
        _shareUsageData = prefs.getBool('privacy_share_usage_data') ?? false;
        _personalizedAds = prefs.getBool('privacy_personalized_ads') ?? false;
        _locationSharing = prefs.getBool('privacy_location_sharing') ?? true;
      });
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // --- General UI Building Blocks ---

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: _primaryColor, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildCardSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSectionHeader(icon: icon, title: title, trailing: trailing),
          const Divider(height: 1),
          // Section content
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.3),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: _primaryColor,
        activeTrackColor: _primaryColor.withOpacity(0.3),
      ),
    );
  }

  // --- Help & Support Methods ---

  void _callSupport() async {
    const phoneUri = 'tel:1-800-3496-4357';
    final Uri uri = Uri.parse(phoneUri);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@fixo.com',
      query: 'subject=Support Request&body=Please describe your issue:',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  void _startLiveChat(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Live Chat'),
        content: const Text(
          'Live chat is currently available Monday-Friday, 9AM-6PM EST. Would you like to start a chat session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Live chat feature coming soon!')),
              );
            },
            child: const Text('Start Chat'),
          ),
        ],
      ),
    );
  }

  String _getGuideContent(String topic) {
    switch (topic) {
      case 'Profile Setup':
        return 'Complete your profile by adding:\n\n• Profile photo\n• Contact information\n• Location details\n• Preferences\n\nA complete profile helps tradies understand your needs better.';
      case 'Finding Tradies':
        return 'Tips for finding the right tradie:\n\n• Check ratings and reviews\n• Look at previous work photos\n• Compare quotes from multiple tradies\n• Verify licenses and insurance\n• Read their profile carefully';
      case 'Communication':
        return 'Best practices:\n\n• Be clear about your requirements\n• Ask questions upfront\n• Share photos if helpful\n• Discuss timeline and budget\n• Keep all communication in the app';
      case 'Security':
        return 'Keep your account secure:\n\n• Use a strong password\n• Enable two-factor authentication\n• Don\'t share login details\n• Log out on shared devices\n• Report suspicious activity';
      case 'Payments':
        return 'Payment information:\n\n• Add multiple payment methods\n• Payments are processed securely\n• You can update payment methods anytime\n• Receipts are available in your account\n• Contact support for payment issues';
      case 'Billing':
        return 'Understanding billing:\n\n• Service fees are clearly shown\n• You\'re charged after job completion\n• Invoices are sent via email\n• Dispute charges through the app\n• Download receipts anytime';
      default:
        return 'Guide content for $topic is being prepared.';
    }
  }

  String _getTroubleshootingContent(String issue) {
    switch (issue) {
      case 'Connection':
        return 'Connection troubleshooting:\n\n1. Check your internet connection\n2. Try switching between WiFi and mobile data\n3. Restart the app\n4. Update to the latest version\n5. Restart your device\n6. Contact support if issues persist';
      case 'Notifications':
        return 'Notification troubleshooting:\n\n1. Check notification settings in the app\n2. Verify device notification permissions\n3. Check Do Not Disturb settings\n4. Ensure the app is updated\n5. Try logging out and back in\n6. Contact support for help';
      default:
        return 'Troubleshooting steps for $issue are being prepared.';
    }
  }

  void _showGuide(BuildContext context, String topic) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$topic Guide'),
        content: SingleChildScrollView(child: Text(_getGuideContent(topic))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTroubleshooting(BuildContext context, String issue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$issue Troubleshooting'),
        content: SingleChildScrollView(
          child: Text(_getTroubleshootingContent(issue)),
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

  void _reportBug(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report a Bug'),
        content: const TextField(
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Please describe the bug you encountered...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bug report submitted. Thank you!'),
                ),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  // --- Privacy Methods ---

  void _showPrivacyInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Information'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your Privacy Matters',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'We are committed to protecting your privacy and giving you control over your personal information.',
              ),
              SizedBox(height: 16),
              Text(
                'What We Collect:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Profile information you provide'),
              Text('• Messages and communication data'),
              Text('• Usage patterns and preferences'),
              Text('• Location data (if enabled)'),
              SizedBox(height: 16),
              Text(
                'How We Use It:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• To provide and improve our services'),
              Text('• To connect you with relevant tradies'),
              Text('• To ensure platform safety and security'),
              Text('• To send important notifications'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showBlockedUsers() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Blocked Users'),
        content: const Text('No blocked users found.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _downloadData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Data'),
        content: const Text(
          'We\'ll prepare your data and send a download link to your email address. This may take up to 24 hours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data download request submitted'),
                ),
              );
            },
            child: const Text('Request Download'),
          ),
        ],
      ),
    );
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion is not yet implemented'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  // --- Tab View Builders ---

  Widget _buildHelpSupportTab() {
    Widget buildQuickAction({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: _primaryColor, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    Widget buildFAQTile(
        {required String question, required String answer}) {
      return ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      );
    }

    Widget buildHelpTile({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: _primaryColor),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey[400],
        ),
        onTap: onTap,
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Quick actions
          Container(
            margin: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: buildQuickAction(
                    icon: Icons.chat,
                    title: 'Live Chat',
                    subtitle: 'Chat with support',
                    onTap: () => _startLiveChat(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: buildQuickAction(
                    icon: Icons.email,
                    title: 'Email Us',
                    subtitle: 'Send an email',
                    onTap: _sendEmail,
                  ),
                ),
              ],
            ),
          ),

          // FAQ Section
          _buildCardSection(
            icon: Icons.help_outline,
            title: 'Frequently Asked Questions',
            children: [
              buildFAQTile(
                question: 'How do I find tradies in my area?',
                answer:
                    'Use the search feature on the home screen to find tradies by location, trade type, or rating. You can also browse categories to see all available tradies.',
              ),
              buildFAQTile(
                question: 'How do I book a tradie?',
                answer:
                    'Browse tradies, view their profiles, and tap "Book Now" or "Get Quote". You can describe your job requirements and the tradie will respond with availability and pricing.',
              ),
              buildFAQTile(
                question: 'How do payments work?',
                answer:
                    'Payments are processed securely through the app. You can pay by card or bank transfer. Payment is typically due after job completion and your approval.',
              ),
              buildFAQTile(
                question: 'What if I\'m not satisfied with the work?',
                answer:
                    'Contact the tradie first to resolve any issues. If unresolved, use our dispute resolution process or contact support for assistance.',
              ),
              buildFAQTile(
                question: 'How do I leave a review?',
                answer:
                    'After job completion, you\'ll receive a notification to rate and review the tradie. You can also access this from your job history.',
              ),
              buildFAQTile(
                question: 'Can I cancel a booking?',
                answer:
                    'Yes, you can cancel bookings through the app. Cancellation policies vary by tradie and timing. Check the booking details for specific terms.',
              ),
            ],
          ),

          // Getting Started
          _buildCardSection(
            icon: Icons.play_circle_outline,
            title: 'Getting Started',
            children: [
              buildHelpTile(
                icon: Icons.person_add,
                title: 'Setting up your profile',
                subtitle: 'Complete your profile to get better matches',
                onTap: () => _showGuide(context, 'Profile Setup'),
              ),
              buildHelpTile(
                icon: Icons.search,
                title: 'Finding the right tradie',
                subtitle: 'Tips for choosing the best tradie for your job',
                onTap: () => _showGuide(context, 'Finding Tradies'),
              ),
              buildHelpTile(
                icon: Icons.message,
                title: 'Communicating with tradies',
                subtitle: 'Best practices for messaging and negotiations',
                onTap: () => _showGuide(context, 'Communication'),
              ),
            ],
          ),

          // Account & Billing
          _buildCardSection(
            icon: Icons.account_circle,
            title: 'Account & Billing',
            children: [
              buildHelpTile(
                icon: Icons.lock,
                title: 'Account security',
                subtitle: 'Keep your account safe and secure',
                onTap: () => _showGuide(context, 'Security'),
              ),
              buildHelpTile(
                icon: Icons.payment,
                title: 'Payment methods',
                subtitle: 'Managing your payment options',
                onTap: () => _showGuide(context, 'Payments'),
              ),
              buildHelpTile(
                icon: Icons.receipt,
                title: 'Billing and invoices',
                subtitle: 'Understanding your charges and receipts',
                onTap: () => _showGuide(context, 'Billing'),
              ),
            ],
          ),

          // Troubleshooting
          _buildCardSection(
            icon: Icons.build,
            title: 'Troubleshooting',
            children: [
              buildHelpTile(
                icon: Icons.wifi_off,
                title: 'Connection issues',
                subtitle: 'Fixing app connectivity problems',
                onTap: () => _showTroubleshooting(context, 'Connection'),
              ),
              buildHelpTile(
                icon: Icons.notifications_off,
                title: 'Notification problems',
                subtitle: 'Not receiving notifications?',
                onTap: () => _showTroubleshooting(context, 'Notifications'),
              ),
              buildHelpTile(
                icon: Icons.bug_report,
                title: 'Report a bug',
                subtitle: 'Found something that\'s not working?',
                onTap: () => _reportBug(context),
              ),
            ],
          ),

          // Contact Information
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _primaryColor.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Still need help?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.phone, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    const Text('1-800-FIXO-HELP'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.email, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    const Text('support@fixo.com'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    const Text('Mon-Fri 9AM-6PM EST'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Messages section
          _buildCardSection(
            icon: Icons.message,
            title: 'Messages',
            children: [
              _buildSettingTile(
                title: 'New Messages',
                subtitle: 'Get notified when you receive a new message',
                value: _newMessages,
                onChanged: (value) {
                  setState(() => _newMessages = value);
                  _saveSetting('notifications_new_messages', value);
                },
              ),
              _buildSettingTile(
                title: 'Message Preview',
                subtitle: 'Show message content in notifications',
                value: _messagePreview,
                onChanged: (value) {
                  setState(() => _messagePreview = value);
                  _saveSetting('notifications_message_preview', value);
                },
              ),
              _buildSettingTile(
                title: 'Sound',
                subtitle: 'Play sound for new messages',
                value: _messageSound,
                onChanged: (value) {
                  setState(() => _messageSound = value);
                  _saveSetting('notifications_message_sound', value);
                },
              ),
            ],
            trailing: Icon(Icons.close, color: Colors.grey[400], size: 20), // Placeholder to match original design
          ),

          // Job Updates section
          _buildCardSection(
            icon: Icons.work,
            title: 'Job Updates',
            children: [
              _buildSettingTile(
                title: 'Status Changes',
                subtitle: 'When job status changes\n(accepted, completed, etc.)',
                value: _statusChanges,
                onChanged: (value) {
                  setState(() => _statusChanges = value);
                  _saveSetting('notifications_status_changes', value);
                },
              ),
              _buildSettingTile(
                title: 'New Job Requests',
                subtitle: 'When you receive a new job request',
                value: _newJobRequests,
                onChanged: (value) {
                  setState(() => _newJobRequests = value);
                  _saveSetting('notifications_new_job_requests', value);
                },
              ),
              _buildSettingTile(
                title: 'Quotes & Estimates',
                subtitle: 'When you receive or send quotes',
                value: _quotesEstimates,
                onChanged: (value) {
                  setState(() => _quotesEstimates = value);
                  _saveSetting('notifications_quotes_estimates', value);
                },
              ),
            ],
            trailing: Icon(Icons.close, color: Colors.grey[400], size: 20), // Placeholder to match original design
          ),

          // General section
          _buildCardSection(
            icon: Icons.notifications,
            title: 'General',
            children: [
              _buildSettingTile(
                title: 'Push Notifications',
                subtitle: 'Enable push notifications on this device',
                value: _pushNotifications,
                onChanged: (value) {
                  setState(() => _pushNotifications = value);
                  _saveSetting('notifications_push', value);
                },
              ),
              _buildSettingTile(
                title: 'Email Notifications',
                subtitle: 'Receive notifications via email',
                value: _emailNotifications,
                onChanged: (value) {
                  setState(() => _emailNotifications = value);
                  _saveSetting('notifications_email', value);
                },
              ),
              _buildSettingTile(
                title: 'Do Not Disturb',
                subtitle: 'Mute all notifications',
                value: _doNotDisturb,
                onChanged: (value) {
                  setState(() => _doNotDisturb = value);
                  _saveSetting('notifications_do_not_disturb', value);
                },
              ),
            ],
            trailing: Icon(Icons.close, color: Colors.grey[400], size: 20), // Placeholder to match original design
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPrivacyTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Profile Visibility
          _buildCardSection(
            icon: Icons.person,
            title: 'Profile Visibility',
            children: [
              _buildSettingTile(
                title: 'Online Status',
                subtitle: 'Show when you\'re online to other users',
                value: _showOnlineStatus,
                onChanged: (value) {
                  setState(() => _showOnlineStatus = value);
                  _saveSetting('privacy_show_online_status', value);
                },
              ),
              _buildSettingTile(
                title: 'Last Seen',
                subtitle: 'Show when you were last active',
                value: _showLastSeen,
                onChanged: (value) {
                  setState(() => _showLastSeen = value);
                  _saveSetting('privacy_show_last_seen', value);
                },
              ),
              _buildSettingTile(
                title: 'Profile Photo',
                subtitle: 'Allow others to see your profile photo',
                value: _showProfilePhoto,
                onChanged: (value) {
                  setState(() => _showProfilePhoto = value);
                  _saveSetting('privacy_show_profile_photo', value);
                },
              ),
              _buildSettingTile(
                title: 'Phone Number',
                subtitle: 'Show your phone number in your profile',
                value: _showPhoneNumber,
                onChanged: (value) {
                  setState(() => _showPhoneNumber = value);
                  _saveSetting('privacy_show_phone_number', value);
                },
              ),
            ],
          ),

          // Messages
          _buildCardSection(
            icon: Icons.message,
            title: 'Messages',
            children: [
              _buildSettingTile(
                title: 'Read Receipts',
                subtitle: 'Let others know when you\'ve read their messages',
                value: _readReceipts,
                onChanged: (value) {
                  setState(() => _readReceipts = value);
                  _saveSetting('privacy_read_receipts', value);
                },
              ),
              _buildSettingTile(
                title: 'Message Requests',
                subtitle: 'Allow messages from users you haven\'t chatted with',
                value: _allowMessageRequests,
                onChanged: (value) {
                  setState(() => _allowMessageRequests = value);
                  _saveSetting('privacy_allow_message_requests', value);
                },
              ),
              _buildSettingTile(
                title: 'Block Unknown Users',
                subtitle: 'Automatically block messages from unknown users',
                value: _blockUnknownUsers,
                onChanged: (value) {
                  setState(() => _blockUnknownUsers = value);
                  _saveSetting('privacy_block_unknown_users', value);
                },
              ),
            ],
          ),

          // Data & Privacy
          _buildCardSection(
            icon: Icons.security,
            title: 'Data & Privacy',
            children: [
              _buildSettingTile(
                title: 'Share Usage Data',
                subtitle:
                    'Help improve the app by sharing anonymous usage data',
                value: _shareUsageData,
                onChanged: (value) {
                  setState(() => _shareUsageData = value);
                  _saveSetting('privacy_share_usage_data', value);
                },
              ),
              _buildSettingTile(
                title: 'Personalized Ads',
                subtitle: 'Show ads based on your interests and activity',
                value: _personalizedAds,
                onChanged: (value) {
                  setState(() => _personalizedAds = value);
                  _saveSetting('privacy_personalized_ads', value);
                },
              ),
              _buildSettingTile(
                title: 'Location Sharing',
                subtitle:
                    'Allow the app to access your location for job matching',
                value: _locationSharing,
                onChanged: (value) {
                  setState(() => _locationSharing = value);
                  _saveSetting('privacy_location_sharing', value);
                },
              ),
            ],
          ),

          // Action buttons
          Container(
            margin: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showBlockedUsers,
                    icon: const Icon(Icons.block),
                    label: const Text('Manage Blocked Users'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[50],
                      foregroundColor: Colors.red[700],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _deleteAccount,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- Main Build Method ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Settings',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: _callSupport,
          ),
          if (_tabController.index == 2) // Info icon only on Privacy tab
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showPrivacyInfo,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Help & Support', icon: Icon(Icons.help_outline)),
            Tab(text: 'Notifications', icon: Icon(Icons.notifications)),
            Tab(text: 'Privacy', icon: Icon(Icons.security)),
          ],
          onTap: (index) {
            setState(() {
              // Rebuild the AppBar to show/hide the Info icon
            });
          },
        ),
      ),
      body: Column(
        children: [
          // Blue header section with search (kept in app bar section)
          Container(
            color: _primaryColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: _tabController.index == 0
                      ? 'Search Help Topics'
                      : _tabController.index == 1
                          ? 'Search Notification Settings'
                          : 'Search Privacy Settings',
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHelpSupportTab(),
                _buildNotificationsTab(),
                _buildPrivacyTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}