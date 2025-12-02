import 'package:flutter/material.dart';
import '../widgets/realtime_chat_widget.dart';
import '../../../core/services/auth_service.dart';

/// Test Screen for Chat
/// Quick way to test the chat functionality
class TestChatScreen extends StatefulWidget {
  const TestChatScreen({super.key});

  @override
  State<TestChatScreen> createState() => _TestChatScreenState();
}

class _TestChatScreenState extends State<TestChatScreen> {
  final TextEditingController _userIdController = TextEditingController(
    text: '1',
  );
  final TextEditingController _otherUserIdController = TextEditingController(
    text: '2',
  );
  final TextEditingController _nameController = TextEditingController(
    text: 'Test User',
  );

  String _userType = 'homeowner';
  String _otherUserType = 'tradie';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Chat'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Setup Test Chat',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Current User Setup
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Info',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _userIdController,
                      decoration: const InputDecoration(
                        labelText: 'Your User ID',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _userType,
                      decoration: const InputDecoration(
                        labelText: 'Your Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'homeowner',
                          child: Text('Homeowner'),
                        ),
                        DropdownMenuItem(
                          value: 'tradie',
                          child: Text('Tradie'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _userType = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Other User Setup
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chat With',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _otherUserIdController,
                      decoration: const InputDecoration(
                        labelText: 'Other User ID',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Other User Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _otherUserType,
                      decoration: const InputDecoration(
                        labelText: 'Other User Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'homeowner',
                          child: Text('Homeowner'),
                        ),
                        DropdownMenuItem(
                          value: 'tradie',
                          child: Text('Tradie'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _otherUserType = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _startChat,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Start Chat', style: TextStyle(fontSize: 18)),
            ),

            const SizedBox(height: 16),

            Card(
              color: Colors.blue[50],
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 Tips:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('• Make sure Laravel server is running'),
                    Text('• User ID 1 = Homeowner, User ID 2 = Tradie'),
                    Text('• Messages are sent via Laravel API'),
                    Text('• Messages are received in real-time from Firebase'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startChat() async {
    final userId = int.tryParse(_userIdController.text);
    final otherUserId = int.tryParse(_otherUserIdController.text);

    if (userId == null || otherUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid user IDs')),
      );
      return;
    }

    // Save current user info
    await AuthService.saveUserId(userId);
    await AuthService.saveUserType(_userType);

    // Navigate to chat
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RealtimeChatWidget(
            otherUserId: otherUserId,
            otherUserName: _nameController.text,
            otherUserType: _otherUserType,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _otherUserIdController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
