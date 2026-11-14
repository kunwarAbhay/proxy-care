import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:proxy_care_client/core/di/core_providers.dart';
import 'package:proxy_care_client/core/error/logger_error_reporter.dart';

import '../../fixtures/env_fixtures.dart';
import '../../helpers/provider_container.dart';
import '../../mocks/core_mocks.dart';

void main() {
  test('envProvider has no default and must be overridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(() => container.read(envProvider), throwsA(anything));
  });

  test('createAppContainer provides the given env', () {
    final env = testEnv(appName: 'Injected');
    final container = createTestContainer(env: env);

    expect(container.read(envProvider), same(env));
  });

  test('loggerProvider builds one logger for the container', () {
    final container = createTestContainer();

    final first = container.read(loggerProvider);
    final second = container.read(loggerProvider);

    expect(first, isA<Logger>());
    expect(second, same(first));
  });

  test('errorReporterProvider defaults to the logger-backed reporter', () {
    final container = createTestContainer();

    expect(container.read(errorReporterProvider), isA<LoggerErrorReporter>());
  });

  test('infrastructure can be replaced with an override', () {
    final reporter = MockErrorReporter();
    final container = createTestContainer(
      overrides: [errorReporterProvider.overrideWithValue(reporter)],
    );

    expect(container.read(errorReporterProvider), same(reporter));
  });

  test('the error reporter writes to the injected logger', () {
    final logger = MockLogger();
    final container = createTestContainer(
      overrides: [loggerProvider.overrideWithValue(logger)],
    );
    final reporter = container.read(errorReporterProvider);
    final error = StateError('boom');

    reporter.report(error, StackTrace.empty, context: 'test');

    verify(
      () => logger.e(
        'Unhandled error (test)',
        error: error,
        stackTrace: StackTrace.empty,
      ),
    ).called(1);
  });
}
