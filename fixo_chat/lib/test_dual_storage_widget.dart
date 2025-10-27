import 'package:flutter/material.dart';
import 'services/dual_storage_service.dart';

class TestDualStorageWidget extends StatefulWidget {
  const TestDualStorageWidget({super.key});

  @override
  _TestDualStorageWidgetState createState() => _TestDualStorageWidgetState();
}

class _TestDualStorageWidgetState extends State<TestDualStorageWidget> {
  final DualStorageService _dualStorage = DualStorageService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  bool _isLoading = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    // Set default values for testing
    _emailController.text =
        'test${DateTime.now().millisecondsSinceEpoch}@example.com';
    _passwordController.text = 'password123';
    _firstNameController.text = 'Test';
    _lastNameController.text = 'User';
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing Laravel connection...';
    });

    try {
      final success = await _dualStorage.testLaravelConnection();
      setState(() {
        _status = success
            ? '✅ Laravel API connection successful!'
            : '❌ Laravel API connection failed!';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Connection test error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testRegistration() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _status = '❌ Please fill in email and password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Creating account with dual storage...';
    });

    try {
      final result = await _dualStorage.registerUser(
        email: _emailController.text,
        password: _passwordController.text,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        userType: 'homeowner',
        phone: '+1234567890',
        address: '123 Test Street',
        city: 'Test City',
        region: 'Test Region',
      );

      if (result?.user != null) {
        setState(() {
          _status =
              '🎉 SUCCESS! Account created and saved to both Firebase and MySQL!\n'
              'Firebase UID: ${result!.user!.uid}\n'
              'Check console logs for detailed information.';
        });
      } else {
        setState(() {
          _status = '❌ Registration failed - no user returned';
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Registration error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Dual Storage'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Dual Storage Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Test Connection Button
            ElevatedButton(
              onPressed: _isLoading ? null : _testConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Test Laravel Connection',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),

            // Form Fields
            TextField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'First Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Last Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),

            // Test Registration Button
            ElevatedButton(
              onPressed: _isLoading ? null : _testRegistration,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Test Dual Storage Registration',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 20),

            // Status Display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[50],
              ),
              child: Text(
                _status.isEmpty ? 'Ready to test...' : _status,
                style: const TextStyle(fontSize: 14),
              ),
            ),

            const SizedBox(height: 20),

            // Instructions
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. First test the Laravel connection'),
                    Text('2. If connection works, test registration'),
                    Text('3. Check console logs for detailed information'),
                    Text(
                      '4. Verify in database: http://127.0.0.1:8000/api/get-homeowners',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }
}
