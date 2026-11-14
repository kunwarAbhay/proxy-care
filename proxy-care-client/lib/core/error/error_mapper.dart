import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:json_annotation/json_annotation.dart';

import 'app_exception.dart';
import 'backend_error_code.dart';

/// Reads a [BackendError] from an error response body. The default is
/// [BackendError.parse]; an endpoint with a different error structure can
/// supply its own parser to [ErrorMapper] or [ErrorMapper.fromResponse].
typedef BackendErrorParser = BackendError Function(Object? body);

/// The parts of a backend error response the app relies on.
///
/// Every endpoint answers errors with the standard envelope:
///
/// ```json
/// {
///   "success": false,
///   "data": null,
///   "error": {
///     "code": "VALIDATION_ERROR",
///     "message": "Request validation failed",
///     "fieldErrors": { "email": ["Invalid email address"] }
///   },
///   "meta": { "timestamp": "…", "correlationId": "abc-123" }
/// }
/// ```
///
/// Independent of any feature DTO: it reads raw JSON.
final class BackendError {
  /// Creates a parsed backend error.
  const BackendError({
    this.code,
    this.message,
    this.fieldErrors = const {},
    this.correlationId,
  });

  /// Parses the standard envelope from [body]: a decoded JSON map or a JSON
  /// string. Anything else (an HTML error page, an empty body) yields an
  /// empty [BackendError], and the HTTP status alone classifies the error.
  factory BackendError.parse(Object? body) {
    final json = _asMap(body);
    final error = _asMap(json?['error']);
    if (json == null || error == null) return const BackendError();
    return BackendError(
      code: _string(error['code']),
      message: _string(error['message']),
      fieldErrors: _fieldErrors(error['fieldErrors']),
      correlationId: _string(_asMap(json['meta'])?['correlationId']),
    );
  }

  /// `error.code`: stable machine-readable identifier.
  final String? code;

  /// `error.message`: technical message, for logs only.
  final String? message;

  /// `error.fieldErrors`: messages per field.
  final Map<String, List<String>> fieldErrors;

  /// `meta.correlationId`.
  final String? correlationId;

  static Map<String, Object?>? _asMap(Object? value) {
    if (value is Map<Object?, Object?>) return value.cast<String, Object?>();
    if (value is String && value.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(value);
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

  static Map<String, List<String>> _fieldErrors(Object? value) {
    if (value is! Map<Object?, Object?>) return const {};
    return {
      for (final MapEntry(:key, :value) in value.entries)
        if (key is String)
          key: switch (value) {
            final String message => [message],
            final List<Object?> messages =>
              messages.whereType<String>().toList(),
            _ => const <String>[],
          },
    };
  }
}

/// Translates any error raised by infrastructure into an [AppException].
///
/// The single place that knows about Dio's exceptions, HTTP status codes,
/// the backend error envelope and serialization errors. Data sources and
/// `guardResult` call it; nothing above the data layer sees a Dio type.
final class ErrorMapper {
  /// Creates the mapper. [parser] reads error bodies; the default reads the
  /// standard envelope.
  const ErrorMapper({this.parser = BackendError.parse});

  /// Reads error response bodies.
  final BackendErrorParser parser;

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
  /// The status decides the exception type. The backend code only refines
  /// what the status leaves open: a 400 / 422 is a [ValidationException]
  /// unless its code says it is a business-rule violation, and any 4xx that
  /// carries field errors is a [ValidationException], so backend validation
  /// errors always reach forms. [parser] overrides the mapper's parser for
  /// one endpoint.
  AppException fromResponse(
    int? statusCode,
    Object? body, {
    Object? cause,
    BackendErrorParser? parser,
  }) {
    final backend = (parser ?? this.parser)(body);
    final message = backend.message;
    final code = backend.code;
    final correlationId = backend.correlationId;
    final isClientError =
        statusCode != null && statusCode >= 400 && statusCode < 500;
    final isBusinessRule =
        BackendErrorCode.fromWire(code) ==
        BackendErrorCode.businessRuleViolation;

    ValidationException validation() => ValidationException(
      message: message ?? 'The request was invalid.',
      fieldErrors: backend.fieldErrors,
      statusCode: statusCode,
      code: code,
      correlationId: correlationId,
      cause: cause,
    );

    ServerException server() => ServerException(
      message: message ?? 'The server failed to handle the request.',
      statusCode: statusCode,
      code: code,
      correlationId: correlationId,
      cause: cause,
    );

    if (isClientError && backend.fieldErrors.isNotEmpty) return validation();

    return switch (statusCode) {
      400 || 422 => isBusinessRule ? server() : validation(),
      401 => UnauthorizedException(
        message: message ?? 'Authentication is required.',
        code: code,
        correlationId: correlationId,
        cause: cause,
      ),
      403 => ForbiddenException(
        message: message ?? 'The action is not allowed.',
        code: code,
        correlationId: correlationId,
        cause: cause,
      ),
      404 || 410 => NotFoundException(
        message: message ?? 'The resource was not found.',
        statusCode: statusCode!,
        code: code,
        correlationId: correlationId,
        cause: cause,
      ),
      408 || 504 => TimeoutException(
        message: message ?? 'The request timed out.',
        statusCode: statusCode,
        code: code,
        correlationId: correlationId,
        cause: cause,
      ),
      _ => server(),
    };
  }

  AppException _fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
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
