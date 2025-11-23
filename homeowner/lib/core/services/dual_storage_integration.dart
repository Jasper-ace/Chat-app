import 'dual_storage_service.dart';
import 'auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_service.dart';

/// Integration service that bridges the homeowner app with the dual storage system
class DualStorageIntegration {
  final DualStorageService _dualStorageService = DualStorageService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();

  /// Register homeowner with comprehensive data
  Future<UserCredential?> registerHomeowner({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? middleName,
    String? phone,
    String? address,
    String? city,
    String? region,
    String? postalCode,
    double? latitude,
    double? longitude,
  }) async {
    try {
      // Register using the dual storage service
      final result = await _dualStorageService.registerUser(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        userType: 'homeowner',
        middleName: middleName,
        phone: phone,
        address: address,
        city: city,
        region: region,
        postalCode: postalCode,
        latitude: latitude,
        longitude: longitude,
      );

      return result;
    } catch (e) {
      print('Homeowner registration error: $e');
      rethrow;
    }
  }

  /// Sign in homeowner
  Future<UserCredential?> signInHomeowner({
    required String email,
    required String password,
  }) async {
    try {
      return await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
        expectedUserType: 'homeowner',
      );
    } catch (e) {
      print('Homeowner sign in error: $e');
      rethrow;
    }
  }

  /// Send message to tradie (saves to both Firebase and Laravel)
  Future<bool> sendMessageToTradie({
    required String tradieFirebaseUid,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      return await _dualStorageService.sendMessage(
        receiverId: tradieFirebaseUid,
        message: message,
        senderUserType: 'homeowner',
        receiverUserType: 'tradie',
        metadata: metadata,
      );
    } catch (e) {
      print('Send message error: $e');
      return false;
    }
  }

  /// Get available tradies from Laravel
  Future<List<dynamic>?> getAvailableTradies({
    double? latitude,
    double? longitude,
    int? radius,
    String? serviceType,
  }) async {
    try {
      return await _apiService.searchTradies(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        serviceType: serviceType,
        availabilityStatus: 'available',
      );
    } catch (e) {
      print('Get available tradies error: $e');
      return null;
    }
  }

  /// Get homeowner's chats from Laravel
  Future<List<dynamic>?> getHomeownerChats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      return await _apiService.getUserChats(user.uid);
    } catch (e) {
      print('Get homeowner chats error: $e');
      return null;
    }
  }

  /// Mark messages as read
  Future<bool> markMessagesAsRead(String tradieFirebaseUid) async {
    try {
      return await _dualStorageService.markMessagesAsRead(tradieFirebaseUid);
    } catch (e) {
      print('Mark messages as read error: $e');
      return false;
    }
  }

  /// Get homeowner data from Laravel
  Future<Map<String, dynamic>?> getHomeownerData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      return await _dualStorageService.getUserData(user.uid, 'homeowner');
    } catch (e) {
      print('Get homeowner data error: $e');
      return null;
    }
  }

  /// Get chat statistics
  Future<Map<String, dynamic>?> getChatStatistics() async {
    try {
      return await _dualStorageService.getChatStats();
    } catch (e) {
      print('Get chat statistics error: $e');
      return null;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      print('Sign out error: $e');
      rethrow;
    }
  }

  /// Get current user
  User? get currentUser => FirebaseAuth.instance.currentUser;

  /// Auth state changes stream
  Stream<User?> get authStateChanges =>
      FirebaseAuth.instance.authStateChanges();
}
