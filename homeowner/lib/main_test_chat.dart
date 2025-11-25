import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/firebase_options.dart';
import 'features/chat/views/test_chat_screen.dart';

/// Test Chat App
/// Run this to test the chat functionality
///
/// Usage:
/// flutter run -t lib/main_test_chat.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TestChatApp());
}

class TestChatApp extends StatelessWidget {
  const TestChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const TestChatScreen(),
    );
  }
}
