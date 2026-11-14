import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:proxy_care_client/core/error/app_exception.dart';
import 'package:proxy_care_client/core/error/error_mapper.dart';

final _options = RequestOptions(path: '/v1/bookings');

DioException _dio(DioExceptionType type, {Object? error}) =>
    DioException(requestOptions: _options, type: type, error: error);

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

  group('backend error body (problem+json)', () {
    test('carries the backend code and detail', () {
      final mapped = mapper.map(
        _response(409, {
          'type': 'https://api.proxycare.in/problems/booking-state',
          'title': 'Conflict',
          'status': 409,
          'detail': 'The booking is no longer WAITING.',
          'code': 'BOOKING_NOT_CANCELLABLE',
        }),
      );

      expect(mapped, isA<ServerException>());
      expect(mapped.code, 'BOOKING_NOT_CANCELLABLE');
      expect(mapped.message, 'The booking is no longer WAITING.');
    });

    test('falls back to the title and accepts errorCode', () {
      final mapped = mapper.map(
        _response(401, {
          'title': 'Token expired',
          'errorCode': 'TOKEN_EXPIRED',
        }),
      );

      expect(mapped, isA<UnauthorizedException>());
      expect(mapped.code, 'TOKEN_EXPIRED');
      expect(mapped.message, 'Token expired');
    });

    test('reads a JSON string body', () {
      final mapped = mapper.map(
        _response(403, '{"detail":"Not your booking","code":"NOT_OWNER"}'),
      );

      expect(mapped, isA<ForbiddenException>());
      expect(mapped.code, 'NOT_OWNER');
    });

    test('ignores a body that is not a problem document', () {
      final mapped = mapper.map(_response(500, '<html>Bad gateway</html>'));

      expect(mapped, isA<ServerException>());
      expect(mapped.message, 'The server failed to handle the request.');
      expect(mapped.code, isNull);
    });
  });

  group('validation errors', () {
    test('a list of field errors', () {
      final mapped = mapper.map(
        _response(422, {
          'title': 'Validation failed',
          'code': 'VALIDATION_FAILED',
          'errors': [
            {'field': 'mobile', 'message': 'Enter 10 digits'},
            {'field': 'mobile', 'message': 'Without 0 or +91'},
            {'pointer': '#/patient/age', 'detail': 'Must be at least 1'},
            {'name': 'pickupAt', 'reason': 'Must be in the future'},
          ],
        }),
      );

      expect(mapped, isA<ValidationException>());
      final validation = mapped as ValidationException;
      expect(validation.code, 'VALIDATION_FAILED');
      expect(validation.fieldErrors, {
        'mobile': ['Enter 10 digits', 'Without 0 or +91'],
        'patient.age': ['Must be at least 1'],
        'pickupAt': ['Must be in the future'],
      });
    });

    test('a map of field errors', () {
      final mapped = mapper.map(
        _response(400, {
          'errors': {
            'pan': 'Enter 10 characters',
            'ifsc': ['Unknown IFSC', 'Use capital letters'],
          },
        }),
      );

      expect((mapped as ValidationException).fieldErrors, {
        'pan': ['Enter 10 characters'],
        'ifsc': ['Unknown IFSC', 'Use capital letters'],
      });
    });

    test('RFC 9457 invalid-params', () {
      final mapped = mapper.map(
        _response(400, {
          'invalid-params': [
            {'name': 'age', 'reason': 'must be a positive integer'},
          ],
        }),
      );

      expect((mapped as ValidationException).fieldErrors, {
        'age': ['must be a positive integer'],
      });
    });

    test('field errors on another 4xx still make a validation error', () {
      final mapped = mapper.map(
        _response(409, {
          'errors': [
            {'field': 'otp', 'message': 'Code expired'},
          ],
        }),
      );

      expect(mapped, isA<ValidationException>());
      expect(mapped.statusCode, 409);
    });

    test('field errors on a 5xx stay a server error', () {
      final mapped = mapper.map(
        _response(500, {
          'errors': [
            {'field': 'otp', 'message': 'Code expired'},
          ],
        }),
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
        _response(422, {
          'errors': {'pan': 'Required'},
        }),
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
