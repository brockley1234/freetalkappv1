import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_logger.dart';
import 'auto_dispose_mixin.dart';

/// Base class for efficient state management with Provider
/// Provides automatic disposal, selective notifiers, and change tracking
abstract class EfficientProvider extends ChangeNotifier {
  final _logger = AppLogger();
  final _resourceManager = ResourceManager();
  bool _disposed = false;
  int _changeCount = 0;
  DateTime _lastChangeTime = DateTime.now();

  @override
  void notifyListeners() {
    if (_disposed) {
      _logger.warning(
        '⚠️ Attempted to notify listeners on disposed ${runtimeType.toString()}',
      );
      return;
    }
    _changeCount++;
    _lastChangeTime = DateTime.now();
    super.notifyListeners();
  }

  /// Selective notification - only notify listeners if condition is true
  void notifyListenersIf(bool condition) {
    if (condition) {
      notifyListeners();
    }
  }

  /// Batch multiple updates into a single notification
  Future<void> batchUpdates(Future<void> Function() updates) async {
    try {
      await updates();
      notifyListeners(); // Single notification for all updates
    } catch (e) {
      _logger.error('Error during batched updates', error: e);
    }
  }

  /// Get provider statistics
  Map<String, dynamic> getStats() {
    return {
      'type': runtimeType.toString(),
      'changeCount': _changeCount,
      'lastChangeTime': _lastChangeTime.toIso8601String(),
      'isDisposed': _disposed,
      'managedResources': _resourceManager.managedResourceCount,
    };
  }

  /// Print provider statistics
  void printStats() {
    final stats = getStats();
    _logger.debug(
      '📊 Provider Stats for ${stats['type']}: '
      '${stats['changeCount']} changes, '
      '${stats['managedResources']} resources, '
      'disposed: ${stats['isDisposed']}',
    );
  }

  @override
  void dispose() {
    if (_disposed) {
      _logger.warning('⚠️ ${runtimeType.toString()} disposed multiple times');
      return;
    }

    _resourceManager.dispose();
    _disposed = true;
    _logger.debug('♻️ ${runtimeType.toString()} disposed');
    super.dispose();
  }

  bool get isDisposed => _disposed;
}

/// Provider for list-based data with selective updates
abstract class ListProvider<T> extends EfficientProvider {
  List<T> _items = [];

  List<T> get items => List.unmodifiable(_items);

  int get itemCount => _items.length;

  bool get isEmpty => _items.isEmpty;

  bool get isNotEmpty => _items.isNotEmpty;

  /// Get item at index with bounds checking
  T? getItem(int index) {
    if (index >= 0 && index < _items.length) {
      return _items[index];
    }
    return null;
  }

  /// Set items and notify only if content changed
  void setItems(List<T> newItems) {
    if (_itemsEqual(_items, newItems)) {
      _logger.debug('⏭️ Skipping notification - items unchanged');
      return;
    }
    _items = newItems;
    notifyListeners();
  }

  /// Add single item
  void addItem(T item) {
    _items.add(item);
    notifyListeners();
  }

  /// Add multiple items
  void addItems(List<T> items) {
    _items.addAll(items);
    notifyListeners();
  }

  /// Remove item at index
  void removeItemAt(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  /// Clear all items
  void clearItems() {
    if (_items.isNotEmpty) {
      _items.clear();
      notifyListeners();
    }
  }

  /// Check if items are equal
  bool _itemsEqual(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Provider for map-based data with selective updates
abstract class MapProvider<K, V> extends EfficientProvider {
  final Map<K, V> _data = {};

  Map<K, V> get data => Map.unmodifiable(_data);

  int get dataCount => _data.length;

  bool get isEmpty => _data.isEmpty;

  bool get isNotEmpty => _data.isNotEmpty;

  /// Get value by key
  V? getValue(K key) => _data[key];

  /// Set single value
  void setValue(K key, V value) {
    final changed = _data[key] != value;
    _data[key] = value;
    if (changed) {
      notifyListeners();
    }
  }

  /// Set multiple values at once
  void setValues(Map<K, V> values) {
    bool changed = false;
    for (final entry in values.entries) {
      if (_data[entry.key] != entry.value) {
        changed = true;
        _data[entry.key] = entry.value;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Remove key
  void removeKey(K key) {
    if (_data.containsKey(key)) {
      _data.remove(key);
      notifyListeners();
    }
  }

  /// Clear all data
  void clearData() {
    if (_data.isNotEmpty) {
      _data.clear();
      notifyListeners();
    }
  }
}

/// Provider with automatic value tracking and selective notification
abstract class ValueProvider<T> extends EfficientProvider {
  late T _value;

  T get value => _value;

  /// Set value and notify only if changed
  void setValue(T newValue) {
    if (_value == newValue) {
      _logger.debug('⏭️ Skipping notification - value unchanged');
      return;
    }
    _value = newValue;
    notifyListeners();
  }

  /// Update value with a callback
  void updateValue(T Function(T) updater) {
    final newValue = updater(_value);
    setValue(newValue);
  }

  /// Reset to initial value
  void resetValue(T initialValue) {
    _value = initialValue;
    notifyListeners();
  }
}

/// Provider for loading states with error handling
class LoadingProvider extends ValueProvider<LoadingState> {
  String? _errorMessage;

  LoadingProvider() {
    _value = LoadingState.idle;
  }

  LoadingState get state => _value;

  String? get errorMessage => _errorMessage;

  bool get isLoading => _value == LoadingState.loading;

  bool get isIdle => _value == LoadingState.idle;

  bool get isError => _value == LoadingState.error;

  bool get isSuccess => _value == LoadingState.success;

  /// Start loading
  void startLoading() {
    _value = LoadingState.loading;
    _errorMessage = null;
    notifyListeners();
  }

  /// Mark as success
  void setSuccess() {
    _value = LoadingState.success;
    _errorMessage = null;
    notifyListeners();
  }

  /// Mark as error
  void setError(String message) {
    _value = LoadingState.error;
    _errorMessage = message;
    _logger.error('🔴 LoadingProvider error: $message');
    notifyListeners();
  }

  /// Reset to idle
  void reset() {
    _value = LoadingState.idle;
    _errorMessage = null;
    notifyListeners();
  }

  /// Execute async operation with automatic state management
  Future<T> executeAsync<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    try {
      startLoading();
      final result = await operation();
      setSuccess();
      _logger.info('✅ $operationName completed successfully');
      return result;
    } catch (e) {
      setError('$operationName failed: $e');
      rethrow;
    }
  }
}

/// Loading state enum
enum LoadingState {
  idle,
  loading,
  success,
  error,
}

/// Provider that combines multiple child providers
class CompositeProvider extends EfficientProvider {
  final Map<String, ChangeNotifier> _children = {};

  /// Register a child provider
  void registerChild(String name, ChangeNotifier provider) {
    _children[name] = provider;

    // Listen to child changes and propagate them
    provider.addListener(() {
      notifyListeners();
    });
  }

  /// Get child provider
  ChangeNotifier? getChild(String name) => _children[name];

  /// Unregister child
  void unregisterChild(String name) {
    _children.remove(name);
  }

  int get childCount => _children.length;

  @override
  void dispose() {
    // Dispose all children
    for (final child in _children.values) {
      if (child is EfficientProvider) {
        child.dispose();
      }
    }
    _children.clear();
    super.dispose();
  }
}

/// Usage example in a Consumer widget
class SelectiveConsumer<T extends EfficientProvider> extends StatelessWidget {
  final Widget Function(BuildContext, T, Widget?) builder;
  final Widget? child;
  final Object? Function(T)? selector;

  const SelectiveConsumer({
    super.key,
    required this.builder,
    this.child,
    this.selector,
  });

  @override
  Widget build(BuildContext context) {
    if (selector != null) {
      // Only rebuild when selected value changes
      return Selector<T, Object?>(
        selector: (context, provider) => selector!(provider),
        builder: (context, value, child) =>
            builder(context, context.read<T>(), child),
        child: child,
      );
    } else {
      // Rebuild on any provider change
      return Consumer<T>(
        builder: builder,
        child: child,
      );
    }
  }
}
