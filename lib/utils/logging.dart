import 'package:flutter/foundation.dart';

/// Central logger used across the app.
/// Use `dlog(...)` for logging.
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

// Remove per-file aliases once migration completes.
