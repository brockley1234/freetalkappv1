import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/secure_storage_service.dart';

/// Diagnostic utility for game challenges debugging
class GameChallengesDiagnostics {
  /// Get detailed system information for debugging
  static Future<Map<String, dynamic>> getDiagnostics() async {
    try {
      final diagnostics = {
        'timestamp': DateTime.now().toString(),
        'platform': _getPlatform(),
        'user_agent': 'Flutter Web',
        'api_url': 'freetalk.site/api',
        'connection_status': await _checkConnection(),
        'secure_storage_status': await _checkSecureStorage(),
        'token_status': await _checkTokenStatus(),
      };
      
      return diagnostics;
    } catch (e) {
      return {
        'timestamp': DateTime.now().toString(),
        'error': 'Failed to gather diagnostics: $e',
      };
    }
  }

  static String _getPlatform() {
    // This would return the actual platform when run in Flutter
    return 'web';
  }

  static Future<String> _checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('https://freetalk.site/health'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        return 'CONNECTED';
      } else {
        return 'ERROR_${response.statusCode}';
      }
    } catch (e) {
      return 'OFFLINE_OR_ERROR: $e';
    }
  }

  static Future<String> _checkSecureStorage() async {
    try {
      final token = await SecureStorageService().getAccessToken();
      return token != null ? 'OK' : 'NO_TOKEN';
    } catch (e) {
      return 'ERROR: $e';
    }
  }

  static Future<String> _checkTokenStatus() async {
    try {
      final token = await SecureStorageService().getAccessToken();
      if (token == null) return 'NO_TOKEN';
      
      // Check if token is likely expired (basic check)
      try {
        // JWT tokens have 3 parts: header.payload.signature
        final parts = token.split('.');
        if (parts.length != 3) return 'INVALID_FORMAT';
        
        // Decode payload (basic attempt)
        final payload = parts[1];
        return 'TOKEN_EXISTS_${payload.substring(0, 10)}...';
      } catch (e) {
        return 'DECODING_ERROR: $e';
      }
    } catch (e) {
      return 'ERROR: $e';
    }
  }

  /// Log diagnostics in a formatted way
  static void logDiagnostics() async {
    final diagnostics = await getDiagnostics();
    debugPrint('========== GAME CHALLENGES DIAGNOSTICS ==========');
    diagnostics.forEach((key, value) {
      debugPrint('  $key: $value');
    });
    debugPrint('===============================================');
  }

  /// Format error details for user display
  static String formatErrorForUser(int statusCode, String response) {
    switch (statusCode) {
      case 400:
        return '❌ Invalid request (400)\nPlease check the conversation and try again.';
      case 401:
        return '❌ Authentication expired (401)\nPlease log in again and try.';
      case 403:
        return '❌ Not allowed (403)\nBoth users must be in the conversation.';
      case 404:
        return '❌ Game service unavailable (404)\nServer is experiencing issues.';
      case 429:
        return '⏳ Too many requests (429)\nPlease wait a moment and try again.';
      case 500:
        return '❌ Server error (500)\nPlease try again in a moment.';
      default:
        return '❌ Unexpected error ($statusCode)\nTry again or contact support.';
    }
  }

  /// Export diagnostics as text for sharing
  static Future<String> exportDiagnostics() async {
    final diagnostics = await getDiagnostics();
    final buffer = StringBuffer();
    buffer.writeln('=== GAME CHALLENGES DEBUG INFO ===');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('');
    
    diagnostics.forEach((key, value) {
      buffer.writeln('$key: $value');
    });
    
    buffer.writeln('');
    buffer.writeln('=== SYSTEM INFO ===');
    buffer.writeln('Platform: web');
    buffer.writeln('API Base: https://freetalk.site');
    buffer.writeln('Game Endpoint: /api/game-challenges');
    buffer.writeln('');
    buffer.writeln('=== TROUBLESHOOTING STEPS ===');
    buffer.writeln('1. If "Offline", check internet connection');
    buffer.writeln('2. If "NO_TOKEN", log out and log back in');
    buffer.writeln('3. If status 404, backend route missing');
    buffer.writeln('4. If status 403, ensure both users in conversation');
    
    return buffer.toString();
  }
}
