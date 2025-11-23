import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class MessageSortingService {
  static Future<List<UserModel>> sortUsersByLastMessage(
    List<UserModel> users,
    String currentUserType,
    int currentUserId,
  ) async {
    // Create a list of users with their last message timestamps
    List<UserWithTimestamp> usersWithTimestamps = [];

    for (final user in users) {
      final timestamp = await _getLastMessageTimestamp(
        user,
        currentUserType,
        currentUserId,
      );
      usersWithTimestamps.add(UserWithTimestamp(user, timestamp));
    }

    // Sort by timestamp (most recent first)
    usersWithTimestamps.sort((a, b) {
      // Handle null timestamps (users with no messages go to bottom)
      if (a.timestamp == null && b.timestamp == null) {
        return a.user.name.compareTo(b.user.name);
      }
      if (a.timestamp == null) return 1;
      if (b.timestamp == null) return -1;

      return b.timestamp!.compareTo(a.timestamp!);
    });

    return usersWithTimestamps.map((e) => e.user).toList();
  }

  static Future<DateTime?> _getLastMessageTimestamp(
    UserModel user,
    String currentUserType,
    int currentUserId,
  ) async {
    try {
      // Determine tradie and homeowner IDs
      int tradieId, homeownerId;
      if (currentUserType == 'tradie') {
        tradieId = currentUserId;
        homeownerId = int.parse(user.id);
      } else {
        tradieId = int.parse(user.id);
        homeownerId = currentUserId;
      }

      // Find thread
      final threadQuery = await FirebaseFirestore.instance
          .collection('threads')
          .where('tradie_id', isEqualTo: tradieId)
          .where('homeowner_id', isEqualTo: homeownerId)
          .limit(1)
          .get();

      if (threadQuery.docs.isEmpty) return null;

      final threadDoc = threadQuery.docs.first;
      final threadData = threadDoc.data();

      // Get the most recent message timestamp
      final messagesQuery = await FirebaseFirestore.instance
          .collection('threads')
          .doc(threadDoc.id)
          .collection('messages')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (messagesQuery.docs.isNotEmpty) {
        final lastMessage = messagesQuery.docs.first.data();
        final timestamp = lastMessage['date'];

        if (timestamp is Timestamp) {
          return timestamp.toDate();
        } else if (timestamp is DateTime) {
          return timestamp;
        }
      }

      // Fallback to thread's last message time
      final lastMessageTime = threadData['last_message_time'];
      if (lastMessageTime is Timestamp) {
        return lastMessageTime.toDate();
      } else if (lastMessageTime is DateTime) {
        return lastMessageTime;
      }

      return null;
    } catch (e) {
      print('Error getting last message timestamp: $e');
      return null;
    }
  }
}

class UserWithTimestamp {
  final UserModel user;
  final DateTime? timestamp;

  UserWithTimestamp(this.user, this.timestamp);
}
