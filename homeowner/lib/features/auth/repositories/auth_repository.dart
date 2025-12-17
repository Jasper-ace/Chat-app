import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_models.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';

class AuthRepository {
  final DioClient _dioClient = DioClient.instance;

  Future<ApiResult<AuthResponse>> login(LoginRequest request) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.loginEndpoint,
        data: request.toJson(),
      );

      final authResponse = AuthResponse.fromJson(response.data);

      // Store token in both FlutterSecureStorage (for DioClient) and SharedPreferences (for job posting)
      await _dioClient.setToken(authResponse.accessToken);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', authResponse.accessToken);

      // Store user ID and type for later use
      if (authResponse.user.id != null) {
        await _dioClient.setUserId(authResponse.user.id!);
        await prefs.setInt('user_id', authResponse.user.id!);
        await prefs.setString('user_type', 'homeowner');
      }

      print('✅ Login successful - Token stored in both storage systems');
      return Success(authResponse);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return Failure(message: 'An unexpected error occurred: $e');
    }
  }

  Future<ApiResult<AuthResponse>> register(RegisterRequest request) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.registerEndpoint,
        data: request.toJson(),
      );

      final authResponse = AuthResponse.fromJson(response.data);

      // Store token in both FlutterSecureStorage (for DioClient) and SharedPreferences (for job posting)
      await _dioClient.setToken(authResponse.accessToken);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', authResponse.accessToken);

      // Store user ID and type for later use
      if (authResponse.user.id != null) {
        await _dioClient.setUserId(authResponse.user.id!);
        await prefs.setInt('user_id', authResponse.user.id!);
        await prefs.setString('user_type', 'homeowner');
      }

      print('✅ Registration successful - Token stored in both storage systems');
      return Success(authResponse);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return Failure(message: 'An unexpected error occurred: $e');
    }
  }

  Future<ApiResult<void>> logout() async {
    try {
      await _dioClient.dio.post(ApiConstants.logoutEndpoint);

      // Clear from both storage systems
      await _dioClient.clearToken();
      await _dioClient.clearUserId();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_id');
      await prefs.remove('user_type');

      return const Success(null);
    } on DioException catch (e) {
      // Clear token even if logout fails
      await _dioClient.clearToken();
      await _dioClient.clearUserId();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_id');
      await prefs.remove('user_type');

      return _handleDioError(e);
    } catch (e) {
      await _dioClient.clearToken();
      await _dioClient.clearUserId();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_id');
      await prefs.remove('user_type');

      return Failure(message: 'An unexpected error occurred: $e');
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await _dioClient.getToken();
    return token != null;
  }

  Future<int?> getCurrentUserId() async {
    try {
      final token = await _dioClient.getToken();
      print(
        '🔍 Token check: ${token != null ? "Token exists" : "No token found"}',
      );

      if (token == null) {
        print('❌ No token found, user not authenticated');
        return null;
      }

      // Get stored user ID
      final userId = await _dioClient.getUserId();
      if (userId != null) {
        print('✅ Retrieved stored user ID: $userId');
        return userId;
      }

      // Fallback: Make API call to get current user info
      try {
        print('🔄 Making API call to /homeowner/me to get user ID');
        final response = await _dioClient.dio.get('/homeowner/me');
        final userData = response.data;

        print('📥 /homeowner/me response: $userData');

        if (userData != null && userData['data'] != null) {
          final apiUserId = userData['data']['id'] as int?;
          if (apiUserId != null) {
            // Store it for future use
            await _dioClient.setUserId(apiUserId);
            print('✅ Retrieved and stored user ID from API: $apiUserId');
            return apiUserId;
          }
        }
      } catch (apiError) {
        print('⚠️ API call to /homeowner/me failed: $apiError');
        // If we get 401, the token is invalid - clear it
        if (apiError is DioException && apiError.response?.statusCode == 401) {
          print('🔄 Token is invalid, clearing stored credentials');
          await _dioClient.clearToken();
          await _dioClient.clearUserId();
          return null;
        }
      }

      print('❌ No user ID found');
      return null;
    } catch (e) {
      print('❌ Error getting current user ID: $e');
      return null;
    }
  }

  // Add a method to test authentication
  Future<bool> testAuthentication() async {
    try {
      final response = await _dioClient.dio.get('/homeowner/me');
      print('✅ Authentication test successful: ${response.statusCode}');
      return true;
    } catch (e) {
      print('❌ Authentication test failed: $e');
      if (e is DioException && e.response?.statusCode == 401) {
        // Token is invalid, clear it
        await _dioClient.clearAllData();
      }
      return false;
    }
  }

  // Method to validate and refresh authentication
  Future<bool> validateAuthentication() async {
    final token = await _dioClient.getToken();
    if (token == null) {
      return false;
    }

    // Test if the current token is valid
    try {
      await _dioClient.dio.get('/homeowner/me');
      return true;
    } catch (e) {
      // Token is invalid, clear all stored data
      await _dioClient.clearAllData();
      return false;
    }
  }

  ApiResult<T> _handleDioError<T>(DioException e) {
    if (e.response != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic>) {
        final apiError = ApiError.fromJson(data);
        return Failure(
          message: apiError.message,
          statusCode: e.response!.statusCode,
          errors: apiError.errors,
        );
      }
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const Failure(message: 'Connection timeout. Please try again.');
      case DioExceptionType.connectionError:
        return const Failure(message: 'No internet connection.');
      default:
        return Failure(message: 'Network error: ${e.message}');
    }
  }
}
