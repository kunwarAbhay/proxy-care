import 'package:logger/logger.dart';

import 'crash_reporter.dart';
import 'error_reporter.dart';

/// [ErrorReporter] that writes errors to the application [Logger] and
/// forwards a privacy-safe [CrashReport] to the [CrashReporter].
///
/// The logger stays the primary sink: crash reporting is added next to it,
/// never instead of it.
final class LoggerErrorReporter implements ErrorReporter {
  /// Creates a reporter that writes to [logger] and [crashReporter].
  const LoggerErrorReporter(
    this._logger, {
    this.crashReporter = const NoopCrashReporter(),
  });

  final Logger _logger;

  /// Where privacy-safe crash reports go.
  final CrashReporter crashReporter;

  /// Contexts of errors that nothing handled.
  static const Set<String> _uncaughtContexts = {'flutter', 'platform', 'zone'};

  @override
  void report(Object error, StackTrace stackTrace, {String? context}) {
    final where = context == null ? '' : ' ($context)';
    _logger.e('Unhandled error$where', error: error, stackTrace: stackTrace);
    crashReporter.record(
      CrashReport.from(
        error,
        stackTrace,
        context: context,
        fatal: _uncaughtContexts.contains(context),
      ),
    );
  }
}
