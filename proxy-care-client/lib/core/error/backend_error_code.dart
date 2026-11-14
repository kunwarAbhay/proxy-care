/// The backend's standard error codes (the `error.code` field of the error
/// response). Stable, machine-readable identifiers: error handling may
/// branch on them, never on the backend's message text.
///
/// HTTP status codes stay authoritative for transport-level classification;
/// a code only refines what the status leaves open (for example a 422 that
/// is a business-rule violation rather than invalid input).
///
/// Pure Dart: failures carry it into the domain and presentation layers.
enum BackendErrorCode {
  validationError('VALIDATION_ERROR', 422),
  unauthenticated('UNAUTHENTICATED', 401),
  forbidden('FORBIDDEN', 403),
  notFound('NOT_FOUND', 404),
  conflict('CONFLICT', 409),
  businessRuleViolation('BUSINESS_RULE_VIOLATION', 422),
  rateLimited('RATE_LIMITED', 429),
  requestTimeout('REQUEST_TIMEOUT', 408),
  internalError('INTERNAL_ERROR', 500),
  serviceUnavailable('SERVICE_UNAVAILABLE', 503);

  const BackendErrorCode(this.wireName, this.impliedStatus);

  /// The value sent by the backend.
  final String wireName;

  /// The HTTP status this code corresponds to. Used only when an error
  /// arrives with a 2xx status (`"success": false` in a 200 response), where
  /// the transport status cannot classify it.
  final int impliedStatus;

  /// The code for [wireName], or null for a missing or unknown code (the
  /// raw string is still kept on the exception and failure).
  static BackendErrorCode? fromWire(String? wireName) {
    if (wireName == null) return null;
    for (final code in values) {
      if (code.wireName == wireName) return code;
    }
    return null;
  }
}
