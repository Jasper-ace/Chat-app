import 'package:cloud_firestore/cloud_firestore.dart';

class TypingIndicatorModel {
  final String chatId;
  final Map<String, DateTime> typingUsers;
  final DateTime updatedAt;

  TypingIndicatorModel({
    required this.chatId,
    required this.typingUsers,
    required this.updatedAt,
  });

  factory TypingIndicatorModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    Map<String, DateTime> typingUsersMap = {};
    if (data['typingUsers'] != null) {
      Map<String, dynamic> typingData =
          data['typingUsers'] as Map<String, dynamic>;
      typingData.forEach((userId, timestamp) {
        if (timestamp is Timestamp) {
          typingUsersMap[userId] = timestamp.toDate();
        }
      });
    }

    return TypingIndicatorModel(
      chatId: doc.id,
      typingUsers: typingUsersMap,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    Map<String, dynamic> typingUsersData = {};
    typingUsers.forEach((userId, timestamp) {
      typingUsersData[userId] = Timestamp.fromDate(timestamp);
    });

    return {
      'typingUsers': typingUsersData,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  TypingIndicatorModel copyWith({
    String? chatId,
    Map<String, DateTime>? typingUsers,
    DateTime? updatedAt,
  }) {
    return TypingIndicatorModel(
      chatId: chatId ?? this.chatId,
      typingUsers: typingUsers ?? this.typingUsers,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods
  bool isUserTyping(String userId) {
    if (!typingUsers.containsKey(userId)) return false;

    final typingTime = typingUsers[userId]!;
    final now = DateTime.now();
    final difference = now.difference(typingTime);

    // Consider user typing if last update was within 3 seconds
    return difference.inSeconds <= 3;
  }

  List<String> getActiveTypingUsers() {
    final now = DateTime.now();
    return typingUsers.entries
        .where((entry) => now.difference(entry.value).inSeconds <= 3)
        .map((entry) => entry.key)
        .toList();
  }

  bool get hasActiveTypingUsers => getActiveTypingUsers().isNotEmpty;

  int get activeTypingCount => getActiveTypingUsers().length;

  // Add or update typing status for a user
  TypingIndicatorModel addTypingUser(String userId) {
    final updatedTypingUsers = Map<String, DateTime>.from(typingUsers);
    updatedTypingUsers[userId] = DateTime.now();

    return copyWith(typingUsers: updatedTypingUsers, updatedAt: DateTime.now());
  }

  // Remove typing status for a user
  TypingIndicatorModel removeTypingUser(String userId) {
    final updatedTypingUsers = Map<String, DateTime>.from(typingUsers);
    updatedTypingUsers.remove(userId);

    return copyWith(typingUsers: updatedTypingUsers, updatedAt: DateTime.now());
  }

  // Clean up expired typing indicators
  TypingIndicatorModel cleanupExpiredUsers() {
    final now = DateTime.now();
    final activeUsers = <String, DateTime>{};

    typingUsers.forEach((userId, timestamp) {
      if (now.difference(timestamp).inSeconds <= 3) {
        activeUsers[userId] = timestamp;
      }
    });

    return copyWith(typingUsers: activeUsers, updatedAt: DateTime.now());
  }

  // Generate display text for typing indicators
  String getTypingDisplayText(Map<String, String> userNames) {
    final activeUsers = getActiveTypingUsers();

    if (activeUsers.isEmpty) return '';

    if (activeUsers.length == 1) {
      final userName = userNames[activeUsers.first] ?? 'Someone';
      return '$userName is typing...';
    } else if (activeUsers.length == 2) {
      final user1 = userNames[activeUsers[0]] ?? 'Someone';
      final user2 = userNames[activeUsers[1]] ?? 'Someone';
      return '$user1 and $user2 are typing...';
    } else {
      return 'Multiple people are typing...';
    }
  }
}
