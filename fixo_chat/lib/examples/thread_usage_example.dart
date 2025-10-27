import '../services/thread_service.dart';

/// Example usage of the new thread-based chat system
class ThreadUsageExample {
  final ThreadService _threadService = ThreadService();

  /// Example: Tradie (ID: 123) sends message to Homeowner (ID: 456)
  Future<void> tradieToHomeownerExample() async {
    // Tradie details
    const int tradieId = 123;
    const String tradieType = 'tradie';

    // Homeowner details
    const int homeownerId = 456;
    const String homeownerType = 'homeowner';

    try {
      // 1. Get or create thread between tradie and homeowner
      final thread = await _threadService.getOrCreateThread(
        tradieId: tradieId,
        homeownerId: homeownerId,
      );

      print('Thread created/found: ${thread.id}');
      print('Tradie ID (sender_1): ${thread.sender1}');
      print('Homeowner ID (sender_2): ${thread.sender2}');

      // 2. Tradie sends a message
      final message = await _threadService.sendMessage(
        thread: thread,
        senderId: tradieId,
        senderType: tradieType,
        content: 'Hi! I can help you with your plumbing issue.',
      );

      print('Message sent: ${message.content}');
      print('Thread ID: ${message.threadId}');
      print('Sender: ${message.senderType} (ID: ${message.senderId})');
    } catch (e) {
      print('Error: $e');
    }
  }

  /// Example: Homeowner (ID: 456) replies to Tradie (ID: 123)
  Future<void> homeownerReplyExample() async {
    // Homeowner details
    const int homeownerId = 456;
    const String homeownerType = 'homeowner';

    // Tradie details
    const int tradieId = 123;

    try {
      // 1. Find existing thread
      final thread = await _threadService.findThread(
        tradieId: tradieId,
        homeownerId: homeownerId,
      );

      if (thread == null) {
        print('No thread found between these users');
        return;
      }

      // 2. Homeowner sends a reply
      final message = await _threadService.sendMessage(
        thread: thread,
        senderId: homeownerId,
        senderType: homeownerType,
        content: 'Great! When can you come by? The leak is getting worse.',
      );

      print('Reply sent: ${message.content}');
      print('Thread updated: ${thread.id}');
    } catch (e) {
      print('Error: $e');
    }
  }

  /// Example: Get all threads for a tradie
  void getTradieThreadsExample() {
    const int tradieId = 123;
    const String tradieType = 'tradie';

    _threadService
        .getThreadsForUser(userId: tradieId, userType: tradieType)
        .listen((threads) {
          print('Tradie has ${threads.length} active threads:');

          for (final thread in threads) {
            print('- Thread ${thread.id}');
            print('  With Homeowner ID: ${thread.sender2}');
            print('  Last message: "${thread.lastMessage}"');
            print('  Updated: ${thread.updatedAt}');
            print('');
          }
        });
  }

  /// Example: Get messages for a specific thread
  void getThreadMessagesExample() async {
    const int tradieId = 123;
    const int homeownerId = 456;

    try {
      // Find the thread
      final thread = await _threadService.findThread(
        tradieId: tradieId,
        homeownerId: homeownerId,
      );

      if (thread == null) {
        print('No thread found');
        return;
      }

      // Listen to messages in real-time
      _threadService.getMessagesForThread(thread).listen((messages) {
        print('Thread has ${messages.length} messages:');

        for (final message in messages.reversed) {
          // Show oldest first
          final senderLabel = message.senderType == 'tradie'
              ? 'Tradie'
              : 'Homeowner';
          print('[$senderLabel]: ${message.content}');
          print('  Sent: ${message.date}');
          if (message.isEdited) print('  (edited)');
          print('');
        }
      });
    } catch (e) {
      print('Error: $e');
    }
  }

  /// Example: Complete conversation flow
  Future<void> completeConversationExample() async {
    print('=== Complete Conversation Example ===\n');

    const int tradieId = 789;
    const int homeownerId = 101;

    try {
      // 1. Create thread
      final thread = await _threadService.getOrCreateThread(
        tradieId: tradieId,
        homeownerId: homeownerId,
      );

      print(
        'Thread created between Tradie $tradieId and Homeowner $homeownerId\n',
      );

      // 2. Homeowner starts conversation
      await _threadService.sendMessage(
        thread: thread,
        senderId: homeownerId,
        senderType: 'homeowner',
        content: 'Hi, I need help with a leaking kitchen sink.',
      );
      print('Homeowner: Hi, I need help with a leaking kitchen sink.');

      // 3. Tradie responds
      await _threadService.sendMessage(
        thread: thread,
        senderId: tradieId,
        senderType: 'tradie',
        content: 'I can help! What type of sink is it?',
      );
      print('Tradie: I can help! What type of sink is it?');

      // 4. Homeowner provides details
      await _threadService.sendMessage(
        thread: thread,
        senderId: homeownerId,
        senderType: 'homeowner',
        content:
            'It\'s a stainless steel double sink. Water is dripping from the faucet.',
      );
      print(
        'Homeowner: It\'s a stainless steel double sink. Water is dripping from the faucet.',
      );

      // 5. Tradie gives quote
      await _threadService.sendMessage(
        thread: thread,
        senderId: tradieId,
        senderType: 'tradie',
        content:
            'Sounds like a simple faucet repair. I can fix it for \$80. When works for you?',
      );
      print(
        'Tradie: Sounds like a simple faucet repair. I can fix it for \$80. When works for you?',
      );

      // 6. Homeowner accepts
      await _threadService.sendMessage(
        thread: thread,
        senderId: homeownerId,
        senderType: 'homeowner',
        content: 'Perfect! How about tomorrow at 2 PM?',
      );
      print('Homeowner: Perfect! How about tomorrow at 2 PM?');

      print('\n=== Conversation Complete ===');
      print('Thread ID: ${thread.id}');
      print('Total messages: 5');
    } catch (e) {
      print('Error in conversation: $e');
    }
  }
}

/// Run examples
Future<void> main() async {
  final examples = ThreadUsageExample();

  print('🚀 Thread System Examples\n');

  // Run examples
  await examples.tradieToHomeownerExample();
  print('\n---\n');

  await examples.homeownerReplyExample();
  print('\n---\n');

  examples.getTradieThreadsExample();
  print('\n---\n');

  examples.getThreadMessagesExample();
  print('\n---\n');

  await examples.completeConversationExample();
}
