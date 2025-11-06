import 'dart:async';
import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import '../utils/app_logger.dart';

/// Enhanced Socket.IO connection manager with improved reliability
class EnhancedSocketConnectionManager extends ChangeNotifier {
  final SocketService _socketService = SocketService();
  final AppLogger _logger = AppLogger();

  // Connection state
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _lastError;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;

  // Timers
  Timer? _reconnectTimer;
  Timer? _connectionCheckTimer;

  // Listeners
  final List<Function(bool)> _connectionStatusListeners = [];

  // Getters
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get lastError => _lastError;
  int get reconnectAttempts => _reconnectAttempts;

  EnhancedSocketConnectionManager() {
    _logger.info('🚀 EnhancedSocketConnectionManager initialized');
    _setupConnectionListeners();
    _startConnectionCheck();
  }

  void _setupConnectionListeners() {
    // Listen to socket service connection status
    _socketService.addConnectionStatusListener((isConnected) {
      _isConnected = isConnected;
      _lastError = null;

      if (isConnected) {
        _logger.info('✅ Socket connection established');
        _reconnectAttempts = 0;
        _cancelReconnectTimer();
      } else {
        _logger.warning('❌ Socket connection lost');
        _scheduleReconnect();
      }

      notifyListeners();
      _notifyConnectionStatusListeners(isConnected);
    });
  }

  /// Start automatic connection check
  void _startConnectionCheck() {
    _connectionCheckTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isConnected && !_isConnecting) {
        _logger.warning(
            '⚠️  Connection check: Not connected, attempting reconnect');
        connect();
      }
    });
  }

  /// Connect to Socket.IO server
  Future<void> connect() async {
    if (_isConnected) {
      _logger.debug('Socket already connected');
      return;
    }

    if (_isConnecting) {
      _logger.debug('Connection already in progress');
      return;
    }

    _isConnecting = true;
    _lastError = null;
    notifyListeners();

    try {
      _logger.info('🔌 Attempting socket connection...');
      await _socketService.connect();

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _lastError = null;

      _logger.info('✅ Socket connected successfully');
      notifyListeners();
      _notifyConnectionStatusListeners(true);
    } catch (e, st) {
      _isConnecting = false;
      _isConnected = false;
      _lastError = e.toString();

      _logger.error('❌ Socket connection failed', error: e, stackTrace: st);
      notifyListeners();
      _notifyConnectionStatusListeners(false);

      _scheduleReconnect();
    }
  }

  /// Schedule a reconnection attempt with exponential backoff
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _logger.error('❌ Max reconnection attempts reached');
      _lastError = 'Max reconnection attempts reached';
      notifyListeners();
      return;
    }

    _cancelReconnectTimer();

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 32s, 60s (capped)
    final delaySeconds = (1 << _reconnectAttempts).clamp(1, 60);
    _reconnectAttempts++;

    _logger.info(
        '⏰ Scheduling reconnect attempt $_reconnectAttempts in ${delaySeconds}s');

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      _logger.info('🔄 Executing reconnect attempt $_reconnectAttempts');
      await connect();
    });
  }

  /// Cancel pending reconnect timer
  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Force an immediate reconnection
  Future<void> forceReconnect() async {
    _logger.info('🔄 Force reconnecting socket...');
    _cancelReconnectTimer();
    _reconnectAttempts = 0;

    await _socketService.forceReconnect();

    _isConnected = true;
    _lastError = null;
    notifyListeners();
    _notifyConnectionStatusListeners(true);
  }

  /// Disconnect from Socket.IO server
  Future<void> disconnect() async {
    _logger.info('🔌 Disconnecting socket...');
    _cancelReconnectTimer();
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;

    _socketService.disconnect();

    _isConnected = false;
    _isConnecting = false;
    _lastError = null;
    _reconnectAttempts = 0;

    notifyListeners();
    _notifyConnectionStatusListeners(false);
  }

  /// Add connection status listener
  void addConnectionStatusListener(Function(bool) listener) {
    _connectionStatusListeners.add(listener);
  }

  /// Remove connection status listener
  void removeConnectionStatusListener(Function(bool) listener) {
    _connectionStatusListeners.remove(listener);
  }

  void _notifyConnectionStatusListeners(bool isConnected) {
    for (var listener in _connectionStatusListeners) {
      try {
        listener(isConnected);
      } catch (e) {
        _logger.error('Error in connection listener', error: e);
      }
    }
  }

  /// Get connection status as a displayable string
  String getStatusMessage() {
    if (_isConnected) {
      return 'Connected';
    } else if (_isConnecting) {
      return 'Connecting...';
    } else if (_reconnectAttempts > 0) {
      return 'Reconnecting... (attempt $_reconnectAttempts/$_maxReconnectAttempts)';
    } else if (_lastError != null) {
      return 'Connection failed: $_lastError';
    } else {
      return 'Disconnected';
    }
  }

  /// Get color for status indicator
  Color getStatusColor() {
    if (_isConnected) return Colors.green;
    if (_isConnecting) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _cancelReconnectTimer();
    _connectionCheckTimer?.cancel();
    _connectionStatusListeners.clear();
    super.dispose();
  }
}
