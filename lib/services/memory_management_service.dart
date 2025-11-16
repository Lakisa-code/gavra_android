import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/widgets.dart';

/// 🚀 MEMORY MANAGEMENT SERVICE
/// Automatski upravlja memorijom aplikacije i spre'ava memory leak-ove
class MemoryManagementService {
  factory MemoryManagementService() => _instance;
  MemoryManagementService._internal();
  static final MemoryManagementService _instance =
      MemoryManagementService._internal();

  // 📊 MEMORY TRACKING
  final Map<String, DateTime> _streamControllers = {};
  final Map<String, DateTime> _timers = {};
  final Map<String, DateTime> _subscriptions = {};
  final Queue<String> _memoryWarnings = Queue<String>();

  // ⚡ CONFIGURATION
  static const int _maxWarnings = 50;
  static const Duration _cleanupInterval = Duration(minutes: 5);
  static const Duration _resourceTimeout = Duration(minutes: 30);

  Timer? _cleanupTimer;

  /// Initialize memory management
  void initialize() {
    _startPeriodicCleanup();
  }

  /// 🔄 Register StreamController for monitoring
  void registerStreamController(
      String id, StreamController<dynamic> controller) {
    _streamControllers[id] = DateTime.now();

    // Auto-dispose after timeout
    Timer(_resourceTimeout, () {
      if (_streamControllers.containsKey(id) && !controller.isClosed) {
        _addWarning(
            'StreamController $id not disposed after ${_resourceTimeout.inMinutes} minutes');
        try {
          controller.close();
        } catch (e) {
          // Already closed or error
        }
        _streamControllers.remove(id);
      }
    });
  }

  /// 🔄 Register Timer for monitoring
  void registerTimer(String id, Timer timer) {
    _timers[id] = DateTime.now();

    // Auto-cancel after timeout if still active
    Timer(_resourceTimeout, () {
      if (_timers.containsKey(id) && timer.isActive) {
        _addWarning(
            'Timer $id not cancelled after ${_resourceTimeout.inMinutes} minutes');
        try {
          timer.cancel();
        } catch (e) {
          // Already cancelled or error
        }
        _timers.remove(id);
      }
    });
  }

  /// 🔄 Register Subscription for monitoring
  void registerSubscription(
      String id, StreamSubscription<dynamic> subscription) {
    _subscriptions[id] = DateTime.now();

    // Auto-cancel after timeout
    Timer(_resourceTimeout, () {
      if (_subscriptions.containsKey(id)) {
        _addWarning(
            'Subscription $id not cancelled after ${_resourceTimeout.inMinutes} minutes');
        try {
          subscription.cancel();
        } catch (e) {
          // Already cancelled or error
        }
        _subscriptions.remove(id);
      }
    });
  }

  /// ✅ Unregister resources when properly disposed
  void unregisterStreamController(String id) {
    _streamControllers.remove(id);
  }

  void unregisterTimer(String id) {
    _timers.remove(id);
  }

  void unregisterSubscription(String id) {
    _subscriptions.remove(id);
  }

  /// 🧹 Start periodic cleanup
  void _startPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) {
      _performCleanup();
    });
  }

  /// 🧹 Perform automatic cleanup
  void _performCleanup() {
    final now = DateTime.now();
    final cutoff = now.subtract(_resourceTimeout);

    // Clean old StreamControllers
    _streamControllers.removeWhere((id, time) {
      if (time.isBefore(cutoff)) {
        _addWarning('Auto-cleaned StreamController: $id');
        return true;
      }
      return false;
    });

    // Clean old Timers
    _timers.removeWhere((id, time) {
      if (time.isBefore(cutoff)) {
        _addWarning('Auto-cleaned Timer: $id');
        return true;
      }
      return false;
    });

    // Clean old Subscriptions
    _subscriptions.removeWhere((id, time) {
      if (time.isBefore(cutoff)) {
        _addWarning('Auto-cleaned Subscription: $id');
        return true;
      }
      return false;
    });

    // Force garbage collection if too many resources
    final totalResources =
        _streamControllers.length + _timers.length + _subscriptions.length;
    if (totalResources > 100) {
      _forceGarbageCollection();
    }
  }

  /// 🗑️ Force garbage collection
  void _forceGarbageCollection() {
    try {
      // Suggest garbage collection
      // Note: Dart doesn't have explicit GC control, but we can encourage it
      _addWarning(
          'Suggesting garbage collection - ${getTotalResources()} active resources');
    } catch (e) {
      _addWarning('Error during garbage collection suggestion: $e');
    }
  }

  /// ⚠️ Add memory warning
  void _addWarning(String warning) {
    _memoryWarnings.add('${DateTime.now().toIso8601String()}: $warning');

    // Keep only recent warnings
    while (_memoryWarnings.length > _maxWarnings) {
      _memoryWarnings.removeFirst();
    }
  }

  /// 📊 Get memory statistics
  Map<String, dynamic> getMemoryStats() {
    final processInfo = ProcessInfo.currentRss;

    return {
      'active_stream_controllers': _streamControllers.length,
      'active_timers': _timers.length,
      'active_subscriptions': _subscriptions.length,
      'total_resources': getTotalResources(),
      'memory_warnings_count': _memoryWarnings.length,
      'current_rss_bytes': processInfo,
      'current_rss_mb': (processInfo / (1024 * 1024)).toStringAsFixed(2),
      'cleanup_interval_minutes': _cleanupInterval.inMinutes,
      'resource_timeout_minutes': _resourceTimeout.inMinutes,
    };
  }

  /// 📊 Get recent memory warnings
  List<String> getMemoryWarnings() {
    return List.from(_memoryWarnings);
  }

  /// 📊 Get total number of tracked resources
  int getTotalResources() {
    return _streamControllers.length + _timers.length + _subscriptions.length;
  }

  /// 🚨 Check if memory usage is critical
  bool isMemoryUsageCritical() {
    final totalResources = getTotalResources();
    final warningCount = _memoryWarnings.length;

    return totalResources > 200 || warningCount > 30;
  }

  /// 🧹 Manual cleanup of all resources
  void forceCleanupAll() {
    _streamControllers.clear();
    _timers.clear();
    _subscriptions.clear();
    _memoryWarnings.clear();

    _forceGarbageCollection();
  }

  /// 🚫 Dispose memory management service
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    forceCleanupAll();
  }
}

/// 🚀 MEMORY AWARE MIXIN
/// Dodaj ovaj mixin u State klase za automatsko praćenje resursa
mixin MemoryAwareMixin<T extends StatefulWidget> on State<T> {
  final List<String> _managedResources = [];

  /// Create and register a StreamController
  StreamController<R> createManagedStreamController<R>([String? id]) {
    final controller = StreamController<R>();
    final resourceId = id ?? '${T.toString()}_${controller.hashCode}';

    MemoryManagementService().registerStreamController(resourceId, controller);
    _managedResources.add(resourceId);

    return controller;
  }

  /// Create and register a Timer
  Timer createManagedTimer(Duration duration, void Function() callback,
      [String? id]) {
    final timer = Timer(duration, callback);
    final resourceId = id ?? '${T.toString()}_${timer.hashCode}';

    MemoryManagementService().registerTimer(resourceId, timer);
    _managedResources.add(resourceId);

    return timer;
  }

  /// Create and register a periodic Timer
  Timer createManagedPeriodicTimer(
      Duration duration, void Function(Timer) callback,
      [String? id]) {
    final timer = Timer.periodic(duration, callback);
    final resourceId = id ?? '${T.toString()}_${timer.hashCode}';

    MemoryManagementService().registerTimer(resourceId, timer);
    _managedResources.add(resourceId);

    return timer;
  }

  /// Register an existing subscription
  void registerManagedSubscription(StreamSubscription<dynamic> subscription,
      [String? id]) {
    final resourceId = id ?? '${T.toString()}_${subscription.hashCode}';

    MemoryManagementService().registerSubscription(resourceId, subscription);
    _managedResources.add(resourceId);
  }

  @override
  void dispose() {
    // Unregister all managed resources
    for (final resourceId in _managedResources) {
      MemoryManagementService().unregisterStreamController(resourceId);
      MemoryManagementService().unregisterTimer(resourceId);
      MemoryManagementService().unregisterSubscription(resourceId);
    }
    _managedResources.clear();
    super.dispose();
  }
}

/// 🚀 RESOURCE TRACKER
/// Simple wrapper za praćenje resursa van widget-a
class ResourceTracker {
  static final Map<String, DateTime> _trackedResources = {};

  static void track(String id, dynamic resource) {
    _trackedResources[id] = DateTime.now();

    if (resource is StreamController) {
      MemoryManagementService().registerStreamController(id, resource);
    } else if (resource is Timer) {
      MemoryManagementService().registerTimer(id, resource);
    } else if (resource is StreamSubscription) {
      MemoryManagementService().registerSubscription(id, resource);
    }
  }

  static void untrack(String id) {
    _trackedResources.remove(id);
    MemoryManagementService().unregisterStreamController(id);
    MemoryManagementService().unregisterTimer(id);
    MemoryManagementService().unregisterSubscription(id);
  }

  static Map<String, DateTime> getTrackedResources() {
    return Map.from(_trackedResources);
  }
}
