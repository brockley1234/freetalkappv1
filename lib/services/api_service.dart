import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../config/app_config.dart';
import 'secure_storage_service.dart';

class ApiService {
  // Use centralized configuration
  static String get messagebaseUrl => AppConfig.messagebaseUrl;
  static String get appName => AppConfig.appName;
  static String get appVersion => AppConfig.appVersion;
  static String get videosbaseUrl => AppConfig.videosbaseUrl;
  static String get baseApi => AppConfig.baseApi;
  static String get baseUrl => AppConfig.baseUrl;

  // In-memory cache for device ID to avoid repeated secure storage reads
  // This significantly improves performance since device ID is used in every API request
  static String? _cachedDeviceId;
  static bool _deviceIdInitialized = false;

  // Helper method for conditional logging (only in debug mode)
  static void _log(String message) {
    if (AppConfig.enableDebugLogs) {
      debugPrint(message);
    }
  }

  // Get stored access token (SECURE: Uses Keychain/EncryptedSharedPreferences)
  static Future<String?> getAccessToken() async {
    return await SecureStorageService().getAccessToken();
  }

  // Get stored refresh token (SECURE: Uses Keychain/EncryptedSharedPreferences)
  static Future<String?> getRefreshToken() async {
    return await SecureStorageService().getRefreshToken();
  }

  // Store tokens and user ID (SECURE: Uses Keychain/EncryptedSharedPreferences)
  static Future<void> storeTokens(
    String accessToken,
    String refreshToken, {
    String? userId,
  }) async {
    await SecureStorageService().setAccessToken(accessToken);
    await SecureStorageService().setRefreshToken(refreshToken);
    if (userId != null) {
      await SecureStorageService().setUserId(userId);
      _log('✅ Stored userId securely: $userId');
    }
  }

  // Clear tokens and user ID (SECURE: Uses Keychain/EncryptedSharedPreferences)
  static Future<void> clearTokens() async {
    await SecureStorageService().clearAuthCredentials();
    // Note: Device ID is NOT cleared on logout as it's device-specific, not user-specific
    // This allows the backend to track device usage patterns for security
    _log('✅ Cleared tokens and userId');
  }

  // Store remembered credentials (for Remember Me feature)
  static Future<void> storeRememberedCredentials({
    required String email,
    String? name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('remembered_email', email);
    await prefs.setBool('remember_me', true);
    if (name != null) {
      await prefs.setString('remembered_name', name);
    }
    _log('✅ Stored remembered credentials for: $email');
  }

  // Get remembered credentials
  static Future<Map<String, String?>> getRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (!rememberMe) {
      return {'email': null, 'name': null};
    }

    return {
      'email': prefs.getString('remembered_email'),
      'name': prefs.getString('remembered_name'),
    };
  }

  // Clear remembered credentials
  static Future<void> clearRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('remembered_email');
    await prefs.remove('remembered_name');
    await prefs.remove('remember_me');
    _log('✅ Cleared remembered credentials');
  }

  // Check if Remember Me is enabled
  static Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('remember_me') ?? false;
  }

  // Get platform identifier for API requests
  static String _getPlatform() {
    if (kIsWeb) {
      return 'web';
    } else if (Platform.isIOS) {
      return 'ios';
    } else if (Platform.isAndroid) {
      return 'android';
    } else {
      return 'unknown';
    }
  }

  // Get device ID (if available) - uses device_info_plus package
  // Device ID is cached in memory and secure storage for optimal performance
  // iOS: Uses identifierForVendor (App Store compliant, unique per app on device)
  // Android: Uses Android ID (unique per app installation)
  // Web: Uses browser user agent hash
  static Future<String?> _getDeviceId() async {
    try {
      // Return cached device ID if available (fast path for performance)
      if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
        return _cachedDeviceId;
      }

      // If already initialized but cache is empty, return null to avoid repeated attempts
      if (_deviceIdInitialized) {
        return null;
      }

      // Mark as initialized to prevent concurrent initialization
      _deviceIdInitialized = true;

      // Try to get cached device ID from secure storage
      final storedDeviceId = await SecureStorageService().readSecure('device_id');
      if (storedDeviceId != null && storedDeviceId.isNotEmpty) {
        _cachedDeviceId = storedDeviceId;
        return _cachedDeviceId;
      }

      // If not cached, generate and store device ID
      final deviceInfo = DeviceInfoPlugin();
      String? deviceId;

      if (kIsWeb) {
        // For web, use a combination of browser info
        // Note: User agent hash is not a persistent identifier but sufficient for web
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceId = 'web_${webInfo.userAgent?.hashCode ?? DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isAndroid) {
        // For Android, use Android ID (unique per app installation)
        // No special permissions required - this is a system identifier
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = 'android_${androidInfo.id}';
      } else if (Platform.isIOS) {
        // For iOS, use identifierForVendor (unique per app on device)
        // This is App Store compliant and doesn't require special permissions
        // identifierForVendor may be null on iOS 14+ if user resets advertising identifier
        final iosInfo = await deviceInfo.iosInfo;
        final vendorId = iosInfo.identifierForVendor;
        if (vendorId != null && vendorId.isNotEmpty) {
          deviceId = 'ios_$vendorId';
        } else {
          // Fallback: Generate a persistent ID stored in secure storage
          // This ensures we have a stable identifier even if identifierForVendor is unavailable
          final fallbackId = await SecureStorageService().readSecure('ios_fallback_device_id');
          if (fallbackId != null && fallbackId.isNotEmpty) {
            deviceId = 'ios_fallback_$fallbackId';
          } else {
            final newFallbackId = DateTime.now().millisecondsSinceEpoch.toString();
            await SecureStorageService().writeSecure('ios_fallback_device_id', newFallbackId);
            deviceId = 'ios_fallback_$newFallbackId';
          }
        }
      } else {
        // Fallback for other platforms
        deviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      }

      // Store device ID in secure storage and memory cache for future use
      if (deviceId.isNotEmpty) {
        await SecureStorageService().writeSecure('device_id', deviceId);
        _cachedDeviceId = deviceId;
        _log('✅ Device ID initialized and cached: ${deviceId.substring(0, deviceId.length > 20 ? 20 : deviceId.length)}...');
      }

      return deviceId;
    } catch (e) {
      _log('❌ Error retrieving device ID: $e');
      _deviceIdInitialized = true; // Mark as initialized even on error to prevent retry loops
      return null;
    }
  }

  // Clear device ID cache (useful for testing or when user logs out)
  static void clearDeviceIdCache() {
    _cachedDeviceId = null;
    _deviceIdInitialized = false;
  }

  // Get headers with authentication and platform info
  static Future<Map<String, String>> _getHeaders({
    bool includeAuth = false,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'x-platform': _getPlatform(), // Add platform header for backend
    };

    // Add device ID if available
    final deviceId = await _getDeviceId();
    if (deviceId != null) {
      headers['x-device-id'] = deviceId;
    }

    if (includeAuth) {
      final token = await getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // Handle API response
  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final body = json.decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body;
      } else {
        // For 403 responses with requiresPremium flag, return the body instead of throwing
        // This allows the frontend to handle premium requirements gracefully
        if (response.statusCode == 403 && body['requiresPremium'] == true) {
          return body;
        }
        
        throw ApiException(
          statusCode: response.statusCode,
          message: body['message'] ?? 'An error occurred',
          errors: body['errors'],
        );
      }
    } catch (e) {
      // If JSON parsing fails or any other error occurs
      if (e is ApiException) {
        rethrow; // Re-throw ApiException as-is
      }

      // For JSON parsing errors or other issues, create a generic error
      debugPrint('❌ Error parsing response: $e');
      debugPrint('Response body: ${response.body}');
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to process server response. Please try again.',
      );
    }
  }

  // Track last refresh attempt to prevent rapid retries
  static DateTime? _lastRefreshAttempt;
  static int _refreshRetryCount = 0;
  static const int _maxRefreshRetries = 5;
  static const Duration _minRefreshInterval = Duration(seconds: 5);

  // Refresh access token with exponential backoff
  static Future<bool> refreshToken() async {
    try {
      // Prevent rapid successive refresh attempts
      if (_lastRefreshAttempt != null) {
        final timeSinceLastAttempt = DateTime.now().difference(_lastRefreshAttempt!);
        if (timeSinceLastAttempt < _minRefreshInterval) {
          if (AppConfig.enableDebugLogs) {
            debugPrint('⏱️ Rate limiting: Too soon since last refresh attempt');
          }
          return false;
        }
      }

      if (AppConfig.enableDebugLogs) {
        debugPrint('🔄 Attempting to refresh token...');
      }
      
      final storedRefreshToken = await getRefreshToken();
      if (storedRefreshToken == null) {
        if (AppConfig.enableDebugLogs) {
          debugPrint('❌ No refresh token found');
        }
        return false;
      }

      _lastRefreshAttempt = DateTime.now();

      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: await _getHeaders(),
        body: json.encode({'refreshToken': storedRefreshToken}),
      ).timeout(AppConfig.apiTimeout);

      if (AppConfig.enableDebugLogs) {
        debugPrint('🔄 Refresh response status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        await storeTokens(
          body['data']['accessToken'],
          body['data']['refreshToken'],
        );
        _refreshRetryCount = 0; // Reset retry count on success
        if (AppConfig.enableDebugLogs) {
          debugPrint('✅ Token refreshed successfully');
        }
        return true;
      } else if (response.statusCode == 401) {
        // 401 means refresh token is invalid (user logged out or token expired)
        // Clear tokens to prevent further refresh attempts
        if (AppConfig.enableDebugLogs) {
          debugPrint('❌ Refresh token invalid (401) - user has logged out');
        }
        await clearTokens();
        _refreshRetryCount = 0;
        return false;
      } else if (response.statusCode == 429) {
        // Rate limited - implement exponential backoff
        _refreshRetryCount++;
        if (_refreshRetryCount <= _maxRefreshRetries) {
          final waitTime = Duration(seconds: (2 * _refreshRetryCount));
          if (AppConfig.enableDebugLogs) {
            debugPrint('⚠️ Rate limited (429). Retry $_refreshRetryCount/$_maxRefreshRetries after ${waitTime.inSeconds}s');
          }
          await Future.delayed(waitTime);
          return refreshToken(); // Recursive retry with exponential backoff
        } else {
          if (AppConfig.enableDebugLogs) {
            debugPrint('❌ Max refresh retries exceeded');
          }
          _refreshRetryCount = 0;
          return false;
        }
      }
      
      if (AppConfig.enableDebugLogs) {
        debugPrint('❌ Token refresh failed with status: ${response.statusCode}');
      }
      return false;
    } catch (e) {
      if (AppConfig.enableDebugLogs) {
        debugPrint('❌ Token refresh error: $e');
      }
      return false;
    }
  }

  // Make authenticated API call with token refresh
  static Future<Map<String, dynamic>> _makeAuthenticatedRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      var response = await request();
      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException && e.statusCode == 401) {
        if (AppConfig.enableDebugLogs) {
          debugPrint('🔐 Got 401 error, attempting token refresh...');
        }
        // Try to refresh token
        final refreshed = await refreshToken();
        if (refreshed) {
          if (AppConfig.enableDebugLogs) {
            debugPrint('🔐 Token refreshed, retrying request...');
          }
          // Retry the request
          final response = await request();
          return _handleResponse(response);
        } else {
          if (AppConfig.enableDebugLogs) {
            debugPrint('🔐 Token refresh failed, clearing tokens');
          }
          // Refresh failed, clear tokens
          await clearTokens();
          rethrow;
        }
      }
      rethrow;
    }
  }

  // Public helpers for other services
  static Future<Map<String, String>> getAuthHeaders() async {
    return await _getHeaders(includeAuth: true);
  }

  static Future<Map<String, dynamic>> makeAuthenticated(
    Future<http.Response> Function() request,
  ) async {
    return await _makeAuthenticatedRequest(request);
  }

  // Register user
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String pinCode,
    required String securityQuestion,
    required String securityAnswer,
    String? password, // Optional for backward compatibility
  }) async {
    try {
      final body = {
        'name': name,
        'email': email,
        'pinCode': pinCode,
        'securityQuestion': securityQuestion,
        'securityAnswer': securityAnswer,
      };

      // Only include password if provided (for backward compatibility)
      if (password != null && password.isNotEmpty) {
        body['password'] = password;
      }

      debugPrint('📤 Registering user: $email');
      debugPrint(
          '📋 PIN length: ${pinCode.length}, PIN value: ${pinCode.isEmpty ? "[EMPTY]" : "[PROVIDED]"}');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: await _getHeaders(),
        body: json.encode(body),
      );

      debugPrint('📥 Register response status: ${response.statusCode}');

      final result = _handleResponse(response);

      // Store tokens if registration successful
      if (result['success'] == true && result['data'] != null) {
        final userId = result['data']['user']?['_id'];
        await storeTokens(
          result['data']['accessToken'],
          result['data']['refreshToken'],
          userId: userId,
        );
        debugPrint(
          '✅ Registration successful - stored tokens and userId: $userId',
        );
      }

      return result;
    } catch (e) {
      debugPrint('❌ Registration error: $e');
      rethrow; // Re-throw to let the UI handle it
    }
  }

  // Login user
  static Future<Map<String, dynamic>> login({
    required String email,
    String? password,
    String? pinCode,
  }) async {
    final body = {'email': email.trim()};

    // Add PIN code or password based on what's provided
    if (pinCode != null && pinCode.isNotEmpty) {
      body['pinCode'] = pinCode.trim();
    } else if (password != null && password.isNotEmpty) {
      body['password'] = password;
    }

    // Debug logging
    _log(
        '🔐 Login attempt - Email: $email, Has PIN: ${pinCode?.isNotEmpty ?? false}, Has Password: ${password?.isNotEmpty ?? false}');
    _log('📤 Request body: ${json.encode(body)}');

    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: await _getHeaders(),
      body: json.encode(body),
    );

    _log(
        '📥 Login response - Status: ${response.statusCode}, Body: ${response.body}');

    final result = _handleResponse(response);

    // Store tokens if login successful
    if (result['success'] == true && result['data'] != null) {
      final userId = result['data']['user']?['_id'];
      await storeTokens(
        result['data']['accessToken'],
        result['data']['refreshToken'],
        userId: userId,
      );
      _log('✅ Login successful - stored tokens and userId: $userId');
    }

    return result;
  }

  // Reset PIN code using old PIN verification
  static Future<Map<String, dynamic>> resetPin({
    required String email,
    required String oldPinCode,
    required String newPinCode,
  }) async {
    try {
      debugPrint('📤 Resetting PIN for: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-pin'),
        headers: await _getHeaders(),
        body: json.encode({
          'email': email,
          'oldPinCode': oldPinCode,
          'newPinCode': newPinCode,
        }),
      );

      debugPrint('📥 Reset PIN response status: ${response.statusCode}');

      final result = _handleResponse(response);

      if (result['success'] == true) {
        debugPrint('✅ PIN reset successful');
      }

      return result;
    } catch (e) {
      debugPrint('❌ Reset PIN error: $e');
      rethrow; // Re-throw to let the UI handle it
    }
  }

  // Verify security answer and get permission to reset PIN
  static Future<Map<String, dynamic>> verifySecurityAnswer({
    required String email,
    required String securityAnswer,
  }) async {
    try {
      debugPrint('📤 Verifying security answer for: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/recover-pin'),
        headers: await _getHeaders(),
        body: json.encode({
          'email': email,
          'securityAnswer': securityAnswer,
        }),
      );

      debugPrint(
          '📥 Verify security answer response status: ${response.statusCode}');

      final result = _handleResponse(response);

      if (result['success'] == true) {
        debugPrint('✅ Security answer verified successfully');
      }

      return result;
    } catch (e) {
      debugPrint('❌ Verify security answer error: $e');
      rethrow;
    }
  }

  // Reset PIN using security answer (after verification)
  static Future<Map<String, dynamic>> recoverPinWithSecurityAnswer({
    required String email,
    required String securityAnswer,
    required String newPinCode,
  }) async {
    try {
      debugPrint('📤 Recovering PIN with security answer for: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/recover-pin-reset'),
        headers: await _getHeaders(),
        body: json.encode({
          'email': email,
          'securityAnswer': securityAnswer,
          'newPinCode': newPinCode,
        }),
      );

      debugPrint('📥 Recover PIN response status: ${response.statusCode}');

      final result = _handleResponse(response);

      if (result['success'] == true) {
        debugPrint('✅ PIN recovered and reset successfully');
      }

      return result;
    } catch (e) {
      debugPrint('❌ Recover PIN error: $e');
      rethrow;
    }
  }

  // Request PIN reset via email
  static Future<Map<String, dynamic>> forgotPin({
    required String email,
  }) async {
    try {
      debugPrint('📤 Requesting PIN reset for: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-pin'),
        headers: await _getHeaders(),
        body: json.encode({
          'email': email,
        }),
      );

      debugPrint('📥 Forgot PIN response status: ${response.statusCode}');

      final result = _handleResponse(response);

      if (result['success'] == true) {
        debugPrint('✅ PIN reset email sent successfully');
      }

      return result;
    } catch (e) {
      debugPrint('❌ Forgot PIN error: $e');
      rethrow;
    }
  }

  // Reset PIN using email token
  static Future<Map<String, dynamic>> resetPinWithToken({
    required String token,
    required String newPinCode,
  }) async {
    try {
      debugPrint('📤 Resetting PIN with token');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-pin-with-token'),
        headers: await _getHeaders(),
        body: json.encode({
          'token': token,
          'newPinCode': newPinCode,
        }),
      );

      debugPrint('📥 Reset PIN with token response status: ${response.statusCode}');

      final result = _handleResponse(response);

      if (result['success'] == true) {
        debugPrint('✅ PIN reset with token successful');
      }

      return result;
    } catch (e) {
      debugPrint('❌ Reset PIN with token error: $e');
      rethrow;
    }
  }

  // Reset password using PIN code (no SMS/email verification needed)
  static Future<Map<String, dynamic>> resetPasswordWithPin({
    required String email,
    required String pinCode,
    required String newPassword,
  }) async {
    try {
      debugPrint('📤 Resetting password with PIN for: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password-with-pin'),
        headers: await _getHeaders(),
        body: json.encode({
          'email': email,
          'pinCode': pinCode,
          'newPassword': newPassword,
        }),
      );

      debugPrint('📥 Reset password response status: ${response.statusCode}');

      final result = _handleResponse(response);

      if (result['success'] == true) {
        debugPrint('✅ Password reset successful');
      }

      return result;
    } catch (e) {
      debugPrint('❌ Reset password error: $e');
      rethrow; // Re-throw to let the UI handle it
    }
  }

  // Resend verification email
  static Future<Map<String, dynamic>> resendVerificationEmail(
    String userId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/resend-verification'),
        headers: await _getHeaders(),
        body: json.encode({'userId': userId}),
      );

      return _handleResponse(response);
    } catch (e) {
      _log('❌ Error resending verification email: $e');
      throw ApiException(
        statusCode: 500,
        message: 'Failed to resend verification email. Please try again later.',
      );
    }
  }

  // Add phone number to user account
  static Future<Map<String, dynamic>> addPhone({
    required String userId,
    required String phoneNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/add-phone'),
        headers: await _getHeaders(),
        body: json.encode({
          'userId': userId,
          'phoneNumber': phoneNumber,
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      _log('❌ Error adding phone: $e');
      throw ApiException(
        statusCode: 500,
        message: 'Failed to send verification code. Please try again later.',
      );
    }
  }

  // Verify phone number with code
  static Future<Map<String, dynamic>> verifyPhone({
    required String userId,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-phone'),
        headers: await _getHeaders(),
        body: json.encode({
          'userId': userId,
          'code': code,
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      _log('❌ Error verifying phone: $e');
      throw ApiException(
        statusCode: 500,
        message: 'Failed to verify phone. Please try again.',
      );
    }
  }

  // Social login (Apple, Google, Facebook)
  static Future<Map<String, dynamic>> socialLogin({
    required String provider,
    required String identityToken,
    String? email,
    String? name,
    String? accessToken, // Add optional access token parameter
  }) async {
    final body = <String, dynamic>{};

    // Different providers use different token field names
    if (provider == 'google') {
      // For Google, try to send ID token, but also send access token if available
      body['idToken'] = identityToken;
      if (accessToken != null) {
        body['accessToken'] = accessToken;
      }
    } else if (provider == 'facebook') {
      body['accessToken'] = identityToken;
    } else if (provider == 'apple') {
      body['identityToken'] = identityToken;
    } else {
      body['identityToken'] = identityToken; // fallback
    }

    if (email != null) body['email'] = email;
    if (name != null) body['name'] = name;

    final response = await http.post(
      Uri.parse('$baseUrl/auth/$provider'),
      headers: await _getHeaders(),
      body: json.encode(body),
    );

    final result = _handleResponse(response);

    // Store tokens if login successful
    if (result['success'] == true && result['data'] != null) {
      final userId =
          result['data']['user']?['id'] ?? result['data']['user']?['_id'];
      final tokens = result['data']['tokens'];

      if (tokens != null) {
        await storeTokens(
          tokens['accessToken'],
          tokens['refreshToken'],
          userId: userId,
        );
        _log(
            '✅ $provider login successful - stored tokens and userId: $userId');
      }
    }

    return result;
  }

  // Logout user
  // Always clears tokens locally, even if backend call fails
  // Handles 401 errors specially (token already invalid) - clears tokens immediately
  static Future<Map<String, dynamic>> logout() async {
    try {
      // Get token before making request
      final token = await getAccessToken();
      
      // If no token exists, just clear everything and return success
      if (token == null) {
        _log('⚠️ No token found, clearing local data');
        await clearTokens();
        await clearRememberedCredentials();
        clearDeviceIdCache();
        return {
          'success': true,
          'message': 'Already logged out',
        };
      }
      
      // Try to call backend logout endpoint
      // Use direct http call instead of _makeAuthenticatedRequest to avoid token refresh attempts
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: await _getHeaders(includeAuth: true),
        ).timeout(AppConfig.apiTimeout);
        
        final result = _handleResponse(response);
        
        // Clear tokens and credentials after successful logout
        await clearTokens();
        await clearRememberedCredentials();
        clearDeviceIdCache();
        
        _log('✅ Logout successful - tokens cleared');
        return result;
      } catch (apiError) {
        // Handle API errors (including 401 - token already invalid)
        if (apiError is ApiException && apiError.statusCode == 401) {
          _log('⚠️ Token already invalid (401), clearing tokens locally');
        } else {
          _log('⚠️ Backend logout failed, clearing tokens locally: $apiError');
        }
        
        // Always clear tokens locally, even if backend call fails
        await clearTokens();
        await clearRememberedCredentials();
        clearDeviceIdCache();
        
        _log('✅ Tokens cleared locally');
        
        // Return success response so UI can proceed with logout
        return {
          'success': true,
          'message': 'Logged out locally',
        };
      }
    } catch (e) {
      // Catch-all error handler - ensure tokens are always cleared
      _log('❌ Unexpected error during logout, clearing tokens: $e');
      
      try {
        await clearTokens();
        await clearRememberedCredentials();
        clearDeviceIdCache();
        _log('✅ Tokens cleared despite error');
      } catch (clearError) {
        _log('❌ Error clearing tokens: $clearError');
      }
      
      // Return success response so UI can proceed with logout
      return {
        'success': true,
        'message': 'Logged out locally (error occurred)',
      };
    }
  }

  // Update FCM token
  static Future<Map<String, dynamic>> updateFCMToken(String fcmToken) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/auth/update-fcm-token'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({'fcmToken': fcmToken}),
      );
    });
  }

  // Get current user profile
  static Future<Map<String, dynamic>> getCurrentUser() async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Update user profile
  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? bio,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    // Always include bio (even if empty string) to allow clearing bio
    body['bio'] = bio ?? '';

    return await _makeAuthenticatedRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/users/profile'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode(body),
      );
    });
  }

  // Upload profile avatar
  static Future<Map<String, dynamic>> uploadProfileAvatar(
    XFile imageFile,
  ) async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/users/profile/avatar'),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add image file
      final bytes = await imageFile.readAsBytes();

      // Determine the proper mime type
      String fileExtension = imageFile.path.split('.').last.toLowerCase();
      String mimeSubtype;

      // Map common extensions to proper MIME subtypes
      switch (fileExtension) {
        case 'jpg':
        case 'jpeg':
          mimeSubtype = 'jpeg';
          break;
        case 'png':
          mimeSubtype = 'png';
          break;
        case 'gif':
          mimeSubtype = 'gif';
          break;
        case 'webp':
          mimeSubtype = 'webp';
          break;
        case 'bmp':
          mimeSubtype = 'bmp';
          break;
        default:
          mimeSubtype = fileExtension;
      }

      debugPrint('📤 Uploading avatar:');
      debugPrint('   Filename: ${imageFile.name}');
      debugPrint('   Extension: $fileExtension');
      debugPrint('   MIME Type: image/$mimeSubtype');
      debugPrint('   Size: ${bytes.length} bytes');

      final multipartFile = http.MultipartFile.fromBytes(
        'avatar',
        bytes,
        filename: imageFile.name,
        contentType: MediaType('image', mimeSubtype),
      );
      request.files.add(multipartFile);

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('Upload avatar response status: ${response.statusCode}');
      debugPrint('Upload avatar response body: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error uploading profile avatar: $e');
      rethrow;
    }
  }

  // Upload feed banner photo
  static Future<Map<String, dynamic>> uploadFeedBanner(
    XFile imageFile,
  ) async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/users/feed-banner'),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add image file
      final bytes = await imageFile.readAsBytes();

      // Determine the proper mime type
      String fileExtension = imageFile.path.split('.').last.toLowerCase();
      String mimeSubtype;

      // Map common extensions to proper MIME subtypes
      switch (fileExtension) {
        case 'jpg':
        case 'jpeg':
          mimeSubtype = 'jpeg';
          break;
        case 'png':
          mimeSubtype = 'png';
          break;
        case 'gif':
          mimeSubtype = 'gif';
          break;
        case 'webp':
          mimeSubtype = 'webp';
          break;
        case 'bmp':
          mimeSubtype = 'bmp';
          break;
        default:
          mimeSubtype = fileExtension;
      }

      debugPrint('📤 Uploading feed banner:');
      debugPrint('   Filename: ${imageFile.name}');
      debugPrint('   Extension: $fileExtension');
      debugPrint('   MIME Type: image/$mimeSubtype');
      debugPrint('   Size: ${bytes.length} bytes');

      final multipartFile = http.MultipartFile.fromBytes(
        'feedBanner',
        bytes,
        filename: imageFile.name,
        contentType: MediaType('image', mimeSubtype),
      );
      request.files.add(multipartFile);

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('Upload feed banner response status: ${response.statusCode}');
      debugPrint('Upload feed banner response body: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error uploading feed banner: $e');
      rethrow;
    }
  }

  // Get user by ID
  static Future<Map<String, dynamic>> getUserById(String userId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get suggested users
  static Future<Map<String, dynamic>> getSuggestedUsers({
    int limit = 5,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/users/suggested?limit=$limit'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get top users by follower count
  static Future<Map<String, dynamic>> getTopUsers({
    int limit = 5,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/users/top?limit=$limit'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Search users
  static Future<Map<String, dynamic>> searchUsers({
    required String query,
    int limit = 10,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/users/search?q=$query&limit=$limit'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get current user's followers
  static Future<Map<String, dynamic>> getMyFollowers() async {
    return await _makeAuthenticatedRequest(() async {
      final userResult = await getCurrentUser();
      if (userResult['success'] == true) {
        final userId = userResult['data']['user']['_id'];
        return await http.get(
          Uri.parse('$baseUrl/users/$userId/followers'),
          headers: await _getHeaders(includeAuth: true),
        );
      }
      throw Exception('Failed to get current user');
    });
  }

  // Search users for @mention autocomplete (followers only)
  static Future<Map<String, dynamic>> searchForMention(String query) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse(
          '$baseUrl/user/mention-search?q=${Uri.encodeComponent(query)}&limit=10',
        ),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null;
  }

  // Health check
  static Future<Map<String, dynamic>> healthCheck() async {
    final response = await http.get(
      Uri.parse('$baseUrl/health'),
      headers: await _getHeaders(),
    );

    return _handleResponse(response);
  }

  // ========== Posts API ==========

  // Search posts by content
  static Future<Map<String, dynamic>> searchPosts({
    required String query,
    int page = 1,
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) {
      return {'success': false, 'message': 'Search query cannot be empty'};
    }

    return await _makeAuthenticatedRequest(() async {
      final encodedQuery = Uri.encodeComponent(query.trim());
      return await http.get(
        Uri.parse(
          '$baseUrl/posts/search?q=$encodedQuery&page=$page&limit=$limit',
        ),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get top videos by engagement
  static Future<Map<String, dynamic>> getTopVideos({
    int limit = 5,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/videos/top?limit=$limit'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Search videos
  static Future<Map<String, dynamic>> searchVideos({
    required String query,
    int page = 1,
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) {
      return {'success': false, 'message': 'Search query cannot be empty'};
    }

    return await _makeAuthenticatedRequest(() async {
      final encodedQuery = Uri.encodeComponent(query.trim());
      return await http.get(
        Uri.parse(
          '$baseUrl/videos/search?q=$encodedQuery&page=$page&limit=$limit',
        ),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Search stories
  static Future<Map<String, dynamic>> searchStories({
    required String query,
  }) async {
    if (query.trim().isEmpty) {
      return {'success': false, 'message': 'Search query cannot be empty'};
    }

    return await _makeAuthenticatedRequest(() async {
      final encodedQuery = Uri.encodeComponent(query.trim());
      // Note: Limit is now fixed at 20 stories on the backend
      // Stories are sorted by most views (viewersCount) descending
      // Results are cached for 3 hours on the server
      return await http.get(
        Uri.parse(
          '$baseUrl/stories/search?q=$encodedQuery',
        ),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Search saved posts
  static Future<Map<String, dynamic>> searchSavedPosts({
    required String query,
    int page = 1,
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) {
      return {'success': false, 'message': 'Search query cannot be empty'};
    }

    return await _makeAuthenticatedRequest(() async {
      final encodedQuery = Uri.encodeComponent(query.trim());
      return await http.get(
        Uri.parse(
          '$baseUrl/posts/saved/search?q=$encodedQuery&page=$page&limit=$limit',
        ),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get top posts from user's followers by engagement
  static Future<Map<String, dynamic>> getTopFollowerPosts({
    int limit = 5,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/posts/top?limit=$limit'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get all posts (feed)
  static Future<Map<String, dynamic>> getPosts({
    int page = 1,
    int limit = 10,
    String? filter,
    String? sort,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      String url = '$baseUrl/posts?page=$page&limit=$limit';
      if (filter != null) url += '&filter=$filter';
      if (sort != null) url += '&sort=$sort';
      
      return await http.get(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get single post by ID
  static Future<Map<String, dynamic>> getPost(String postId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Create a new post
  static Future<Map<String, dynamic>> createPost({
    required String content,
    List<String>? images,
    String visibility = 'public',
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/posts'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'content': content,
          'images': images ?? [],
          'visibility': visibility,
        }),
      );
    });
  }

  // Create a new post with media files (multipart)
  static Future<Map<String, dynamic>> createPostWithMedia({
    required String content,
    required List<XFile> mediaFiles,
    String visibility = 'public',
    List<String>? taggedUserIds,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        throw Exception('No access token found');
      }

      final uri = Uri.parse('$baseUrl/posts');
      final request = http.MultipartRequest('POST', uri);

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add text fields
      request.fields['content'] = content;
      request.fields['visibility'] = visibility;

      // Add tagged users if provided
      if (taggedUserIds != null && taggedUserIds.isNotEmpty) {
        request.fields['taggedUsers'] = json.encode(taggedUserIds);
      }

      // Add media files
      for (var mediaFile in mediaFiles) {
        final fileName = mediaFile.name;

        // Determine content type
        String? mimeType;
        if (fileName.toLowerCase().endsWith('.jpg') ||
            fileName.toLowerCase().endsWith('.jpeg')) {
          mimeType = 'image/jpeg';
        } else if (fileName.toLowerCase().endsWith('.png')) {
          mimeType = 'image/png';
        } else if (fileName.toLowerCase().endsWith('.gif')) {
          mimeType = 'image/gif';
        } else if (fileName.toLowerCase().endsWith('.mp4')) {
          mimeType = 'video/mp4';
        } else if (fileName.toLowerCase().endsWith('.mov')) {
          mimeType = 'video/quicktime';
        } else if (fileName.toLowerCase().endsWith('.avi')) {
          mimeType = 'video/x-msvideo';
        }

        // Read file as bytes (works on all platforms including web)
        final bytes = await mediaFile.readAsBytes();

        final multipartFile = http.MultipartFile.fromBytes(
          'media',
          bytes,
          filename: fileName,
          contentType: mimeType != null ? MediaType.parse(mimeType) : null,
        );

        request.files.add(multipartFile);
      }

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Handle token refresh if needed
      if (response.statusCode == 401) {
        final refreshed = await refreshToken();
        if (refreshed) {
          // Retry with new token
          final newToken = await getAccessToken();
          if (newToken != null) {
            request.headers['Authorization'] = 'Bearer $newToken';

            final retryStreamedResponse = await request.send();
            final retryResponse = await http.Response.fromStream(
              retryStreamedResponse,
            );

            return json.decode(retryResponse.body);
          }
        }
      }

      return json.decode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to create post: ${e.toString()}',
      };
    }
  }

  // Update a post
  static Future<Map<String, dynamic>> updatePost({
    required String postId,
    required String content,
    List<String>? images,
    String? visibility,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final body = <String, dynamic>{'content': content};
      if (images != null) body['images'] = images;
      if (visibility != null) body['visibility'] = visibility;

      return await http.put(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode(body),
      );
    });
  }

  // Delete a post
  static Future<Map<String, dynamic>> deletePost(String postId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Edit/update a post
  static Future<Map<String, dynamic>> editPost(
    String postId,
    String content,
  ) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({'content': content}),
      );
    });
  }

  // Save/unsave a post (toggle bookmark)
  static Future<Map<String, dynamic>> toggleSavePost(String postId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/posts/$postId/save'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get user's saved posts
  static Future<Map<String, dynamic>> getSavedPosts({
    int page = 1,
    int limit = 10,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/users/saved-posts?page=$page&limit=$limit'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Share a post
  static Future<Map<String, dynamic>> sharePost({
    required String postId,
    required String shareType, // 'feed' or 'message'
    List<String>? recipients, // Required for 'message' type
    String? message, // Optional message to include
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/posts/$postId/share'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'shareType': shareType,
          if (recipients != null) 'recipients': recipients,
          if (message != null) 'message': message,
        }),
      );
    });
  }

  // Report a post
  static Future<Map<String, dynamic>> reportPost({
    required String postId,
    required String reason,
    String? details,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/posts/$postId/report'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'reason': reason,
          if (details != null) 'details': details,
        }),
      );
    });
  }

  // Like a post
  static Future<Map<String, dynamic>> likePost(String postId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/posts/$postId/like'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Unlike a post
  static Future<Map<String, dynamic>> unlikePost(String postId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/posts/$postId/like'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Add or update reaction to a post
  static Future<Map<String, dynamic>> addReaction({
    required String postId,
    required String reactionType,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/posts/$postId/react'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({'reactionType': reactionType}),
      );
    });
  }

  // Remove reaction from a post
  static Future<Map<String, dynamic>> removeReaction({
    required String postId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/posts/$postId/react'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get all reactions for a post
  static Future<Map<String, dynamic>> getPostReactions(String postId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/posts/$postId/reactions'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Add a comment to a post with optional images
  static Future<Map<String, dynamic>> addCommentWithImages({
    required String postId,
    required String content,
    List<XFile>? images,
    String? gif,
  }) async {
    try {
      if ((images == null || images.isEmpty) && gif == null) {
        // Fall back to regular text comment
        return await addComment(
          postId: postId,
          content: content,
          gif: gif,
        );
      }

      // Get auth token
      final token = await getAccessToken();
      if (token == null) {
        throw ApiException(
          statusCode: 401,
          message: 'No authentication token available',
        );
      }

      // Use multipart form data for file uploads
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/posts/$postId/comments'),
      );

      // Add headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
      });

      // Add fields
      if (content.isNotEmpty) {
        request.fields['content'] = content;
      }
      if (gif != null && gif.isNotEmpty) {
        request.fields['gif'] = gif;
      }

      // Add files
      if (images != null && images.isNotEmpty) {
        for (final image in images) {
          final file = await http.MultipartFile.fromPath(
            'images',
            image.path,
            contentType: MediaType('image', 'jpeg'),
          );
          request.files.add(file);
        }
      }

      debugPrint('📤 Uploading comment with ${images?.length ?? 0} images');
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final decodedResponse = json.decode(responseData) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decodedResponse;
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: decodedResponse['message'] ?? 'Failed to add comment',
          errors: decodedResponse['errors'],
        );
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      debugPrint('❌ Error uploading comment with images: $e');
      throw ApiException(
        statusCode: 500,
        message: 'Failed to upload comment: ${e.toString()}',
      );
    }
  }

  // Add a comment to a post
  static Future<Map<String, dynamic>> addComment({
    required String postId,
    required String content,
    String? gif,
    List<String>? mentionedUserIds,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final body = <String, dynamic>{'content': content};

      if (gif != null && gif.isNotEmpty) {
        body['gif'] = gif;
      }

      if (mentionedUserIds != null && mentionedUserIds.isNotEmpty) {
        body['mentionedUserIds'] = mentionedUserIds;
      }

      final jsonBody = json.encode(body);
      debugPrint('📤 addComment request body: $body');
      debugPrint('📤 addComment JSON: $jsonBody');
      debugPrint('📤 addComment GIF is${gif == null ? "" : " NOT"} null');
      debugPrint('📤 addComment GIF isEmpty: ${gif?.isEmpty ?? "N/A"}');

      return await http.post(
        Uri.parse('$baseUrl/posts/$postId/comments'),
        headers: await _getHeaders(includeAuth: true),
        body: jsonBody,
      );
    });
  }

  // Add reply to comment
  static Future<Map<String, dynamic>> addCommentReply({
    required String postId,
    required String commentId,
    required String content,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/posts/$postId/comments/$commentId/reply'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({'content': content}),
      );
    });
  }

  // Delete a comment
  static Future<Map<String, dynamic>> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/posts/$postId/comments/$commentId'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // React to comment
  static Future<Map<String, dynamic>> reactToComment({
    required String postId,
    required String commentId,
    required String reactionType,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/posts/$postId/comments/$commentId/react'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({'reactionType': reactionType}),
      );
    });
  }

  // Remove reaction from comment
  static Future<Map<String, dynamic>> removeCommentReaction({
    required String postId,
    required String commentId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/posts/$postId/comments/$commentId/react'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // React to a reply
  static Future<Map<String, dynamic>> reactToReply({
    required String postId,
    required String commentId,
    required String replyId,
    required String reactionType,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse(
          '$baseUrl/posts/$postId/comments/$commentId/replies/$replyId/react',
        ),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({'reactionType': reactionType}),
      );
    });
  }

  // Remove reaction from reply
  static Future<Map<String, dynamic>> removeReplyReaction({
    required String postId,
    required String commentId,
    required String replyId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.delete(
        Uri.parse(
          '$baseUrl/posts/$postId/comments/$commentId/replies/$replyId/react',
        ),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Add nested reply (reply to a reply)
  static Future<Map<String, dynamic>> addNestedReply({
    required String postId,
    required String commentId,
    required String replyId,
    required String content,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse(
          '$baseUrl/posts/$postId/comments/$commentId/replies/$replyId/reply',
        ),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({'content': content}),
      );
    });
  }

  // Get posts by user
  static Future<Map<String, dynamic>> getUserPosts({
    required String userId,
    int page = 1,
    int limit = 10,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/posts/user/$userId?page=$page&limit=$limit'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // ==================== Photo Methods ====================

  // Upload a photo
  static Future<Map<String, dynamic>> uploadPhoto({
    required XFile photoFile,
    String? caption,
    String visibility = 'followers',
    List<String>? tags,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$baseUrl/photos');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      final token = await getAccessToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add photo file
      final bytes = await photoFile.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'photo',
        bytes,
        filename: photoFile.name,
        contentType: MediaType('image', photoFile.name.split('.').last),
      );
      request.files.add(multipartFile);

      // Add fields
      if (caption != null && caption.isNotEmpty) {
        request.fields['caption'] = caption;
      }
      request.fields['visibility'] = visibility;
      if (tags != null && tags.isNotEmpty) {
        request.fields['tags'] = jsonEncode(tags);
      }

      final streamedResponse = await request.send();
      return await http.Response.fromStream(streamedResponse);
    });
  }

  // Get user photos
  static Future<Map<String, dynamic>> getUserPhotos({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/photos/user/$userId?page=$page&limit=$limit'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get single photo
  static Future<Map<String, dynamic>> getPhoto(String photoId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/photos/$photoId'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Update photo
  static Future<Map<String, dynamic>> updatePhoto({
    required String photoId,
    String? caption,
    String? visibility,
    List<String>? tags,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final body = <String, dynamic>{};
      if (caption != null) body['caption'] = caption;
      if (visibility != null) body['visibility'] = visibility;
      if (tags != null) body['tags'] = tags;

      return await http.put(
        Uri.parse('$baseUrl/photos/$photoId'),
        headers: await _getHeaders(includeAuth: true),
        body: jsonEncode(body),
      );
    });
  }

  // Delete photo
  static Future<Map<String, dynamic>> deletePhoto(String photoId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/photos/$photoId'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // ==================== Notification Methods ====================

  // Get notifications
  static Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    try {
      final headers = await _getHeaders(includeAuth: true);
      final url =
          '$baseUrl/notifications?page=$page&limit=$limit&unreadOnly=$unreadOnly';

      debugPrint('📡 Fetching notifications from: $url');
      debugPrint('📡 Request headers: $headers');

      final response = await http.get(Uri.parse(url), headers: headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - server may be down');
        },
      );

      debugPrint('📡 Notifications response status: ${response.statusCode}');
      debugPrint('📡 Notifications response body: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📡 Error in getNotifications: $e');
        debugPrint('📡 Error type: ${e.runtimeType}');
      }
      // Error handled by ErrorHandler
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // Get unread notification count
  static Future<Map<String, dynamic>> getUnreadNotificationCount() async {
    try {
      final headers = await _getHeaders(includeAuth: true);
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/unread-count'),
        headers: headers,
      );

      return _handleResponse(response);
    } catch (e) {
      // Error handled by ErrorHandler
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // Get unread message count
  static Future<Map<String, dynamic>> getUnreadCount() async {
    try {
      final headers = await _getHeaders(includeAuth: true);
      final response = await http.get(
        Uri.parse('$baseUrl/conversations/unread-count'),
        headers: headers,
      );

      return _handleResponse(response);
    } catch (e) {
      // Error handled by ErrorHandler
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // Mark notification as read
  static Future<Map<String, dynamic>> markNotificationAsRead(
    String notificationId,
  ) async {
    try {
      final headers = await _getHeaders(includeAuth: true);
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
        headers: headers,
      );

      return _handleResponse(response);
    } catch (e) {
      // Error handled by ErrorHandler
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // Mark all notifications as read
  static Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
    try {
      final headers = await _getHeaders(includeAuth: true);
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/read-all'),
        headers: headers,
      );

      return _handleResponse(response);
    } catch (e) {
      // Error handled by ErrorHandler
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // Delete notification
  static Future<Map<String, dynamic>> deleteNotification(
    String notificationId,
  ) async {
    try {
      final headers = await _getHeaders(includeAuth: true);
      final response = await http.delete(
        Uri.parse('$baseUrl/notifications/$notificationId'),
        headers: headers,
      );

      return _handleResponse(response);
    } catch (e) {
      // Error handled by ErrorHandler
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // Delete all notifications
  static Future<Map<String, dynamic>> deleteAllNotifications() async {
    try {
      final headers = await _getHeaders(includeAuth: true);
      final response = await http.delete(
        Uri.parse('$baseUrl/notifications'),
        headers: headers,
      );

      return _handleResponse(response);
    } catch (e) {
      // Error handled by ErrorHandler
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // ==================== STORIES ====================

  // Create story
  static Future<Map<String, dynamic>> createStory({
    XFile? mediaFile,
    String? caption,
    String? backgroundColor,
    String? textContent,
    String? mediaType,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/stories'),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Handle text-only story
      if (mediaType == 'text') {
        debugPrint('📤 Creating text story');
        request.fields['mediaType'] = 'text';
        request.fields['textContent'] = textContent ?? '';
        if (backgroundColor != null) {
          request.fields['backgroundColor'] = backgroundColor;
        }
        if (caption != null && caption.isNotEmpty) {
          request.fields['caption'] = caption;
        }
      } else {
        // Handle media story (image/video)
        if (mediaFile == null) {
          throw Exception('Media file is required for image/video stories');
        }

        final bytes = await mediaFile.readAsBytes();

        // Determine the proper mime type
        String mimeType;
        String mimeSubtype;

        // For web, use the file name; for mobile, use the path
        String fileName = kIsWeb ? mediaFile.name : mediaFile.path;
        String fileExtension = fileName.split('.').last.toLowerCase();

        // Check if it's a video
        if ([
          'mp4',
          'avi',
          'mov',
          'wmv',
          'flv',
          'mkv',
          'webm',
        ].contains(fileExtension)) {
          mimeType = 'video';
          mimeSubtype = fileExtension == 'mov' ? 'quicktime' : fileExtension;
        } else {
          // It's an image
          mimeType = 'image';
          switch (fileExtension) {
            case 'jpg':
            case 'jpeg':
              mimeSubtype = 'jpeg';
              break;
            case 'png':
              mimeSubtype = 'png';
              break;
            case 'gif':
              mimeSubtype = 'gif';
              break;
            case 'webp':
              mimeSubtype = 'webp';
              break;
            default:
              mimeSubtype = fileExtension;
          }
        }

        debugPrint('📤 Uploading story:');
        debugPrint('   Filename: ${mediaFile.name}');
        debugPrint('   MIME Type: $mimeType/$mimeSubtype');
        debugPrint('   Size: ${bytes.length} bytes');

        final multipartFile = http.MultipartFile.fromBytes(
          'media',
          bytes,
          filename: mediaFile.name,
          contentType: MediaType(mimeType, mimeSubtype),
        );
        request.files.add(multipartFile);

        // Add optional fields
        if (caption != null && caption.isNotEmpty) {
          request.fields['caption'] = caption;
        }
        if (backgroundColor != null) {
          request.fields['backgroundColor'] = backgroundColor;
        }
      }

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('Create story response status: ${response.statusCode}');
      debugPrint('Create story response body: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error creating story: $e');
      rethrow;
    }
  }

  // Get all stories (grouped by user)
  static Future<Map<String, dynamic>> getStories() async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/stories'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get trending topics/hashtags
  static Future<Map<String, dynamic>> getTrendingTopics(
      {int limit = 10}) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/posts/trending/topics?limit=$limit'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get trending posts
  static Future<Map<String, dynamic>> getTrendingPosts(
      {int page = 1, int limit = 10}) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/posts/trending?page=$page&limit=$limit'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get stories by user
  static Future<Map<String, dynamic>> getUserStories(String userId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/stories/user/$userId'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get single story
  static Future<Map<String, dynamic>> getStory(String storyId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/stories/$storyId'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Mark story as viewed
  static Future<Map<String, dynamic>> viewStory(String storyId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/stories/$storyId/view'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Delete story
  static Future<Map<String, dynamic>> deleteStory(String storyId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/stories/$storyId'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // React to story
  static Future<Map<String, dynamic>> reactToStory(
    String storyId,
    String emoji,
  ) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/stories/$storyId/react'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({'emoji': emoji}),
      );
    });
  }

  // Story Highlights and Collections
  static Future<Map<String, dynamic>> getStoryHighlights(String userId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/story-highlights/$userId'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  static Future<Map<String, dynamic>> addStoryToHighlight({
    required String storyId,
    required String collectionName,
    String? coverUrl,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/story-highlights/add'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'storyId': storyId,
          'collectionName': collectionName,
          'coverUrl': coverUrl,
        }),
      );
    });
  }

  static Future<Map<String, dynamic>> removeStoryFromHighlight(String storyId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/story-highlights/remove'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({'storyId': storyId}),
      );
    });
  }

  // Story Analytics
  static Future<Map<String, dynamic>> getStoryAnalytics(String storyId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/story-analytics/$storyId'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  static Future<Map<String, dynamic>> getUserAnalyticsSummary(String userId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/story-analytics/user/$userId/summary'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  static Future<Map<String, dynamic>> getTrendingStories({int limit = 20, int timeframe = 24}) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/story-analytics/trending?limit=$limit&timeframe=$timeframe'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Story Creative Tools
  static Future<Map<String, dynamic>> getStoryTemplates() async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/story-creative/templates'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  static Future<Map<String, dynamic>> getStoryFilters() async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/story-creative/filters'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  static Future<Map<String, dynamic>> applyStoryTemplate({
    required String storyId,
    required String templateName,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/story-creative/apply-template'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'storyId': storyId,
          'templateName': templateName,
        }),
      );
    });
  }

  static Future<Map<String, dynamic>> addStoryFilter({
    required String storyId,
    required String filterName,
    int intensity = 50,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/story-creative/add-filter'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'storyId': storyId,
          'filterName': filterName,
          'intensity': intensity,
        }),
      );
    });
  }

  static Future<Map<String, dynamic>> addStorySticker({
    required String storyId,
    required String emoji,
    required Map<String, double> position,
    double scale = 1.0,
    double rotation = 0,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/story-creative/add-sticker'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'storyId': storyId,
          'emoji': emoji,
          'position': position,
          'scale': scale,
          'rotation': rotation,
        }),
      );
    });
  }

  static Future<Map<String, dynamic>> addStoryText({
    required String storyId,
    required String text,
    required String font,
    required int size,
    required String color,
    required Map<String, double> position,
    String alignment = 'center',
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/story-creative/add-text'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'storyId': storyId,
          'text': text,
          'font': font,
          'size': size,
          'color': color,
          'position': position,
          'alignment': alignment,
        }),
      );
    });
  }

  // Remove story reaction
  static Future<Map<String, dynamic>> removeStoryReaction(
    String storyId,
  ) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/stories/$storyId/react'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get story viewers
  static Future<Map<String, dynamic>> getStoryViewers(String storyId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/stories/$storyId/viewers'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // ==================== STORY REPLIES ====================

  // Create story reply
  static Future<Map<String, dynamic>> createStoryReply({
    required String storyId,
    required String content,
    List<String> mentions = const [],
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/stories/$storyId/replies'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'content': content,
          'mentions': mentions,
        }),
      );
    });
  }

  // Get story replies
  static Future<Map<String, dynamic>> getStoryReplies(
    String storyId, {
    int page = 1,
    int limit = 20,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse(
          '$baseUrl/stories/$storyId/replies?page=$page&limit=$limit',
        ),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // React to story reply
  static Future<Map<String, dynamic>> reactToStoryReply(
    String storyId,
    String replyId,
    String emoji,
  ) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/stories/$storyId/replies/$replyId/react'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({'emoji': emoji}),
      );
    });
  }

  // Remove reaction from story reply
  static Future<Map<String, dynamic>> removeStoryReplyReaction(
    String storyId,
    String replyId,
    String emoji,
  ) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.delete(
        Uri.parse(
          '$baseUrl/stories/$storyId/replies/$replyId/react/$emoji',
        ),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Delete story reply
  static Future<Map<String, dynamic>> deleteStoryReply(
    String storyId,
    String replyId,
  ) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/stories/$storyId/replies/$replyId'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Fix reply count for a story
  static Future<Map<String, dynamic>> fixStoryReplyCount(String storyId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/stories/$storyId/fix-reply-count'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Follow user
  static Future<Map<String, dynamic>> followUser(String userId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/users/$userId/follow'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Unfollow user
  static Future<Map<String, dynamic>> unfollowUser(String userId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/users/$userId/unfollow'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get user's followers list
  static Future<Map<String, dynamic>> getUserFollowers(String userId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/users/$userId/followers'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get user's following list
  static Future<Map<String, dynamic>> getUserFollowing(String userId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/users/$userId/following'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get user settings
  static Future<Map<String, dynamic>> getUserSettings() async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/users/settings'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Update user settings
  static Future<Map<String, dynamic>> updateUserSettings(
    Map<String, dynamic> settings,
  ) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/users/settings'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode(settings),
      );
    });
  }

  // Change password
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/users/password'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );
    });
  }

  // Delete account
  static Future<Map<String, dynamic>> deleteAccount() async {
    return await _makeAuthenticatedRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/users/account'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Block user
  static Future<Map<String, dynamic>> blockUser(String userId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/users/$userId/block'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Unblock user
  static Future<Map<String, dynamic>> unblockUser(String userId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/users/$userId/unblock'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get blocked users list
  static Future<Map<String, dynamic>> getBlockedUsers() async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/users/blocked'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Record a profile visit
  static Future<Map<String, dynamic>> recordProfileVisit(String userId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/users/$userId/visit'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Report a user
  static Future<Map<String, dynamic>> reportUser(
    String userId, {
    required String reason,
    String? details,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/users/$userId/report'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'reason': reason,
          if (details != null && details.isNotEmpty) 'details': details,
        }),
      );
    });
  }

  // ============ Admin API Methods ============

  // Get all reports
  static Future<Map<String, dynamic>> getReports({
    int page = 1,
    int limit = 20,
    String? status,
    String? reportType,
    String? reason,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null) 'status': status,
        if (reportType != null) 'reportType': reportType,
        if (reason != null) 'reason': reason,
      };

      final uri = Uri.parse('$baseUrl/admin/reports')
          .replace(queryParameters: queryParams);

      return await http.get(
        uri,
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get single report by ID
  static Future<Map<String, dynamic>> getReport(String reportId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/admin/reports/$reportId'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Review a report
  static Future<Map<String, dynamic>> reviewReport(
    String reportId, {
    required String status,
    String? adminNotes,
    String? actionTaken,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/admin/reports/$reportId/review'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'status': status,
          if (adminNotes != null) 'adminNotes': adminNotes,
          if (actionTaken != null) 'actionTaken': actionTaken,
        }),
      );
    });
  }

  // Delete a report
  static Future<Map<String, dynamic>> deleteReport(String reportId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/admin/reports/$reportId'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get report statistics
  static Future<Map<String, dynamic>> getReportStats() async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/admin/reports/stats'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Check if current user is admin
  static Future<bool> checkIsAdmin() async {
    try {
      final result = await _makeAuthenticatedRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/users/admin-status'),
          headers: await _getHeaders(includeAuth: true),
        );
      });
      return result['data']?['isAdmin'] ?? false;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  // Get all users (admin only)
  static Future<Map<String, dynamic>> getAllUsers({
    int page = 1,
    int limit = 100,
    String? search,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final uri = Uri.parse('$baseUrl/admin/users')
          .replace(queryParameters: queryParams);

      return await http.get(
        uri,
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Suspend a user
  static Future<Map<String, dynamic>> suspendUser(
    String userId, {
    String? reason,
    int? duration,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/admin/users/$userId/suspend'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          if (reason != null) 'reason': reason,
          if (duration != null) 'duration': duration,
        }),
      );
    });
  }

  // Unsuspend a user
  static Future<Map<String, dynamic>> unsuspendUser(
    String userId, {
    String? reason,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/admin/users/$userId/unsuspend'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          if (reason != null) 'reason': reason,
        }),
      );
    });
  }

  // Ban a user
  static Future<Map<String, dynamic>> banUser(
    String userId, {
    String? reason,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/admin/users/$userId/ban'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          if (reason != null) 'reason': reason,
        }),
      );
    });
  }

  // Unban a user
  static Future<Map<String, dynamic>> unbanUser(
    String userId, {
    String? reason,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/admin/users/$userId/unban'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          if (reason != null) 'reason': reason,
        }),
      );
    });
  }

  // Mute a user
  static Future<Map<String, dynamic>> muteUser(
    String userId, {
    String? reason,
    int? duration,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/admin/users/$userId/mute'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          if (reason != null) 'reason': reason,
          if (duration != null) 'duration': duration,
        }),
      );
    });
  }

  // Unmute a user
  static Future<Map<String, dynamic>> unmuteUser(String userId) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/admin/users/$userId/unmute'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Delete a user account (admin action)
  static Future<Map<String, dynamic>> deleteUser(
    String userId, {
    String? reason,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/admin/users/$userId'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          if (reason != null) 'reason': reason,
        }),
      );
    });
  }

  // Get profile visitor statistics
  static Future<Map<String, dynamic>> getProfileVisitorStats() async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/users/profile-visitors/stats'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get profile visitors
  static Future<Map<String, dynamic>> getProfileVisitors({
    int page = 1,
    int limit = 20,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/users/profile-visitors?page=$page&limit=$limit'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // ==================== Messages API ====================

  // Get or create conversation with a user
  static Future<Map<String, dynamic>> getOrCreateConversation(
    String userId,
  ) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/messages/conversation/$userId'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Send a message
  static Future<Map<String, dynamic>> sendMessage({
    String? recipientId,
    String? conversationId,
    required String content,
    String? replyTo,
    String? storyId,
  }) async {
    // Must provide either recipientId (for 1-on-1) or conversationId (for groups)
    assert(
      recipientId != null || conversationId != null,
      'Either recipientId or conversationId must be provided',
    );

    return await _makeAuthenticatedRequest(() async {
      final body = <String, dynamic>{'content': content};

      if (recipientId != null) {
        body['recipient'] = recipientId;
      }
      if (conversationId != null) {
        body['conversationId'] = conversationId;
      }
      if (replyTo != null) {
        body['replyTo'] = replyTo;
      }
      if (storyId != null) {
        body['storyId'] = storyId;
      }

      return await http.post(
        Uri.parse('$baseUrl/messages'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode(body),
      );
    });
  }

  // Get all conversations
  static Future<Map<String, dynamic>> getConversations({
    int page = 1,
    int limit = 20,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/messages/conversations?page=$page&limit=$limit'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Get messages in a conversation
  static Future<Map<String, dynamic>> getMessages({
    required String conversationId,
    int page = 1,
    int limit = 50,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/messages/$conversationId?page=$page&limit=$limit'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // Mark messages as read
  static Future<Map<String, dynamic>> markMessagesAsRead(
    String conversationId,
  ) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/messages/$conversationId/read'),
        headers: await _getHeaders(includeAuth: true),
      );
    });
  }

  // ==================== ENGAGEMENT & GAMIFICATION ====================

  // Get daily reward status
  static Future<Map<String, dynamic>> getDailyRewardStatus() async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('${ApiService.baseUrl}/daily-rewards/status'),
        headers: await ApiService._getHeaders(includeAuth: true),
      );
    });
  }

  // Claim daily reward
  static Future<Map<String, dynamic>> claimDailyReward() async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('${ApiService.baseUrl}/daily-rewards/claim'),
        headers: await ApiService._getHeaders(includeAuth: true),
      );
    });
  }

  // Get daily reward history
  static Future<Map<String, dynamic>> getDailyRewardHistory({
    int limit = 30,
  }) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('${ApiService.baseUrl}/daily-rewards/history?limit=$limit'),
        headers: await ApiService._getHeaders(includeAuth: true),
      );
    });
  }

  // Get daily reward leaderboard
  static Future<Map<String, dynamic>> getDailyRewardLeaderboard({
    int limit = 20,
  }) async {
    return await http.get(
      Uri.parse('${ApiService.baseUrl}/daily-rewards/leaderboard?limit=$limit'),
      headers: await ApiService._getHeaders(includeAuth: false),
    ).then((response) =>
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  // Get referral code
  static Future<Map<String, dynamic>> getMyReferralCode() async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('${ApiService.baseUrl}/referrals/my-code'),
        headers: await ApiService._getHeaders(includeAuth: true),
      );
    });
  }

  // Claim referral code
  static Future<Map<String, dynamic>> claimReferralCode({
    required String code,
  }) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('${ApiService.baseUrl}/referrals/claim'),
        headers: await ApiService._getHeaders(includeAuth: true),
        body: json.encode({'code': code}),
      );
    });
  }

  // Get referral stats
  static Future<Map<String, dynamic>> getReferralStats() async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('${ApiService.baseUrl}/referrals/stats'),
        headers: await ApiService._getHeaders(includeAuth: true),
      );
    });
  }

  // Get referral leaderboard
  static Future<Map<String, dynamic>> getReferralLeaderboard({
    int limit = 20,
  }) async {
    return await http.get(
      Uri.parse('${ApiService.baseUrl}/referrals/leaderboard?limit=$limit'),
      headers: await ApiService._getHeaders(includeAuth: false),
    ).then((response) =>
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  // Get active challenges
  static Future<Map<String, dynamic>> getActiveChallenges() async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('${ApiService.baseUrl}/challenges/active'),
        headers: await ApiService._getHeaders(includeAuth: true),
      );
    });
  }

  // Get available challenges
  static Future<Map<String, dynamic>> getAvailableChallenges() async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('${ApiService.baseUrl}/challenges/available'),
        headers: await ApiService._getHeaders(includeAuth: true),
      );
    });
  }

  // Join a challenge
  static Future<Map<String, dynamic>> joinChallenge({
    required String challengeId,
  }) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('${ApiService.baseUrl}/challenges/$challengeId/join'),
        headers: await ApiService._getHeaders(includeAuth: true),
      );
    });
  }

  // Update challenge progress
  static Future<Map<String, dynamic>> updateChallengeProgress({
    required String challengeId,
    int increment = 1,
  }) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('${ApiService.baseUrl}/challenges/$challengeId/update-progress'),
        headers: await ApiService._getHeaders(includeAuth: true),
        body: json.encode({'increment': increment}),
      );
    });
  }

  // Claim challenge reward
  static Future<Map<String, dynamic>> claimChallengeReward({
    required String userChallengeId,
  }) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('${ApiService.baseUrl}/challenges/$userChallengeId/claim-reward'),
        headers: await ApiService._getHeaders(includeAuth: true),
      );
    });
  }

  // Get challenge leaderboard
  static Future<Map<String, dynamic>> getChallengeLeaderboard({
    required String challengeId,
    int limit = 20,
  }) async {
    return await http.get(
      Uri.parse('${ApiService.baseUrl}/challenges/leaderboard/$challengeId?limit=$limit'),
      headers: await ApiService._getHeaders(includeAuth: false),
    ).then((response) =>
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ============================================================================
  // GAME CHALLENGES (Multiplayer Games)
  // ============================================================================

  /// Make a move in a multiplayer game (Connect 4, Tic-Tac-Toe, etc.)
  static Future<Map<String, dynamic>> makeGameMove({
    required String gameChallengeId,
    required Map<String, dynamic> moveData,
    required List<dynamic> boardState,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/game-challenges/$gameChallengeId/move'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'moveData': moveData,
          'boardState': boardState,
        }),
      );
    });
  }

  // ============================================================================
  // RECOMMENDATIONS
  // ============================================================================

  /// Get job recommendations
  static Future<Map<String, dynamic>> getJobRecommendations({
    int limit = 10,
  }) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('${ApiService.baseUrl}/recommendations/jobs?limit=$limit'),
        headers: await ApiService._getHeaders(includeAuth: true),
      );
    });
  }

  /// Get recommendation preferences
  static Future<Map<String, dynamic>> getRecommendationPreferences() async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('${ApiService.baseUrl}/recommendations/preferences'),
        headers: await ApiService._getHeaders(includeAuth: true),
      );
    });
  }

  /// Update recommendation preferences
  static Future<Map<String, dynamic>> updateRecommendationPreferences({
    required Map<String, dynamic> preferences,
  }) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.put(
        Uri.parse('${ApiService.baseUrl}/recommendations/preferences'),
        headers: await ApiService._getHeaders(includeAuth: true),
        body: json.encode(preferences),
      );
    });
  }

  // ============================================================================
  // STORY ANALYTICS
  // ============================================================================

  // ============================================================================
  // STORY ARCHIVE & HIGHLIGHTS
  // ============================================================================

  /// Archive a story (move to highlights)
  static Future<Map<String, dynamic>> archiveStory(
    String storyId, {
    String? highlightName,
  }) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('${ApiService.baseUrl}/api/stories/$storyId/archive'),
        headers: await ApiService._getHeaders(includeAuth: true),
        body: json.encode({
          if (highlightName != null) 'highlightName': highlightName,
        }),
      );
    });
  }

  /// Unarchive a story
  static Future<Map<String, dynamic>> unarchiveStory(String storyId) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.delete(
        Uri.parse('${ApiService.baseUrl}/api/stories/$storyId/archive'),
        headers: await ApiService._getHeaders(includeAuth: true),
      );
    });
  }

  // ============================================================================
  // STORY HIGHLIGHTS
  // ============================================================================

  /// Get all highlights for a user
  static Future<Map<String, dynamic>> getUserHighlights(String userId) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('${ApiService.baseUrl}/api/users/$userId/highlights'),
        headers: await ApiService._getHeaders(includeAuth: true),
      );
    });
  }

  /// Create a new highlight collection
  static Future<Map<String, dynamic>> createHighlight({
    required String name,
    required List<String> stories,
    String? description,
    String? coverImage,
  }) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('${ApiService.baseUrl}/api/stories/highlights'),
        headers: await ApiService._getHeaders(includeAuth: true),
        body: json.encode({
          'name': name,
          'description': description,
          'stories': stories,
          if (coverImage != null) 'coverImage': coverImage,
        }),
      );
    });
  }

  /// Update a highlight collection
  static Future<Map<String, dynamic>> updateHighlight({
    required String highlightId,
    String? name,
    String? description,
    List<String>? stories,
    String? coverImage,
  }) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;
      if (stories != null) body['stories'] = stories;
      if (coverImage != null) body['coverImage'] = coverImage;

      return await http.put(
        Uri.parse('${ApiService.baseUrl}/api/highlights/$highlightId'),
        headers: await ApiService._getHeaders(includeAuth: true),
        body: json.encode(body),
      );
    });
  }

  /// Get a specific highlight by ID
  static Future<Map<String, dynamic>> getHighlightDetail(
      String highlightId) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('${ApiService.baseUrl}/api/highlights/$highlightId'),
        headers: await ApiService._getHeaders(includeAuth: true),
      );
    });
  }

  /// Delete a highlight collection
  static Future<Map<String, dynamic>> deleteHighlight(
      String highlightId) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.delete(
        Uri.parse('${ApiService.baseUrl}/api/highlights/$highlightId'),
        headers: await ApiService._getHeaders(includeAuth: true),
      );
    });
  }

  // ============================================================================
  // STORY POLLS
  // ============================================================================

  /// Create a poll story
  static Future<Map<String, dynamic>> createPollStory({
    required String question,
    required List<String> options,
    bool isMultipleChoice = false,
    bool allowChangingVote = true,
    Duration? duration,
  }) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('${ApiService.baseUrl}/api/stories/polls'),
        headers: await ApiService._getHeaders(includeAuth: true),
        body: json.encode({
          'mediaType': 'poll',
          'poll': {
            'question': question,
            'options': options,
            'isMultipleChoice': isMultipleChoice,
            'allowChangingVote': allowChangingVote,
            if (duration != null)
              'expiresAt': DateTime.now().add(duration).toIso8601String(),
          },
        }),
      );
    });
  }

  /// Vote on a poll
  static Future<Map<String, dynamic>> voteOnPoll(
    String storyId, {
    required List<int> optionIndices,
  }) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('${ApiService.baseUrl}/api/stories/$storyId/vote'),
        headers: await ApiService._getHeaders(includeAuth: true),
        body: json.encode({'optionIndices': optionIndices}),
      );
    });
  }

  /// Get poll results
  static Future<Map<String, dynamic>> getPollResults(String storyId) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('${ApiService.baseUrl}/api/stories/$storyId/poll-results'),
        headers: await ApiService._getHeaders(includeAuth: true),
      );
    });
  }

  /// Update story privacy settings
  static Future<Map<String, dynamic>> updateStoryPrivacy(
    String storyId, {
    required String privacy,
    List<String>? allowedUsers,
  }) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.put(
        Uri.parse('${ApiService.baseUrl}/api/stories/$storyId/privacy'),
        headers: await ApiService._getHeaders(includeAuth: true),
        body: json.encode({
          'privacy': privacy,
          'allowedUsers': allowedUsers,
        }),
      );
    });
  }

  /// Save a story draft
  static Future<Map<String, dynamic>> saveDraft({
    required String content,
    String? mediaUrl,
    String? mediaType,
    String? privacy,
  }) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('${ApiService.baseUrl}/api/stories/drafts'),
        headers: await ApiService._getHeaders(includeAuth: true),
        body: json.encode({
          'content': content,
          'mediaUrl': mediaUrl,
          'mediaType': mediaType,
          'privacy': privacy,
        }),
      );
    });
  }

  /// Get user's story drafts
  static Future<Map<String, dynamic>> getDrafts() async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('${ApiService.baseUrl}/api/stories/drafts'),
        headers: await ApiService._getHeaders(includeAuth: true),
      );
    });
  }

  /// Delete a story draft
  static Future<Map<String, dynamic>> deleteDraft(String draftId) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.delete(
        Uri.parse('${ApiService.baseUrl}/api/stories/drafts/$draftId'),
        headers: await ApiService._getHeaders(includeAuth: true),
      );
    });
  }

  /// Post a story reply with mentions
  static Future<Map<String, dynamic>> replyToStoryWithMentions({
    required String storyId,
    required String content,
    List<Map<String, dynamic>>? mentions,
    List<String>? tags,
  }) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.post(
        Uri.parse('${ApiService.baseUrl}/api/stories/$storyId/replies'),
        headers: await ApiService._getHeaders(includeAuth: true),
        body: json.encode({
          'content': content,
          if (mentions != null) 'mentions': mentions,
          if (tags != null) 'tags': tags,
        }),
      );
    });
  }

  // ============================================================================
  // GROUP CHAT
  // ============================================================================

  /// Create a new group chat
  static Future<Map<String, dynamic>> createGroup({
    required String groupName,
    String? groupDescription,
    required List<String> participants,
  }) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      final body = {'groupName': groupName, 'participants': participants};
      if (groupDescription != null && groupDescription.isNotEmpty) {
        body['groupDescription'] = groupDescription;
      }
      return await http.post(
        Uri.parse('${ApiService.baseUrl}/messages/groups'),
        headers: await ApiService._getHeaders(includeAuth: true),
        body: json.encode(body),
      );
    });
  }

  /// Get followers
  static Future<Map<String, dynamic>> getFollowers({int? limit}) async {
    return await ApiService._makeAuthenticatedRequest(() async {
      return await http.get(
        Uri.parse('${ApiService.baseUrl}/users/followers?limit=${limit ?? 20}'),
        headers: await ApiService._getHeaders(includeAuth: true),
      );
    });
  }

  /// Upload a single image file (for event covers, etc.)
  static Future<Map<String, dynamic>> uploadImage(XFile imageFile) async {
    final token = await getAccessToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/images/upload'),
    );

    request.headers['Authorization'] = 'Bearer $token';

    final bytes = await imageFile.readAsBytes();

    // Best-effort MIME detection with web support
    String? mimeType = imageFile.mimeType; // available on web
    String filename = imageFile.name;

    // If no extension in the name, derive one later
    String? extFromName = filename.contains('.') ? filename.split('.').last.toLowerCase() : null;

    // Fallback: sniff bytes for common image types
    String? extFromBytes;
    if (bytes.length >= 12) {
      // JPEG: FF D8
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
        extFromBytes = 'jpg';
        mimeType ??= 'image/jpeg';
      }
      // PNG: 89 50 4E 47 0D 0A 1A 0A
      else if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
        extFromBytes = 'png';
        mimeType ??= 'image/png';
      }
      // GIF: GIF87a / GIF89a
      else if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
        extFromBytes = 'gif';
        mimeType ??= 'image/gif';
      }
      // WEBP: RIFF....WEBP
      else if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
               bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
        extFromBytes = 'webp';
        mimeType ??= 'image/webp';
      }
    }

    // If still unknown, try derive from imageFile.path (non-web)
    if (mimeType == null || mimeType.isEmpty) {
      final pathExt = imageFile.path.contains('.') ? imageFile.path.split('.').last.toLowerCase() : null;
      switch (pathExt) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
      }
      extFromName ??= pathExt;
    }

    // Ensure we always send an image/* type; default to jpeg
    mimeType ??= 'image/jpeg';

    // Ensure filename has an extension the server can use
    final resolvedExt = (extFromName ?? extFromBytes) ?? (mimeType.split('/').last);
    if (!filename.contains('.')) {
      filename = 'upload.$resolvedExt';
    }

    final mediaType = MediaType.parse(mimeType);

    final multipartFile = http.MultipartFile.fromBytes(
      'image',
      bytes,
      filename: filename,
      contentType: mediaType,
    );
    request.files.add(multipartFile);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    return _handleResponse(response);
  }

  // Search for GIFs using Giphy API (via backend proxy)
  static Future<Map<String, dynamic>> searchGifs({
    required String query,
    int limit = 25,
    int offset = 0,
    String rating = 'g',
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = {
        'q': query,
        'limit': limit.toString(),
        'offset': offset.toString(),
        'rating': rating,
      };
      final uri = Uri.parse('$baseUrl/giphy/search').replace(queryParameters: queryParams);
      return await http.get(uri, headers: await _getHeaders(includeAuth: true));
    });
  }

  // Get trending GIFs from Giphy API (via backend proxy)
  static Future<Map<String, dynamic>> getTrendingGifs({
    int limit = 25,
    int offset = 0,
    String rating = 'g',
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
        'rating': rating,
      };
      final uri = Uri.parse('$baseUrl/giphy/trending').replace(queryParameters: queryParams);
      return await http.get(uri, headers: await _getHeaders(includeAuth: true));
    });
  }

  // Get random GIF from Giphy API (via backend proxy)
  static Future<Map<String, dynamic>> getRandomGif({
    String? tag,
    String rating = 'g',
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = <String, String>{
        'rating': rating,
      };
      if (tag != null && tag.isNotEmpty) {
        queryParams['tag'] = tag;
      }
      final uri = Uri.parse('$baseUrl/giphy/random').replace(queryParameters: queryParams);
      return await http.get(uri, headers: await _getHeaders(includeAuth: true));
    });
  }

  // Get online users count (public endpoint - sends auth token if available for tracking)
  static Future<int> getOnlineUsersCount() async {
    try {
      final uri = Uri.parse('$baseUrl/socketio-diagnostics/online-users-count');
      // Include auth token if available so backend can update user's lastActive timestamp
      final headers = await _getHeaders(includeAuth: true);
      final response = await http.get(uri, headers: headers);
      
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true) {
          return body['count'] ?? 0;
        }
      }
      return 0;
    } catch (e) {
      _log('Error fetching online users count: $e');
      return 0;
    }
  }
}

// Custom exception class for API errors
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final List<dynamic>? errors;

  ApiException({required this.statusCode, required this.message, this.errors});

  @override
  String toString() {
    return 'ApiException: $message (Status: $statusCode)';
  }

  String get userFriendlyMessage {
    switch (statusCode) {
      case 400:
        // First, check if we have a detailed message from the server
        if (message.isNotEmpty && message != 'An error occurred') {
          return message;
        }

        // Then check for validation errors array
        if (errors != null && errors!.isNotEmpty) {
          // Extract validation error messages
          final validationErrors = errors!
              .map((e) => e['msg'] ?? e['message'] ?? '')
              .where((msg) => msg.isNotEmpty)
              .join('\n');
          if (validationErrors.isNotEmpty) {
            return validationErrors;
          }
        }

        // Last resort fallback
        return 'Invalid request. Please check your input.';
      case 401:
        return 'Authentication failed. Please login again.';
      case 403:
        return 'You don\'t have permission to perform this action.';
      case 404:
        return 'The requested resource was not found.';
      case 409:
        return message; // Usually meaningful for conflicts like "Email already exists"
      case 429:
        return 'Too many requests. Please try again later.';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return message.isNotEmpty ? message : 'An unexpected error occurred.';
    }
  }
}

