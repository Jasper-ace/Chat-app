import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'laravel_api_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Generate consistent chat ID between two users
  String _getChatId(String userId, String otherUserId) {
    return userId.hashCode <= otherUserId.hashCode
        ? '$userId-$otherUserId'
        : '$otherUserId-$userId';
  }

  // Send a message
  Future<void> sendMessage({
    required String receiverId,
    required String message,
    required String senderUserType, // 'homeowner' or 'tradie'
    required String receiverUserType, // 'homeowner' or 'tradie'
  }) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final chatId = _getChatId(currentUser.uid, receiverId);

      // Add message to messages collection
      await _firestore.collection('messages').add({
        'chatId': chatId,
        'senderId': currentUser.uid,
        'receiverId': receiverId,
        'senderUserType': senderUserType,
        'receiverUserType': receiverUserType,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Update chat metadata
      await _firestore.collection('chats').doc(chatId).set({
        'participants': [currentUser.uid, receiverId],
        'participantTypes': [senderUserType, receiverUserType],
        'lastMessage': message,
        'lastSenderId': currentUser.uid,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also save to Laravel database
      await LaravelApiService.saveMessageToLaravel(
        senderFirebaseUid: currentUser.uid,
        receiverFirebaseUid: receiverId,
        senderType: senderUserType,
        receiverType: receiverUserType,
        message: message,
      );
    } catch (e) {
      print('Send message error: $e');
      rethrow;
    }
  }

  // Get messages for a chat
  Stream<QuerySnapshot> getMessages(String otherUserId) {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final chatId = _getChatId(currentUser.uid, otherUserId);

    return _firestore
        .collection('messages')
        .where('chatId', isEqualTo: chatId)
        .snapshots();
  }

  // Get users of opposite type for chat
  Stream<QuerySnapshot> getAvailableUsers(String currentUserType) {
    String targetCollection = currentUserType == 'homeowner'
        ? 'tradies'
        : 'homeowners';

    return _firestore.collection(targetCollection).orderBy('name').snapshots();
  }

  // Get recent chats for current user
  Stream<QuerySnapshot> getRecentChats() {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('lastTimestamp', descending: true)
        .snapshots();
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String otherUserId) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final chatId = _getChatId(currentUser.uid, otherUserId);

      // Get unread messages from other user
      QuerySnapshot unreadMessages = await _firestore
          .collection('messages')
          .where('chatId', isEqualTo: chatId)
          .where('senderId', isEqualTo: otherUserId)
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('read', isEqualTo: false)
          .get();

      // Mark them as read
      WriteBatch batch = _firestore.batch();
      for (QueryDocumentSnapshot doc in unreadMessages.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();

      // Also mark as read in Laravel
      await LaravelApiService.markMessagesAsRead(
        senderFirebaseUid: otherUserId,
        receiverFirebaseUid: currentUser.uid,
      );
    } catch (e) {
      print('Mark messages as read error: $e');
      rethrow;
    }
  }

  // Get unread message count
  Future<int> getUnreadMessageCount() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return 0;

      QuerySnapshot unreadMessages = await _firestore
          .collection('messages')
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('read', isEqualTo: false)
          .get();

      return unreadMessages.docs.length;
    } catch (e) {
      print('Get unread count error: $e');
      return 0;
    }
  }

  // Get user info from either collection
  Future<DocumentSnapshot?> getUserInfo(String userId, String userType) async {
    try {
      String collection = userType == 'homeowner' ? 'homeowners' : 'tradies';
      return await _firestore.collection(collection).doc(userId).get();
    } catch (e) {
      print('Get user info error: $e');
      return null;
    }
  }

  // Search users by name
  Stream<QuerySnapshot> searchUsers(
    String currentUserType,
    String searchQuery,
  ) {
    String targetCollection = currentUserType == 'homeowner'
        ? 'tradies'
        : 'homeowners';

    return _firestore
        .collection(targetCollection)
        .where('name', isGreaterThanOrEqualTo: searchQuery)
        .where('name', isLessThanOrEqualTo: '$searchQuery\uf8ff')
        .snapshots();
  }
}
