import 'dart:async';

import 'package:flutter/material.dart';

/// TIMER MANAGER - Centralizovano upravljanje timer-ima za sprečavanje memory leak-ova
class TimerManager {
  static final Map<String, Timer> _activeTimers = {};
  static final Map<String, DateTime> _timerStartTimes = {};

  /// Kreiraj imenovani timer
  static Timer createTimer(
    String name,
    Duration duration,
    VoidCallback callback, {
    bool isPeriodic = false,
  }) {
    // Ukloni postojeći timer sa istim imenom
    cancelTimer(name);

    final timer = isPeriodic ? Timer.periodic(duration, (timer) => callback()) : Timer(duration, callback);

    _activeTimers[name] = timer;
    _timerStartTimes[name] = DateTime.now();

    return timer;
  }

  /// Otkaži timer po imenu
  static void cancelTimer(String name) {
    final timer = _activeTimers[name];
    if (timer != null) {
      timer.cancel();
      _activeTimers.remove(name);
      _timerStartTimes.remove(name);
    }
  }

  /// Proveri da li timer postoji
  static bool hasTimer(String name) {
    return _activeTimers.containsKey(name) && _activeTimers[name]!.isActive;
  }

  /// Dobij koliko dugo timer radi
  static Duration? getTimerUptime(String name) {
    final startTime = _timerStartTimes[name];
    if (startTime != null) {
      return DateTime.now().difference(startTime);
    }
    return null;
  }

  /// Otkaži sve timer-e
  static void cancelAllTimers() {
    for (final entry in _activeTimers.entries) {
      entry.value.cancel();
    }

    _activeTimers.clear();
    _timerStartTimes.clear();
  }

  /// Dobij statistike timer-a
  static Map<String, dynamic> getStats() {
    final activeCount = _activeTimers.values.where((t) => t.isActive).length;
    final inactiveCount = _activeTimers.length - activeCount;

    return {
      'total_timers': _activeTimers.length,
      'active_timers': activeCount,
      'inactive_timers': inactiveCount,
      'timer_names': _activeTimers.keys.toList(),
      'uptime_info': _activeTimers.keys.map((name) {
        final uptime = getTimerUptime(name);
        return {
          'name': name,
          'uptime_seconds': uptime?.inSeconds ?? 0,
          'is_active': _activeTimers[name]?.isActive ?? false,
        };
      }).toList(),
    };
  }

  /// Restartuj timer
  static Timer restartTimer(
    String name,
    Duration duration,
    VoidCallback callback, {
    bool isPeriodic = false,
  }) {
    cancelTimer(name);
    return createTimer(name, duration, callback, isPeriodic: isPeriodic);
  }

  /// Kreiraj debounced timer (za input fields, search, etc.)
  static void debounce(
    String name,
    Duration delay,
    VoidCallback callback,
  ) {
    cancelTimer(name);
    createTimer(name, delay, callback);
  }

  /// Cleanup neaktivnih timer-a
  static void cleanupInactiveTimers() {
    final inactiveNames = <String>[];

    for (final entry in _activeTimers.entries) {
      if (!entry.value.isActive) {
        inactiveNames.add(entry.key);
      }
    }

    for (final name in inactiveNames) {
      _activeTimers.remove(name);
      _timerStartTimes.remove(name);
    }

    if (inactiveNames.isNotEmpty) {
      // Logger removed
    }
  }

  /// Detektuj dugotrajne timer-e (potencijalni leak)
  static List<String> detectLongRunningTimers({
    Duration threshold = const Duration(hours: 1),
  }) {
    final longRunning = <String>[];

    for (final entry in _timerStartTimes.entries) {
      final uptime = DateTime.now().difference(entry.value);
      if (uptime > threshold && _activeTimers[entry.key]?.isActive == true) {
        longRunning.add(entry.key);
      }
    }

    if (longRunning.isNotEmpty) {
      // Logger removed
    }

    return longRunning;
  }
}
