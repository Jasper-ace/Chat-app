import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../services/chat_service.dart';
import '../services/dual_storage_service.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class ChatScreen extends StatefulWidget {
  final UserModel otherUser;
  final String currentUserType;

  const ChatScreen({
    super.key,
    required this.otherUser,
    required this.currentUserType,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final DualStorageService _dualStorageService = DualStorageService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isTyping = false;
  bool _isOnline = true;
  bool _showEmojiPicker = false;
  bool _isRecording = false;
  String _searchQuery = '';
  List<MessageModel> _searchResults = [];

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
    });

    // Listen for typing indicator
    _messageController.addListener(_onTypingChanged);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    _messageAnimationController.dispose();
    super.dispose();
  }

  void _onTypingChanged() {
    final isCurrentlyTyping = _messageController.text.isNotEmpty;
    if (isCurrentlyTyping != _isTyping) {
      setState(() {
        _isTyping = isCurrentlyTyping;
      });
    }
  }

  void _sendMessage({String? customMessage}) async {
    final message = customMessage ?? _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      // Use dual storage service for comprehensive message handling
      await _dualStorageService.sendMessage(
        receiverId: widget.otherUser.id,
        message: message,
        senderUserType: widget.currentUserType,
        receiverUserType: widget.otherUser.userType,
        metadata: {
          'timestamp': DateTime.now().toIso8601String(),
          'platform': 'mobile',
          'messageType': 'text',
        },
      );

      if (customMessage == null) {
        _messageController.clear();
      }

      setState(() {
        _isTyping = false;
      });

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
            setState(() {
              _searchQuery = value;
            });
            // TODO: Implement message search
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
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  backgroundImage: widget.otherUser.avatar != null
                      ? NetworkImage(widget.otherUser.avatar!)
                      : const NetworkImage(
                          'https://cdn-icons-png.flaticon.com/512/149/149071.png',
                        ),
                  radius: 18,
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        widget.otherUser.userType.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      if (_isTyping) ...[
                        const SizedBox(width: 8),
                        AnimatedBuilder(
                          animation: _typingAnimationController,
                          builder: (context, child) {
                            return Text(
                              'typing...',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            );
                          },
                        ),
                      ] else if (_isOnline) ...[
                        const SizedBox(width: 8),
                        const Text(
                          'online',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _searchMessages,
          ),
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.white),
            onPressed: _makePhoneCall,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'schedule':
                  _scheduleAppointment();
                  break;
                case 'quote':
                  _requestQuote();
                  break;
                case 'profile':
                  // TODO: Show user profile
                  break;
                case 'block':
                  // TODO: Block user
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'schedule',
                child: Row(
                  children: [
                    Icon(Icons.calendar_today),
                    SizedBox(width: 8),
                    Text('Schedule Appointment'),
                  ],
                ),
              ),
              if (widget.currentUserType == 'homeowner')
                const PopupMenuItem(
                  value: 'quote',
                  child: Row(
                    children: [
                      Icon(Icons.request_quote),
                      SizedBox(width: 8),
                      Text('Request Quote'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 8),
                    Text('View Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Block User', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
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

                final messages =
                    snapshot.data!.docs
                        .map((doc) => MessageModel.fromFirestore(doc))
                        .toList()
                      ..sort(
                        (a, b) => b.timestamp.compareTo(a.timestamp),
                      ); // Sort by timestamp descending

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe =
                        message.senderUserType == widget.currentUserType;
                    final showAvatar =
                        index == messages.length - 1 ||
                        messages[index + 1].senderUserType !=
                            message.senderUserType;

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
                                        ? NetworkImage(widget.otherUser.avatar!)
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
                              onLongPress: () => _showMessageOptions(message),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Colors.blueAccent
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(20),
                                    topRight: const Radius.circular(20),
                                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 20),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildMessageContent(message, isMe),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _formatTime(message.timestamp),
                                          style: TextStyle(
                                            color: isMe
                                                ? Colors.white70
                                                : Colors.grey[600],
                                            fontSize: 12,
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
                );
              },
            ),
          ),

          // Quick replies bar
          if (widget.currentUserType == 'homeowner' ||
              widget.currentUserType == 'tradie')
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children:
                    (widget.currentUserType == 'homeowner'
                            ? _homeownerQuickReplies.take(3)
                            : _tradieQuickReplies.take(3))
                        .map(
                          (reply) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              label: Text(reply),
                              onPressed: () =>
                                  _sendMessage(customMessage: reply),
                              backgroundColor: Colors.blue[50],
                              labelStyle: const TextStyle(
                                color: Colors.blueAccent,
                              ),
                            ),
                          ),
                        )
                        .toList(),
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
                      icon: const Icon(Icons.attach_file, color: Colors.grey),
                      onPressed: () => _showAttachmentOptions(),
                    ),

                    // Message input field
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                decoration: InputDecoration(
                                  hintText:
                                      widget.currentUserType == 'homeowner'
                                      ? 'Ask about services, pricing, availability...'
                                      : 'Respond to client inquiries...',
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                maxLines: null,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.emoji_emotions_outlined,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showEmojiPicker = !_showEmojiPicker;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Send/Voice button
                    AnimatedBuilder(
                      animation: _messageAnimationController,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            color: _messageController.text.isNotEmpty
                                ? Colors.blueAccent
                                : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              _messageController.text.isNotEmpty
                                  ? Icons.send
                                  : Icons.mic,
                              color: Colors.white,
                            ),
                            onPressed: _messageController.text.isNotEmpty
                                ? _sendMessage
                                : _startVoiceRecording,
                          ),
                        );
                      },
                    ),

                    // Quick replies button
                    IconButton(
                      icon: const Icon(Icons.reply, color: Colors.grey),
                      onPressed: _showQuickReplies,
                    ),
                  ],
                ),

                // Professional features for tradies
                if (widget.currentUserType == 'tradie')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildProfessionalButton(
                          icon: Icons.schedule,
                          label: 'Schedule',
                          onPressed: _scheduleAppointment,
                        ),
                        _buildProfessionalButton(
                          icon: Icons.request_quote,
                          label: 'Quote',
                          onPressed: () => _sendQuote(),
                        ),
                        _buildProfessionalButton(
                          icon: Icons.photo_camera,
                          label: 'Photo',
                          onPressed: _sendImage,
                        ),
                        _buildProfessionalButton(
                          icon: Icons.location_on,
                          label: 'Location',
                          onPressed: _sendLocation,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(MessageModel message, bool isMe) {
    // Handle different message types
    if (message.message.startsWith('📷')) {
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
    } else if (message.message.startsWith('📄')) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_file, color: Colors.white70, size: 16),
          const SizedBox(width: 4),
          Text(
            message.message.substring(2),
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
              fontSize: 16,
            ),
          ),
        ],
      );
    } else if (message.message.startsWith('📅')) {
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
    } else if (message.message.startsWith('💰')) {
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
    return Text(
      message.message,
      style: TextStyle(
        color: isMe ? Colors.white : Colors.black87,
        fontSize: 16,
      ),
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
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.message));
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
                _messageController.text =
                    'Replying to: "${message.message}"\n\n';
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_border),
              title: const Text('Star Message'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement star message
              },
            ),
            if (message.senderUserType == widget.currentUserType)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement delete message
                },
              ),
          ],
        ),
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
}
