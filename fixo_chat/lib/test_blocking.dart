import 'package:flutter/material.dart';
import 'services/chat_service.dart';

class TestBlockingWidget extends StatefulWidget {
  const TestBlockingWidget({super.key});

  @override
  State<TestBlockingWidget> createState() => _TestBlockingWidgetState();
}

class _TestBlockingWidgetState extends State<TestBlockingWidget> {
  final ChatService _chatService = ChatService();
  final TextEditingController _userIdController = TextEditingController();
  String _status = 'Ready to test';
  bool _isLoading = false;

  Future<void> _testBlockUser() async {
    if (_userIdController.text.isEmpty) {
      setState(() {
        _status = 'Please enter a user ID';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Blocking user...';
    });

    try {
      await _chatService.blockUser(_userIdController.text);
      setState(() {
        _status = 'User blocked successfully!';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error blocking user: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testUnblockUser() async {
    if (_userIdController.text.isEmpty) {
      setState(() {
        _status = 'Please enter a user ID';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Unblocking user...';
    });

    try {
      await _chatService.unblockUser(_userIdController.text);
      setState(() {
        _status = 'User unblocked successfully!';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error unblocking user: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkBlockStatus() async {
    if (_userIdController.text.isEmpty) {
      setState(() {
        _status = 'Please enter a user ID';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Checking block status...';
    });

    try {
      final isBlocked = await _chatService.isUserBlocked(
        _userIdController.text,
      );
      setState(() {
        _status = 'User is ${isBlocked ? 'BLOCKED' : 'NOT BLOCKED'}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error checking status: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Blocking Feature'),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _userIdController,
              decoration: const InputDecoration(
                labelText: 'User ID to test',
                hintText: 'Enter any user ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _isLoading ? null : _testBlockUser,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Block User'),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: _isLoading ? null : _testUnblockUser,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Unblock User'),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: _isLoading ? null : _checkBlockStatus,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Check Block Status'),
            ),

            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_isLoading)
                    const Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text('Processing...'),
                      ],
                    )
                  else
                    Text(
                      _status,
                      style: TextStyle(
                        color: _status.contains('Error')
                            ? Colors.red
                            : _status.contains('successfully')
                            ? Colors.green
                            : Colors.black,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Instructions:\n'
              '1. Enter any user ID (can be fake for testing)\n'
              '2. Try blocking the user\n'
              '3. Check the status to verify\n'
              '4. Try unblocking the user\n'
              '5. Check status again',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
