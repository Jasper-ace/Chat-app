import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HomeownerApiAuthService {
  // Use 10.0.2.2 for Android emulator (maps to host machine's 127.0.0.1)
  // Use 127.0.0.1 for iOS simulator or web
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  // Register homeowner via Laravel API
  Future<Map<String, dynamic>?> registerHomeowner({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    try {
      print('🔵 Attempting registration to: $baseUrl/homeowner/register');
      print('📧 Email: $email');
      print('👤 Name: $name');

      final response = await http.post(
        Uri.parse('$baseUrl/homeowner/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
          'phone': phone,
        }),
      );

      print('📡 Response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);

        // Laravel returns: {access_token, token_type, expires_in, user}
        if (data['access_token'] != null) {
          final token = data['access_token'];
          final user = data['user'];

          // Save token and user data
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          await prefs.setString('user_type', 'homeowner');
          await prefs.setInt('user_id', user['id']);

          print('✅ Registration successful! User ID: ${user['id']}');

          return {'token': token, 'user': user};
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

  // Sign in homeowner via Laravel API
  Future<Map<String, dynamic>?> signInHomeowner({
    required String email,
    required String password,
  }) async {
    try {
      print('🔵 Attempting login to: $baseUrl/homeowner/login');
      print('📧 Email: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/homeowner/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      print('📡 Response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Laravel returns: {access_token, token_type, expires_in, user}
        if (data['access_token'] != null) {
          final token = data['access_token'];
          final user = data['user'];

          // Save token and user data
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          await prefs.setString('user_type', 'homeowner');
          await prefs.setInt('user_id', user['id']);

          print('✅ Login successful! User ID: ${user['id']}');

          return {'token': token, 'user': user};
        }
      } else if (response.statusCode == 401) {
        print('❌ Invalid credentials');
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error']['message'] ?? 'Invalid credentials');
      } else if (response.statusCode == 422) {
        print('❌ Validation error');
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error']['message'] ?? 'Validation failed');
      } else {
        print('❌ Login failed with status: ${response.statusCode}');
        throw Exception('Login failed');
      }

      return null;
    } catch (e) {
      print('❌ Sign in error: $e');
      rethrow;
    }
  }

  // Get current user data
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/homeowner/me'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Laravel returns: {success: true, data: {...}}
        if (data['success'] == true && data['data'] != null) {
          return data['data'];
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
          Uri.parse('$baseUrl/homeowner/logout'),
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
