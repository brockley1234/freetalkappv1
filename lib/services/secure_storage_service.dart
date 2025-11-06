import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

/// Secure storage service for sensitive data
/// iOS: Uses Keychain
/// Android: Uses EncryptedSharedPreferences with AES encryption
/// Complies with Apple App Store and Google Play Store security requirements
class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  // Configure secure storage with appropriate settings
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      // Use stronger encryption
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      // Use most secure iOS Keychain options
      accessibility: KeychainAccessibility.first_unlock_this_device,
      // Synchronize with iCloud Keychain (optional)
      synchronizable: false,
    ),
  );

  // Keys for storing sensitive data
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserName = 'user_name';
  static const String _keyRememberMe = 'remember_me';
  static const String _keyBiometricEnabled = 'biometric_enabled';

  /// Store access token securely
  Future<void> setAccessToken(String token) async {
    try {
      await _storage.write(key: _keyAccessToken, value: token);
      debugPrint('✅ Access token stored securely');
    } catch (e) {
      debugPrint('❌ Error storing access token: $e');
      rethrow;
    }
  }

  /// Retrieve access token securely
  Future<String?> getAccessToken() async {
    try {
      final token = await _storage.read(key: _keyAccessToken);
      return token;
    } catch (e) {
      debugPrint('❌ Error retrieving access token: $e');
      return null;
    }
  }

  /// Store refresh token securely
  Future<void> setRefreshToken(String token) async {
    try {
      await _storage.write(key: _keyRefreshToken, value: token);
      debugPrint('✅ Refresh token stored securely');
    } catch (e) {
      debugPrint('❌ Error storing refresh token: $e');
      rethrow;
    }
  }

  /// Retrieve refresh token securely
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (e) {
      debugPrint('❌ Error retrieving refresh token: $e');
      return null;
    }
  }

  /// Store user ID
  Future<void> setUserId(String userId) async {
    try {
      await _storage.write(key: _keyUserId, value: userId);
    } catch (e) {
      debugPrint('❌ Error storing user ID: $e');
      rethrow;
    }
  }

  /// Retrieve user ID
  Future<String?> getUserId() async {
    try {
      return await _storage.read(key: _keyUserId);
    } catch (e) {
      debugPrint('❌ Error retrieving user ID: $e');
      return null;
    }
  }

  /// Store user email
  Future<void> setUserEmail(String email) async {
    try {
      await _storage.write(key: _keyUserEmail, value: email);
    } catch (e) {
      debugPrint('❌ Error storing user email: $e');
      rethrow;
    }
  }

  /// Retrieve user email
  Future<String?> getUserEmail() async {
    try {
      return await _storage.read(key: _keyUserEmail);
    } catch (e) {
      debugPrint('❌ Error retrieving user email: $e');
      return null;
    }
  }

  /// Store user name
  Future<void> setUserName(String name) async {
    try {
      await _storage.write(key: _keyUserName, value: name);
    } catch (e) {
      debugPrint('❌ Error storing user name: $e');
      rethrow;
    }
  }

  /// Retrieve user name
  Future<String?> getUserName() async {
    try {
      return await _storage.read(key: _keyUserName);
    } catch (e) {
      debugPrint('❌ Error retrieving user name: $e');
      return null;
    }
  }

  /// Store remember me preference
  Future<void> setRememberMe(bool remember) async {
    try {
      await _storage.write(key: _keyRememberMe, value: remember.toString());
    } catch (e) {
      debugPrint('❌ Error storing remember me: $e');
      rethrow;
    }
  }

  /// Get remember me preference
  Future<bool> getRememberMe() async {
    try {
      final value = await _storage.read(key: _keyRememberMe);
      return value == 'true';
    } catch (e) {
      debugPrint('❌ Error retrieving remember me: $e');
      return false;
    }
  }

  /// Store biometric authentication preference
  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      await _storage.write(
          key: _keyBiometricEnabled, value: enabled.toString());
    } catch (e) {
      debugPrint('❌ Error storing biometric preference: $e');
      rethrow;
    }
  }

  /// Get biometric authentication preference
  Future<bool> getBiometricEnabled() async {
    try {
      final value = await _storage.read(key: _keyBiometricEnabled);
      return value == 'true';
    } catch (e) {
      debugPrint('❌ Error retrieving biometric preference: $e');
      return false;
    }
  }

  /// Store authentication credentials (for login)
  Future<void> storeAuthCredentials({
    required String accessToken,
    String? refreshToken,
    required String userId,
    required String email,
    String? name,
  }) async {
    try {
      await Future.wait([
        setAccessToken(accessToken),
        if (refreshToken != null) setRefreshToken(refreshToken),
        setUserId(userId),
        setUserEmail(email),
        if (name != null) setUserName(name),
      ]);
      debugPrint('✅ All auth credentials stored securely');
    } catch (e) {
      debugPrint('❌ Error storing auth credentials: $e');
      rethrow;
    }
  }

  /// Clear all auth credentials (for logout)
  Future<void> clearAuthCredentials() async {
    try {
      await Future.wait([
        _storage.delete(key: _keyAccessToken),
        _storage.delete(key: _keyRefreshToken),
        _storage.delete(key: _keyUserId),
        _storage.delete(key: _keyUserEmail),
        _storage.delete(key: _keyUserName),
      ]);
      debugPrint('✅ All auth credentials cleared');
    } catch (e) {
      debugPrint('❌ Error clearing auth credentials: $e');
      rethrow;
    }
  }

  /// Clear all stored data
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      debugPrint('✅ All secure storage cleared');
    } catch (e) {
      debugPrint('❌ Error clearing secure storage: $e');
      rethrow;
    }
  }

  /// Check if user is authenticated (has valid access token)
  Future<bool> isAuthenticated() async {
    try {
      final token = await getAccessToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking authentication: $e');
      return false;
    }
  }

  /// Get all authentication data
  Future<Map<String, String?>> getAuthData() async {
    try {
      final results = await Future.wait([
        getAccessToken(),
        getRefreshToken(),
        getUserId(),
        getUserEmail(),
        getUserName(),
      ]);

      return {
        'accessToken': results[0],
        'refreshToken': results[1],
        'userId': results[2],
        'email': results[3],
        'name': results[4],
      };
    } catch (e) {
      debugPrint('❌ Error getting auth data: $e');
      return {};
    }
  }

  /// Store a custom key-value pair securely
  Future<void> writeSecure(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('❌ Error writing to secure storage: $e');
      rethrow;
    }
  }

  /// Read a custom key from secure storage
  Future<String?> readSecure(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('❌ Error reading from secure storage: $e');
      return null;
    }
  }

  /// Delete a custom key from secure storage
  Future<void> deleteSecure(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('❌ Error deleting from secure storage: $e');
      rethrow;
    }
  }

  /// Check if a key exists in secure storage
  Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      debugPrint('❌ Error checking key existence: $e');
      return false;
    }
  }

  /// Get all keys in secure storage
  Future<Map<String, String>> getAllSecure() async {
    try {
      return await _storage.readAll();
    } catch (e) {
      debugPrint('❌ Error reading all from secure storage: $e');
      return {};
    }
  }
}
