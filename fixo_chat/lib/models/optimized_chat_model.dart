import 'package:cloud_firestore/cloud_firestore.dart';

// Optimized Chat Model with integrated typing status
class OptimizedChatModel {
  final String id;
  final List<String> participants;
  final List<String> participantTypes;
  final String lastMessage;
  final DateTime lastMessageTimestamp;
  final String lastSenderId;
  final String? jobId;
  final String? jobTitle;
  final bool isArchived;
  final Map<String, int> unreadCount;
  final Map<String, DateTime?> typingStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  OptimizedChatModel({
    required this.id,
    required this.participants,
    required this.participantTypes,
    required this.lastMessage,
    required this.lastMessageTimestamp,
    required this.lastSenderId,
    this.jobId,
    this.jobTitle,
    this.isArchived = false,
    this.unreadCount = const {},
    this.typingStatus = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory OptimizedChatModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Parse unread count
    Map<String, int> unreadCountMap = {};
    if (data['unread_count'] != null) {
      Map<String, dynamic> unreadData =
          data['unread_count'] as Map<String, dynamic>;
      unreadData.forEach((userId, count) {
        unreadCountMap[userId] = count as int? ?? 0;
      });
    }

    // Parse typing status
    Map<String, DateTime?> typingStatusMap = {};
    if (data['typing_status'] != null) {
      Map<String, dynamic> typingData =
          data['typing_status'] as Map<String, dynamic>;
      typingData.forEach((userId, timestamp) {
        if (timestamp is Timestamp) {
          typingStatusMap[userId] = timestamp.toDate();
        } else {
          typingStatusMap[userId] = null;
        }
      });
    }

    return OptimizedChatModel(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      participantTypes: List<String>.from(data['participant_types'] ?? []),
      lastMessage: data['last_message'] ?? '',
      lastMessageTimestamp:
          (data['last_message_timestamp'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      lastSenderId: data['last_sender_id'] ?? '',
      jobId: data['job_id'],
      jobTitle: data['job_title'],
      isArchived: data['is_archived'] ?? false,
      unreadCount: unreadCountMap,
      typingStatus: typingStatusMap,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    Map<String, dynamic> unreadCountData = {};
    unreadCount.forEach((userId, count) {
      unreadCountData[userId] = count;
    });

    Map<String, dynamic> typingStatusData = {};
    typingStatus.forEach((userId, timestamp) {
      typingStatusData[userId] = timestamp != null
          ? Timestamp.fromDate(timestamp)
          : null;
    });

    return {
      'participants': participants,
      'participant_types': participantTypes,
      'last_message': lastMessage,
      'last_message_timestamp': Timestamp.fromDate(lastMessageTimestamp),
      'last_sender_id': lastSenderId,
      'job_id': jobId,
      'job_title': jobTitle,
      'is_archived': isArchived,
      'unread_count': unreadCountData,
      'typing_status': typingStatusData,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  // Helper methods
  bool isUserTyping(String userId) {
    final typingTime = typingStatus[userId];
    if (typingTime == null) return false;

    final now = DateTime.now();
    final difference = now.difference(typingTime);
    return difference.inSeconds <= 3;
  }

  List<String> getActiveTypingUsers() {
    final now = DateTime.now();
    return typingStatus.entries
        .where(
          (entry) =>
              entry.value != null &&
              now.difference(entry.value!).inSeconds <= 3,
        )
        .map((entry) => entry.key)
        .toList();
  }

  String getOtherParticipantId(String currentUserId) {
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  int getUnreadCountForUser(String userId) {
    return unreadCount[userId] ?? 0;
  }

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

  OptimizedChatModel copyWith({
    String? id,
    List<String>? participants,
    List<String>? participantTypes,
    String? lastMessage,
    DateTime? lastMessageTimestamp,
    String? lastSenderId,
    String? jobId,
    String? jobTitle,
    bool? isArchived,
    Map<String, int>? unreadCount,
    Map<String, DateTime?>? typingStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OptimizedChatModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      participantTypes: participantTypes ?? this.participantTypes,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      jobId: jobId ?? this.jobId,
      jobTitle: jobTitle ?? this.jobTitle,
      isArchived: isArchived ?? this.isArchived,
      unreadCount: unreadCount ?? this.unreadCount,
      typingStatus: typingStatus ?? this.typingStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Optimized Message Model
class OptimizedMessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String senderType;
  final String content;
  final String messageType;
  final DateTime timestamp;
  final Map<String, DateTime?> readBy;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String? mediaUrl;
  final String? mediaThumbnail;

  OptimizedMessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderType,
    required this.content,
    this.messageType = 'text',
    required this.timestamp,
    this.readBy = const {},
    this.editedAt,
    this.deletedAt,
    this.mediaUrl,
    this.mediaThumbnail,
  });

  factory OptimizedMessageModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Parse read_by status
    Map<String, DateTime?> readByMap = {};
    if (data['read_by'] != null) {
      Map<String, dynamic> readData = data['read_by'] as Map<String, dynamic>;
      readData.forEach((userId, timestamp) {
        if (timestamp is Timestamp) {
          readByMap[userId] = timestamp.toDate();
        } else {
          readByMap[userId] = null;
        }
      });
    }

    return OptimizedMessageModel(
      id: doc.id,
      chatId: data['chat_id'] ?? '',
      senderId: data['sender_id'] ?? '',
      senderType: data['sender_type'] ?? '',
      content: data['content'] ?? '',
      messageType: data['message_type'] ?? 'text',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readBy: readByMap,
      editedAt: (data['edited_at'] as Timestamp?)?.toDate(),
      deletedAt: (data['deleted_at'] as Timestamp?)?.toDate(),
      mediaUrl: data['media_url'],
      mediaThumbnail: data['media_thumbnail'],
    );
  }

  Map<String, dynamic> toFirestore() {
    Map<String, dynamic> readByData = {};
    readBy.forEach((userId, timestamp) {
      readByData[userId] = timestamp != null
          ? Timestamp.fromDate(timestamp)
          : null;
    });

    return {
      'chat_id': chatId,
      'sender_id': senderId,
      'sender_type': senderType,
      'content': content,
      'message_type': messageType,
      'timestamp': Timestamp.fromDate(timestamp),
      'read_by': readByData,
      'edited_at': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'deleted_at': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'media_url': mediaUrl,
      'media_thumbnail': mediaThumbnail,
    };
  }

  bool isReadBy(String userId) {
    return readBy[userId] != null;
  }

  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null;
  bool get hasMedia => mediaUrl != null;
}
