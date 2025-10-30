import 'dart:developer' as developer;

/// Simple logging service to replace print statements
class LoggerService {
  static const String _tag = 'FixoApp';

  /// Log debug information
  static void debug(String message, [String? tag]) {
    developer.log(
      message,
      name: tag ?? _tag,
      level: 500, // Debug level
    );
  }

  /// Log informational messages
  static void info(String message, [String? tag]) {
    developer.log(
      message,
      name: tag ?? _tag,
      level: 800, // Info level
    );
  }

  /// Log warnings
  static void warning(String message, [String? tag]) {
    developer.log(
      message,
      name: tag ?? _tag,
      level: 900, // Warning level
    );
  }

  /// Log errors
  static void error(String message, [String? tag, Object? error]) {
    developer.log(
      message,
      name: tag ?? _tag,
      level: 1000, // Error level
      error: error,
    );
  }

  /// Log success messages
  static void success(String message, [String? tag]) {
    developer.log(
      '✅ $message',
      name: tag ?? _tag,
      level: 800, // Info level
    );
  }
}