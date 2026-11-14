import 'api_response.dart';

/// A request for one page of a cursor-paginated list.
///
/// The backend standard is cursor pagination; the exact parameter and
/// field names are not in the API contract yet, so they are configurable
/// here and the defaults (`cursor`, `limit`; `meta.nextCursor`) are
/// provisional.
final class PageRequest {
  /// Creates a page request. A null [cursor] asks for the first page.
  const PageRequest({
    this.cursor,
    this.limit = defaultLimit,
    this.cursorParameter = 'cursor',
    this.limitParameter = 'limit',
  }) : assert(limit > 0, 'limit must be positive');

  /// Page size used when none is given.
  static const int defaultLimit = 20;

  /// Where to continue; null for the first page.
  final String? cursor;

  /// Maximum number of items.
  final int limit;

  /// Query parameter that carries [cursor].
  final String cursorParameter;

  /// Query parameter that carries [limit].
  final String limitParameter;

  /// The query parameters for this page.
  Map<String, Object> toQuery() => {
    limitParameter: limit,
    cursorParameter: ?cursor,
  };

  /// The request for the page after [page], or null on the last page.
  PageRequest? next(CursorPage<Object?> page) => page.hasMore
      ? PageRequest(
          cursor: page.nextCursor,
          limit: limit,
          cursorParameter: cursorParameter,
          limitParameter: limitParameter,
        )
      : null;
}

/// One page of items and where the next page starts.
final class CursorPage<T> {
  /// Creates a page.
  const CursorPage({required this.items, this.nextCursor});

  /// Builds a page from an enveloped response whose `data` is the list of
  /// items and whose `meta` holds the next cursor under [nextCursorKey].
  factory CursorPage.fromResponse(
    ApiResponse<List<T>> response, {
    String nextCursorKey = 'nextCursor',
  }) {
    final cursor = response.meta.raw[nextCursorKey];
    return CursorPage(
      items: response.data,
      nextCursor: cursor is String && cursor.isNotEmpty ? cursor : null,
    );
  }

  /// The items, in order. Unmodifiable when built by [CursorPage.fromResponse]
  /// from a decoded list.
  final List<T> items;

  /// Cursor of the next page; null on the last page.
  final String? nextCursor;

  /// Whether another page follows.
  bool get hasMore => nextCursor != null;
}

/// Decodes a JSON list with [decodeItem], for paginated `data`.
JsonDecoder<List<T>> listDecoder<T>(T Function(Object? json) decodeItem) =>
    (json) => List<T>.unmodifiable(
      (json! as List<Object?>).map(decodeItem),
    );
