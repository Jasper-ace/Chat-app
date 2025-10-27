import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final List<String> participantTypes;
  final String lastMessage;
  final DateTime lastMessageTimestamp;
  final String lastSenderId;
  final String? jobId;
  final String? jobTitle;
  final bool isArchived;
  final bool isBlocked;
  final String? blockedBy;
  final int unreadCount;
  final UserModel? otherUser;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatModel({
    required this.id,
    required this.participants,
    required this.participantTypes,
    required this.lastMessage,
    required this.lastMessageTimestamp,
    required this.lastSenderId,
    this.jobId,
    this.jobTitle,
    this.isArchived = false,
    this.isBlocked = false,
    this.blockedBy,
    this.unreadCount = 0,
    this.otherUser,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatModel.fromFirestore(
    DocumentSnapshot doc, {
    UserModel? otherUser,
  }) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return ChatModel(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      participantTypes: List<String>.from(data['participantTypes'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTimestamp:
          (data['lastMessageTimestamp'] as Timestamp?)?.toDate() ??
          (data['lastTimestamp'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      lastSenderId: data['lastSenderId'] ?? '',
      jobId: data['jobId'],
      jobTitle: data['jobTitle'],
      isArchived: data['isArchived'] ?? false,
      isBlocked: data['isBlocked'] ?? false,
      blockedBy: data['blockedBy'],
      unreadCount: data['unreadCount'] ?? 0,
      otherUser: otherUser,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'participants': participants,
      'participantTypes': participantTypes,
      'lastMessage': lastMessage,
      'lastMessageTimestamp': Timestamp.fromDate(lastMessageTimestamp),
      'lastSenderId': lastSenderId,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'isArchived': isArchived,
      'isBlocked': isBlocked,
      'blockedBy': blockedBy,
      'unreadCount': unreadCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ChatModel copyWith({
    String? id,
    List<String>? participants,
    List<String>? participantTypes,
    String? lastMessage,
    DateTime? lastMessageTimestamp,
    String? lastSenderId,
    String? jobId,
    String? jobTitle,
    bool? isArchived,
    bool? isBlocked,
    String? blockedBy,
    int? unreadCount,
    UserModel? otherUser,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      participantTypes: participantTypes ?? this.participantTypes,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      jobId: jobId ?? this.jobId,
      jobTitle: jobTitle ?? this.jobTitle,
      isArchived: isArchived ?? this.isArchived,
      isBlocked: isBlocked ?? this.isBlocked,
      blockedBy: blockedBy ?? this.blockedBy,
      unreadCount: unreadCount ?? this.unreadCount,
      otherUser: otherUser ?? this.otherUser,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper method to get the other participant's ID
  String getOtherParticipantId(String currentUserId) {
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  // Helper method to check if current user is the last sender
  bool isLastMessageFromMe(String currentUserId) {
    return lastSenderId == currentUserId;
  }

  // Helper method to get display title
  String get displayTitle {
    if (jobTitle != null && jobTitle!.isNotEmpty) {
      return jobTitle!;
    }
    if (otherUser != null) {
      return otherUser!.displayName;
    }
    return 'Chat';
  }

  // Helper method to get last message preview
  String get lastMessagePreview {
    if (lastMessage.isEmpty) return 'No messages yet';
    if (lastMessage.length > 50) {
      return '${lastMessage.substring(0, 50)}...';
    }
    return lastMessage;
  }
}
