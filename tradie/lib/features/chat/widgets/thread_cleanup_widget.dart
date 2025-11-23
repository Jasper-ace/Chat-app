import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Widget to clean up duplicate threads directly from the app
class ThreadCleanupWidget extends StatefulWidget {
  const ThreadCleanupWidget({super.key});

  @override
  State<ThreadCleanupWidget> createState() => _ThreadCleanupWidgetState();
}

class _ThreadCleanupWidgetState extends State<ThreadCleanupWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _status = 'Ready to clean up duplicate threads';
  final List<String> _logs = [];

  void _addLog(String message) {
    setState(() {
      _logs.add(message);
      _status = message;
    });
    print(message);
  }

  Future<void> _cleanupDuplicateThreads() async {
    setState(() {
      _isLoading = true;
      _logs.clear();
    });

    try {
      _addLog('🔧 Starting cleanup process...');

      // Get all threads
      final threadsQuery = await _firestore.collection('threads').get();
      _addLog('📊 Found ${threadsQuery.docs.length} total threads');

      // Group by tradie-homeowner pairs
      Map<String, List<QueryDocumentSnapshot>> conversationMap = {};

      for (final doc in threadsQuery.docs) {
        final data = doc.data();
        final tradieId = data['tradie_id'];
        final homeownerId = data['homeowner_id'];

        if (tradieId != null && homeownerId != null) {
          final key = '${tradieId}_$homeownerId';
          conversationMap[key] ??= [];
          conversationMap[key]!.add(doc);
        }
      }

      _addLog('👥 Found ${conversationMap.length} unique conversations');

      int duplicatesRemoved = 0;
      int conversationsFixed = 0;

      // Process each conversation
      for (final entry in conversationMap.entries) {
        final conversationKey = entry.key;
        final threads = entry.value;

        if (threads.length > 1) {
          conversationsFixed++;
          _addLog(
            '🔴 Fixing conversation $conversationKey (${threads.length} threads)',
          );

          // Sort by creation time (keep oldest)
          threads.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>?;
            final bData = b.data() as Map<String, dynamic>?;
            final aCreated = aData?['created_at'] as Timestamp?;
            final bCreated = bData?['created_at'] as Timestamp?;

            if (aCreated == null && bCreated == null) return 0;
            if (aCreated == null) return 1;
            if (bCreated == null) return -1;

            return aCreated.compareTo(bCreated);
          });

          final keepThread = threads.first;
          final duplicateThreads = threads.skip(1).toList();

          _addLog('   ✅ Keeping: ${keepThread.id}');

          // Merge messages from duplicates
          for (final duplicate in duplicateThreads) {
            _addLog('   🔄 Merging: ${duplicate.id} → ${keepThread.id}');
            await _mergeThreadMessages(keepThread.id, duplicate.id);

            _addLog('   🗑️ Deleting: ${duplicate.id}');
            await duplicate.reference.delete();
            duplicatesRemoved++;
          }
        }
      }

      // Reset thread counter
      _addLog('🔢 Resetting thread counter...');
      await _resetThreadCounter();

      _addLog('🎉 CLEANUP COMPLETED!');
      _addLog('✅ Conversations fixed: $conversationsFixed');
      _addLog('✅ Duplicate threads removed: $duplicatesRemoved');
      _addLog('✅ System is now ready for single-thread conversations');
    } catch (e) {
      _addLog('❌ Error during cleanup: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _mergeThreadMessages(
    String destThreadId,
    String sourceThreadId,
  ) async {
    try {
      // Get messages from source
      final sourceMessages = await _firestore
          .collection('threads')
          .doc(sourceThreadId)
          .collection('messages')
          .orderBy('timestamp')
          .get();

      if (sourceMessages.docs.isEmpty) return;

      // Get current message count in destination
      final destThread = await _firestore
          .collection('threads')
          .doc(destThreadId)
          .get();

      int messageCount = destThread.data()?['message_count'] as int? ?? 0;

      // Copy messages
      final batch = _firestore.batch();

      for (final messageDoc in sourceMessages.docs) {
        messageCount++;
        final newMessageRef = _firestore
            .collection('threads')
            .doc(destThreadId)
            .collection('messages')
            .doc('msg_$messageCount');

        final messageData = messageDoc.data();
        batch.set(newMessageRef, {...messageData, 'message_id': messageCount});
      }

      // Update thread message count
      batch.update(_firestore.collection('threads').doc(destThreadId), {
        'message_count': messageCount,
        'updated_at': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      _addLog('     ❌ Error merging messages: $e');
    }
  }

  Future<void> _resetThreadCounter() async {
    try {
      // Find highest thread_id
      final threadsQuery = await _firestore
          .collection('threads')
          .orderBy('thread_id', descending: true)
          .limit(1)
          .get();

      int nextId = 1;
      if (threadsQuery.docs.isNotEmpty) {
        final highestId =
            threadsQuery.docs.first.data()['thread_id'] as int? ?? 0;
        nextId = highestId + 1;
      }

      // Set counter
      await _firestore.collection('counters').doc('thread_counter').set({
        'current_id': nextId - 1,
      });

      _addLog(
        '✅ Counter set to: ${nextId - 1} (next thread will be thread_$nextId)',
      );
    } catch (e) {
      _addLog('❌ Error resetting counter: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thread Cleanup'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Duplicate Thread Cleanup',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This will fix duplicate threads in your database. '
                      'Each conversation will have exactly one thread after cleanup.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _isLoading ? null : _cleanupDuplicateThreads,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Cleaning up...'),
                      ],
                    )
                  : const Text('Clean Up Duplicate Threads'),
            ),

            const SizedBox(height: 16),

            Text(
              'Status: $_status',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _logs
                        .map(
                          (log) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              log,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
