import 'package:flutter/foundation.dart';

class ApiConfig {
  // Base URL for API - change this to your production URL
  static const String _devBaseUrl = 'http://localhost:5000/api';
  static const String _devSocketUrl = 'http://localhost:5000';

  // Socket URL for real-time events
  static const String _prodBaseUrl = 'https://freetalk.site/api';
  static const String _prodSocketUrl = 'https://freetalk.site';

  // Use development URLs in debug mode, production URLs in release mode
  static String get baseUrl => kDebugMode ? _devBaseUrl : _prodBaseUrl;
  static String get socketUrl => kDebugMode ? _devSocketUrl : _prodSocketUrl;
}
