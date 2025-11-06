import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'secure_storage_service.dart';

class HttpService {
  static final HttpService _instance = HttpService._internal();
  factory HttpService() => _instance;
  HttpService._internal() {
    // Initialize Dio in the constructor
    _initializeDio();
  }

  late Dio _dio;
  final Map<String, CancelToken> _cancelTokens = {};
  static final String baseUrl = '${ApiService.baseApi}/api';

  void _initializeDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Add interceptor for automatic token handling
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token if available from secure storage
          final token = await SecureStorageService().getAccessToken();
          if (kDebugMode) {
            debugPrint('🔐 HTTP Request: ${options.method} ${options.uri}');
          }
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
            if (kDebugMode) {
              debugPrint('🔐 ✅ Auth token added (length: ${token.length})');
            }
          } else {
            if (kDebugMode) {
              debugPrint('🔐 ⚠️ No auth token found in secure storage');
            }
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (kDebugMode) {
            debugPrint(
              '🔐 ❌ HTTP Error: ${error.response?.statusCode} - ${error.message}',
            );
            debugPrint('🔐 Response data: ${error.response?.data}');
          }
          // Handle 401 errors (token expired)
          if (error.response?.statusCode == 401) {
            if (kDebugMode) {
              debugPrint('🔐 ⚠️ 401 Unauthorized - clearing tokens');
            }
            // Clear tokens from secure storage
            await SecureStorageService().clearAuthCredentials();
          }
          return handler.next(error);
        },
      ),
    );
  }

  // Public initialize method for backward compatibility (optional to call)
  void initialize() {
    // Dio is already initialized in constructor, but this can be used
    // to reinitialize if needed
    if (kDebugMode) {
      debugPrint('🔐 HttpService already initialized in constructor');
    }
  }

  // Cancel request by tag
  void cancelRequest(String tag) {
    if (_cancelTokens.containsKey(tag)) {
      _cancelTokens[tag]?.cancel('Request cancelled by user');
      _cancelTokens.remove(tag);
    }
  }

  // Cancel all pending requests
  void cancelAllRequests() {
    for (var token in _cancelTokens.values) {
      token.cancel('All requests cancelled');
    }
    _cancelTokens.clear();
  }

  // GET request with deduplication
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? tag,
  }) async {
    // Cancel previous request with same tag if exists
    if (tag != null) {
      cancelRequest(tag);
      _cancelTokens[tag] = CancelToken();
    }

    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        cancelToken: tag != null ? _cancelTokens[tag] : null,
      );

      if (tag != null) _cancelTokens.remove(tag);
      return response;
    } catch (e) {
      if (tag != null) _cancelTokens.remove(tag);
      rethrow;
    }
  }

  // POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    String? tag,
  }) async {
    if (tag != null) {
      cancelRequest(tag);
      _cancelTokens[tag] = CancelToken();
    }

    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: tag != null ? _cancelTokens[tag] : null,
      );

      if (tag != null) _cancelTokens.remove(tag);
      return response;
    } catch (e) {
      if (tag != null) _cancelTokens.remove(tag);
      rethrow;
    }
  }

  // PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    String? tag,
  }) async {
    if (tag != null) {
      cancelRequest(tag);
      _cancelTokens[tag] = CancelToken();
    }

    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: tag != null ? _cancelTokens[tag] : null,
      );

      if (tag != null) _cancelTokens.remove(tag);
      return response;
    } catch (e) {
      if (tag != null) _cancelTokens.remove(tag);
      rethrow;
    }
  }

  // DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    String? tag,
  }) async {
    if (tag != null) {
      cancelRequest(tag);
      _cancelTokens[tag] = CancelToken();
    }

    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: tag != null ? _cancelTokens[tag] : null,
      );

      if (tag != null) _cancelTokens.remove(tag);
      return response;
    } catch (e) {
      if (tag != null) _cancelTokens.remove(tag);
      rethrow;
    }
  }

  // Upload file with progress
  Future<Response> uploadFile(
    String path, {
    required FormData formData,
    Function(int, int)? onProgress,
    String? tag,
  }) async {
    if (tag != null) {
      cancelRequest(tag);
      _cancelTokens[tag] = CancelToken();
    }

    try {
      final response = await _dio.post(
        path,
        data: formData,
        onSendProgress: onProgress,
        cancelToken: tag != null ? _cancelTokens[tag] : null,
      );

      if (tag != null) _cancelTokens.remove(tag);
      return response;
    } catch (e) {
      if (tag != null) _cancelTokens.remove(tag);
      rethrow;
    }
  }
}
