import 'app_exception.dart';
import 'failure.dart';

/// Converts infrastructure exceptions into application failures. Used by
/// repositories (through `guardResult`); the domain never sees an
/// [AppException].
extension AppExceptionToFailure on AppException {
  /// The application failure for this exception.
  AppFailure toFailure() => switch (this) {
    NetworkException(:final message, :final cause) => NetworkFailure(
      message,
      cause: cause,
    ),
    TimeoutException(:final message, :final cause) => NetworkFailure(
      message,
      isTimeout: true,
      cause: cause,
    ),
    UnauthorizedException(:final message, :final code, :final cause) =>
      UnauthorizedFailure(message, code: code, cause: cause),
    ForbiddenException(:final message, :final code, :final cause) =>
      ForbiddenFailure(message, code: code, cause: cause),
    NotFoundException(:final message, :final code, :final cause) =>
      NotFoundFailure(message, code: code, cause: cause),
    ValidationException(
      :final message,
      :final fieldErrors,
      :final code,
      :final cause,
    ) =>
      ValidationFailure(
        message,
        fieldErrors: fieldErrors,
        code: code,
        cause: cause,
      ),
    ServerException(
      :final message,
      :final statusCode,
      :final code,
      :final cause,
    ) =>
      ServerFailure(message, statusCode: statusCode, code: code, cause: cause),
    CancelledException(:final message, :final cause) => CancelledFailure(
      message,
      cause: cause,
    ),
    UnknownException(:final message, :final cause) => UnexpectedFailure(
      message,
      cause: cause,
    ),
  };
}
