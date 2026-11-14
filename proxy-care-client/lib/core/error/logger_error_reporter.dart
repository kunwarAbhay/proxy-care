import 'package:logger/logger.dart';

import 'error_reporter.dart';

/// [ErrorReporter] that writes errors to the application [Logger].
final class LoggerErrorReporter implements ErrorReporter {
  /// Creates a reporter that writes to [logger].
  const LoggerErrorReporter(this._logger);

  final Logger _logger;

  @override
  void report(Object error, StackTrace stackTrace, {String? context}) {
    final where = context == null ? '' : ' ($context)';
    _logger.e('Unhandled error$where', error: error, stackTrace: stackTrace);
  }
}
