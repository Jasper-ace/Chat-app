import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChatApiService {
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Send message via Laravel API (which writes to Firebase)
  // Returns the thread_id if successful, null otherwise
  Future<String?> sendMessage({
    required String chatId,
    required String senderId,
    required String senderType,
    required String receiverId,
    required String receiverType,
    required String message,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      print('📤 Sending message: sender=$senderId, receiver=$receiverId');

      final response = await http.post(
        Uri.parse('$baseUrl/chats/send-message'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'sender_id': int.tryParse(senderId) ?? 0,
          'sender_type': senderType,
          'receiver_id': int.tryParse(receiverId) ?? 0,
          'receiver_type': receiverType,
          'message': message,
        }),
      );

      print('📤 Send message response: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('📦 Parsed response data: $data');
        print('📦 data["data"]: ${data['data']}');

        if (data['success'] == true) {
          // The response structure is: { success: true, data: { success: true, thread_id: "...", message_id: 1 } }
          final responseData = data['data'];
          if (responseData != null && responseData['thread_id'] != null) {
            return responseData['thread_id'] as String;
          }
          print('❌ No thread_id in response data');
        }
      }

      return null;
    } catch (e) {
      print('❌ Send message error: $e');
      rethrow;
    }
  }

  // Create a new chat room
  Future<String?> createChatRoom({
    required String participant1Id,
    required String participant1Type,
    required String participant2Id,
    required String participant2Type,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // Determine which is homeowner and which is tradie
      String homeownerId;
      String tradieId;

      if (participant1Type == 'homeowner') {
        homeownerId = participant1Id;
        tradieId = participant2Id;
      } else {
        homeownerId = participant2Id;
        tradieId = participant1Id;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/chats/create-room'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'homeowner_id': int.parse(homeownerId),
          'tradie_id': int.parse(tradieId),
        }),
      );

      print('📡 Create room response: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Laravel returns 'room_id' not 'chat_id'
          return data['data']['room_id'] ?? data['data']['chat_id'];
        }
      }

      print('❌ Failed to create room: ${response.body}');
      return null;
    } catch (e) {
      print('❌ Create chat room error: $e');
      rethrow;
    }
  }

  // Get user's chats
  Future<List<Map<String, dynamic>>> getUserChats({
    required String userId,
    required String userType,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse(
          '$baseUrl/chats/user-chats?user_id=$userId&user_type=$userType',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data'] ?? []);
        }
      }

      return [];
    } catch (e) {
      print('❌ Get user chats error: $e');
      return [];
    }
  }

  // Get all homeowners
  Future<List<Map<String, dynamic>>> getAllHomeowners() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/homeowners'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data'] ?? []);
        }
      }

      return [];
    } catch (e) {
      print('❌ Get all homeowners error: $e');
      return [];
    }
  }
}
