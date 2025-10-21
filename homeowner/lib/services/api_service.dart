import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';
  static const _storage = FlutterSecureStorage();

  late final Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptor for authentication
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  /// Register homeowner in Laravel database
  Future<Map<String, dynamic>?> registerHomeowner({
    required String firebaseUid,
    required String firstName,
    required String lastName,
    required String email,
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
      final response = await _dio.post(
        '/homeowners',
        data: {
          'firebase_uid': firebaseUid,
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          if (middleName != null) 'middle_name': middleName,
          if (phone != null) 'phone': phone,
          if (address != null) 'address': address,
          if (city != null) 'city': city,
          if (region != null) 'region': region,
          if (postalCode != null) 'postal_code': postalCode,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        },
      );

      if (response.statusCode == 201) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('Error registering homeowner: $e');
      return null;
    }
  }

  /// Get homeowner by Firebase UID
  Future<Map<String, dynamic>?> getHomeownerByFirebaseUid(
    String firebaseUid,
  ) async {
    try {
      final response = await _dio.get('/homeowners/firebase/$firebaseUid');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      print('Error getting homeowner: $e');
      return null;
    }
  }

  /// Send message to Laravel (dual storage)
  Future<bool> sendMessage({
    required String senderFirebaseUid,
    required String receiverFirebaseUid,
    required String senderType,
    required String receiverType,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _dio.post(
        '/chats/send-message',
        data: {
          'sender_firebase_uid': senderFirebaseUid,
          'receiver_firebase_uid': receiverFirebaseUid,
          'sender_type': senderType,
          'receiver_type': receiverType,
          'message': message,
          if (metadata != null) 'metadata': metadata,
        },
      );

      return response.statusCode == 201;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  /// Get user chats from Laravel
  Future<List<dynamic>?> getUserChats(String firebaseUid) async {
    try {
      final response = await _dio.get(
        '/chats/user-chats',
        queryParameters: {'firebase_uid': firebaseUid},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      print('Error getting user chats: $e');
      return null;
    }
  }

  /// Search tradies
  Future<List<dynamic>?> searchTradies({
    double? latitude,
    double? longitude,
    int? radius,
    String? serviceType,
    String? availabilityStatus,
  }) async {
    try {
      final response = await _dio.post(
        '/tradies/search',
        data: {
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (radius != null) 'radius': radius,
          if (serviceType != null) 'service_type': serviceType,
          if (availabilityStatus != null)
            'availability_status': availabilityStatus,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      print('Error searching tradies: $e');
      return null;
    }
  }

  /// Mark messages as read
  Future<bool> markMessagesAsRead({
    required String senderFirebaseUid,
    required String receiverFirebaseUid,
  }) async {
    try {
      final response = await _dio.post(
        '/chats/mark-as-read',
        data: {
          'sender_firebase_uid': senderFirebaseUid,
          'receiver_firebase_uid': receiverFirebaseUid,
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error marking messages as read: $e');
      return false;
    }
  }

  /// Get chat statistics
  Future<Map<String, dynamic>?> getChatStats(String firebaseUid) async {
    try {
      final response = await _dio.get(
        '/chats/stats',
        queryParameters: {'firebase_uid': firebaseUid},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      print('Error getting chat stats: $e');
      return null;
    }
  }
}
