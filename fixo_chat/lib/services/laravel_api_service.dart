import 'dart:convert';
import 'package:http/http.dart' as http;

class LaravelApiService {
  // Update this URL to match your Laravel API endpoint
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  // Headers for API requests
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Save user to Laravel database after Firebase registration
  static Future<bool> saveUserToLaravel({
    required String firebaseUid,
    required String firstName,
    required String lastName,
    required String email,
    required String userType, // 'homeowner' or 'tradie'
    String? middleName,
    String? phone,
    String? address,
    String? city,
    String? region,
    String? postalCode,
    double? latitude,
    double? longitude,
    String? tradeType, // Only for tradies
    String? businessName, // Only for tradies
    String? licenseNumber, // Only for tradies
    int? yearsExperience, // Only for tradies
    double? hourlyRate, // Only for tradies
  }) async {
    try {
      final String endpoint = userType == 'homeowner'
          ? '$baseUrl/homeowners'
          : '$baseUrl/tradies';

      Map<String, dynamic> userData = {
        'firebase_uid': firebaseUid,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
      };

      // Add optional fields if provided
      if (middleName != null) userData['middle_name'] = middleName;
      if (phone != null) userData['phone'] = phone;
      if (address != null) userData['address'] = address;
      if (city != null) userData['city'] = city;
      if (region != null) userData['region'] = region;
      if (postalCode != null) userData['postal_code'] = postalCode;
      if (latitude != null) userData['latitude'] = latitude;
      if (longitude != null) userData['longitude'] = longitude;

      // Add tradie-specific fields
      if (userType == 'tradie') {
        if (tradeType != null) userData['trade_type'] = tradeType;
        if (businessName != null) userData['business_name'] = businessName;
        if (licenseNumber != null) userData['license_number'] = licenseNumber;
        if (yearsExperience != null) {
          userData['years_experience'] = yearsExperience;
        }
        if (hourlyRate != null) userData['hourly_rate'] = hourlyRate;
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: json.encode(userData),
      );

      if (response.statusCode == 201) {
        print('User saved to Laravel successfully');
        return true;
      } else {
        print('Failed to save user to Laravel: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error saving user to Laravel: $e');
      return false;
    }
  }

  /// Save message to Laravel database
  static Future<bool> saveMessageToLaravel({
    required String senderFirebaseUid,
    required String receiverFirebaseUid,
    required String senderType,
    required String receiverType,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chats/send-message'),
        headers: headers,
        body: json.encode({
          'sender_firebase_uid': senderFirebaseUid,
          'receiver_firebase_uid': receiverFirebaseUid,
          'sender_type': senderType,
          'receiver_type': receiverType,
          'message': message,
          if (metadata != null) 'metadata': metadata,
        }),
      );

      if (response.statusCode == 201) {
        print('Message saved to Laravel successfully');
        return true;
      } else {
        print('Failed to save message to Laravel: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error saving message to Laravel: $e');
      return false;
    }
  }

  /// Get user chats from Laravel
  static Future<List<dynamic>?> getUserChats(String firebaseUid) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chats/user-chats?firebase_uid=$firebaseUid'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Error getting user chats from Laravel: $e');
      return null;
    }
  }

  /// Get chat messages from Laravel
  static Future<List<dynamic>?> getChatMessages(
    int chatId, {
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/chats/$chatId/messages?page=$page&per_page=$perPage',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data']['messages']['data'];
        }
      }
      return null;
    } catch (e) {
      print('Error getting chat messages from Laravel: $e');
      return null;
    }
  }

  /// Mark messages as read in Laravel
  static Future<bool> markMessagesAsRead({
    required String senderFirebaseUid,
    required String receiverFirebaseUid,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chats/mark-as-read'),
        headers: headers,
        body: json.encode({
          'sender_firebase_uid': senderFirebaseUid,
          'receiver_firebase_uid': receiverFirebaseUid,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error marking messages as read in Laravel: $e');
      return false;
    }
  }

  /// Get user by Firebase UID from Laravel
  static Future<Map<String, dynamic>?> getUserByFirebaseUid(
    String firebaseUid,
    String userType,
  ) async {
    try {
      final String endpoint = userType == 'homeowner'
          ? '$baseUrl/homeowners/firebase/$firebaseUid'
          : '$baseUrl/tradies/firebase/$firebaseUid';

      final response = await http.get(Uri.parse(endpoint), headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Error getting user from Laravel: $e');
      return null;
    }
  }

  /// Search tradies from Laravel
  static Future<List<dynamic>?> searchTradies({
    double? latitude,
    double? longitude,
    int? radius,
    String? serviceType,
    String? availabilityStatus,
  }) async {
    try {
      Map<String, dynamic> searchParams = {};

      if (latitude != null) searchParams['latitude'] = latitude;
      if (longitude != null) searchParams['longitude'] = longitude;
      if (radius != null) searchParams['radius'] = radius;
      if (serviceType != null) searchParams['service_type'] = serviceType;
      if (availabilityStatus != null) {
        searchParams['availability_status'] = availabilityStatus;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/tradies/search'),
        headers: headers,
        body: json.encode(searchParams),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Error searching tradies from Laravel: $e');
      return null;
    }
  }

  /// Get chat statistics from Laravel
  static Future<Map<String, dynamic>?> getChatStats(String firebaseUid) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chats/stats?firebase_uid=$firebaseUid'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Error getting chat stats from Laravel: $e');
      return null;
    }
  }
}
