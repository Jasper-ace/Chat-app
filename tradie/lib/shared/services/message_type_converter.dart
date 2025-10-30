/// Service to handle type conversions for message system
class MessageTypeConverter {
  /// Convert sender_id to int safely
  static int convertSenderId(dynamic senderId) {
    if (senderId is int) return senderId;
    if (senderId is String) {
      // Try to parse as int first
      final parsed = int.tryParse(senderId);
      if (parsed != null) return parsed;

      // Fallback to hashCode for Firebase UIDs
      return senderId.hashCode.abs();
    }
    return 0;
  }

  /// Convert user ID to int for thread system
  static int convertUserId(dynamic userId) {
    if (userId is int) return userId;
    if (userId is String) {
      final parsed = int.tryParse(userId);
      if (parsed != null) return parsed;
      return userId.hashCode.abs();
    }
    return 0;
  }

  /// Safely get auto-increment ID from user data
  static int? getAutoIncrementId(Map<String, dynamic> userData) {
    final id = userData['id'];
    if (id is int) return id;
    if (id is String) {
      return int.tryParse(id);
    }
    return null;
  }

  /// Check if two IDs match (handles different types)
  static bool idsMatch(dynamic id1, dynamic id2) {
    return convertUserId(id1) == convertUserId(id2);
  }

  /// Debug method to show type conversions
  static void debugConversion(String label, dynamic original, int converted) {
    print('$label: $original (${original.runtimeType}) -> $converted (int)');
  }
}
