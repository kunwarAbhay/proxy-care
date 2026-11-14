import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/error/app_exception.dart';
import 'package:proxy_care_client/core/network/api_client.dart';
import 'package:proxy_care_client/core/network/interceptors/log_redactor.dart';
import 'package:proxy_care_client/core/network/interceptors/logging_interceptor.dart';
import 'package:proxy_care_client/core/network/request_options.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/network_harness.dart';

FakeResponder _ok() => respondJson(successEnvelope(null));

FakeResponder _status(int status) =>
    respondJson(errorEnvelope('INTERNAL_ERROR'), status: status);

void main() {
  group('AuthInterceptor', () {
    test('attaches the bearer token', () async {
      final harness = NetworkHarness(
        session: FakeSession(token: 'access-1'),
        responses: [_ok()],
      );

      await harness.client.get('/v1/me', decode: ignoreBody);

      expect(
        harness.adapter.requests.single.headers['Authorization'],
        'Bearer access-1',
      );
    });

    test('sends no header when signed out', () async {
      final harness = NetworkHarness(responses: [_ok()]);

      await harness.client.get('/v1/public', decode: ignoreBody);

      expect(
        harness.adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('skipAuth sends no token, even a caller-supplied one', () async {
      final harness = NetworkHarness(
        session: FakeSession(token: 'access-1'),
        responses: [_ok()],
      );

      await harness.client.post(
        '/v1/auth/refresh',
        decode: ignoreBody,
        options: const ApiRequestOptions(
          skipAuth: true,
          headers: {'Authorization': 'Bearer leaked'},
        ),
      );

      expect(
        harness.adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('a 401 refreshes once and repeats with the new token', () async {
      final session = FakeSession(token: 'old', refreshedToken: 'new');
      final harness = NetworkHarness(
        session: session,
        responses: [_status(401), _ok()],
      );

      await harness.client.get('/v1/me', decode: ignoreBody);

      expect(session.refreshes, ['old']);
      final requests = harness.adapter.requests;
      expect(requests, hasLength(2));
      expect(requests.last.headers['Authorization'], 'Bearer new');
      expect(
        requests.last.headers['X-Correlation-Id'],
        requests.first.headers['X-Correlation-Id'],
      );
    });

    test('a failed refresh surfaces as UnauthorizedException', () async {
      final session = FakeSession(token: 'old');
      final harness = NetworkHarness(
        session: session,
        responses: [_status(401)],
      );

      await expectLater(
        harness.client.get('/v1/me', decode: ignoreBody),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(session.refreshes, hasLength(1));
    });

    test('a second 401 after refreshing is not refreshed again', () async {
      final session = FakeSession(token: 'old', refreshedToken: 'new');
      final harness = NetworkHarness(
        session: session,
        responses: [_status(401), _status(401)],
      );

      await expectLater(
        harness.client.get('/v1/me', decode: ignoreBody),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(session.refreshes, hasLength(1));
      expect(harness.adapter.requests, hasLength(2));
    });

    test('a 401 on a skipAuth request (the refresh call) is not '
        'intercepted', () async {
      final session = FakeSession(token: 'old', refreshedToken: 'new');
      final harness = NetworkHarness(
        session: session,
        responses: [_status(401)],
      );

      await expectLater(
        harness.client.post(
          '/v1/auth/refresh',
          decode: ignoreBody,
          options: const ApiRequestOptions(skipAuth: true),
        ),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(session.refreshes, isEmpty);
    });
  });

  group('RetryInterceptor', () {
    test('retries a GET up to three times with exponential backoff', () async {
      final harness = NetworkHarness(
        responses: [
          for (var i = 0; i < 4; i++) failWith(DioExceptionType.connectionError),
        ],
      );

      await expectLater(
        harness.client.get('/v1/visits', decode: ignoreBody),
        throwsA(isA<NetworkException>()),
      );

      expect(harness.adapter.requests, hasLength(4), reason: '1 + 3 retries');
      expect(harness.delays, const [
        Duration(milliseconds: 500),
        Duration(seconds: 1),
        Duration(seconds: 2),
      ]);
    });

    for (final status in [502, 503, 504]) {
      test('retries a GET on $status and stops once it succeeds', () async {
        final harness = NetworkHarness(
          responses: [_status(status), _status(status), _ok()],
        );

        await harness.client.get('/v1/visits', decode: ignoreBody);

        expect(harness.adapter.requests, hasLength(3));
      });
    }

    test('retries a connection timeout', () async {
      final harness = NetworkHarness(
        responses: [failWith(DioExceptionType.connectionTimeout), _ok()],
      );

      await harness.client.get('/v1/visits', decode: ignoreBody);

      expect(harness.adapter.requests, hasLength(2));
    });

    for (final status in [400, 401, 404, 409, 500]) {
      test('does not retry HTTP $status', () async {
        final harness = NetworkHarness(responses: [_status(status)]);

        await expectLater(
          harness.client.get('/v1/visits', decode: ignoreBody),
          throwsA(isA<AppException>()),
        );
        expect(harness.adapter.requests, hasLength(1));
      });
    }

    test('does not retry a receive timeout', () async {
      final harness = NetworkHarness(
        responses: [failWith(DioExceptionType.receiveTimeout)],
      );

      await expectLater(
        harness.client.get('/v1/visits', decode: ignoreBody),
        throwsA(isA<TimeoutException>()),
      );
      expect(harness.adapter.requests, hasLength(1));
    });

    for (final method in ['POST', 'PUT', 'PATCH', 'DELETE']) {
      test('does not retry $method by default', () async {
        final harness = NetworkHarness(responses: [_status(503)]);

        final call = switch (method) {
          'POST' => harness.client.post('/v1/x', decode: ignoreBody),
          'PUT' => harness.client.put('/v1/x', decode: ignoreBody),
          'PATCH' => harness.client.patch('/v1/x', decode: ignoreBody),
          _ => harness.client.delete('/v1/x', decode: ignoreBody),
        };
        await expectLater(call, throwsA(isA<ServerException>()));
        expect(harness.adapter.requests, hasLength(1));
      });
    }

    test('retries a write when the request opts in', () async {
      final harness = NetworkHarness(responses: [_status(503), _ok()]);

      await harness.client.post(
        '/v1/payments',
        decode: ignoreBody,
        options: const ApiRequestOptions(
          retry: RetryPolicy.always,
          idempotencyKey: 'key-1',
        ),
      );

      final requests = harness.adapter.requests;
      expect(requests, hasLength(2));
      expect(requests.last.headers['Idempotency-Key'], 'key-1');
    });

    test('respects a request that disables retries', () async {
      final harness = NetworkHarness(responses: [_status(503)]);

      await expectLater(
        harness.client.get(
          '/v1/visits',
          decode: ignoreBody,
          options: const ApiRequestOptions(retry: RetryPolicy.never),
        ),
        throwsA(isA<ServerException>()),
      );
      expect(harness.adapter.requests, hasLength(1));
    });

    test('respects a request-specific retry limit', () async {
      final harness = NetworkHarness(
        responses: [_status(503), _status(503), _status(503)],
      );

      await expectLater(
        harness.client.get(
          '/v1/visits',
          decode: ignoreBody,
          options: const ApiRequestOptions(retry: RetryPolicy(maxRetries: 1)),
        ),
        throwsA(isA<ServerException>()),
      );
      expect(harness.adapter.requests, hasLength(2));
    });

    test('never retries a cancelled request', () async {
      final harness = NetworkHarness(
        responses: [failWith(DioExceptionType.cancel)],
      );

      await expectLater(
        harness.client.get('/v1/visits', decode: ignoreBody),
        throwsA(isA<CancelledException>()),
      );
      expect(harness.adapter.requests, hasLength(1));
      expect(harness.delays, isEmpty);
    });

    test('keeps one correlation ID across retries and logs each try', () async {
      final harness = NetworkHarness(
        responses: [_status(503), _status(502), _ok()],
      );

      await harness.client.get('/v1/visits', decode: ignoreBody);

      final ids = harness.adapter.requests
          .map((r) => r.headers['X-Correlation-Id'])
          .toSet();
      expect(ids, hasLength(1));
      expect(harness.logs, hasLength(3), reason: 'no duplicated lines');
      expect(harness.logs[1], contains('(retry 1)'));
      expect(harness.logs[2], contains('(retry 2)'));
    });

    test('a refresh repeat that hits a 503 is retried, once per loop', () async {
      final session = FakeSession(token: 'old', refreshedToken: 'new');
      final harness = NetworkHarness(
        session: session,
        responses: [_status(401), _status(503), _ok()],
      );

      await harness.client.get('/v1/me', decode: ignoreBody);

      expect(harness.adapter.requests, hasLength(3));
      expect(session.refreshes, hasLength(1));
    });
  });

  group('CorrelationIdInterceptor', () {
    test('generates a UUID v4 per logical request', () async {
      final harness = NetworkHarness(responses: [_ok(), _ok()]);

      await harness.client.get('/a', decode: ignoreBody);
      await harness.client.get('/b', decode: ignoreBody);

      final ids = [
        for (final r in harness.adapter.requests)
          r.headers['X-Correlation-Id']! as String,
      ];
      expect(ids.toSet(), hasLength(2));
      for (final id in ids) {
        expect(
          id,
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
              r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
      }
    });

    test('propagates an ID supplied by the caller', () async {
      final harness = NetworkHarness(responses: [_ok()]);

      await harness.client.get(
        '/a',
        decode: ignoreBody,
        options: const ApiRequestOptions(
          headers: {'X-Correlation-Id': 'abc-123'},
        ),
      );

      expect(
        harness.adapter.requests.single.headers['X-Correlation-Id'],
        'abc-123',
      );
    });
  });

  group('LoggingInterceptor', () {
    test('logs method, path, status and duration only', () async {
      final harness = NetworkHarness(
        session: FakeSession(token: 'secret-token'),
        responses: [
          respondJson(
            successEnvelope({'patientName': 'Kamla Devi', 'age': 72}),
          ),
        ],
      );

      await harness.client.get(
        '/v1/patients',
        query: {'name': 'Kamla'},
        decode: ignoreBody,
      );

      final line = harness.logs.single;
      expect(line, startsWith('GET /v1/patients → 200 in '));
      expect(line, matches(RegExp(r'in \d+ ms')));
      for (final secret in ['secret-token', 'Kamla', 'api.proxycare']) {
        expect(line, isNot(contains(secret)), reason: secret);
      }
    });

    test('logs failures with their status or type', () async {
      final harness = NetworkHarness(
        responses: [failWith(DioExceptionType.receiveTimeout)],
      );

      await expectLater(
        harness.client.get('/v1/visits', decode: ignoreBody),
        throwsA(isA<TimeoutException>()),
      );

      expect(harness.logs.single, contains('→ receiveTimeout'));
    });

    test('detailed logs mask secrets and show only query names', () async {
      final harness = NetworkHarness(
        session: FakeSession(token: 'secret-token'),
        detailedLogging: true,
        responses: [_ok()],
      );

      await harness.client.get(
        '/v1/patients',
        query: {'mobile': '9876543210'},
        decode: ignoreBody,
        options: const ApiRequestOptions(
          headers: {'X-Api-Key': 'k-123', 'Cookie': 'session=1'},
        ),
      );

      final all = harness.logs.join('\n');
      expect(all, contains('query: mobile'));
      for (final secret in ['9876543210', 'k-123', 'session=1']) {
        expect(all, isNot(contains(secret)), reason: secret);
      }
    });

    test('the token is attached after logging, so it is never logged', () {
      // Logging runs before AuthInterceptor in the request phase.
      final lines = <String>[];
      final interceptor = LoggingInterceptor(log: lines.add, detailed: true);
      final options = RequestOptions(
        path: '/v1/me',
        headers: {'Authorization': 'Bearer abc'},
      );

      interceptor.onRequest(options, RequestInterceptorHandler());

      expect(lines.single, contains('Authorization: ***'));
      expect(lines.single, isNot(contains('abc')));
    });

    test('measures duration with the injected clock', () {
      var now = DateTime(2026, 11, 14, 10);
      final lines = <String>[];
      final interceptor = LoggingInterceptor(log: lines.add, clock: () => now);
      final options = RequestOptions(path: '/v1/me', method: 'GET');

      interceptor.onRequest(options, RequestInterceptorHandler());
      now = now.add(const Duration(milliseconds: 182));
      interceptor.onResponse(
        Response<Object?>(requestOptions: options, statusCode: 200),
        ResponseInterceptorHandler(),
      );

      expect(lines.single, 'GET /v1/me → 200 in 182 ms');
    });
  });

  group('LogRedactor', () {
    const redactor = LogRedactor();

    test('masks credentials and personal fields at any depth', () {
      final redacted = redactor.json({
        'bookingId': 'PC-2481',
        'password': 'p',
        'refresh_token': 't',
        'patient': {'name': 'Kamla', 'healthNotes': 'diabetic'},
        'items': [
          {'aadhaarNumber': '1234', 'amount': 500},
        ],
      });

      expect(redacted, {
        'bookingId': 'PC-2481',
        'password': '***',
        'refresh_token': '***',
        'patient': '***',
        'items': [
          {'aadhaarNumber': '***', 'amount': 500},
        ],
      });
    });

    test('masks sensitive headers', () {
      expect(
        redactor.headers({
          'Authorization': 'Bearer x',
          'Accept': 'application/json',
          'X-Refresh-Token': 'y',
        }),
        {
          'Authorization': '***',
          'Accept': 'application/json',
          'X-Refresh-Token': '***',
        },
      );
    });

    test('accepts extra sensitive names', () {
      const custom = LogRedactor(extraSensitiveKeys: ['ward']);
      expect(custom.isSensitive('wardNumber'), isTrue);
      expect(redactor.isSensitive('wardNumber'), isFalse);
    });
  });
}
