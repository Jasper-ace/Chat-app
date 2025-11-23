import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BlockService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Block a user
  static Future<bool> blockUser(
    String blockedUserId,
    String blockedUserType,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Add to blocked users collection
      await _firestore
          .collection('blocked_users')
          .doc('${currentUser.uid}_$blockedUserId')
          .set({
            'blocker_id': currentUser.uid,
            'blocked_user_id': blockedUserId,
            'blocked_user_type': blockedUserType,
            'blocked_at': FieldValue.serverTimestamp(),
            'is_active': true,
          });

      // Also add to user's blocked list for quick access
      await _firestore.collection('users').doc(currentUser.uid).update({
        'blocked_users': FieldValue.arrayUnion([blockedUserId]),
      });

      print('✅ User blocked successfully');
      return true;
    } catch (e) {
      print('❌ Error blocking user: $e');
      return false;
    }
  }

  /// Unblock a user
  static Future<bool> unblockUser(String blockedUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Remove from blocked users collection
      await _firestore
          .collection('blocked_users')
          .doc('${currentUser.uid}_$blockedUserId')
          .delete();

      // Remove from user's blocked list
      await _firestore.collection('users').doc(currentUser.uid).update({
        'blocked_users': FieldValue.arrayRemove([blockedUserId]),
      });

      print('✅ User unblocked successfully');
      return true;
    } catch (e) {
      print('❌ Error unblocking user: $e');
      return false;
    }
  }

  /// Check if a user is blocked
  static Future<bool> isUserBlocked(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final doc = await _firestore
          .collection('blocked_users')
          .doc('${currentUser.uid}_$userId')
          .get();

      return doc.exists && (doc.data()?['is_active'] == true);
    } catch (e) {
      print('❌ Error checking if user is blocked: $e');
      return false;
    }
  }

  /// Get list of blocked users
  static Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      final snapshot = await _firestore
          .collection('blocked_users')
          .where('blocker_id', isEqualTo: currentUser.uid)
          .where('is_active', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      print('❌ Error getting blocked users: $e');
      return [];
    }
  }

  /// Check if current user is blocked by another user
  static Future<bool> isBlockedBy(String otherUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final doc = await _firestore
          .collection('blocked_users')
          .doc('${otherUserId}_${currentUser.uid}')
          .get();

      return doc.exists && (doc.data()?['is_active'] == true);
    } catch (e) {
      print('❌ Error checking if blocked by user: $e');
      return false;
    }
  }
}
