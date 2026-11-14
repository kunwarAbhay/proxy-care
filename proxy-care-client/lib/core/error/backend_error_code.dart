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
  validationError('VALIDATION_ERROR'),
  unauthenticated('UNAUTHENTICATED'),
  forbidden('FORBIDDEN'),
  notFound('NOT_FOUND'),
  conflict('CONFLICT'),
  businessRuleViolation('BUSINESS_RULE_VIOLATION'),
  rateLimited('RATE_LIMITED'),
  requestTimeout('REQUEST_TIMEOUT'),
  internalError('INTERNAL_ERROR'),
  serviceUnavailable('SERVICE_UNAVAILABLE');

  const BackendErrorCode(this.wireName);

  /// The value sent by the backend.
  final String wireName;

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
