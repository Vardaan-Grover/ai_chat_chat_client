import 'package:logging/logging.dart';
import 'dart:developer' as developer;

class LoggingService {
  static bool _initialized = false;

  static void init({bool includeTimestamp = true}) {
    if (_initialized) return;

    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      String message =
          includeTimestamp
              ? '${record.time}: ${record.level.name}: ${record.message}'
              : '${record.level.name}: ${record.message}';

      if (record.error != null) {
        message += '\nError: ${record.error}';
      }
      if (record.stackTrace != null) {
        message += '\nStack Trace: ${record.stackTrace}';
      }

      developer.log(
        message,
        name: record.loggerName,
        level: record.level.value,
        error: record.error,
        stackTrace: record.stackTrace,
      );

      if (record.level >= Level.SEVERE) {
        // TODO: Send logs to external service like Firebase Crashlytics
      }
    });

    _initialized = true;
  }

  static Logger getLogger(String name) => Logger(name);
}
