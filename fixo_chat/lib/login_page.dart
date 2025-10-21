import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../register/tradie_register_page.dart';
import '../register/homeowner_register_page.dart';
import '../users/user_list_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String email = '';
  String password = '';
  bool loading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void login() async {
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter email and password')));
      return;
    }

    setState(() => loading = true);

    try {
      // Login with Firebase Auth
      UserCredential cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      User? user = cred.user;

      if (user != null) {
        // Fetch user role from Firestore
        var userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('User data not found')));
          setState(() => loading = false);
          return;
        }

        String role = userDoc['role'];

        // Navigate to User List page filtered by role
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => UserListPage(
              currentUserId: user.uid,
              currentUserRole: role,
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Login Failed: ${e.message}')));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              decoration: InputDecoration(labelText: 'Email'),
              onChanged: (val) => email = val,
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
              onChanged: (val) => password = val,
            ),
            SizedBox(height: 20),
            loading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: login,
                    child: Text('Login'),
                  ),
            SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => TradieRegisterPage())),
              child: Text('Register as Tradie'),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => HomeOwnerRegisterPage())),
              child: Text('Register as Homeowner'),
            ),
          ],
        ),
      ),
    );
  }
}
