import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'api_service.dart';

class PasswordResetService {
  static String get baseUrl => '${ApiService.baseUrl}/auth';

  /// Request password reset email
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      developer.log('🔄 Starting password reset for: $email');

      final uri = Uri.parse('$baseUrl/forgot-password');
      developer.log('📤 Sending request to: $uri');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      developer.log('📥 Response status: ${response.statusCode}');
      developer.log('📥 Response body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        developer.log('✅ Password reset request successful');
        return {
          'success': true,
          'message':
              data['message'] ?? 'Password reset link sent to your email',
        };
      } else if (response.statusCode == 400) {
        // Bad request - likely social auth user
        developer.log('⚠️ Bad request: ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Invalid request',
        };
      } else if (response.statusCode == 429) {
        // Too many requests
        developer.log('⚠️ Rate limit exceeded');
        return {
          'success': false,
          'message':
              data['message'] ?? 'Too many requests. Please try again later.',
        };
      } else if (response.statusCode >= 500) {
        // Server error
        developer.log('❌ Server error: ${response.statusCode}');
        return {
          'success': false,
          'message': data['message'] ?? 'Server error. Please try again later.',
        };
      } else {
        developer.log('❌ Unexpected error: ${response.statusCode}');
        return {
          'success': false,
          'message': data['message'] ?? 'An error occurred',
        };
      }
    } catch (e) {
      developer.log('❌ Exception in forgotPassword: $e');
      return {
        'success': false,
        'message': 'Network error. Please check your connection.',
      };
    }
  }

  /// Reset password with token
  Future<Map<String, dynamic>> resetPassword(
      String token, String newPassword) async {
    try {
      developer.log('🔄 Resetting password with token');

      final uri = Uri.parse('$baseUrl/reset-password');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'token': token,
          'newPassword': newPassword,
        }),
      );

      developer.log('📥 Response status: ${response.statusCode}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        developer.log('✅ Password reset successful');
        return {
          'success': true,
          'message': data['message'] ?? 'Password reset successful',
        };
      } else if (response.statusCode == 400) {
        developer.log('⚠️ Invalid or expired token');
        return {
          'success': false,
          'message': data['message'] ?? 'Invalid or expired reset link',
        };
      } else {
        developer.log('❌ Error: ${response.statusCode}');
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to reset password',
        };
      }
    } catch (e) {
      developer.log('❌ Exception in resetPassword: $e');
      return {
        'success': false,
        'message': 'Network error. Please check your connection.',
      };
    }
  }

  /// Verify if reset token is valid
  Future<Map<String, dynamic>> verifyResetToken(String token) async {
    try {
      developer.log('🔄 Verifying reset token');

      final uri = Uri.parse('$baseUrl/verify-reset-token/$token');

      final response = await http.get(uri);

      developer.log('📥 Response status: ${response.statusCode}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        developer.log('✅ Token is valid');
        return {
          'success': true,
          'email': data['data']?['email'],
        };
      } else {
        developer.log('⚠️ Token invalid or expired');
        return {
          'success': false,
          'message': data['message'] ?? 'Invalid or expired token',
        };
      }
    } catch (e) {
      developer.log('❌ Exception in verifyResetToken: $e');
      return {
        'success': false,
        'message': 'Network error. Please check your connection.',
      };
    }
  }

  // ========================================================================
  // SMS-BASED PASSWORD RESET
  // ========================================================================

  /// Request SMS verification code for password reset
  Future<Map<String, dynamic>> requestSmsReset(String phoneNumber) async {
    try {
      developer.log('🔄 Requesting SMS reset for: $phoneNumber');

      final uri = Uri.parse('$baseUrl/request-sms-reset');
      developer.log('📤 Sending request to: $uri');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phoneNumber': phoneNumber}),
      );

      developer.log('📥 Response status: ${response.statusCode}');
      developer.log('📥 Response body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        developer.log('✅ SMS verification code sent');
        return {
          'success': true,
          'message': data['message'] ?? 'Verification code sent to your phone',
          // In development, the API returns the code for testing
          if (data['verificationCode'] != null)
            'verificationCode': data['verificationCode'],
          if (data['dev'] == true) 'isDev': true,
        };
      } else if (response.statusCode == 400) {
        developer.log('⚠️ Bad request: ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Invalid phone number',
        };
      } else if (response.statusCode == 403) {
        developer.log('⚠️ Phone not verified: ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Phone number not verified',
          'needsVerification': true,
        };
      } else if (response.statusCode == 429) {
        developer.log('⚠️ Rate limit exceeded');
        return {
          'success': false,
          'message':
              data['message'] ?? 'Too many requests. Please try again later.',
        };
      } else {
        developer.log('❌ Unexpected error: ${response.statusCode}');
        return {
          'success': false,
          'message': data['message'] ?? 'An error occurred',
        };
      }
    } catch (e) {
      developer.log('❌ Exception in requestSmsReset: $e');
      return {
        'success': false,
        'message': 'Network error. Please check your connection.',
      };
    }
  }

  /// Verify SMS code and reset password
  Future<Map<String, dynamic>> verifySmsReset({
    required String phoneNumber,
    required String code,
    required String newPassword,
  }) async {
    try {
      developer.log('🔄 Verifying SMS code and resetting password');

      final uri = Uri.parse('$baseUrl/verify-sms-reset');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phoneNumber': phoneNumber,
          'code': code,
          'newPassword': newPassword,
        }),
      );

      developer.log('📥 Response status: ${response.statusCode}');
      developer.log('📥 Response body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        developer.log('✅ Password reset successful');
        return {
          'success': true,
          'message': data['message'] ?? 'Password reset successful',
        };
      } else if (response.statusCode == 400) {
        developer.log('⚠️ Verification failed: ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Invalid verification code',
        };
      } else {
        developer.log('❌ Error: ${response.statusCode}');
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to reset password',
        };
      }
    } catch (e) {
      developer.log('❌ Exception in verifySmsReset: $e');
      return {
        'success': false,
        'message': 'Network error. Please check your connection.',
      };
    }
  }
}
