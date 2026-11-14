import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:json_annotation/json_annotation.dart';

import 'app_exception.dart';

/// The parts of a backend error body the app relies on.
///
/// The backend answers errors with `application/problem+json` (RFC 9457).
/// Its exact extensions are not specified yet, so parsing is tolerant:
///
/// * message: `detail`, else `title`, else `message`;
/// * code: `code`, else `errorCode`;
/// * field errors: `errors` (a list of `{field | pointer | name, message |
///   detail | reason}` or a map of field to message(s)), else
///   `invalid-params` / `invalidParams` (the RFC's own example).
///
/// Independent of any feature DTO: it reads a raw JSON map.
final class BackendError {
  /// Creates a parsed backend error.
  const BackendError({this.message, this.code, this.fieldErrors = const {}});

  /// Parses [body], which may be a decoded JSON map, a JSON string, or
  /// anything else (ignored).
  factory BackendError.parse(Object? body) {
    final json = _asMap(body);
    if (json == null) return const BackendError();
    return BackendError(
      message:
          _string(json['detail']) ??
          _string(json['title']) ??
          _string(json['message']),
      code: _string(json['code']) ?? _string(json['errorCode']),
      fieldErrors: _fieldErrors(
        json['errors'] ?? json['invalid-params'] ?? json['invalidParams'],
      ),
    );
  }

  /// Human-readable description from the backend (for logs).
  final String? message;

  /// Machine-readable error code.
  final String? code;

  /// Messages per field.
  final Map<String, List<String>> fieldErrors;

  static Map<String, Object?>? _asMap(Object? body) {
    if (body is Map<Object?, Object?>) return body.cast<String, Object?>();
    if (body is String && body.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<Object?, Object?>) {
          return decoded.cast<String, Object?>();
        }
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  static String? _string(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static Map<String, List<String>> _fieldErrors(Object? errors) {
    final result = <String, List<String>>{};
    void add(String? field, Object? message) {
      if (field == null) return;
      final messages = switch (message) {
        final String text => [text],
        final List<Object?> list => list.whereType<String>().toList(),
        _ => const <String>[],
      };
      (result[field] ??= []).addAll(messages);
    }

    if (errors is Map<Object?, Object?>) {
      for (final MapEntry(:key, :value) in errors.entries) {
        add(key is String ? key : null, value);
      }
    } else if (errors is List) {
      for (final item in errors.whereType<Map<Object?, Object?>>()) {
        final field =
            _string(item['field']) ??
            _pointerField(_string(item['pointer'])) ??
            _string(item['name']);
        add(
          field,
          _string(item['message']) ??
              _string(item['detail']) ??
              _string(item['reason']),
        );
      }
    }
    return result;
  }

  /// `#/patient/name` or `/patient/name` → `patient.name`.
  static String? _pointerField(String? pointer) {
    if (pointer == null) return null;
    final path = pointer.replaceFirst(RegExp('^#?/'), '').replaceAll('/', '.');
    return path.isEmpty ? null : path;
  }
}

/// Translates any error raised by infrastructure into an [AppException].
///
/// The single place that knows about Dio's exceptions, HTTP status codes,
/// the backend error body and serialization errors. Data sources and
/// `guardResult` call it; nothing above the data layer sees a Dio type.
final class ErrorMapper {
  /// Creates the mapper.
  const ErrorMapper();

  /// Maps [error] to an [AppException]. Existing [AppException]s are
  /// returned unchanged; unclassifiable errors become [UnknownException].
  AppException map(Object error) {
    return switch (error) {
      AppException() => error,
      DioException() => _fromDio(error),
      _ when isSerializationError(error) => ServerException.invalidResponse(
        cause: error,
      ),
      _ => UnknownException(cause: error),
    };
  }

  /// Maps an HTTP error response by its [statusCode] and [body].
  ///
  /// A 4xx response that carries field errors is a [ValidationException]
  /// whatever its status, so backend validation errors always reach forms.
  AppException fromResponse(int? statusCode, Object? body, {Object? cause}) {
    final backend = BackendError.parse(body);
    final message = backend.message;
    final code = backend.code;
    final isClientError =
        statusCode != null && statusCode >= 400 && statusCode < 500;

    if (isClientError && backend.fieldErrors.isNotEmpty) {
      return ValidationException(
        message: message ?? 'The request was invalid.',
        fieldErrors: backend.fieldErrors,
        statusCode: statusCode,
        code: code,
        cause: cause,
      );
    }

    return switch (statusCode) {
      400 || 422 => ValidationException(
        message: message ?? 'The request was invalid.',
        statusCode: statusCode,
        code: code,
        cause: cause,
      ),
      401 => UnauthorizedException(
        message: message ?? 'Authentication is required.',
        code: code,
        cause: cause,
      ),
      403 => ForbiddenException(
        message: message ?? 'The action is not allowed.',
        code: code,
        cause: cause,
      ),
      404 || 410 => NotFoundException(
        message: message ?? 'The resource was not found.',
        statusCode: statusCode!,
        code: code,
        cause: cause,
      ),
      408 || 504 => TimeoutException(
        message: message ?? 'The request timed out.',
        statusCode: statusCode,
        cause: cause,
      ),
      _ => ServerException(
        message: message ?? 'The server failed to handle the request.',
        statusCode: statusCode,
        code: code,
        cause: cause,
      ),
    };
  }

  AppException _fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException(cause: error);
      case DioExceptionType.cancel:
        return CancelledException(cause: error);
      case DioExceptionType.connectionError:
        return NetworkException(cause: error);
      case DioExceptionType.badCertificate:
        return NetworkException(
          message: 'The server certificate was rejected.',
          cause: error,
        );
      case DioExceptionType.badResponse:
        final response = error.response;
        return fromResponse(response?.statusCode, response?.data, cause: error);
      case DioExceptionType.unknown:
        final inner = error.error;
        if (inner is AppException) return inner;
        if (inner != null && isSerializationError(inner)) {
          return ServerException.invalidResponse(
            statusCode: error.response?.statusCode,
            cause: error,
          );
        }
        return UnknownException(cause: error);
    }
  }

  /// Whether [error] means a payload could not be decoded or did not match
  /// the expected shape: invalid JSON, or a `json_serializable` check
  /// failure.
  static bool isSerializationError(Object error) =>
      error is FormatException || error is CheckedFromJsonException;
}
