import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';
import '../utils/app_logger.dart';
import 'global_notification_service.dart';
import 'api_service.dart';

// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already done
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final logger = AppLogger();
  logger.info('📱 Handling background message: ${message.messageId}');

  // Show local notification for background messages
  await _showLocalNotification(message);
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const settings =
      InitializationSettings(android: androidSettings, iOS: iosSettings);

  await flutterLocalNotificationsPlugin.initialize(settings);

  const androidDetails = AndroidNotificationDetails(
    'high_importance_channel',
    'High Importance Notifications',
    importance: Importance.high,
    priority: Priority.high,
  );

  const iosDetails = DarwinNotificationDetails();
  const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    message.notification?.title ?? 'New Notification',
    message.notification?.body ?? 'You have a new message',
    details,
    payload: message.data.toString(),
  );
}

class FirebaseMessagingService {
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final _logger = AppLogger();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.info('🔥 Initializing Firebase Messaging...');

      // Firebase Messaging doesn't support web in the same way
      // On web, we'll rely on Socket.IO for real-time notifications
      if (kIsWeb) {
        _logger.info(
            '⚠️ Firebase Messaging not fully supported on web, using Socket.IO instead');
        _isInitialized = true;
        return;
      }

      // Initialize local notifications (mobile only)
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const settings =
          InitializationSettings(android: androidSettings, iOS: iosSettings);

      await _flutterLocalNotificationsPlugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request permissions
      await _requestPermissions();

      // Get FCM token and register with backend for push delivery
      final token = await _firebaseMessaging.getToken();
      _logger.info('📱 FCM Token: $token');
      if (token != null) {
        await _sendTokenToBackend(token);
      }

      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Handle when app is opened from terminated state via notification
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      _isInitialized = true;
      _logger.info('✅ Firebase Messaging initialized successfully');
    } catch (e) {
      _logger.error('❌ Failed to initialize Firebase Messaging: $e');
      _isInitialized = true; // Mark as initialized to prevent retries
    }
  }

  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    _logger
        .info('📱 Notification permissions: ${settings.authorizationStatus}');
  }

  void _onForegroundMessage(RemoteMessage message) {
    _logger.info('📱 Foreground message received: ${message.messageId}');

    // When app is open, use Socket.IO for real-time, but still show notification if needed
    // For now, show local notification for foreground too, or handle via GlobalNotificationService

    final globalNotificationService = GlobalNotificationService();

    // Show in-app notification
    globalNotificationService.showNotification(
      title: message.notification?.title ?? 'New Notification',
      message: message.notification?.body ?? 'You have a new message',
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    _logger.info('📱 Message opened app: ${message.messageId}');

    // Handle navigation based on message data
    _handleMessageNavigation(message);
  }

  void _onNotificationTapped(NotificationResponse response) {
    _logger.info('📱 Notification tapped: ${response.payload}');

    // Parse payload and navigate
    if (response.payload != null) {
      // For simplicity, assume payload is message data
      // In real app, parse JSON
    }
  }

  void _handleMessageNavigation(RemoteMessage message) {
    final data = message.data;
    final navigatorKey = GlobalNotificationService().navigatorKey;

    if (data.containsKey('type')) {
      switch (data['type']) {
        case 'message':
          // Navigate to chat
          break;
        case 'post':
          // Navigate to post
          if (data.containsKey('postId')) {
            navigatorKey.currentState
                ?.pushNamed('/post', arguments: data['postId']);
          }
          break;
        case 'profile':
          // Navigate to profile
          if (data.containsKey('userId')) {
            navigatorKey.currentState
                ?.pushNamed('/profile', arguments: data['userId']);
          }
          break;
      }
    }
  }

  Future<String?> getToken() async {
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      // Send token to backend
      await _sendTokenToBackend(token);
    }
    return token;
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await ApiService.updateFCMToken(token);
      _logger.info('📱 FCM Token sent to backend successfully');
    } catch (e) {
      _logger.error('❌ Failed to send FCM token to backend: $e');
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    _logger.info('📱 Subscribed to topic: $topic');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    _logger.info('📱 Unsubscribed from topic: $topic');
  }
}
