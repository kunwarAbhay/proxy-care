import 'dart:convert';

import '../error/app_exception.dart';
import '../error/backend_error_code.dart';
import '../error/error_mapper.dart';
import '../error/serialization.dart';
import 'api_response.dart';

/// Turns a successful HTTP response (2xx) into a typed [ApiResponse].
///
/// * **Envelope** ([ResponseFormat.envelope]): `success: true` hands `data`
///   to the decoder; `success: false` (an error inside a 2xx) is mapped like
///   an error response, classified by its code; a body that is not an
///   envelope is an invalid response.
/// * **Raw** ([ResponseFormat.raw]): the whole body goes to the decoder.
/// * **Empty or null** body (for example 204 No Content): the decoder gets
///   `null`, so a decoder for a nullable or `void` type succeeds and any
///   other fails as an invalid response.
/// * A decoder that throws on an unexpected shape (`TypeError`,
///   `FormatException`, `CheckedFromJsonException`) produces
///   `ServerException.invalidResponse`.
///
/// Error responses (non-2xx) never reach the parser: Dio rejects them and
/// `ErrorMapper` reads their envelope.
final class ResponseParser {
  /// Creates a parser that maps `success: false` bodies with [errorMapper].
  const ResponseParser({this.errorMapper = const ErrorMapper()});

  /// Maps error envelopes.
  final ErrorMapper errorMapper;

  /// Parses [body], received with [statusCode], into an [ApiResponse].
  ApiResponse<T> parse<T>(
    Object? body,
    JsonDecoder<T> decode, {
    required int statusCode,
    ResponseFormat format = ResponseFormat.envelope,
  }) {
    final payload = _isEmpty(body) ? null : body;

    if (format == ResponseFormat.raw || payload == null) {
      return ApiResponse(
        data: decodeResponse(() => decode(payload)),
        statusCode: statusCode,
      );
    }

    final decoded = _decodeJsonText(payload);
    if (decoded is! Map<Object?, Object?> || decoded['success'] is! bool) {
      throw ServerException.invalidResponse(
        message: 'Expected the standard response envelope.',
        statusCode: statusCode,
      );
    }
    final envelope = decoded.cast<String, Object?>();

    if (envelope['success'] != true) {
      throw _errorInSuccessStatus(envelope);
    }

    final meta = _meta(envelope['meta']);
    return ApiResponse(
      data: decodeResponse(() => decode(envelope['data'])),
      statusCode: statusCode,
      meta: meta,
    );
  }

  /// `success: false` in a 2xx response: the transport status says nothing,
  /// so the code's implied status classifies it.
  AppException _errorInSuccessStatus(Map<String, Object?> envelope) {
    final backend = errorMapper.parser(envelope);
    final status =
        BackendErrorCode.fromWire(backend.code)?.impliedStatus ?? 500;
    return errorMapper.fromResponse(status, envelope);
  }

  /// A JSON body sent with a non-JSON content type arrives as text.
  static Object? _decodeJsonText(Object body) {
    if (body is! String) return body;
    return decodeResponse(() => jsonDecode(body));
  }

  static bool _isEmpty(Object? body) =>
      body == null || (body is String && body.trim().isEmpty);

  static ResponseMeta _meta(Object? value) {
    if (value is! Map<Object?, Object?>) return ResponseMeta.empty;
    final meta = Map<String, Object?>.unmodifiable(
      value.cast<String, Object?>(),
    );
    String? text(String key) => switch (meta[key]) {
      final String value => value,
      _ => null,
    };
    return ResponseMeta(
      correlationId: text('correlationId'),
      timestamp: text('timestamp'),
      raw: meta,
    );
  }
}
