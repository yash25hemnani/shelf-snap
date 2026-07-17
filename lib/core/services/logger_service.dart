import 'dart:developer' as developer;

/// Centralized logging so app code calls one API instead of scattering raw
/// `print()` calls. Logs go through `dart:developer.log` instead of `print`
/// because it tags entries with [name] and [level] and isn't truncated by
/// Flutter's console in the way long `print()` output can be.
class LoggerService {
  final String name;

  const LoggerService(this.name);

  /// Verbose play-by-play detail (OCR counts, queries, scores). Use for
  /// anything you'd only want to see while actively debugging a flow.
  void debug(String message) => _log(message, level: 500);

  /// Notable, expected events worth keeping in the log by default.
  void info(String message) => _log(message, level: 800);

  /// Something unexpected happened but execution continued
  /// (e.g. a non-200 response from a backend call).
  void warning(String message) => _log(message, level: 900);

  /// An operation failed outright. Pass [error]/[stackTrace] when available
  /// so they're attached to the log entry instead of stringified by hand.
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(message, level: 1000, error: error, stackTrace: stackTrace);
  }

  void _log(
    String message, {
    required int level,
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: name,
      level: level,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
