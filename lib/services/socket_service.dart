import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../utils/app_logger.dart';
import 'api_service.dart';
import 'secure_storage_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  final _logger = AppLogger();

  io.Socket? _socket;
  String? _userId;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;

  // Getters
  io.Socket? get socket => _socket;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;

  // Connection status callbacks
  final List<Function(bool)> _connectionStatusListeners = [];

  // Debounce timers for event handlers
  final Map<String, Timer?> _debounceTimers = {};
  final Map<String, dynamic> _pendingData = {};

  // Multiple listeners per event
  final Map<String, List<Function(dynamic)>> _eventListeners = {};

  // Initialize and connect to Socket.IO server
  Future<void> connect() async {
    _logger.debug(
      'Socket connect() called - state: ${_socket != null ? "exists" : "null"}, connected: ${_socket?.connected ?? false}, connecting: $_isConnecting',
    );

    if (_socket != null && _socket!.connected) {
      _logger.debug('Socket already connected - skipping initialization');
      _reconnectAttempts = 0;
      return;
    }

    if (_isConnecting) {
      _logger.debug('Socket connection already in progress');
      return;
    }

    _isConnecting = true;

    try {
      // Get token and userId from SecureStorage
      final secureStorage = SecureStorageService();
      final token = await secureStorage.getAccessToken();
      _userId = await secureStorage.getUserId();

      if (token == null || _userId == null) {
        _logger.error('Socket connection failed: No auth credentials found');
        _isConnecting = false;
        return;
      }

      _logger.info('Connecting to socket server...');
      _logger.info('API URL: ${ApiService.baseApi}');
      _logger.info('User ID: $_userId');

      // Initialize Socket.IO connection
      _socket = io.io(
        ApiService.baseApi, // HTTPS connection to production server
        io.OptionBuilder()
            .setTransports([
              'websocket',
              'polling',
            ]) // Prefer websocket, fall back to polling if necessary
            .setTimeout(15000)
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .build(),
      );

      // Connection event handlers
      _socket!.onConnect((_) {
        _logger.info('🔌 ================================================');
        _logger.info('🔌 Socket connected: ${_socket!.id}');
        _logger.info('🔌 User ID: $_userId');
        _logger.info('🔌 ================================================');
        _isConnected = true;
        _isConnecting = false;
        _reconnectAttempts = 0;
        _notifyConnectionStatus(true);

        // Authenticate with user ID
        _logger.info('👤 Authenticating with userId: $_userId');
        _socket!.emit('authenticate', _userId);

        // Re-register all event listeners that were registered before connection
        _reRegisterListeners();

        // Start heartbeat to keep connection alive
        _startHeartbeat();
      });

      _socket!.on('authenticated', (data) {
        _logger.info('🔌 ================================================');
        _logger.info('🔌 ✅ Socket authenticated for user: $_userId');
        _logger.info('🔌 Socket ID: ${_socket!.id}');
        _logger.info('🔌 Data: $data');
        _logger.info('🔌 ================================================');
      });

      // Debug: Listen to ALL socket events (only in debug mode)
      _socket!.onAny((event, data) {
        _logger.socket('Event: $event');
      });

      _socket!.onDisconnect((_) {
        _logger.warning('Socket disconnected');
        _isConnected = false;
        _isConnecting = false;
        _stopHeartbeat();
        _notifyConnectionStatus(false);

        // Attempt to reconnect after a delay
        _scheduleReconnect();
      });

      _socket!.onConnectError((error) {
        _logger.error('Socket connection error', error: error);
        _isConnected = false;
        _isConnecting = false;
        _notifyConnectionStatus(false);

        // Attempt to reconnect after a delay
        _scheduleReconnect();
      });

      _socket!.onError((error) {
        _logger.error('Socket error', error: error);
      });

      _socket!.onReconnect((attempt) {
        debugPrint('🔄 Reconnected after $attempt attempts');
        _isConnected = true;
        _notifyConnectionStatus(true);

        // Re-authenticate and re-register listeners
        debugPrint('👤 Re-authenticating after reconnection...');
        _socket!.emit('authenticate', _userId);
        _reRegisterListeners();
      });

      _socket!.onReconnectAttempt((attempt) {
        _logger.info('Socket reconnection attempt $attempt');
      });

      _socket!.onReconnectError((error) {
        _logger.warning('Socket reconnection error: $error');
      });

      _socket!.onReconnectFailed((_) {
        _logger.error('Socket reconnection failed after all attempts');
        _isConnected = false;
        _notifyConnectionStatus(false);
      });

      // Connect to server
      _socket!.connect();
    } catch (e, st) {
      _logger.error('Error initializing socket', error: e, stackTrace: st);
      _isConnected = false;
      _isConnecting = false;

      // Schedule reconnect on error
      _scheduleReconnect();
    }
  }

  // Start heartbeat timer to keep connection alive
  void _startHeartbeat() {
    _stopHeartbeat(); // Clear any existing timer

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (_socket != null && _socket!.connected) {
        _logger.debug('💓 Sending heartbeat ping');
        _socket!.emit('ping', {'timestamp': DateTime.now().toIso8601String()});
      } else {
        _logger.warning('💓 Heartbeat: Socket not connected');
        timer.cancel();
      }
    });
  }

  // Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // Schedule reconnection with exponential backoff
  void _scheduleReconnect() {
    // Clear any existing reconnect timer
    _reconnectTimer?.cancel();

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _logger
          .error('Max reconnection attempts reached. Please restart the app.');
      return;
    }

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 32s, 60s (capped)
    final delaySeconds = (1 << _reconnectAttempts).clamp(1, 60);
    _reconnectAttempts++;

    _logger.info(
        '⏰ Scheduling reconnect attempt $_reconnectAttempts in ${delaySeconds}s');

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      _logger.info('🔄 Attempting to reconnect...');
      await connect();
    });
  }

  // Disconnect from Socket.IO server
  void disconnect() {
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;

    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      _isConnecting = false;
      _notifyConnectionStatus(false);
      _logger.info('Socket disconnected');
    }
  }

  // Listen to specific events with support for multiple listeners
  void on(String event, Function(dynamic) callback) {
    _logger.debug('Registering listener for event: $event');

    // Store the callback in our map
    if (!_eventListeners.containsKey(event)) {
      _eventListeners[event] = [];
    }
    _eventListeners[event]!.add(callback);

    _logger.debug(
      'Total listeners for $event: ${_eventListeners[event]!.length}',
    );

    // Set up socket listener only once per event
    if (_eventListeners[event]!.length == 1) {
      if (_socket != null) {
        _logger.debug('Setting up socket listener for: $event');
        _socket!.on(event, (data) {
          _logger.socket('📡 Event received: $event');
          _logger.socket('📡 Data: $data');
          _logger.socket(
              '📡 Number of listeners: ${_eventListeners[event]?.length ?? 0}');

          // Call all registered callbacks for this event
          final listeners = List<Function(dynamic)>.from(
            _eventListeners[event] ?? [],
          );

          _logger.socket('📡 Calling ${listeners.length} listener(s)');
          for (var listener in listeners) {
            try {
              listener(data);
            } catch (e, st) {
              _logger.error(
                'Error in event listener for $event',
                error: e,
                stackTrace: st,
              );
            }
          }
        });
      } else {
        _logger.debug(
          'Socket is null, listener for $event will be set up when socket connects',
        );
      }
    }
  }

  // Re-register all event listeners (called after connection)
  void _reRegisterListeners() {
    _logger.debug(
      'Re-registering ${_eventListeners.length} socket event listeners',
    );

    for (var entry in _eventListeners.entries) {
      final event = entry.key;
      final listeners = entry.value;

      if (listeners.isNotEmpty) {
        _socket!.on(event, (data) {
          // Call all registered callbacks for this event
          final listenersCopy = List<Function(dynamic)>.from(listeners);

          for (var listener in listenersCopy) {
            try {
              listener(data);
            } catch (e, st) {
              _logger.error(
                'Error in socket event listener for $event',
                error: e,
                stackTrace: st,
              );
            }
          }
        });
      }
    }
  }

  // Listen with debouncing to prevent rapid updates
  void onWithDebounce(
    String event,
    Function(dynamic) callback, {
    Duration debounceTime = const Duration(milliseconds: 300),
  }) {
    _socket?.on(event, (data) {
      // Cancel previous timer if exists
      _debounceTimers[event]?.cancel();

      // Store the latest data
      _pendingData[event] = data;

      // Create new timer
      _debounceTimers[event] = Timer(debounceTime, () {
        callback(_pendingData[event]);
        _pendingData.remove(event);
      });
    });
  }

  // Remove a specific event listener
  void off(String event, Function(dynamic)? callback) {
    if (callback != null && _eventListeners.containsKey(event)) {
      _eventListeners[event]!.remove(callback);

      // If no more listeners for this event, remove the socket listener
      if (_eventListeners[event]!.isEmpty) {
        _socket?.off(event);
        _eventListeners.remove(event);
      }
    } else if (callback == null) {
      // Remove all listeners for this event
      _socket?.off(event);
      _eventListeners.remove(event);
    }
  }

  // Emit events
  void emit(String event, [dynamic data]) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit(event, data);
    } else {
      debugPrint('Cannot emit: Socket not connected');
    }
  }

  // Add connection status listener
  void addConnectionStatusListener(Function(bool) listener) {
    _connectionStatusListeners.add(listener);
  }

  // Remove connection status listener
  void removeConnectionStatusListener(Function(bool) listener) {
    _connectionStatusListeners.remove(listener);
  }

  // Track if we have a pending notification to avoid duplicate callbacks
  bool _hasPendingNotification = false;
  bool? _lastNotifiedStatus;

  // Notify all listeners of connection status change
  void _notifyConnectionStatus(bool isConnected) {
    // Prevent duplicate notifications for the same status
    if (_lastNotifiedStatus == isConnected) {
      return;
    }

    // If we're in the middle of a frame build/layout/paint, defer callbacks
    // to avoid "setState() called when widget tree was locked" assertions.
    final phase = SchedulerBinding.instance.schedulerPhase;

    void invokeListeners() {
      _hasPendingNotification = false;
      _lastNotifiedStatus = isConnected;

      // Work on a copy in case listeners modify the list
      final listeners = List<Function(bool)>.from(_connectionStatusListeners);
      for (var listener in listeners) {
        try {
          listener(isConnected);
        } catch (e, st) {
          debugPrint('⚠️ Error in connection status listener: $e\n$st');
        }
      }
    }

    if (phase == SchedulerPhase.idle) {
      // Safe to call immediately
      invokeListeners();
    } else if (!_hasPendingNotification) {
      // Only schedule one callback at a time to prevent callback queue buildup
      _hasPendingNotification = true;
      SchedulerBinding.instance.addPostFrameCallback((_) => invokeListeners());
    }
  }

  // Clean up
  void dispose() {
    // Cancel all debounce timers
    for (var timer in _debounceTimers.values) {
      timer?.cancel();
    }
    _debounceTimers.clear();
    _pendingData.clear();

    // Clear event listeners
    _eventListeners.clear();

    disconnect();
    _connectionStatusListeners.clear();
  }

  // Force reconnect (useful for manual reconnection)
  Future<void> forceReconnect() async {
    _logger.info('🔄 Force reconnecting socket...');
    disconnect();
    _reconnectAttempts = 0;
    await Future.delayed(const Duration(milliseconds: 500));
    await connect();
  }
}
