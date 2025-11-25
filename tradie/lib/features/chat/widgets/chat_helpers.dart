import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChatHelpers {
  // Open chat list
  static void openChatList(
    BuildContext context,
    String userType,
    int currentUserId,
  ) {
    context.push('/chats');
  }

  // Open direct chat with another user
  static void openChat(
    BuildContext context, {
    required String chatId,
    required String otherUserName,
    required String otherUserId,
    required String otherUserType,
  }) {
    context.push(
      '/chat/$chatId',
      extra: {
        'otherUserName': otherUserName,
        'otherUserId': otherUserId,
        'otherUserType': otherUserType,
      },
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
