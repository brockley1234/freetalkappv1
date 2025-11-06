import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:async';
import '../config/api_config.dart';
import 'api_service.dart';
import '../utils/app_logger.dart';

class EventSocketService {
  static io.Socket? _socket;
  static final _eventControllers =
      <String, StreamController<Map<String, dynamic>>>{};

  static StreamController<Map<String, dynamic>> _getController(String event) {
    if (!_eventControllers.containsKey(event)) {
      _eventControllers[event] =
          StreamController<Map<String, dynamic>>.broadcast();
    }
    return _eventControllers[event]!;
  }

  static Stream<Map<String, dynamic>> get onEventCreated =>
      _getController('event:created').stream;
  static Stream<Map<String, dynamic>> get onEventUpdated =>
      _getController('event:updated').stream;
  static Stream<Map<String, dynamic>> get onEventDeleted =>
      _getController('event:deleted').stream;
  static Stream<Map<String, dynamic>> get onEventRSVP =>
      _getController('event:rsvp').stream;
  static Stream<Map<String, dynamic>> get onEventCheckIn =>
      _getController('event:checkin').stream;
  static Stream<Map<String, dynamic>> get onEventReminder =>
      _getController('event:reminder').stream;
  static Stream<Map<String, dynamic>> get onBirthdayToday =>
      _getController('birthday:today').stream;
  static Stream<Map<String, dynamic>> get onInviteAccepted =>
      _getController('event:invite-accepted').stream;
  static Stream<Map<String, dynamic>> get onInviteDeclined =>
      _getController('event:invite-declined').stream;
  static Stream<Map<String, dynamic>> get onInvited =>
      _getController('event:invited').stream;

  static Future<void> connect(String userId) async {
    if (_socket?.connected == true) return;

    final token = await ApiService.getAccessToken();

    _socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['polling', 'websocket'])
          .enableAutoConnect()
          .enableForceNew()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      AppLogger.s('Event Socket connected');
      _socket!.emit('authenticate', userId);
    });

    _socket!.on('authenticated', (data) {
      AppLogger.s('Event Socket authenticated: $data');
    });

    // Listen to event-related socket events
    _socket!.on('event:created', (data) {
      _getController('event:created').add(Map<String, dynamic>.from(data));
    });

    _socket!.on('event:updated', (data) {
      _getController('event:updated').add(Map<String, dynamic>.from(data));
    });

    _socket!.on('event:deleted', (data) {
      _getController('event:deleted').add(Map<String, dynamic>.from(data));
    });

    _socket!.on('event:rsvp', (data) {
      _getController('event:rsvp').add(Map<String, dynamic>.from(data));
    });

    _socket!.on('event:checkin', (data) {
      _getController('event:checkin').add(Map<String, dynamic>.from(data));
    });

    _socket!.on('event:reminder', (data) {
      _getController('event:reminder').add(Map<String, dynamic>.from(data));
    });

    _socket!.on('birthday:today', (data) {
      _getController('birthday:today').add(Map<String, dynamic>.from(data));
    });

    _socket!.on('event:invite-accepted', (data) {
      _getController('event:invite-accepted')
          .add(Map<String, dynamic>.from(data));
    });

    _socket!.on('event:invite-declined', (data) {
      _getController('event:invite-declined')
          .add(Map<String, dynamic>.from(data));
    });

    _socket!.on('event:invited', (data) {
      _getController('event:invited').add(Map<String, dynamic>.from(data));
    });

    _socket!.onDisconnect((_) {
      AppLogger.s('Event Socket disconnected');
    });
  }

  static void subscribeToEvent(String eventId) {
    if (_socket?.connected == true) {
      _socket!.emit('events:subscribe', {'eventId': eventId});
      AppLogger.s('Subscribed to event: $eventId');
    }
  }

  static void unsubscribeFromEvent(String eventId) {
    if (_socket?.connected == true) {
      _socket!.emit('events:unsubscribe', {'eventId': eventId});
      AppLogger.s('Unsubscribed from event: $eventId');
    }
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    // Close all stream controllers
    for (var controller in _eventControllers.values) {
      controller.close();
    }
    _eventControllers.clear();
  }
}
