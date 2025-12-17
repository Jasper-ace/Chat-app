import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

class DioClient {
  static DioClient? _instance;
  late Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  DioClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': ApiConstants.contentType,
          'Accept': ApiConstants.accept,
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'access_token');
          print('🔑 DioClient: Token check for ${options.path}');
          print('🔑 Token exists: ${token != null}');
          if (token != null) {
            print('🔑 Token preview: ${token.substring(0, 20)}...');
            options.headers[ApiConstants.authorization] =
                '${ApiConstants.bearer} $token';
            print(
              '🔑 Authorization header set: ${ApiConstants.bearer} ${token.substring(0, 20)}...',
            );
          } else {
            print('❌ No token found in storage');
          }
          print('📤 Request headers: ${options.headers}');
          handler.next(options);
        },
        onError: (error, handler) async {
          print('❌ DioClient Error: ${error.response?.statusCode}');
          print('❌ Error data: ${error.response?.data}');
          if (error.response?.statusCode == 401) {
            print('🔄 Clearing token due to 401 error');
            await _storage.delete(key: 'access_token');
            await _storage.delete(key: 'user_id');
          }
          handler.next(error);
        },
      ),
    );
  }

  static DioClient get instance {
    _instance ??= DioClient._internal();
    return _instance!;
  }

  Dio get dio => _dio;

  Future<void> setToken(String token) async {
    await _storage.write(key: 'access_token', value: token);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: 'access_token');
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<void> setUserId(int userId) async {
    await _storage.write(key: 'user_id', value: userId.toString());
  }

  Future<void> clearUserId() async {
    await _storage.delete(key: 'user_id');
  }

  Future<int?> getUserId() async {
    final userIdString = await _storage.read(key: 'user_id');
    return userIdString != null ? int.tryParse(userIdString) : null;
  }

  Future<void> clearAllData() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'user_id');
  }
}
