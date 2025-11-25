import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TradieApiAuthService {
  // Use 10.0.2.2 for Android emulator (maps to host machine's 127.0.0.1)
  // Use 127.0.0.1 for iOS simulator or web
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  // Register tradie via Laravel API
  Future<Map<String, dynamic>?> registerTradie({
    required String email,
    required String password,
    required String name,
    required String tradeType,
    String? phone,
  }) async {
    try {
      print('🔵 Attempting registration to: $baseUrl/tradie/register');
      print('📧 Email: $email');
      print('👤 Name: $name');
      print('🔧 Trade Type: $tradeType');

      final response = await http.post(
        Uri.parse('$baseUrl/tradie/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
          'phone': phone,
          'business_name':
              tradeType, // Using tradeType as business_name for now
        }),
      );

      print('📡 Response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Save token
          final token = data['data']['token'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          await prefs.setString('user_type', 'tradie');
          await prefs.setInt('user_id', data['data']['user']['id']);

          print('✅ Registration successful!');
          return data['data'];
        }
      } else if (response.statusCode == 422) {
        // Validation error
        print('❌ Validation error');
        final errorData = jsonDecode(response.body);
        print('Validation errors: ${errorData['error']['details']}');
        throw Exception('Validation failed: ${errorData['error']['message']}');
      } else {
        print('❌ Registration failed with status: ${response.statusCode}');
        try {
          final errorData = jsonDecode(response.body);
          print('Error details: $errorData');
          throw Exception(
            errorData['error']['message'] ?? 'Registration failed',
          );
        } catch (e) {
          throw Exception('Server error: ${response.statusCode}');
        }
      }

      return null;
    } catch (e) {
      print('❌ Register error: $e');
      rethrow;
    }
  }

  // Sign in tradie via Laravel API
  Future<Map<String, dynamic>?> signInTradie({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tradie/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Save token
          final token = data['data']['token'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          await prefs.setString('user_type', 'tradie');
          await prefs.setInt('user_id', data['data']['user']['id']);

          return data['data'];
        }
      }

      return null;
    } catch (e) {
      print('Sign in error: $e');
      return null;
    }
  }

  // Get current user data
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/tradie/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data']['user'];
        }
      }

      return null;
    } catch (e) {
      print('Get user error: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token != null) {
        await http.post(
          Uri.parse('$baseUrl/tradie/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }

      await prefs.remove('auth_token');
      await prefs.remove('user_type');
      await prefs.remove('user_id');
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') != null;
  }

  // Get stored token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Get stored user ID
  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }
}
