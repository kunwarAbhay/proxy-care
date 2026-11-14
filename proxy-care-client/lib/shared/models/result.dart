import '../../core/error/failure.dart';

/// The outcome of an operation that can fail in an expected way: either an
/// [Ok] holding a value or an [Err] holding a [Failure].
///
/// Repositories and use cases return `Result` instead of throwing for
/// expected failures. Callers handle both cases with an exhaustive `switch`:
///
/// ```dart
/// switch (result) {
///   case Ok(:final value):
///     // use value
///   case Err(:final failure):
///     // show failure
/// }
/// ```
sealed class Result<T> {
  const Result();

  /// A successful result holding [value].
  const factory Result.ok(T value) = Ok<T>;

  /// A failed result holding [failure].
  const factory Result.err(Failure failure) = Err<T>;

  /// Whether this is an [Ok].
  bool get isOk => this is Ok<T>;

  /// The value if this is an [Ok], otherwise `null`.
  T? get valueOrNull => switch (this) {
    Ok(:final value) => value,
    Err() => null,
  };
}

/// A successful [Result].
final class Ok<T> extends Result<T> {
  /// Creates a successful result holding [value].
  const Ok(this.value);

  /// The produced value.
  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok, value);

  @override
  String toString() => 'Ok($value)';
}

/// A failed [Result].
final class Err<T> extends Result<T> {
  /// Creates a failed result holding [failure].
  const Err(this.failure);

  /// What went wrong.
  final Failure failure;

  @override
  bool operator ==(Object other) => other is Err<T> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err, failure);

  @override
  String toString() => 'Err($failure)';
}
