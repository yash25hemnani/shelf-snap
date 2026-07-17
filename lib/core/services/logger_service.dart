import 'package:flutter/foundation.dart';

/// Centralized logging so app code calls one API instead of scattering raw
/// `print()` calls. Uses [debugPrint] rather than `dart:developer.log` —
/// the latter only reaches DevTools' logging view, not the plain `flutter
/// run` console, which made every debug call invisible during testing.
class LoggerService {
  final String name;

  const LoggerService(this.name);

  /// Verbose play-by-play detail (OCR counts, queries, scores). Use for
  /// anything you'd only want to see while actively debugging a flow.
  void debug(String message) => _log('DEBUG', message);

  /// Notable, expected events worth keeping in the log by default.
  void info(String message) => _log('INFO', message);

  /// Something unexpected happened but execution continued
  /// (e.g. a non-200 response from a backend call).
  void warning(String message) => _log('WARN', message);

  /// An operation failed outright. Pass [error]/[stackTrace] when available
  /// so they're attached to the log entry instead of stringified by hand.
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log('ERROR', message);
    if (error != null) debugPrint('  caused by: $error');
    if (stackTrace != null) debugPrint('$stackTrace');
  }

  void _log(String level, String message) {
    debugPrint('[$level] $name: $message');
  }
}
