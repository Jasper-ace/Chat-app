import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat_screen.dart';

class UserListScreen extends StatefulWidget {
  final String userType; // 'tradie' or 'homeowner'
  final Map<String, dynamic> loggedInUser;

  const UserListScreen({
    super.key,
    required this.userType,
    required this.loggedInUser,
  });

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  List users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final otherType = widget.userType == 'tradie' ? 'homeowners' : 'tradies';
    final url = Uri.parse('http://10.0.2.2:8000/api/$otherType');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          users = data['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.userType == 'tradie' ? "Homeowners" : "Tradies";

    return Scaffold(
      appBar: AppBar(
        title: Text("Fixo Chat - $title"),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final name =
                    user['name'] ??
                    "${user['first_name'] ?? ''} ${user['last_name'] ?? ''}"
                        .trim();
                final receiverType = widget.userType == 'tradie'
                    ? 'Homeowner'
                    : 'Tradie';

                return ListTile(
                  title: Text(name),
                  subtitle: Text(user['email'] ?? ''),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          receiverId: user['id'],
                          receiverType: receiverType,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
