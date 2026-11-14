/// Base type for expected, recoverable failures, such as a network error or
/// a rejected request, that repositories and use cases return inside a
/// `Result`.
///
/// Pure Dart so the domain layer can depend on it. Concrete failure types are
/// added by the error-handling layer and by features; they extend this
/// class. Unexpected programming errors are not failures: let them throw and
/// reach the `ErrorReporter`.
abstract class Failure {
  /// Creates a failure with a developer-facing [message] and an optional
  /// underlying [cause].
  const Failure(this.message, {this.cause});

  /// Developer-facing description. Not shown to users as-is.
  final String message;

  /// The exception or error this failure was created from, if any.
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}
