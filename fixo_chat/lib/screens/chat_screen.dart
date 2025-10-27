import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import '../services/chat_service.dart';
import '../services/dual_storage_service.dart';
import '../services/user_presence_service.dart';

import '../utils/user_id_converter.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

import '../widgets/chat_menu_widget.dart';
import '../widgets/job_confirmation_widget.dart';
import 'user_profile_screen.dart';
import 'enhanced_user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final UserModel otherUser;
  final String currentUserType;
  final int currentUserId; // Add the actual current user ID (integer)

  const ChatScreen({
    super.key,
    required this.otherUser,
    required this.currentUserType,
    required this.currentUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final DualStorageService _dualStorageService = DualStorageService();
  final UserPresenceService _presenceService = UserPresenceService();
  final TypingService _typingService = TypingService();

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isTyping = false;

  bool _isOnline = false;
  String _userStatus = 'Offline';
  bool _showEmojiPicker = false;
  bool _isRecording = false;
  // Removed unused search fields
  Timer? _typingTimer;
  Timer? _typingDebounceTimer;

  // Get current user ID from Firebase Auth (for Firebase operations)
  String? get firebaseUserId => _auth.currentUser?.uid;

  // Get current user ID as integer (for message comparison)
  int get currentUserIdAsInt {
    final firebaseUid = _auth.currentUser?.uid;
    if (firebaseUid != null) {
      return UserIdConverter.firebaseUidToInt(firebaseUid);
    }
    return widget.currentUserId;
  }

  StreamSubscription<String>? _typingSubscription;
  StreamSubscription<Map<String, dynamic>>? _presenceSubscription;

  // Block status tracking
  bool _isBlocked = false;
  bool _canChat = true;
  String? _blockReason;

  // Animation controllers
  late AnimationController _typingAnimationController;
  late AnimationController _messageAnimationController;

  // Quick reply templates
  final List<String> _homeownerQuickReplies = [
    "What's your availability?",
    "Can you provide a quote?",
    "When can you start?",
    "Do you have insurance?",
    "What's included in the service?",
    "Thank you!",
  ];

  final List<String> _tradieQuickReplies = [
    "I'm available this week",
    "Let me check my schedule",
    "I'll send you a quote",
    "Yes, I'm fully insured",
    "I can start immediately",
    "You're welcome!",
  ];

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _messageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Mark messages as read when entering chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatService.markMessagesAsRead(widget.otherUser.id);
      _checkBlockStatus();
      _presenceService.setUserOnline(); // Set current user online
    });

    // Listen for typing indicator
    _messageController.addListener(_onTypingChanged);

    // Typing indicators disabled - collections removed

    // Listen for other user's presence status
    _presenceSubscription = _presenceService
        .getUserPresence(widget.otherUser.id)
        .listen((presenceData) {
          final isOnline = presenceData['isOnline'] ?? false;
          final statusText = presenceData['statusText'] ?? 'Offline';

          if (mounted && (isOnline != _isOnline || statusText != _userStatus)) {
            setState(() {
              _isOnline = isOnline;
              _userStatus = statusText;
            });
          }
        });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    _messageAnimationController.dispose();
    _typingTimer?.cancel();
    _typingDebounceTimer?.cancel();
    _typingSubscription?.cancel();
    _presenceSubscription?.cancel();

    // Typing indicators disabled

    // Set user offline when leaving chat
    _presenceService.setUserOffline();

    // Dispose services
    _typingService.dispose();
    _presenceService.dispose();

    super.dispose();
  }

  void _onTypingChanged() {
    final isCurrentlyTyping = _messageController.text.isNotEmpty;

    // Only update state if typing status actually changed
    if (isCurrentlyTyping != _isTyping) {
      _isTyping = isCurrentlyTyping;
      // Don't call setState here to avoid rebuilds
    }

    // Cancel previous debounce timer
    _typingDebounceTimer?.cancel();

    // Typing indicators disabled - collections removed
  }

  void _sendMessage({String? customMessage}) async {
    final message = customMessage ?? _messageController.text.trim();
    if (message.isEmpty) return;

    // Check if chat is blocked
    if (!_canChat) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_blockReason ?? 'Cannot send message: Chat is blocked'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Use chat service directly for better reliability
      await _chatService.sendMessage(
        receiverId: widget.otherUser.id,
        message: message,
        senderUserType: widget.currentUserType,
        receiverUserType: widget.otherUser.userType,
      );

      if (customMessage == null) {
        _messageController.clear();
      }

      setState(() {
        _isTyping = false;
      });

      // Typing indicators disabled

      // Animate message send
      _messageAnimationController.forward().then((_) {
        _messageAnimationController.reset();
      });

      // Scroll to bottom after sending
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      // Haptic feedback
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _sendMessage(customMessage: message),
            ),
          ),
        );
      }
    }
  }

  void _sendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        // TODO: Upload image to storage and send image message
        _sendMessage(customMessage: '📷 Image sent');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send image: $e')));
      }
    }
  }

  void _sendFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );

      if (result != null) {
        // TODO: Upload file to storage and send file message
        _sendMessage(customMessage: '📄 ${result.files.first.name}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send file: $e')));
      }
    }
  }

  void _makePhoneCall() async {
    // TODO: Get phone number from user profile
    const phoneNumber = 'tel:+1234567890';
    if (await canLaunchUrl(Uri.parse(phoneNumber))) {
      await launchUrl(Uri.parse(phoneNumber));
    }
  }

  void _scheduleAppointment() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select a date and time for your appointment:'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _sendMessage(customMessage: '📅 Appointment request sent');
              },
              child: const Text('Send Appointment Request'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _requestQuote() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Quote'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextField(
              decoration: InputDecoration(
                labelText: 'Project Description',
                hintText: 'Describe your project...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Budget Range',
                hintText: 'e.g., \$500 - \$1000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendMessage(customMessage: '💰 Quote request sent');
            },
            child: const Text('Send Quote Request'),
          ),
        ],
      ),
    );
  }

  void _searchMessages() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Messages'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: 'Search',
            hintText: 'Enter keywords...',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            // TODO: Implement message search
            // setState(() {
            //   _searchQuery = value;
            // });
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showQuickReplies() {
    final quickReplies = widget.currentUserType == 'homeowner'
        ? _homeownerQuickReplies
        : _tradieQuickReplies;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Replies',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...quickReplies.map(
              (reply) => ListTile(
                title: Text(reply),
                onTap: () {
                  Navigator.pop(context);
                  _sendMessage(customMessage: reply);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A90E2),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EnhancedUserProfileScreen(
                  user: widget.otherUser,
                  currentUserType: widget.currentUserType,
                ),
              ),
            );
          },
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    backgroundImage: widget.otherUser.avatar != null
                        ? NetworkImage(widget.otherUser.avatar!)
                        : const NetworkImage(
                            'https://cdn-icons-png.flaticon.com/512/149/149071.png',
                          ),
                    radius: 20,
                  ),
                  if (_isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUser.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _isOnline ? 'Active now' : _userStatus,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => ChatMenuWidget(
                  otherUser: widget.otherUser,
                  currentUserType: widget.currentUserType,
                  onArchive: () => _archiveChat(),
                  onDelete: () => _deleteChat(),
                  onBlock: () => _blockUser(),
                  onMute: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notifications muted')),
                    );
                  },
                ),
              );
            },
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(widget.otherUser.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                final allMessages = snapshot.data!.docs
                    .map((doc) => MessageModel.fromFirestore(doc))
                    .toList();

                // Filter messages based on delete status
                final messages =
                    allMessages.where((message) {
                      // Show all non-deleted messages
                      if (!message.isDeleted) return true;

                      // For deleted messages, only show to the user who deleted them
                      // We'll use the sender type to determine if current user deleted it
                      return message.senderId == currentUserIdAsInt;
                    }).toList()..sort(
                      (a, b) => b.date.compareTo(a.date),
                    ); // Sort by timestamp descending

                return Column(
                  children: [
                    // Typing indicator disabled - collections removed

                    // Messages ListView with fixed itemCount
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message.senderId == currentUserIdAsInt;
                          final showAvatar =
                              index == messages.length - 1 ||
                              messages[index + 1].senderId != message.senderId;

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: isMe
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isMe) ...[
                                  showAvatar
                                      ? CircleAvatar(
                                          backgroundImage:
                                              widget.otherUser.avatar != null
                                              ? NetworkImage(
                                                  widget.otherUser.avatar!,
                                                )
                                              : const NetworkImage(
                                                  'https://cdn-icons-png.flaticon.com/512/149/149071.png',
                                                ),
                                          radius: 16,
                                        )
                                      : const SizedBox(width: 32),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: GestureDetector(
                                    onLongPress: () =>
                                        _showMessageOptions(message),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (message.isDeleted ||
                                                message.isUnsent)
                                            ? Colors.grey[400]?.withOpacity(0.6)
                                            : isMe
                                            ? const Color(0xFF4A90E2)
                                            : const Color(0xFF2D2D2D),
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(18),
                                          topRight: const Radius.circular(18),
                                          bottomLeft: Radius.circular(
                                            isMe ? 18 : 4,
                                          ),
                                          bottomRight: Radius.circular(
                                            isMe ? 4 : 18,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildMessageContent(message, isMe),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _formatTime(message.date),
                                                style: TextStyle(
                                                  color: isMe
                                                      ? Colors.white70
                                                      : Colors.grey[400],
                                                  fontSize: 11,
                                                ),
                                              ),
                                              if (isMe) ...[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  message.read
                                                      ? Icons.done_all
                                                      : Icons.done,
                                                  size: 16,
                                                  color: message.read
                                                      ? Colors.blue[200]
                                                      : Colors.white70,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 8),
                                  showAvatar
                                      ? CircleAvatar(
                                          backgroundColor: Colors.blueAccent,
                                          radius: 16,
                                          child: const Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        )
                                      : const SizedBox(width: 32),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Job confirmation widget (example)
          const JobConfirmationWidget(
            jobTitle: 'Kitchen Sink Plumbing Repair',
            status: 'confirmed',
          ),

          // Block status banner
          if (!_canChat && _blockReason != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red[50],
              child: Row(
                children: [
                  const Icon(Icons.block, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _blockReason!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (_blockReason == 'You have blocked this user')
                    TextButton(
                      onPressed: () async {
                        try {
                          await _chatService.unblockUser(widget.otherUser.id);
                          await _checkBlockStatus();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${widget.otherUser.displayName} has been unblocked',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text(
                        'Unblock',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                ],
              ),
            ),

          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Attachment button
                    IconButton(
                      icon: Icon(
                        Icons.attach_file,
                        color: _canChat ? Colors.grey : Colors.grey[400],
                      ),
                      onPressed: _canChat
                          ? () => _showAttachmentOptions()
                          : null,
                    ),

                    // Message input field
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _canChat ? Colors.white : Colors.grey[200],
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.attach_file,
                                color: _canChat
                                    ? Colors.grey[600]
                                    : Colors.grey[400],
                              ),
                              onPressed: _canChat
                                  ? _showAttachmentOptions
                                  : null,
                            ),
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                enabled: _canChat,
                                decoration: const InputDecoration(
                                  hintText: 'Type your message...',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 12,
                                  ),
                                ),
                                maxLines: null,
                                textInputAction: TextInputAction.send,
                                onSubmitted: _canChat
                                    ? (_) => _sendMessage()
                                    : null,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.emoji_emotions_outlined,
                                color: _canChat
                                    ? const Color(0xFFFFA500)
                                    : Colors.grey[400],
                              ),
                              onPressed: _canChat
                                  ? () {
                                      setState(() {
                                        _showEmojiPicker = !_showEmojiPicker;
                                      });
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Send button
                    AnimatedBuilder(
                      animation: _messageAnimationController,
                      builder: (context, child) {
                        final canSend =
                            _canChat && _messageController.text.isNotEmpty;
                        return Container(
                          decoration: BoxDecoration(
                            color: canSend
                                ? const Color(0xFF4A90E2)
                                : Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed: canSend ? _sendMessage : null,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(MessageModel message, bool isMe) {
    // Handle deleted messages (only show for the user who deleted it)
    if (message.isDeleted) {
      return Text(
        'You deleted this message',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // Handle unsent messages
    if (message.isUnsent) {
      return Text(
        'This message was unsent',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // Handle different message types
    if (message.content.startsWith('📷')) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image, color: Colors.white70, size: 16),
          const SizedBox(width: 4),
          Text(
            'Image',
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
              fontSize: 16,
            ),
          ),
        ],
      );
    } else if (message.content.startsWith('📄')) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_file, color: Colors.white70, size: 16),
          const SizedBox(width: 4),
          Text(
            message.content.substring(2),
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
              fontSize: 16,
            ),
          ),
        ],
      );
    } else if (message.content.startsWith('📅')) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: 0.2) : Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today,
              color: isMe ? Colors.white : Colors.blueAccent,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              'Appointment Request',
              style: TextStyle(
                color: isMe ? Colors.white : Colors.blueAccent,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (message.content.startsWith('💰')) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: 0.2) : Colors.green[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.request_quote,
              color: isMe ? Colors.white : Colors.green,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              'Quote Request',
              style: TextStyle(
                color: isMe ? Colors.white : Colors.green,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Regular text message
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.content,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.white,
            fontSize: 16,
          ),
        ),
        if (message.isEdited)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'edited',
              style: TextStyle(
                color: isMe ? Colors.white60 : Colors.grey[400],
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfessionalButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.blueAccent, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.blueAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(MessageModel message) {
    // Don't show options for deleted or unsent messages
    if (message.isDeleted || message.isUnsent) {
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Message copied')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                _replyToMessage(message);
              },
            ),
            if (message.senderId == currentUserIdAsInt) ...[
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Edit', style: TextStyle(color: Colors.blue)),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.orange),
                title: const Text(
                  'Delete for Me',
                  style: TextStyle(color: Colors.orange),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessageForMe(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  'Unsend',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showUnsendConfirmation(message);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.orange),
                title: const Text(
                  'Delete for Me',
                  style: TextStyle(color: Colors.orange),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessageForMe(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.report, color: Colors.red),
                title: const Text(
                  'Report',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _reportMessage(message);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _deleteMessageForMe(MessageModel message) async {
    try {
      await _chatService.deleteMessageForMe(message.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete message: $e')));
      }
    }
  }

  void _showUnsendConfirmation(MessageModel message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsend Message'),
        content: const Text(
          'Are you sure you want to unsend this message? It will be removed for everyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _unsendMessage(message);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unsend'),
          ),
        ],
      ),
    );
  }

  void _unsendMessage(MessageModel message) async {
    try {
      await _chatService.unsendMessage(message.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message unsent')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to unsend message: $e')));
      }
    }
  }

  void _editMessage(MessageModel message) {
    final TextEditingController editController = TextEditingController(
      text: message.content,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            hintText: 'Edit your message...',
            border: OutlineInputBorder(),
          ),
          maxLines: null,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newContent = editController.text.trim();
              if (newContent.isNotEmpty && newContent != message.content) {
                try {
                  await _chatService.editMessage(message.id, newContent);
                  Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message edited')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to edit message: $e')),
                    );
                  }
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _replyToMessage(MessageModel message) {
    setState(() {
      _messageController.text = 'Replying to: "${message.content}"\n\n';
    });
    // Focus on the text field
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _reportMessage(MessageModel message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Why are you reporting this message?'),
            const SizedBox(height: 16),
            ...['Spam', 'Harassment', 'Inappropriate content', 'Other'].map(
              (reason) => ListTile(
                title: Text(reason),
                onTap: () async {
                  try {
                    await _chatService.reportUser(
                      reportedUserId: widget.otherUser.id,
                      reason: reason,
                      description: 'Reported message: "${message.content}"',
                      chatId: message.chatId,
                    );
                    Navigator.pop(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Message reported')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to report: $e')),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Send Attachment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.photo_camera,
                  label: 'Camera',
                  onPressed: () {
                    Navigator.pop(context);
                    _takePicture();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onPressed: () {
                    Navigator.pop(context);
                    _sendImage();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.attach_file,
                  label: 'File',
                  onPressed: () {
                    Navigator.pop(context);
                    _sendFile();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.location_on,
                  label: 'Location',
                  onPressed: () {
                    Navigator.pop(context);
                    _sendLocation();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.blueAccent, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.blueAccent,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _takePicture() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        _sendMessage(customMessage: '📷 Photo taken');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to take picture: $e')));
      }
    }
  }

  void _sendLocation() {
    _sendMessage(customMessage: '📍 Location shared');
  }

  void _sendQuote() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Quote'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextField(
              decoration: InputDecoration(
                labelText: 'Service Description',
                hintText: 'Describe the service...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Price',
                hintText: 'Enter price...',
                prefixText: '\$',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Timeline',
                hintText: 'e.g., 2-3 days',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendMessage(
                customMessage: '💰 Quote: Professional service quote sent',
              );
            },
            child: const Text('Send Quote'),
          ),
        ],
      ),
    );
  }

  void _startVoiceRecording() {
    setState(() {
      _isRecording = !_isRecording;
    });

    if (_isRecording) {
      // TODO: Start voice recording
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Voice recording started')));
    } else {
      // TODO: Stop and send voice recording
      _sendMessage(customMessage: '🎤 Voice message');
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inHours > 0) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

  Future<void> _checkBlockStatus() async {
    try {
      final blockStatus = await _chatService.getChatBlockStatus(
        widget.otherUser.id,
      );

      if (mounted) {
        setState(() {
          _isBlocked = blockStatus['isBlocked'] ?? false;
          _canChat = blockStatus['canChat'] ?? true;

          if (blockStatus['userBlocked'] == true) {
            _blockReason = 'You have blocked this user';
          } else if (blockStatus['blockedByUser'] == true) {
            _blockReason = 'This user has blocked you';
          } else if (_isBlocked) {
            _blockReason = 'Chat is blocked';
          } else {
            _blockReason = null;
          }
        });
      }
    } catch (e) {
      print('Error checking block status: $e');
    }
  }

  void _showUserProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          user: widget.otherUser,
          currentUserType: widget.currentUserType,
        ),
      ),
    ).then((_) {
      // Refresh block status when returning from profile
      _checkBlockStatus();
    });
  }

  void _showBlockUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Block ${widget.otherUser.displayName}?'),
        content: Text(
          'Are you sure you want to block ${widget.otherUser.displayName}? '
          'You will no longer receive messages from this user.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _chatService.blockUser(widget.otherUser.id);
                Navigator.pop(context); // Close dialog

                // Refresh block status
                await _checkBlockStatus();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${widget.otherUser.displayName} has been blocked',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error blocking user: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Block User'),
          ),
        ],
      ),
    );
  }

  void _showUnblockUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unblock ${widget.otherUser.displayName}?'),
        content: Text(
          'Are you sure you want to unblock ${widget.otherUser.displayName}? '
          'You will be able to send and receive messages again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _chatService.unblockUser(widget.otherUser.id);
                Navigator.pop(context); // Close dialog

                // Refresh block status
                await _checkBlockStatus();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${widget.otherUser.displayName} has been unblocked',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error unblocking user: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Unblock User'),
          ),
        ],
      ),
    );
  }

  void _deleteChat() async {
    try {
      await _chatService.deleteChat(widget.otherUser.id, deleteForBoth: false);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chat deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete chat: $e')));
      }
    }
  }

  void _archiveChat() async {
    try {
      await _chatService.archiveChat(widget.otherUser.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chat archived')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to archive chat: $e')));
      }
    }
  }

  void _blockUser() async {
    try {
      await _chatService.blockUser(widget.otherUser.id);
      await _checkBlockStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.otherUser.displayName} has been blocked'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to block user: $e')));
      }
    }
  }
}
