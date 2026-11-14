/// Converts decoded JSON (a `Map`, `List`, primitive or null) into a typed
/// value, usually `(json) => UserDto.fromJson(json! as Map<String, dynamic>)`.
typedef JsonDecoder<T> = T Function(Object? json);

/// How an endpoint shapes its response body.
enum ResponseFormat {
  /// The standard envelope: `{"success", "data", "error", "meta"}`. The
  /// decoder receives `data`.
  envelope,

  /// No envelope: the decoder receives the whole body (third-party or
  /// legacy endpoints).
  raw,
}

/// The `meta` object of an enveloped response.
final class ResponseMeta {
  /// Creates response metadata.
  const ResponseMeta({this.correlationId, this.timestamp, this.raw = const {}});

  /// Empty metadata (raw responses, empty bodies).
  static const ResponseMeta empty = ResponseMeta();

  /// `meta.correlationId`.
  final String? correlationId;

  /// `meta.timestamp`, as sent.
  final String? timestamp;

  /// The whole `meta` object, for endpoint-specific fields such as
  /// pagination cursors. Unmodifiable.
  final Map<String, Object?> raw;
}

/// A successful response: the typed [data] plus response metadata.
final class ApiResponse<T> {
  /// Creates a response.
  const ApiResponse({
    required this.data,
    required this.statusCode,
    this.meta = ResponseMeta.empty,
  });

  /// The decoded payload.
  final T data;

  /// HTTP status (2xx).
  final int statusCode;

  /// Envelope metadata.
  final ResponseMeta meta;
}
