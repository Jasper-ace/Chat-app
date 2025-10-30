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
      if (currentUser == null) {
        print('❌ No current user found');
        return false;
      }

      print('🔄 Blocking user: $blockedUserId (type: $blockedUserType)');
      print('🔄 Current user: ${currentUser.uid}');

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

      print('✅ Added to blocked_users collection');

      // Also add to user's blocked list for quick access (create document if it doesn't exist)
      try {
        await _firestore.collection('users').doc(currentUser.uid).set({
          'blocked_users': FieldValue.arrayUnion([blockedUserId]),
        }, SetOptions(merge: true));
        print('✅ Updated user blocked list');
      } catch (userUpdateError) {
        print('⚠️ Could not update user blocked list: $userUpdateError');
        // This is not critical - the main blocking is still in place
      }

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
      if (currentUser == null) {
        print('❌ No current user found');
        return false;
      }

      print('🔄 Unblocking user: $blockedUserId');
      print('🔄 Current user: ${currentUser.uid}');

      // Remove from blocked users collection
      await _firestore
          .collection('blocked_users')
          .doc('${currentUser.uid}_$blockedUserId')
          .delete();

      print('✅ Removed from blocked_users collection');

      // Remove from user's blocked list
      try {
        await _firestore.collection('users').doc(currentUser.uid).set({
          'blocked_users': FieldValue.arrayRemove([blockedUserId]),
        }, SetOptions(merge: true));
        print('✅ Updated user blocked list');
      } catch (userUpdateError) {
        print('⚠️ Could not update user blocked list: $userUpdateError');
        // This is not critical - the main unblocking is still in place
      }

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
      if (currentUser == null) {
        print('❌ No current user found for block check');
        return false;
      }

      final doc = await _firestore
          .collection('blocked_users')
          .doc('${currentUser.uid}_$userId')
          .get();

      final isBlocked = doc.exists && (doc.data()?['is_active'] == true);
      print('🔍 Block check: ${currentUser.uid} -> $userId = $isBlocked');

      return isBlocked;
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
