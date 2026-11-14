import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/error/failure.dart';
import 'package:proxy_care_client/shared/models/result.dart';

/// Minimal concrete failure for tests.
final class _TestFailure extends Failure {
  const _TestFailure(super.message);
}

void main() {
  const failure = _TestFailure('offline');

  test('Result.ok holds a value', () {
    const Result<int> result = Result.ok(42);

    expect(result, isA<Ok<int>>());
    expect(result.isOk, isTrue);
    expect(result.valueOrNull, 42);
  });

  test('Result.err holds a failure', () {
    const Result<int> result = Result.err(failure);

    expect(result, isA<Err<int>>());
    expect(result.isOk, isFalse);
    expect(result.valueOrNull, isNull);
  });

  test('can be handled exhaustively with a switch', () {
    String describe(Result<int> result) => switch (result) {
      Ok(:final value) => 'value $value',
      Err(:final failure) => 'failed: ${failure.message}',
    };

    expect(describe(const Result.ok(1)), 'value 1');
    expect(describe(const Result.err(failure)), 'failed: offline');
  });

  test('compares by value', () {
    expect(const Ok(1), const Ok(1));
    expect(const Ok(1).hashCode, const Ok(1).hashCode);
    expect(const Ok(1), isNot(const Ok(2)));
    expect(const Err<int>(failure), const Err<int>(failure));
  });

  test('Failure describes itself with its type and message', () {
    expect(failure.toString(), '_TestFailure: offline');
  });
}
