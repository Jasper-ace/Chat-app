import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/message_type_converter.dart';

enum MessageType { text, image, system }

class MessageModel {
  final String id; // Firestore document ID
  final int threadId; // Reference to thread document
  final int senderId; // ID of the sender (tradie or homeowner)
  final String senderType; // "tradie" or "homeowner"
  final String content; // Message text
  final DateTime date; // When the message was sent
  final MessageType messageType;
  final String? imageUrl;
  final String? imageThumbnail;
  final bool read;
  final bool isDeleted;
  final bool isUnsent;
  final bool isEdited;
  final DateTime? editedAt;
  final int? deletedBy;
  final String? chatId; // For backward compatibility
  final Map<String, dynamic>? replyTo; // Reply information
  final String? replyToMessageId; // ID of message being replied to

  MessageModel({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.senderType,
    required this.content,
    required this.date,
    this.messageType = MessageType.text,
    this.imageUrl,
    this.imageThumbnail,
    this.read = false,
    this.isDeleted = false,
    this.isUnsent = false,
    this.isEdited = false,
    this.editedAt,
    this.deletedBy,
    this.chatId,
    this.replyTo,
    this.replyToMessageId,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return MessageModel(
      id: doc.id,
      threadId: MessageTypeConverter.convertUserId(data['thread_id'] ?? 0),
      senderId: MessageTypeConverter.convertSenderId(data['sender_id'] ?? 0),
      senderType: data['sender_type'] ?? '',
      content: data['content'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      messageType: _parseMessageType(data['messageType']),
      imageUrl: data['imageUrl'],
      imageThumbnail: data['imageThumbnail'],
      read: data['read'] ?? false,
      isDeleted: data['isDeleted'] ?? false,
      isUnsent: data['isUnsent'] ?? false,
      isEdited: data['isEdited'] ?? false,
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
      deletedBy: MessageTypeConverter.convertUserId(data['deletedBy']),
      chatId: data['chatId'],
      replyTo: data['reply_to'] as Map<String, dynamic>?,
      replyToMessageId: data['reply_to_message_id'],
    );
  }

  static MessageType _parseMessageType(dynamic value) {
    if (value == null) return MessageType.text;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'image':
          return MessageType.image;
        case 'system':
          return MessageType.system;
        default:
          return MessageType.text;
      }
    }
    return MessageType.text;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'thread_id': threadId,
      'sender_id': senderId,
      'sender_type': senderType,
      'content': content,
      'date': Timestamp.fromDate(date),
      'messageType': messageType.name,
      'imageUrl': imageUrl,
      'imageThumbnail': imageThumbnail,
      'read': read,
      'isDeleted': isDeleted,
      'isUnsent': isUnsent,
      'isEdited': isEdited,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'deletedBy': deletedBy,
      'chatId': chatId,
      'reply_to': replyTo,
      'reply_to_message_id': replyToMessageId,
    };
  }

  MessageModel copyWith({
    String? id,
    int? threadId,
    int? senderId,
    String? senderType,
    String? content,
    DateTime? date,
    MessageType? messageType,
    String? imageUrl,
    String? imageThumbnail,
    bool? read,
    bool? isDeleted,
    bool? isUnsent,
    bool? isEdited,
    DateTime? editedAt,
    int? deletedBy,
    String? chatId,
    Map<String, dynamic>? replyTo,
    String? replyToMessageId,
  }) {
    return MessageModel(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      senderId: senderId ?? this.senderId,
      senderType: senderType ?? this.senderType,
      content: content ?? this.content,
      date: date ?? this.date,
      messageType: messageType ?? this.messageType,
      imageUrl: imageUrl ?? this.imageUrl,
      imageThumbnail: imageThumbnail ?? this.imageThumbnail,
      read: read ?? this.read,
      isDeleted: isDeleted ?? this.isDeleted,
      isUnsent: isUnsent ?? this.isUnsent,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      chatId: chatId ?? this.chatId,
      replyTo: replyTo ?? this.replyTo,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
    );
  }
}
