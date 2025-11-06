import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/app_logger.dart';

/// Mixin that ensures proper disposal of all resources (streams, subscriptions, timers, etc.)
/// Apply this to StatefulWidget States to guarantee cleanup.
mixin AutoDisposeMixin on State {
  final _logger = AppLogger();
  final List<StreamSubscription> _subscriptions = [];
  final List<StreamController> _controllers = [];
  final List<Timer> _timers = [];
  final List<TextEditingController> _textControllers = [];
  final List<AnimationController> _animationControllers = [];

  /// Register a stream subscription for auto-disposal
  StreamSubscription<T> subscribe<T>(
    Stream<T> stream,
    void Function(T) onData, {
    Function? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  }) {
    final subscription = stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    _subscriptions.add(subscription);
    return subscription;
  }

  /// Register a stream controller for auto-disposal
  StreamController<T> createController<T>({
    void Function()? onListen,
    void Function()? onCancel,
  }) {
    final controller = StreamController<T>(
      onListen: onListen,
      onCancel: onCancel,
    );
    _controllers.add(controller);
    return controller;
  }

  /// Register a broadcast stream controller
  StreamController<T> createBroadcastController<T>({
    void Function()? onListen,
    void Function()? onCancel,
  }) {
    final controller = StreamController<T>.broadcast(
      onListen: onListen,
      onCancel: onCancel,
    );
    _controllers.add(controller);
    return controller;
  }

  /// Register a timer for auto-disposal
  Timer createTimer(Duration duration, void Function() callback) {
    final timer = Timer(duration, callback);
    _timers.add(timer);
    return timer;
  }

  /// Register a periodic timer for auto-disposal
  Timer createPeriodicTimer(
    Duration duration,
    void Function(Timer) callback,
  ) {
    final timer = Timer.periodic(duration, callback);
    _timers.add(timer);
    return timer;
  }

  /// Register a text editing controller for auto-disposal
  TextEditingController createTextController({
    String initialValue = '',
  }) {
    final controller = TextEditingController(text: initialValue);
    _textControllers.add(controller);
    return controller;
  }

  /// Register an animation controller for auto-disposal
  /// Note: For this to work, your State should also use TickerProviderStateMixin
  /// Example: class MyState extends State<MyWidget> with TickerProviderStateMixin, AutoDisposeMixin
  AnimationController createAnimationController({
    required TickerProvider vsyncProvider,
    Duration duration = const Duration(milliseconds: 300),
    String? debugLabel,
  }) {
    final controller = AnimationController(
      duration: duration,
      vsync: vsyncProvider,
      debugLabel: debugLabel,
    );
    _animationControllers.add(controller);
    return controller;
  }

  /// Get all tracked subscriptions
  List<StreamSubscription> getSubscriptions() =>
      List.unmodifiable(_subscriptions);

  /// Get all tracked controllers
  List<StreamController> getControllers() => List.unmodifiable(_controllers);

  /// Get all tracked timers
  List<Timer> getTimers() => List.unmodifiable(_timers);

  /// Manually cancel a specific subscription
  void cancelSubscription(StreamSubscription subscription) {
    if (_subscriptions.remove(subscription)) {
      subscription.cancel();
      _logger.debug('✅ Subscription cancelled manually');
    }
  }

  /// Manually close a specific controller
  void closeController(StreamController controller) {
    if (_controllers.remove(controller)) {
      controller.close();
      _logger.debug('✅ StreamController closed manually');
    }
  }

  /// Manually cancel a specific timer
  void cancelTimer(Timer timer) {
    if (_timers.remove(timer)) {
      timer.cancel();
      _logger.debug('✅ Timer cancelled manually');
    }
  }

  /// Get cleanup stats
  Map<String, int> getCleanupStats() {
    return {
      'subscriptions': _subscriptions.length,
      'controllers': _controllers.length,
      'timers': _timers.length,
      'textControllers': _textControllers.length,
      'animationControllers': _animationControllers.length,
      'total': _subscriptions.length +
          _controllers.length +
          _timers.length +
          _textControllers.length +
          _animationControllers.length,
    };
  }

  /// Print cleanup report
  void printCleanupReport() {
    final stats = getCleanupStats();
    _logger.debug(
      '📊 Cleanup Report for ${runtimeType.toString()}: '
      '${stats['subscriptions']} subscriptions, '
      '${stats['controllers']} controllers, '
      '${stats['timers']} timers, '
      '${stats['textControllers']} text controllers, '
      '${stats['animationControllers']} animation controllers',
    );
  }

  // ============================================================================
  // AUTOMATIC CLEANUP ON DISPOSE
  // ============================================================================

  @override
  void dispose() {
    printCleanupReport();

    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      try {
        subscription.cancel();
      } catch (e) {
        _logger.error('Error cancelling subscription', error: e);
      }
    }
    _subscriptions.clear();

    // Close all stream controllers
    for (final controller in _controllers) {
      try {
        if (!controller.isClosed) {
          controller.close();
        }
      } catch (e) {
        _logger.error('Error closing controller', error: e);
      }
    }
    _controllers.clear();

    // Cancel all timers
    for (final timer in _timers) {
      try {
        if (timer.isActive) {
          timer.cancel();
        }
      } catch (e) {
        _logger.error('Error cancelling timer', error: e);
      }
    }
    _timers.clear();

    // Dispose text editing controllers
    for (final controller in _textControllers) {
      try {
        controller.dispose();
      } catch (e) {
        _logger.error('Error disposing TextEditingController', error: e);
      }
    }
    _textControllers.clear();

    // Dispose animation controllers
    for (final controller in _animationControllers) {
      try {
        controller.dispose();
      } catch (e) {
        _logger.error('Error disposing AnimationController', error: e);
      }
    }
    _animationControllers.clear();

    _logger.debug('✅ All resources disposed for ${runtimeType.toString()}');
    super.dispose();
  }
}

/// Alternative approach using a resource manager class
class ResourceManager {
  final _logger = AppLogger();
  final List<StreamSubscription> _subscriptions = [];
  final List<StreamController> _controllers = [];
  final List<Timer> _timers = [];
  bool _disposed = false;

  /// Add a subscription to be managed
  void addSubscription(StreamSubscription subscription) {
    if (_disposed) {
      _logger.warning(
        '⚠️ Attempted to add subscription to disposed ResourceManager',
      );
      return;
    }
    _subscriptions.add(subscription);
  }

  /// Add a controller to be managed
  void addController(StreamController controller) {
    if (_disposed) {
      _logger.warning(
          '⚠️ Attempted to add controller to disposed ResourceManager');
      return;
    }
    _controllers.add(controller);
  }

  /// Add a timer to be managed
  void addTimer(Timer timer) {
    if (_disposed) {
      _logger.warning('⚠️ Attempted to add timer to disposed ResourceManager');
      return;
    }
    _timers.add(timer);
  }

  /// Dispose all managed resources
  void dispose() {
    if (_disposed) return;

    int disposedCount = 0;

    for (final subscription in _subscriptions) {
      try {
        subscription.cancel();
        disposedCount++;
      } catch (e) {
        _logger.error('Error disposing subscription', error: e);
      }
    }
    _subscriptions.clear();

    for (final controller in _controllers) {
      try {
        if (!controller.isClosed) {
          controller.close();
        }
        disposedCount++;
      } catch (e) {
        _logger.error('Error disposing controller', error: e);
      }
    }
    _controllers.clear();

    for (final timer in _timers) {
      try {
        if (timer.isActive) {
          timer.cancel();
        }
        disposedCount++;
      } catch (e) {
        _logger.error('Error disposing timer', error: e);
      }
    }
    _timers.clear();

    _disposed = true;
    _logger.debug(
        '♻️ ResourceManager disposed ($disposedCount resources cleaned)');
  }

  bool get isDisposed => _disposed;

  int get managedResourceCount =>
      _subscriptions.length + _controllers.length + _timers.length;
}

/// Helper to ensure a value is disposed if it implements Disposable interface
abstract class Disposable {
  void dispose();
}

/// Decorator to track disposable lifecycle
class DisposableTracker<T extends Disposable> {
  final T resource;
  final String name;
  final DateTime createdAt;
  DateTime? disposedAt;

  DisposableTracker({
    required this.resource,
    required this.name,
  }) : createdAt = DateTime.now();

  void dispose() {
    resource.dispose();
    disposedAt = DateTime.now();
  }

  Duration get lifespan => (disposedAt ?? DateTime.now()).difference(createdAt);

  bool get isDisposed => disposedAt != null;

  @override
  String toString() =>
      'Disposable: $name (${lifespan.inMilliseconds}ms)${isDisposed ? ' [DISPOSED]' : ''}';
}
