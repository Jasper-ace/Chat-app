import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to manage conversation states (pin, archive, block, mute, etc.)
class ConversationStateService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user's conversation preferences
  static Future<DocumentReference> _getUserPreferencesRef() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    return _firestore.collection('userPreferences').doc(currentUser.uid);
  }

  /// Pin a conversation
  static Future<void> pinConversation(String otherUserId) async {
    try {
      final prefsRef = await _getUserPreferencesRef();
      await prefsRef.set({
        'pinnedConversations': FieldValue.arrayUnion([otherUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error pinning conversation: $e');
      rethrow;
    }
  }

  /// Unpin a conversation
  static Future<void> unpinConversation(String otherUserId) async {
    try {
      final prefsRef = await _getUserPreferencesRef();
      await prefsRef.set({
        'pinnedConversations': FieldValue.arrayRemove([otherUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error unpinning conversation: $e');
      rethrow;
    }
  }

  /// Archive a conversation
  static Future<void> archiveConversation(String otherUserId) async {
    try {
      final prefsRef = await _getUserPreferencesRef();
      await prefsRef.set({
        'archivedConversations': FieldValue.arrayUnion([otherUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error archiving conversation: $e');
      rethrow;
    }
  }

  /// Unarchive a conversation
  static Future<void> unarchiveConversation(String otherUserId) async {
    try {
      final prefsRef = await _getUserPreferencesRef();
      await prefsRef.set({
        'archivedConversations': FieldValue.arrayRemove([otherUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error unarchiving conversation: $e');
      rethrow;
    }
  }

  /// Block a user
  static Future<void> blockUser(
    String otherUserId, [
    String userType = 'unknown',
  ]) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Update all blocking storage locations for consistency
      final batch = _firestore.batch();

      // 1. Add to blocked_users collection (for BlockService compatibility)
      final blockedUserRef = _firestore
          .collection('blocked_users')
          .doc('${currentUser.uid}_$otherUserId');
      batch.set(blockedUserRef, {
        'blocker_id': currentUser.uid,
        'blocked_user_id': otherUserId,
        'blocked_user_type': userType,
        'blocked_at': FieldValue.serverTimestamp(),
        'is_active': true,
      });

      // 2. Add to userPreferences (for ConversationStateService)
      final prefsRef = await _getUserPreferencesRef();
      batch.set(prefsRef, {
        'blockedUsers': FieldValue.arrayUnion([otherUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Add to userProfiles (for ChatService compatibility)
      final profileRef = _firestore
          .collection('userProfiles')
          .doc(currentUser.uid);
      batch.set(profileRef, {
        'blockedUsers': FieldValue.arrayUnion([otherUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Execute all updates atomically
      await batch.commit();
    } catch (e) {
      print('Error blocking user: $e');
      rethrow;
    }
  }

  /// Unblock a user
  static Future<void> unblockUser(String otherUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Update all blocking storage locations for consistency
      final batch = _firestore.batch();

      // 1. Remove from blocked_users collection
      final blockedUserRef = _firestore
          .collection('blocked_users')
          .doc('${currentUser.uid}_$otherUserId');
      batch.delete(blockedUserRef);

      // 2. Remove from userPreferences
      final prefsRef = await _getUserPreferencesRef();
      batch.set(prefsRef, {
        'blockedUsers': FieldValue.arrayRemove([otherUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Remove from userProfiles
      final profileRef = _firestore
          .collection('userProfiles')
          .doc(currentUser.uid);
      batch.set(profileRef, {
        'blockedUsers': FieldValue.arrayRemove([otherUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Execute all updates atomically
      await batch.commit();
    } catch (e) {
      print('Error unblocking user: $e');
      rethrow;
    }
  }

  /// Mute a conversation
  static Future<void> muteConversation(String otherUserId) async {
    try {
      final prefsRef = await _getUserPreferencesRef();
      await prefsRef.set({
        'mutedConversations': FieldValue.arrayUnion([otherUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error muting conversation: $e');
      rethrow;
    }
  }

  /// Unmute a conversation
  static Future<void> unmuteConversation(String otherUserId) async {
    try {
      final prefsRef = await _getUserPreferencesRef();
      await prefsRef.set({
        'mutedConversations': FieldValue.arrayRemove([otherUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error unmuting conversation: $e');
      rethrow;
    }
  }

  /// Mark conversation as unread
  static Future<void> markAsUnread(String otherUserId) async {
    try {
      final prefsRef = await _getUserPreferencesRef();
      await prefsRef.set({
        'unreadConversations': FieldValue.arrayUnion([otherUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error marking as unread: $e');
      rethrow;
    }
  }

  /// Mark conversation as read
  static Future<void> markAsRead(String otherUserId) async {
    try {
      final prefsRef = await _getUserPreferencesRef();
      await prefsRef.set({
        'unreadConversations': FieldValue.arrayRemove([otherUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error marking as read: $e');
      rethrow;
    }
  }

  /// Get user preferences as a stream for real-time updates
  static Stream<Map<String, dynamic>> getUserPreferencesStream() {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return Stream.value({
          'pinnedConversations': <String>[],
          'archivedConversations': <String>[],
          'blockedUsers': <String>[],
          'mutedConversations': <String>[],
          'unreadConversations': <String>[],
        });
      }

      return _firestore
          .collection('userPreferences')
          .doc(currentUser.uid)
          .snapshots()
          .handleError((error) {
            print('Error in user preferences stream: $error');
          })
          .map((doc) {
            if (doc.exists && doc.data() != null) {
              final data = doc.data() as Map<String, dynamic>;
              // Ensure all required fields exist
              return {
                'pinnedConversations':
                    data['pinnedConversations'] ?? <String>[],
                'archivedConversations':
                    data['archivedConversations'] ?? <String>[],
                'blockedUsers': data['blockedUsers'] ?? <String>[],
                'mutedConversations': data['mutedConversations'] ?? <String>[],
                'unreadConversations':
                    data['unreadConversations'] ?? <String>[],
                'updatedAt': data['updatedAt'],
                'createdAt': data['createdAt'],
              };
            } else {
              // Initialize preferences if document doesn't exist
              initializeUserPreferences();
              return {
                'pinnedConversations': <String>[],
                'archivedConversations': <String>[],
                'blockedUsers': <String>[],
                'mutedConversations': <String>[],
                'unreadConversations': <String>[],
              };
            }
          });
    } catch (e) {
      print('Error getting user preferences stream: $e');
      return Stream.value({
        'pinnedConversations': <String>[],
        'archivedConversations': <String>[],
        'blockedUsers': <String>[],
        'mutedConversations': <String>[],
        'unreadConversations': <String>[],
      });
    }
  }

  /// Get user preferences (one-time fetch)
  static Future<Map<String, dynamic>> getUserPreferences() async {
    try {
      final prefsRef = await _getUserPreferencesRef();
      final doc = await prefsRef.get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      } else {
        return {
          'pinnedConversations': <String>[],
          'archivedConversations': <String>[],
          'blockedUsers': <String>[],
          'mutedConversations': <String>[],
          'unreadConversations': <String>[],
        };
      }
    } catch (e) {
      print('Error getting user preferences: $e');
      return {
        'pinnedConversations': <String>[],
        'archivedConversations': <String>[],
        'blockedUsers': <String>[],
        'mutedConversations': <String>[],
        'unreadConversations': <String>[],
      };
    }
  }

  /// Check if conversation is pinned
  static Future<bool> isConversationPinned(String otherUserId) async {
    final prefs = await getUserPreferences();
    final pinnedList = List<String>.from(prefs['pinnedConversations'] ?? []);
    return pinnedList.contains(otherUserId);
  }

  /// Check if conversation is archived
  static Future<bool> isConversationArchived(String otherUserId) async {
    final prefs = await getUserPreferences();
    final archivedList = List<String>.from(
      prefs['archivedConversations'] ?? [],
    );
    return archivedList.contains(otherUserId);
  }

  /// Check if user is blocked (current user blocked the other user)
  static Future<bool> isUserBlocked(String otherUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Check multiple sources for blocking status
      // 1. Check userPreferences first (fastest)
      final prefs = await getUserPreferences();
      final blockedList = List<String>.from(prefs['blockedUsers'] ?? []);
      if (blockedList.contains(otherUserId)) return true;

      // 2. Check blocked_users collection as fallback
      final blockedUserDoc = await _firestore
          .collection('blocked_users')
          .doc('${currentUser.uid}_$otherUserId')
          .get();

      if (blockedUserDoc.exists &&
          (blockedUserDoc.data()?['is_active'] == true)) {
        // Sync the blocking status to userPreferences for future fast access
        final prefsRef = await _getUserPreferencesRef();
        await prefsRef.set({
          'blockedUsers': FieldValue.arrayUnion([otherUserId]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return true;
      }

      return false;
    } catch (e) {
      print('Error checking if user is blocked: $e');
      return false;
    }
  }

  /// Check if current user is blocked by another user
  static Future<bool> isBlockedByUser(String otherUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Check if the other user has blocked the current user
      // 1. Check blocked_users collection
      final blockedUserDoc = await _firestore
          .collection('blocked_users')
          .doc('${otherUserId}_${currentUser.uid}')
          .get();

      if (blockedUserDoc.exists &&
          (blockedUserDoc.data()?['is_active'] == true)) {
        return true;
      }

      // 2. Check other user's userPreferences
      final otherUserPrefsDoc = await _firestore
          .collection('userPreferences')
          .doc(otherUserId)
          .get();

      if (otherUserPrefsDoc.exists) {
        final data = otherUserPrefsDoc.data() as Map<String, dynamic>;
        final blockedList = List<String>.from(data['blockedUsers'] ?? []);
        return blockedList.contains(currentUser.uid);
      }

      // 3. Check other user's userProfiles (for ChatService compatibility)
      final otherUserProfileDoc = await _firestore
          .collection('userProfiles')
          .doc(otherUserId)
          .get();

      if (otherUserProfileDoc.exists) {
        final data = otherUserProfileDoc.data() as Map<String, dynamic>;
        final blockedList = List<String>.from(data['blockedUsers'] ?? []);
        return blockedList.contains(currentUser.uid);
      }

      return false;
    } catch (e) {
      print('Error checking if blocked by user: $e');
      return false;
    }
  }

  /// Check if conversation is muted
  static Future<bool> isConversationMuted(String otherUserId) async {
    final prefs = await getUserPreferences();
    final mutedList = List<String>.from(prefs['mutedConversations'] ?? []);
    return mutedList.contains(otherUserId);
  }

  /// Check if conversation is marked as unread
  static Future<bool> isConversationUnread(String otherUserId) async {
    final prefs = await getUserPreferences();
    final unreadList = List<String>.from(prefs['unreadConversations'] ?? []);
    return unreadList.contains(otherUserId);
  }

  /// Force refresh user preferences (useful after operations)
  static Future<void> refreshUserPreferences() async {
    try {
      final prefsRef = await _getUserPreferencesRef();
      await prefsRef.set({
        'lastRefresh': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error refreshing user preferences: $e');
    }
  }

  /// Initialize user preferences if they don't exist
  static Future<void> initializeUserPreferences() async {
    try {
      final prefsRef = await _getUserPreferencesRef();
      await prefsRef.set({
        'pinnedConversations': <String>[],
        'archivedConversations': <String>[],
        'blockedUsers': <String>[],
        'mutedConversations': <String>[],
        'unreadConversations': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error initializing user preferences: $e');
    }
  }

  /// Batch update multiple conversation states
  static Future<void> batchUpdateConversationStates({
    List<String>? pin,
    List<String>? unpin,
    List<String>? archive,
    List<String>? unarchive,
    List<String>? mute,
    List<String>? unmute,
    List<String>? markRead,
    List<String>? markUnread,
  }) async {
    try {
      final prefsRef = await _getUserPreferencesRef();
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (pin != null && pin.isNotEmpty) {
        updates['pinnedConversations'] = FieldValue.arrayUnion(pin);
      }
      if (unpin != null && unpin.isNotEmpty) {
        updates['pinnedConversations'] = FieldValue.arrayRemove(unpin);
      }
      if (archive != null && archive.isNotEmpty) {
        updates['archivedConversations'] = FieldValue.arrayUnion(archive);
      }
      if (unarchive != null && unarchive.isNotEmpty) {
        updates['archivedConversations'] = FieldValue.arrayRemove(unarchive);
      }
      if (mute != null && mute.isNotEmpty) {
        updates['mutedConversations'] = FieldValue.arrayUnion(mute);
      }
      if (unmute != null && unmute.isNotEmpty) {
        updates['mutedConversations'] = FieldValue.arrayRemove(unmute);
      }
      if (markRead != null && markRead.isNotEmpty) {
        updates['unreadConversations'] = FieldValue.arrayRemove(markRead);
      }
      if (markUnread != null && markUnread.isNotEmpty) {
        updates['unreadConversations'] = FieldValue.arrayUnion(markUnread);
      }

      if (updates.length > 1) {
        // More than just updatedAt
        await prefsRef.set(updates, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error batch updating conversation states: $e');
      rethrow;
    }
  }
}
