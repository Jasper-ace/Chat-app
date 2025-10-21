import 'package:flutter/material.dart';
import '../screens/chat_list_screen.dart';
import '../screens/chat_screen.dart';
import '../models/user_model.dart';

class ChatHelpers {
  // Open chat list for a specific user type
  static void openChatList(BuildContext context, String userType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatListScreen(currentUserType: userType),
      ),
    );
  }

  // Open specific chat with another user
  static void openChat(
    BuildContext context, {
    required UserModel otherUser,
    required String currentUserType,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChatScreen(otherUser: otherUser, currentUserType: currentUserType),
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
        return userType;
    }
  }

  // Get opposite user type
  static String getOppositeUserType(String userType) {
    return userType == 'homeowner' ? 'tradie' : 'homeowner';
  }

  // Get collection name for user type
  static String getCollectionName(String userType) {
    return userType == 'homeowner' ? 'homeowners' : 'tradies';
  }
}
