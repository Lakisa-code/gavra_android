import 'package:flutter/foundation.dart';

/// Central logger used across the app.
/// Use `dlog(...)` for simple debug prints or obtain a per-file logger
/// with `final _logger = getLogger('MyFile');` and call `_logger.d(...)` etc.
///
/// Debug mode je omogućen u:
/// - Debug builds (kDebugMode)
/// - Eksplicitno sa --dart-define=DEBUG=true
bool get _isDebugEnabled => kDebugMode || const bool.fromEnvironment('DEBUG');

void dlog(Object? message) {
  if (_isDebugEnabled) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    debugPrint('[$timestamp] $message');
  }
}

/// Error logging - uvek omogućen
void elog(Object? message, [Object? error, StackTrace? stackTrace]) {
  final timestamp = DateTime.now().toString().substring(11, 19);
  debugPrint('❌ [$timestamp] $message');
  if (error != null) debugPrint('   Error: $error');
  if (stackTrace != null) debugPrint('   Stack: $stackTrace');
}

/// Warning logging - uvek omogućen
void wlog(Object? message) {
  final timestamp = DateTime.now().toString().substring(11, 19);
  debugPrint('⚠️ [$timestamp] $message');
}

/// Simple logger adapter returned by `getLogger(name)`.
class SimpleLogger {
  SimpleLogger(this.name);
  final String name;

  void d(Object? message) => dlog('[$name] $message');

  void i(Object? message) => dlog('ℹ️ [$name] $message');

  void w(Object? message) => wlog('[$name] $message');

  void e(Object? message, [Object? error, StackTrace? stackTrace]) =>
      elog('[$name] $message', error, stackTrace);
}

/// Returns a lightweight logger instance for a file or class.
SimpleLogger getLogger(String name) => SimpleLogger(name);

// Remove per-file aliases once migration completes.
