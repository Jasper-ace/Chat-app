class Message {
  final int id;
  final int senderId;
  final int receiverId;
  final String senderName;
  final String message;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required this.message,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      senderName: json['sender_name'] ?? '',
      message: json['message'],
    );
  }
}
