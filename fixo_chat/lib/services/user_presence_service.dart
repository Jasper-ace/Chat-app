import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class UserPresenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _presenceTimer;
  StreamSubscription<DocumentSnapshot>? _presenceSubscription;

  // Update user's online status
  Future<void> setUserOnline() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore.collection('userPresence').doc(currentUser.uid).set({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Start periodic updates to maintain online status
      _startPresenceUpdates();
    } catch (e) {
      print('Error setting user online: $e');
    }
  }

  // Update user's offline status
  Future<void> setUserOffline() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore.collection('userPresence').doc(currentUser.uid).set({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _stopPresenceUpdates();
    } catch (e) {
      print('Error setting user offline: $e');
    }
  }

  // Start periodic presence updates (every 30 seconds)
  void _startPresenceUpdates() {
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updatePresence();
    });
  }

  // Stop presence updates
  void _stopPresenceUpdates() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
  }

  // Update presence timestamp
  Future<void> _updatePresence() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore.collection('userPresence').doc(currentUser.uid).update({
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating presence: $e');
    }
  }

  // Get user's online status
  Stream<Map<String, dynamic>> getUserPresence(String userId) {
    return _firestore.collection('userPresence').doc(userId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) {
        return {'isOnline': false, 'lastSeen': null, 'statusText': 'Offline'};
      }

      final data = doc.data() as Map<String, dynamic>;
      final isOnline = data['isOnline'] ?? false;
      final lastSeen = data['lastSeen'] as Timestamp?;

      return {
        'isOnline': isOnline,
        'lastSeen': lastSeen?.toDate(),
        'statusText': _formatUserStatus(isOnline, lastSeen?.toDate()),
      };
    });
  }

  // Format user status like Instagram
  String _formatUserStatus(bool isOnline, DateTime? lastSeen) {
    if (isOnline) {
      return 'Online';
    }

    if (lastSeen == null) {
      return 'Offline';
    }

    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Active now';
    } else if (difference.inMinutes < 60) {
      return 'Active ${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return 'Active ${difference.inHours}h ago';
    } else if (difference.inDays <= 3) {
      return 'Active ${difference.inDays}d ago';
    } else {
      return 'Active more than 3 days ago';
    }
  }

  // Dispose resources
  void dispose() {
    _stopPresenceUpdates();
    _presenceSubscription?.cancel();
  }
}

// Enhanced typing indicator service
class TypingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _typingTimer;
  String? _currentChatId;

  // Start typing with auto-stop after 3 seconds
  Future<void> startTyping(String otherUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final chatId = _getChatId(currentUser.uid, otherUserId);
      _currentChatId = chatId;

      // Cancel previous timer
      _typingTimer?.cancel();

      // Set typing status (debounced - only if not already typing)
      await _firestore.collection('typing').doc(chatId).set({
        'typingUsers.${currentUser.uid}': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Auto-stop typing after 3 seconds
      _typingTimer = Timer(const Duration(seconds: 3), () {
        stopTyping(otherUserId);
      });
    } catch (e) {
      print('Error starting typing: $e');
    }
  }

  // Stop typing
  Future<void> stopTyping(String otherUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final chatId = _getChatId(currentUser.uid, otherUserId);

      await _firestore.collection('typing').doc(chatId).update({
        'typingUsers.${currentUser.uid}': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _typingTimer?.cancel();
      _currentChatId = null;
    } catch (e) {
      print('Error stopping typing: $e');
    }
  }

  // Get typing status with Instagram-style formatting
  Stream<String> getTypingStatus(String otherUserId, String otherUserName) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value('');
    }

    final chatId = _getChatId(currentUser.uid, otherUserId);

    return _firestore.collection('typing').doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return '';

      final data = doc.data() as Map<String, dynamic>;
      final typingUsers = data['typingUsers'] as Map<String, dynamic>? ?? {};

      // Check if other user is typing (not current user)
      final otherUserTyping = typingUsers.containsKey(otherUserId);
      if (!otherUserTyping) return '';

      // Check if typing is recent (within 5 seconds)
      final typingTimestamp = typingUsers[otherUserId] as Timestamp?;
      if (typingTimestamp != null) {
        final typingTime = typingTimestamp.toDate();
        final now = DateTime.now();
        final difference = now.difference(typingTime);

        if (difference.inSeconds <= 5) {
          return 'typing...';
        }
      }

      return '';
    });
  }

  // Generate consistent chat ID
  String _getChatId(String userId, String otherUserId) {
    return userId.hashCode <= otherUserId.hashCode
        ? '$userId-$otherUserId'
        : '$otherUserId-$userId';
  }

  // Dispose resources
  void dispose() {
    _typingTimer?.cancel();
  }
}
