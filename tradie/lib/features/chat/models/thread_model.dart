import 'package:cloud_firestore/cloud_firestore.dart';

class ThreadModel {
  final String id; // Firestore document ID
  final int sender1; // tradie_id (always tradie)
  final int sender2; // homeowner_id (always homeowner)
  final DateTime createdAt;
  final DateTime updatedAt;
  final String lastMessage;
  final DateTime lastMessageTime;

  ThreadModel({
    required this.id,
    required this.sender1,
    required this.sender2,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessage,
    required this.lastMessageTime,
  });

  factory ThreadModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return ThreadModel(
      id: doc.id,
      sender1: data['sender_1'] ?? 0,
      sender2: data['sender_2'] ?? 0,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessage: data['last_message'] ?? '',
      lastMessageTime:
          (data['last_message_time'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'sender_1': sender1,
      'sender_2': sender2,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'last_message': lastMessage,
      'last_message_time': Timestamp.fromDate(lastMessageTime),
    };
  }

  ThreadModel copyWith({
    String? id,
    int? sender1,
    int? sender2,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessage,
    DateTime? lastMessageTime,
  }) {
    return ThreadModel(
      id: id ?? this.id,
      sender1: sender1 ?? this.sender1,
      sender2: sender2 ?? this.sender2,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
    );
  }

  /// Get the other participant's ID based on current user
  int getOtherParticipantId(int currentUserId, String currentUserType) {
    if (currentUserType == 'tradie') {
      return sender2; // Return homeowner ID
    } else {
      return sender1; // Return tradie ID
    }
  }

  /// Check if user is participant in this thread
  bool isParticipant(int userId, String userType) {
    if (userType == 'tradie') {
      return sender1 == userId;
    } else {
      return sender2 == userId;
    }
  }
}
