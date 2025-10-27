import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class TypingCollectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _typingTimer;
  Timer? _cleanupTimer;
  String? _currentChatId;

  // Start typing indicator with auto-cleanup
  Future<void> startTyping(String otherUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final chatId = _getChatId(currentUser.uid, otherUserId);
      _currentChatId = chatId;

      // Cancel previous timer
      _typingTimer?.cancel();

      // Set typing status in dedicated typing collection
      await _firestore.collection('typing_indicators').doc(chatId).set({
        'chatId': chatId,
        'typingUsers': {
          currentUser.uid: {
            'isTyping': true,
            'timestamp': FieldValue.serverTimestamp(),
            'userId': currentUser.uid,
          },
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Auto-stop typing after 3 seconds of inactivity
      _typingTimer = Timer(const Duration(seconds: 3), () {
        stopTyping(otherUserId);
      });

      // Start cleanup timer to remove old typing indicators
      _startCleanupTimer();
    } catch (e) {
      print('Error starting typing: $e');
    }
  }

  // Stop typing indicator
  Future<void> stopTyping(String otherUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final chatId = _getChatId(currentUser.uid, otherUserId);

      // Remove typing status
      await _firestore.collection('typing_indicators').doc(chatId).update({
        'typingUsers.${currentUser.uid}': FieldValue.delete(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      _typingTimer?.cancel();
      _currentChatId = null;
    } catch (e) {
      print('Error stopping typing: $e');
    }
  }

  // Get typing status for a chat
  Stream<List<String>> getTypingUsers(String otherUserId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    final chatId = _getChatId(currentUser.uid, otherUserId);

    return _firestore
        .collection('typing_indicators')
        .doc(chatId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return <String>[];

          final data = doc.data() as Map<String, dynamic>;
          final typingUsers =
              data['typingUsers'] as Map<String, dynamic>? ?? {};

          final List<String> activeTypers = [];
          final now = DateTime.now();

          typingUsers.forEach((userId, userTypingData) {
            // Skip current user
            if (userId == currentUser.uid) return;

            final typingData = userTypingData as Map<String, dynamic>;
            final isTyping = typingData['isTyping'] ?? false;
            final timestamp = typingData['timestamp'] as Timestamp?;

            if (isTyping && timestamp != null) {
              final typingTime = timestamp.toDate();
              final difference = now.difference(typingTime);

              // Only show as typing if within last 5 seconds
              if (difference.inSeconds <= 5) {
                activeTypers.add(userId);
              }
            }
          });

          return activeTypers;
        });
  }

  // Get formatted typing status text
  Stream<String> getTypingStatusText(String otherUserId, String otherUserName) {
    return getTypingUsers(otherUserId).map((typingUsers) {
      if (typingUsers.isEmpty) return '';

      if (typingUsers.length == 1) {
        return 'typing...';
      } else {
        return '${typingUsers.length} people typing...';
      }
    });
  }

  // Start cleanup timer to remove old typing indicators
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _cleanupOldTypingIndicators();
    });
  }

  // Clean up old typing indicators
  Future<void> _cleanupOldTypingIndicators() async {
    try {
      final cutoffTime = DateTime.now().subtract(const Duration(seconds: 10));

      final oldIndicators = await _firestore
          .collection('typing_indicators')
          .where('lastUpdated', isLessThan: Timestamp.fromDate(cutoffTime))
          .get();

      final batch = _firestore.batch();
      for (final doc in oldIndicators.docs) {
        batch.delete(doc.reference);
      }

      if (oldIndicators.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      print('Error cleaning up typing indicators: $e');
    }
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
    _cleanupTimer?.cancel();

    // Clean up current user's typing status
    if (_currentChatId != null) {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        _firestore
            .collection('typing_indicators')
            .doc(_currentChatId)
            .update({
              'typingUsers.${currentUser.uid}': FieldValue.delete(),
              'lastUpdated': FieldValue.serverTimestamp(),
            })
            .catchError((e) {
              print('Error cleaning up typing on dispose: $e');
            });
      }
    }
  }

  // Batch update typing status for multiple chats (for efficiency)
  Future<void> batchUpdateTypingStatus(
    Map<String, bool> chatTypingStatus,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final batch = _firestore.batch();

      chatTypingStatus.forEach((chatId, isTyping) {
        final docRef = _firestore.collection('typing_indicators').doc(chatId);

        if (isTyping) {
          batch.set(docRef, {
            'chatId': chatId,
            'typingUsers': {
              currentUser.uid: {
                'isTyping': true,
                'timestamp': FieldValue.serverTimestamp(),
                'userId': currentUser.uid,
              },
            },
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          batch.update(docRef, {
            'typingUsers.${currentUser.uid}': FieldValue.delete(),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      });

      await batch.commit();
    } catch (e) {
      print('Error batch updating typing status: $e');
    }
  }

  // Get all active typing indicators for current user's chats
  Stream<Map<String, List<String>>> getAllTypingIndicators() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value({});
    }

    return _firestore
        .collection('typing_indicators')
        .where('chatId', isGreaterThan: '')
        .snapshots()
        .map((snapshot) {
          final Map<String, List<String>> allTypingIndicators = {};

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final chatId = data['chatId'] as String;

            // Only include chats where current user is a participant
            if (!chatId.contains(currentUser.uid)) continue;

            final typingUsers =
                data['typingUsers'] as Map<String, dynamic>? ?? {};
            final List<String> activeTypers = [];
            final now = DateTime.now();

            typingUsers.forEach((userId, userTypingData) {
              // Skip current user
              if (userId == currentUser.uid) return;

              final typingData = userTypingData as Map<String, dynamic>;
              final isTyping = typingData['isTyping'] ?? false;
              final timestamp = typingData['timestamp'] as Timestamp?;

              if (isTyping && timestamp != null) {
                final typingTime = timestamp.toDate();
                final difference = now.difference(typingTime);

                // Only show as typing if within last 5 seconds
                if (difference.inSeconds <= 5) {
                  activeTypers.add(userId);
                }
              }
            });

            if (activeTypers.isNotEmpty) {
              allTypingIndicators[chatId] = activeTypers;
            }
          }

          return allTypingIndicators;
        });
  }
}
