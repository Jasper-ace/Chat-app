import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save or update user info
  Future<void> saveUser(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).set({
      ...data,
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Generate consistent chat ID between two users
  String _getChatId(String userId, String otherUserId) {
    return userId.hashCode <= otherUserId.hashCode
        ? '$userId-$otherUserId'
        : '$otherUserId-$userId';
  }

  /// Send a message
  Future<void> sendMessage(
    String senderId,
    String receiverId,
    String message,
  ) async {
    final chatId = _getChatId(senderId, receiverId);

    await _firestore.collection('chats').doc(chatId).collection('messages').add(
      {
        'senderId': senderId,
        'receiverId': receiverId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false, // mark new messages as unread
      },
    );

    // Optionally store metadata for quick access
    await _firestore.collection('chats').doc(chatId).set({
      'lastMessage': message,
      'lastSenderId': senderId,
      'lastReceiverId': receiverId,
      'lastTimestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get all messages between two users (live stream)
  Stream<QuerySnapshot> getMessages(String userId, String otherUserId) {
    final chatId = _getChatId(userId, otherUserId);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Mark all messages from sender -> receiver as read
  Future<void> markMessagesAsRead(String senderId, String receiverId) async {
    final chatId = _getChatId(senderId, receiverId);
    final unreadMessages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isEqualTo: senderId)
        .where('receiverId', isEqualTo: receiverId)
        .where('read', isEqualTo: false)
        .get();

    for (var doc in unreadMessages.docs) {
      await doc.reference.update({'read': true});
    }
  }

  /// Fetch opposite role users
  Stream<QuerySnapshot> getOtherUsers(
    String currentUserId,
    String currentUserRole,
  ) {
    final targetRole = currentUserRole == 'tradie' ? 'homeowner' : 'tradie';
    return _firestore
        .collection('users')
        .where('role', isEqualTo: targetRole)
        .snapshots();
  }

  /// Get the last message info between two users
  Future<Map<String, dynamic>?> getLastMessage(
    String userId,
    String otherUserId,
  ) async {
    final chatId = _getChatId(userId, otherUserId);
    final query = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return query.docs.first.data();
  }

  /// Stream chat metadata for displaying recent message previews
  Stream<QuerySnapshot> getRecentChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastTimestamp', descending: true)
        .snapshots();
  }

  /// Get user info
  Future<DocumentSnapshot> getUser(String uid) async {
    return await _firestore.collection('users').doc(uid).get();
  }
}
