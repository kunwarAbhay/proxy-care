import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../config/env.dart';
import '../error/error_reporter.dart';
import '../error/logger_error_reporter.dart';

// Infrastructure providers shared by every feature.
//
// Conventions (see ARCHITECTURE.md, "Dependency injection"):
// * Providers are top-level `final` variables named `<thing>Provider`.
// * A provider's type is the abstraction callers need (for example
//   `ErrorReporter`), not the implementation class.
// * Resources that hold handles are closed with `ref.onDispose`.
// * Feature providers live in `features/<feature>/<feature>_providers.dart`.

/// The validated build configuration.
///
/// Has no default value: `createAppContainer` overrides it with the `Env`
/// read at start-up, and tests override it with a fixture. Reading it
/// without an override is a wiring bug.
final envProvider = Provider<Env>(
  (ref) => throw UnimplementedError(
    'envProvider has no default; override it (see createAppContainer).',
  ),
);

/// Application logger. Writes nothing when `ENABLE_LOGGING` is false.
///
/// Lives for the whole app and is closed when the container is disposed.
final loggerProvider = Provider<Logger>((ref) {
  final env = ref.watch(envProvider);
  final logger = Logger(
    filter: ProductionFilter(),
    level: env.enableLogging ? Level.debug : Level.off,
  );
  ref.onDispose(logger.close);
  return logger;
});

/// Destination for errors that nothing else handled.
///
/// Override it to send errors to a crash-reporting service.
final errorReporterProvider = Provider<ErrorReporter>(
  (ref) => LoggerErrorReporter(ref.watch(loggerProvider)),
);
