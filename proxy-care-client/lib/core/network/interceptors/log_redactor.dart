/// Removes secrets and personal data from what is logged.
///
/// Matching is by name (case-insensitive substring), so `refresh_token`,
/// `X-Api-Key` and `patientName` are all caught. The list errs on the side
/// of hiding: a log line never needs these values.
final class LogRedactor {
  /// Creates a redactor; [extraSensitiveKeys] adds names to the defaults.
  const LogRedactor({this.extraSensitiveKeys = const []});

  /// Shown instead of a hidden value.
  static const String mask = '***';

  /// Name fragments whose values are never logged: credentials, tokens,
  /// identity documents, payment and contact details, and anything about a
  /// person's health.
  static const List<String> defaultSensitiveKeys = [
    'authorization',
    'cookie',
    'password',
    'passwd',
    'secret',
    'token',
    'apikey',
    'api_key',
    'api-key',
    'otp',
    'pin',
    'code',
    'signature',
    'session',
    'aadhaar',
    'pan',
    'account',
    'ifsc',
    'card',
    'cvv',
    'upi',
    'bank',
    'mobile',
    'phone',
    'email',
    'address',
    'name',
    'dob',
    'birth',
    'age',
    'sex',
    'gender',
    'health',
    'medical',
    'diagnos',
    'prescription',
    'mobility',
    'note',
    'instruction',
    'report',
    'patient',
  ];

  /// Additional name fragments.
  final List<String> extraSensitiveKeys;

  /// Whether values named [key] must be hidden.
  bool isSensitive(String key) {
    final lower = key.toLowerCase();
    return [
      ...defaultSensitiveKeys,
      ...extraSensitiveKeys,
    ].any((fragment) => lower.contains(fragment.toLowerCase()));
  }

  /// [headers] with sensitive values masked.
  Map<String, String> headers(Map<String, Object?> headers) => {
    for (final MapEntry(:key, :value) in headers.entries)
      key: isSensitive(key) ? mask : '$value',
  };

  /// A copy of a JSON value with every sensitive field masked, at any
  /// depth. Only used when body logging is switched on explicitly.
  Object? json(Object? value) => switch (value) {
    final Map<Object?, Object?> map => {
      for (final MapEntry(:key, :value) in map.entries)
        '$key': isSensitive('$key') ? mask : json(value),
    },
    final List<Object?> list => [for (final item in list) json(item)],
    _ => value,
  };
}
