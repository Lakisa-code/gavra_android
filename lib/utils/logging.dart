import 'package:flutter/foundation.dart';

/// Central debug logger used across the app.
/// Use `dlog(...)` for debug-only prints.
void dlog(Object? message) {
  if (kDebugMode) debugPrint(message?.toString());
}

// Remove per-file aliases once migration completes.
