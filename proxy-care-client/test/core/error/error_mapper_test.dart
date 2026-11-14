import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:proxy_care_client/core/error/app_exception.dart';
import 'package:proxy_care_client/core/error/backend_error_code.dart';
import 'package:proxy_care_client/core/error/error_mapper.dart';

final _options = RequestOptions(path: '/v1/bookings');

DioException _dio(DioExceptionType type, {Object? error}) =>
    DioException(requestOptions: _options, type: type, error: error);

/// The standard backend error envelope.
Map<String, Object?> _envelope({
  String? code,
  String? message,
  Map<String, Object?>? fieldErrors,
  String? correlationId,
}) => {
  'success': false,
  'data': null,
  'error': {
    'code': ?code,
    'message': ?message,
    'fieldErrors': ?fieldErrors,
  },
  'meta': {
    'timestamp': '2026-11-14T10:00:00Z',
    'correlationId': ?correlationId,
  },
};

DioException _response(int status, [Object? data]) => DioException(
  requestOptions: _options,
  type: DioExceptionType.badResponse,
  response: Response<Object?>(
    requestOptions: _options,
    statusCode: status,
    data: data,
  ),
);

void main() {
  const mapper = ErrorMapper();

  group('DioException types', () {
    final cases = <DioExceptionType, Type>{
      DioExceptionType.connectionTimeout: TimeoutException,
      DioExceptionType.sendTimeout: TimeoutException,
      DioExceptionType.receiveTimeout: TimeoutException,
      DioExceptionType.transformTimeout: TimeoutException,
      DioExceptionType.cancel: CancelledException,
      DioExceptionType.connectionError: NetworkException,
      DioExceptionType.badCertificate: NetworkException,
      DioExceptionType.unknown: UnknownException,
    };

    for (final MapEntry(key: type, value: expected) in cases.entries) {
      test('$type → $expected', () {
        final error = _dio(type);
        final mapped = mapper.map(error);

        expect(mapped.runtimeType, expected);
        expect(mapped.cause, same(error));
      });
    }

    test('unknown wrapping an AppException returns it', () {
      const inner = NotFoundException();
      expect(
        mapper.map(_dio(DioExceptionType.unknown, error: inner)),
        same(inner),
      );
    });

    test('unknown wrapping a decoding error is an invalid response', () {
      final mapped = mapper.map(
        _dio(DioExceptionType.unknown, error: const FormatException('<html>')),
      );

      expect(mapped, isA<ServerException>());
      expect((mapped as ServerException).invalidResponse, isTrue);
    });
  });

  group('HTTP status codes', () {
    final cases = <int, Type>{
      400: ValidationException,
      401: UnauthorizedException,
      403: ForbiddenException,
      404: NotFoundException,
      408: TimeoutException,
      409: ServerException,
      410: NotFoundException,
      422: ValidationException,
      429: ServerException,
      500: ServerException,
      502: ServerException,
      503: ServerException,
      504: TimeoutException,
    };

    for (final MapEntry(key: status, value: expected) in cases.entries) {
      test('$status → $expected', () {
        final mapped = mapper.map(_response(status));

        expect(mapped.runtimeType, expected);
        expect(mapped.statusCode, status);
      });
    }

    test('a response without a status is a server error', () {
      final error = DioException(
        requestOptions: _options,
        type: DioExceptionType.badResponse,
      );

      expect(mapper.map(error), isA<ServerException>());
    });
  });

  group('backend error envelope', () {
    test('reads code, message and correlation id', () {
      final mapped = mapper.map(
        _response(
          409,
          _envelope(
            code: 'CONFLICT',
            message: 'Booking version mismatch',
            correlationId: 'abc-123',
          ),
        ),
      );

      expect(mapped, isA<ServerException>());
      expect(mapped.code, 'CONFLICT');
      expect(mapped.errorCode, BackendErrorCode.conflict);
      expect(mapped.message, 'Booking version mismatch');
      expect(mapped.correlationId, 'abc-123');
    });

    test('reads a JSON string body', () {
      final mapped = mapper.map(
        _response(
          403,
          '{"success":false,"data":null,'
          '"error":{"code":"FORBIDDEN","message":"Not your booking"}}',
        ),
      );

      expect(mapped, isA<ForbiddenException>());
      expect(mapped.errorCode, BackendErrorCode.forbidden);
    });

    test('keeps an unknown code as sent', () {
      final mapped = mapper.map(
        _response(409, _envelope(code: 'SLOT_TAKEN')),
      );

      expect(mapped.code, 'SLOT_TAKEN');
      expect(mapped.errorCode, isNull);
    });

    test('ignores a body that is not the envelope', () {
      for (final body in <Object?>[
        '<html>Bad gateway</html>',
        {'detail': 'problem+json is not the contract'},
        null,
      ]) {
        final mapped = mapper.map(_response(502, body));

        expect(mapped, isA<ServerException>());
        expect(mapped.code, isNull);
        expect(mapped.message, 'The server failed to handle the request.');
      }
    });

    test('the HTTP status stays authoritative over the code', () {
      final mapped = mapper.map(
        _response(401, _envelope(code: 'VALIDATION_ERROR')),
      );

      expect(mapped, isA<UnauthorizedException>());
    });

    test('a 422 business-rule violation is not a validation error', () {
      final mapped = mapper.map(
        _response(422, _envelope(code: 'BUSINESS_RULE_VIOLATION')),
      );

      expect(mapped, isA<ServerException>());
      expect(mapped.errorCode, BackendErrorCode.businessRuleViolation);
    });

    test('an endpoint can supply its own parser', () {
      final custom = ErrorMapper(
        parser: (body) => BackendError(
          code: (body! as Map<String, Object?>)['reason'] as String?,
        ),
      );

      final mapped = custom.map(_response(409, {'reason': 'CONFLICT'}));
      expect(mapped.errorCode, BackendErrorCode.conflict);

      final perCall = mapper.fromResponse(
        404,
        {'legacyCode': 'GONE'},
        parser: (body) => const BackendError(code: 'NOT_FOUND'),
      );
      expect(perCall.errorCode, BackendErrorCode.notFound);
    });
  });

  group('validation errors', () {
    test('field errors from the envelope', () {
      final mapped = mapper.map(
        _response(
          400,
          _envelope(
            code: 'VALIDATION_ERROR',
            message: 'Request validation failed',
            fieldErrors: {
              'email': ['Invalid email address'],
              'mobile': ['Enter 10 digits', 'Without 0 or +91'],
            },
          ),
        ),
      );

      expect(mapped, isA<ValidationException>());
      final validation = mapped as ValidationException;
      expect(validation.errorCode, BackendErrorCode.validationError);
      expect(validation.fieldErrors, {
        'email': ['Invalid email address'],
        'mobile': ['Enter 10 digits', 'Without 0 or +91'],
      });
    });

    test('a single string message per field is accepted', () {
      final mapped = mapper.map(
        _response(
          422,
          _envelope(
            code: 'VALIDATION_ERROR',
            fieldErrors: {'pan': 'Enter 10 characters'},
          ),
        ),
      );

      expect((mapped as ValidationException).fieldErrors, {
        'pan': ['Enter 10 characters'],
      });
    });

    test('field errors on another 4xx still make a validation error', () {
      final mapped = mapper.map(
        _response(
          409,
          _envelope(
            code: 'CONFLICT',
            fieldErrors: {
              'otp': ['Code expired'],
            },
          ),
        ),
      );

      expect(mapped, isA<ValidationException>());
      expect(mapped.statusCode, 409);
    });

    test('field errors on a 5xx stay a server error', () {
      final mapped = mapper.map(
        _response(
          500,
          _envelope(
            code: 'INTERNAL_ERROR',
            fieldErrors: {
              'otp': ['Code expired'],
            },
          ),
        ),
      );

      expect(mapped, isA<ServerException>());
    });

    test('a 400 without field errors is a general validation error', () {
      final mapped = mapper.map(_response(400));

      expect(mapped, isA<ValidationException>());
      expect((mapped as ValidationException).fieldErrors, isEmpty);
    });

    test('field errors cannot be modified', () {
      final mapped = mapper.map(
        _response(
          422,
          _envelope(
            fieldErrors: {
              'pan': ['Required'],
            },
          ),
        ),
      ) as ValidationException;

      expect(() => mapped.fieldErrors['x'] = [], throwsUnsupportedError);
      expect(() => mapped.fieldErrors['pan']!.add('y'), throwsUnsupportedError);
    });
  });

  group('serialization errors', () {
    test('invalid JSON', () {
      final mapped = mapper.map(const FormatException('Unexpected character'));

      expect(mapped, isA<ServerException>());
      expect((mapped as ServerException).invalidResponse, isTrue);
    });

    test('checked fromJson failure', () {
      final error = CheckedFromJsonException(
        const {'id': 1},
        'id',
        'UserDto',
        'type int is not a subtype of String',
      );

      final mapped = mapper.map(error);
      expect((mapped as ServerException).invalidResponse, isTrue);
      expect(mapped.cause, same(error));
    });
  });

  group('unexpected errors', () {
    test('an AppException passes through unchanged', () {
      const error = ForbiddenException();
      expect(mapper.map(error), same(error));
    });

    test('any other exception is unknown and keeps its cause', () {
      final error = Exception('boom');
      final mapped = mapper.map(error);

      expect(mapped, isA<UnknownException>());
      expect(mapped.cause, same(error));
    });

    test('an Error is unknown too (the guard decides whether to catch it)', () {
      expect(mapper.map(StateError('bug')), isA<UnknownException>());
    });
  });
}
