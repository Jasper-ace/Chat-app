class UserIdConverter {
  /// Convert Firebase UID (String) to integer for message comparison
  static int firebaseUidToInt(String firebaseUid) {
    return firebaseUid.hashCode.abs();
  }

  /// Convert any dynamic user ID to integer
  static int toInt(dynamic userId) {
    if (userId is int) return userId;
    if (userId is String) return firebaseUidToInt(userId);
    return 0;
  }

  /// Check if two user IDs match (handles String/int conversion)
  static bool idsMatch(dynamic id1, dynamic id2) {
    return toInt(id1) == toInt(id2);
  }

  /// Debug method to show ID conversion
  static void debugIds(String label, dynamic originalId, int convertedId) {
    print('$label: $originalId (${originalId.runtimeType}) -> $convertedId');
  }
}
