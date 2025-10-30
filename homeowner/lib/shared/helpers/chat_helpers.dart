import 'package:flutter/material.dart';
import '../screens/chat_list_screen.dart';
import '../screens/chat_screen.dart';
import '../models/user_model.dart';

class ChatHelpers {
  // Open chat list for a specific user type
  static void openChatList(
    BuildContext context,
    String userType,
    int currentUserId,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatListScreen(
          currentUserType: userType,
          currentUserId: currentUserId,
        ),
      ),
    );
  }

  // Open direct chat with another user
  static void openChat(
    BuildContext context, {
    required String currentUserType,
    required int currentUserId,
    required UserModel otherUser,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUser: otherUser,
          currentUserType: currentUserType,
          currentUserId: currentUserId,
        ),
      ),
    );
  }

  // Get user type display name
  static String getUserTypeDisplayName(String userType) {
    switch (userType) {
      case 'homeowner':
        return 'Homeowner';
      case 'tradie':
        return 'Tradie';
      default:
        return 'User';
    }
  }
}
