import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// Simple logger service that writes logs to a file for debugging
/// Logs are kept for the last 7 days
class LoggerService {
  static const String _logFileName = 'stuffrite_debug.log';
  static const int _maxLogDays = 7;
  static const int _maxLogLines = 1000;

  static File? _logFile;
  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  /// Initialize the logger
  static Future<void> init() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/$_logFileName');

      // Clean old logs on init
      await _cleanOldLogs();

      log('INFO', 'Logger initialized');
    } catch (e) {
      debugPrint('Failed to initialize logger: $e');
    }
  }

  /// Log a message with a level
  static Future<void> log(String level, String message) async {
    final timestamp = _dateFormat.format(DateTime.now());
    final logEntry = '[$timestamp] [$level] $message\n';

    // Always print to console in debug mode
    if (kDebugMode) {
      debugPrint(logEntry.trim());
    }

    // Write to file
    try {
      if (_logFile == null) {
        await init();
      }

      await _logFile?.writeAsString(
        logEntry,
        mode: FileMode.append,
      );

      // Trim log file if it gets too large
      await _trimLogFile();
    } catch (e) {
      debugPrint('Failed to write log: $e');
    }
  }

  /// Log an info message
  static Future<void> info(String message) async {
    await log('INFO', message);
  }

  /// Log a warning message
  static Future<void> warning(String message) async {
    await log('WARN', message);
  }

  /// Log an error message
  static Future<void> error(String message, [Object? error, StackTrace? stackTrace]) async {
    final errorMessage = error != null ? '$message: $error' : message;
    await log('ERROR', errorMessage);

    if (stackTrace != null) {
      await log('STACK', stackTrace.toString());
    }
  }

  /// Get the log file path
  static Future<String?> getLogFilePath() async {
    if (_logFile == null) {
      await init();
    }
    return _logFile?.path;
  }

  /// Get the log file for sharing/export
  static Future<File?> getLogFile() async {
    if (_logFile == null) {
      await init();
    }

    if (_logFile != null && await _logFile!.exists()) {
      return _logFile;
    }
    return null;
  }

  /// Get recent log contents as string
  static Future<String> getRecentLogs({int lines = 100}) async {
    try {
      if (_logFile == null) {
        await init();
      }

      if (_logFile != null && await _logFile!.exists()) {
        final allLines = await _logFile!.readAsLines();
        final recentLines = allLines.length > lines
            ? allLines.sublist(allLines.length - lines)
            : allLines;
        return recentLines.join('\n');
      }
    } catch (e) {
      return 'Error reading logs: $e';
    }

    return 'No logs available';
  }

  /// Clear all logs
  static Future<void> clearLogs() async {
    try {
      if (_logFile == null) {
        await init();
      }

      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.delete();
        await init();
      }
    } catch (e) {
      debugPrint('Failed to clear logs: $e');
    }
  }

  /// Trim log file to max lines
  static Future<void> _trimLogFile() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        final lines = await _logFile!.readAsLines();

        if (lines.length > _maxLogLines) {
          // Keep only the last _maxLogLines
          final trimmedLines = lines.sublist(lines.length - _maxLogLines);
          await _logFile!.writeAsString('${trimmedLines.join('\n')}\n');
        }
      }
    } catch (e) {
      debugPrint('Failed to trim log file: $e');
    }
  }

  /// Clean logs older than _maxLogDays
  static Future<void> _cleanOldLogs() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        final lastModified = await _logFile!.lastModified();
        final daysSinceModified = DateTime.now().difference(lastModified).inDays;

        if (daysSinceModified > _maxLogDays) {
          await _logFile!.delete();
          debugPrint('Cleaned old log file ($daysSinceModified days old)');
        }
      }
    } catch (e) {
      debugPrint('Failed to clean old logs: $e');
    }
  }
}
