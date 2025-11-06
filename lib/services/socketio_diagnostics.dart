import 'dart:async';
import '../utils/app_logger.dart';
import 'socket_service.dart';

/// Socket.IO Diagnostics Service - helps monitor and debug Socket.IO connections
class SocketIODiagnostics {
  static final SocketIODiagnostics _instance = SocketIODiagnostics._internal();
  factory SocketIODiagnostics() => _instance;
  SocketIODiagnostics._internal();

  final _logger = AppLogger();
  final SocketService _socketService = SocketService();

  // Diagnostic data
  final int _messagesSent = 0;
  int _messagesReceived = 0;
  DateTime? _lastMessageTime;
  final List<String> _eventLog = [];
  Timer? _diagnosticTimer;

  int get messagesSent => _messagesSent;
  int get messagesReceived => _messagesReceived;
  bool get isConnected => _socketService.isConnected;
  String get connectionStatus =>
      _socketService.isConnected ? 'Connected' : 'Disconnected';

  /// Start diagnostic monitoring
  void startMonitoring() {
    _logger.info('🔍 Starting Socket.IO diagnostic monitoring');

    // Log every event that comes through
    _setupEventMonitoring();

    // Periodic diagnostic report
    _diagnosticTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _printDiagnosticReport();
    });
  }

  /// Stop diagnostic monitoring
  void stopMonitoring() {
    _diagnosticTimer?.cancel();
    _logger.info('🔍 Stopped Socket.IO diagnostic monitoring');
  }

  /// Setup event monitoring
  void _setupEventMonitoring() {
    // Monitor common real-time events
    final eventsToMonitor = [
      'message:new',
      'notification:new',
      'notification:unread-count',
      'post:created',
      'post:reacted',
      'post:commented',
      'post:shared',
      'post:deleted',
      'post:updated',
      'story:created',
      'story:viewed',
      'story:deleted',
      'profile:updated',
      'typing:start',
      'typing:stop',
      'presence:online',
      'presence:offline',
    ];

    for (final event in eventsToMonitor) {
      _socketService.on(event, (data) {
        _messagesReceived++;
        _lastMessageTime = DateTime.now();
        _logEvent('📨 Received: $event');
        _logger.debug('Event payload: $data');
      });
    }
  }

  /// Log an event for diagnostics
  void _logEvent(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final entry = '$timestamp - $message';
    _eventLog.add(entry);

    // Keep only last 100 events to prevent memory issues
    if (_eventLog.length > 100) {
      _eventLog.removeAt(0);
    }
  }

  /// Print diagnostic report
  void _printDiagnosticReport() {
    _logger.info('📊 ===== Socket.IO Diagnostic Report =====');
    _logger.info('Connection Status: $connectionStatus');
    _logger.info('Messages Sent: $_messagesSent');
    _logger.info('Messages Received: $_messagesReceived');
    _logger.info(
        'Last Message: ${_lastMessageTime?.toIso8601String() ?? "Never"}');
    _logger.info('Event Log Size: ${_eventLog.length}');

    // Check for issues
    _checkForIssues();

    _logger.info('📊 ========================================');
  }

  /// Check for common Socket.IO issues
  void _checkForIssues() {
    if (!isConnected) {
      _logger.warning('⚠️ Socket.IO is NOT connected!');
      _logger.warning('⚠️ Real-time updates will not work');
      return;
    }

    final now = DateTime.now();
    if (_lastMessageTime != null) {
      final timeSinceLastMessage = now.difference(_lastMessageTime!).inSeconds;
      if (timeSinceLastMessage > 60) {
        _logger.warning(
          '⚠️ No messages received in last ${timeSinceLastMessage}s - connection may be stalled',
        );
      }
    }

    if (_messagesReceived == 0) {
      _logger.warning('⚠️ No real-time messages received since startup');
    }
  }

  /// Get diagnostic report as a map
  Map<String, dynamic> getDiagnosticReport() {
    return {
      'connected': isConnected,
      'connectionStatus': connectionStatus,
      'messagesSent': _messagesSent,
      'messagesReceived': _messagesReceived,
      'lastMessageTime': _lastMessageTime?.toIso8601String(),
      'eventLogSize': _eventLog.length,
      'recentEvents': _eventLog.isNotEmpty
          ? _eventLog.sublist(
              (_eventLog.length - 10).clamp(0, _eventLog.length),
            )
          : [],
    };
  }

  /// Test Socket.IO connection with echo
  Future<bool> testConnection() async {
    _logger.info('🧪 Testing Socket.IO connection...');

    if (!isConnected) {
      _logger.error('🧪 Socket is not connected');
      return false;
    }

    try {
      // Set up listener for response
      final completer = Completer<bool>();
      late Function(dynamic) listener;

      listener = (data) {
        _logger.info('🧪 Received echo response: $data');
        _socketService.off('echo:response', listener);
        completer.complete(true);
      };

      _socketService.on('echo:response', listener);

      // Send test message
      _logger.info('🧪 Sending test message...');
      _socketService.emit('echo:test', {
        'timestamp': DateTime.now().toIso8601String(),
        'message': 'Connection test'
      });

      // Wait for response with timeout
      final result = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _logger.error('🧪 Echo test timed out after 5 seconds');
          _socketService.off('echo:response', listener);
          return false;
        },
      ).catchError((e) {
        _logger.error('🧪 Echo test error: $e');
        _socketService.off('echo:response', listener);
        return false;
      });

      if (result) {
        _logger.info('✅ 🧪 Socket.IO connection test PASSED');
      } else {
        _logger.error('❌ 🧪 Socket.IO connection test FAILED');
      }

      return result;
    } catch (e) {
      _logger.error('🧪 Connection test error: $e');
      return false;
    }
  }

  /// Simulate an event for testing
  void simulateEvent(String eventName, Map<String, dynamic> data) {
    _logger.info('🎭 Simulating event: $eventName');
    _logger.info('🎭 Data: $data');
    // This would typically be used in testing environments
  }

  /// Get formatted diagnostic info for display
  String getFormattedDiagnosticInfo() {
    final report = getDiagnosticReport();
    final buffer = StringBuffer();

    buffer.writeln('📊 Socket.IO Diagnostic Information');
    buffer.writeln('-----------------------------------');
    buffer.writeln('Status: ${report['connectionStatus']}');
    buffer.writeln('Messages Sent: ${report['messagesSent']}');
    buffer.writeln('Messages Received: ${report['messagesReceived']}');
    buffer.writeln('Last Message: ${report['lastMessageTime'] ?? 'Never'}');
    buffer.writeln('Recent Events (${report['eventLogSize']}):');

    final recentEvents = report['recentEvents'] as List;
    if (recentEvents.isEmpty) {
      buffer.writeln('  (none)');
    } else {
      for (final event in recentEvents) {
        buffer.writeln('  • $event');
      }
    }

    return buffer.toString();
  }
}
