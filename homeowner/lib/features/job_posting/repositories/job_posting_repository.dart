import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_result.dart';
import '../../../features/job_posting/models/job_posting_models.dart';

class JobPostingRepository {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<ApiResult<List<CategoryModel>>> getCategories() async {
    try {
      // Use the same authentication method as job posting
      final token = await _getToken();
      print('🔐 Loading categories with token: ${token != null}');

      // Create Dio request with proper headers
      final dio = Dio();
      final response = await dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.categoriesEndpoint}',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );

      print('📥 Categories response: ${response.statusCode}');
      print('📄 Categories data: ${response.data}');

      final List<dynamic> data = response.data['data'] ?? response.data;
      final categories = data
          .map((category) => CategoryModel.fromJson(category))
          .toList();

      print('✅ Loaded ${categories.length} categories');
      return Success(categories);
    } on DioException catch (e) {
      print(
        '❌ Categories error: ${e.response?.statusCode} - ${e.response?.data}',
      );
      return _handleDioError(e);
    } catch (e) {
      print('❌ Categories unexpected error: $e');
      return Failure(message: 'An unexpected error occurred: $e');
    }
  }

  Future<ApiResult<List<ServiceModel>>> getServicesByCategory(
    int categoryId,
  ) async {
    try {
      // Use the same authentication method as job posting
      final token = await _getToken();
      print(
        '🔐 Loading services for category $categoryId with token: ${token != null}',
      );

      // Create Dio request with proper headers
      final dio = Dio();
      final response = await dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.categoriesEndpoint}/$categoryId/services',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );

      print('📥 Services response: ${response.statusCode}');
      print('📄 Services data: ${response.data}');

      // Handle the nested response structure
      final dynamic data = response.data;

      List<dynamic> servicesData = [];

      if (data is Map<String, dynamic>) {
        if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
          servicesData = data['data']['services'] ?? [];
        } else if (data.containsKey('services')) {
          servicesData = data['services'] ?? [];
        } else if (data.containsKey('data') && data['data'] is List) {
          servicesData = data['data'];
        }
      } else if (data is List) {
        servicesData = data;
      }

      final services = servicesData
          .map((service) => ServiceModel.fromJson(service))
          .toList();

      print('✅ Loaded ${services.length} services for category $categoryId');

      return Success(services);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return Failure(message: 'An unexpected error occurred: $e');
    }
  }

  /*   Future<ApiResult<JobPostResponse>> createJobPost(JobPostRequest request) async {
    try {
      final response = await _dioClient.dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.jobOffersEndpoint}',
        data: request.toJson(),
      );

      final jobPostResponse = JobPostResponse.fromJson(response.data['data'] ?? response.data);
      return Success(jobPostResponse);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return Failure(message: 'An unexpected error occurred: $e');
    }
  } */

  Future<ApiResult<JobPostResponse>> createJobPost(
    JobPostRequest request,
  ) async {
    try {
      // Use the same authentication method as messaging
      final token = await _getToken();
      print('🔐 Using messaging auth method:');
      print('🔐 Token exists: ${token != null}');
      if (token == null) {
        return Failure(message: 'Not authenticated. Please log in again.');
      }
      print('🔐 Token preview: ${token.substring(0, 20)}...');

      // Convert request to JSON - Laravel will get homeowner_id from auth token
      final Map<String, dynamic> requestData = request.toJson();

      // DEBUG PRINTING
      print('🚀 === SENDING JOB POST REQUEST ===');
      print('📤 URL: ${ApiConstants.baseUrl}${ApiConstants.jobOffersEndpoint}');
      print('📦 FULL PAYLOAD: $requestData');
      print('🔍 SERVICES FIELD: ${requestData['services']}');
      print('🔍 CATEGORY ID: ${requestData['service_category_id']}');
      print('===================================');

      // Create a new Dio instance with proper headers (like messaging does)
      final dio = Dio();
      final response = await dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.jobOffersEndpoint}',
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      // DEBUG PRINTING - Success Response
      print('✅ === JOB POST SUCCESS ===');
      print('📥 STATUS CODE: ${response.statusCode}');
      print('📄 RESPONSE DATA: ${response.data}');
      print('===========================');

      // FIX: Handle the nested response structure properly
      final responseData = response.data;
      dynamic dataToParse;

      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          // Response has {success: true, message: "...", data: {...}}
          dataToParse = responseData['data'];
          print('🔍 PARSING FROM: response.data[\'data\']');
        } else {
          // Response is the data object directly
          dataToParse = responseData;
          print('🔍 PARSING FROM: response.data directly');
        }
      } else {
        dataToParse = responseData;
      }

      print('🔍 DATA TO PARSE: $dataToParse');

      final jobPostResponse = JobPostResponse.fromJson(dataToParse);
      return Success(jobPostResponse);
    } on DioException catch (e) {
      // DEBUG PRINTING - Dio Error
      print('❌ === JOB POST DIO ERROR ===');
      print('💥 ERROR TYPE: ${e.type}');
      print('📊 STATUS CODE: ${e.response?.statusCode}');
      print('📝 ERROR MESSAGE: ${e.message}');
      print('🔍 ERROR RESPONSE DATA: ${e.response?.data}');
      print('=============================');

      // Handle authentication errors specifically
      if (e.response?.statusCode == 401) {
        // Clear stored credentials using the same method as messaging
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
        await prefs.remove('user_id');
        await prefs.remove('user_type');
        return Failure(
          message: 'Session expired. Please restart the app and log in again.',
          statusCode: 401,
        );
      }

      return _handleDioError(e);
    } catch (e) {
      // DEBUG PRINTING - General Error
      print('❌ === UNEXPECTED ERROR ===');
      print('💥 ERROR: $e');
      print('📋 ERROR TYPE: ${e.runtimeType}');
      if (e is TypeError) {
        print('🔍 TYPE ERROR DETAILS: $e');
      }
      print('===========================');

      return Failure(message: 'An unexpected error occurred: $e');
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

  // Get all job offers for current user
  Future<ApiResult<List<JobListResponse>>> getJobOffers() async {
    try {
      // Use the same authentication method as job posting
      final token = await _getToken();
      print('🔐 Loading job offers with token: ${token != null}');

      if (token == null) {
        return Failure(message: 'Not authenticated. Please log in again.');
      }

      // Create Dio request with proper headers (same as job posting)
      final dio = Dio();
      final response = await dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.jobOffersEndpoint}',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      print('📥 Job offers response: ${response.statusCode}');
      print('📄 Job offers data: ${response.data}');

      final List<dynamic> data = response.data['data'] ?? [];
      final jobOffers = data
          .map((job) => JobListResponse.fromJson(job))
          .toList();

      print('✅ Loaded ${jobOffers.length} job offers');
      return Success(jobOffers);
    } on DioException catch (e) {
      print(
        '❌ Job offers error: ${e.response?.statusCode} - ${e.response?.data}',
      );

      // Handle authentication errors
      if (e.response?.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
        await prefs.remove('user_id');
        await prefs.remove('user_type');
        return Failure(
          message: 'Session expired. Please restart the app and log in again.',
          statusCode: 401,
        );
      }

      return _handleDioError(e);
    } catch (e) {
      print('❌ Job offers unexpected error: $e');
      return Failure(message: 'An unexpected error occurred: $e');
    }
  }

  // Get single job offer details
  Future<ApiResult<JobPostResponse>> getJobOfferDetails(int jobId) async {
    try {
      final token = await _getToken();

      if (token == null) {
        return Failure(message: 'Not authenticated. Please log in again.');
      }

      final dio = Dio();
      final response = await dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.jobOffersEndpoint}/$jobId',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final data = response.data['data'] ?? response.data;
      final jobOffer = JobPostResponse.fromJson(data);

      return Success(jobOffer);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
        await prefs.remove('user_id');
        await prefs.remove('user_type');
        return Failure(
          message: 'Session expired. Please restart the app and log in again.',
          statusCode: 401,
        );
      }
      return _handleDioError(e);
    } catch (e) {
      return Failure(message: 'An unexpected error occurred: $e');
    }
  }

  // Delete job offer
  Future<ApiResult<void>> deleteJobOffer(int jobId) async {
    try {
      final token = await _getToken();

      if (token == null) {
        return Failure(message: 'Not authenticated. Please log in again.');
      }

      final dio = Dio();
      await dio.delete(
        '${ApiConstants.baseUrl}${ApiConstants.jobOffersEndpoint}/$jobId',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      return const Success(null);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
        await prefs.remove('user_id');
        await prefs.remove('user_type');
        return Failure(
          message: 'Session expired. Please restart the app and log in again.',
          statusCode: 401,
        );
      }
      return _handleDioError(e);
    } catch (e) {
      return Failure(message: 'An unexpected error occurred: $e');
    }
  }

  // Update job offer
  Future<ApiResult<JobPostResponse>> updateJobOffer(
    int jobId,
    JobPostRequest request,
  ) async {
    try {
      final token = await _getToken();

      if (token == null) {
        return Failure(message: 'Not authenticated. Please log in again.');
      }

      final Map<String, dynamic> requestData = request.toJson();

      final dio = Dio();
      final response = await dio.put(
        '${ApiConstants.baseUrl}${ApiConstants.jobOffersEndpoint}/$jobId',
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final responseData = response.data;
      dynamic dataToParse;

      if (responseData is Map<String, dynamic>) {
        dataToParse = responseData['data'] ?? responseData;
      } else {
        dataToParse = responseData;
      }

      final jobPostResponse = JobPostResponse.fromJson(dataToParse);
      return Success(jobPostResponse);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
        await prefs.remove('user_id');
        await prefs.remove('user_type');
        return Failure(
          message: 'Session expired. Please restart the app and log in again.',
          statusCode: 401,
        );
      }
      return _handleDioError(e);
    } catch (e) {
      return Failure(message: 'An unexpected error occurred: $e');
    }
  }
}
