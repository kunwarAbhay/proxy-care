import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:proxy_care_client/core/error/error_reporter.dart';

/// Mock of [ErrorReporter] for verifying what gets reported.
class MockErrorReporter extends Mock implements ErrorReporter {}

/// Mock of the `logger` package's [Logger].
class MockLogger extends Mock implements Logger {}
