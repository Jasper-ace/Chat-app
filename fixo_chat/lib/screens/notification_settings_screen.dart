import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  // Message settings
  bool _newMessages = true;
  bool _messagePreview = true;
  bool _messageSound = true;

  // Job update settings
  bool _statusChanges = true;
  bool _newJobRequests = true;
  bool _quotesEstimates = true;

  // General settings
  bool _pushNotifications = true;
  bool _emailNotifications = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A90E2),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.settings, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // Notification Settings Header
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Notification Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Messages Section
                  _buildSectionHeader('Messages', Icons.message),
                  _buildSettingTile(
                    'New Messages',
                    'Get notified when you receive a new message',
                    _newMessages,
                    (value) => setState(() => _newMessages = value),
                  ),
                  _buildSettingTile(
                    'Message Preview',
                    'Show message content in notifications',
                    _messagePreview,
                    (value) => setState(() => _messagePreview = value),
                  ),
                  _buildSettingTile(
                    'Sound',
                    'Play sound for new messages',
                    _messageSound,
                    (value) => setState(() => _messageSound = value),
                  ),

                  const SizedBox(height: 24),

                  // Job Updates Section
                  _buildSectionHeader('Job Updates', Icons.work),
                  _buildSettingTile(
                    'Status Changes',
                    'When job status changes\n(accepted, completed, etc.)',
                    _statusChanges,
                    (value) => setState(() => _statusChanges = value),
                  ),
                  _buildSettingTile(
                    'New Job Requests',
                    'When you receive a new job request',
                    _newJobRequests,
                    (value) => setState(() => _newJobRequests = value),
                  ),
                  _buildSettingTile(
                    'Quotes & Estimates',
                    'When you receive or send quotes',
                    _quotesEstimates,
                    (value) => setState(() => _quotesEstimates = value),
                  ),

                  const SizedBox(height: 24),

                  // General Section
                  _buildSectionHeader('General', Icons.notifications),
                  _buildSettingTile(
                    'Push Notifications',
                    'Enable push notifications on this device',
                    _pushNotifications,
                    (value) => setState(() => _pushNotifications = value),
                  ),
                  _buildSettingTile(
                    'Email Notifications',
                    'Receive notifications via email',
                    _emailNotifications,
                    (value) => setState(() => _emailNotifications = value),
                  ),

                  const SizedBox(height: 32),

                  // Save Button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Save settings
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Settings saved successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A90E2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Save Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF4A90E2),
        ),
      ),
    );
  }
}
