import 'app_environment.dart';
import 'env_exception.dart';

/// Immutable, validated application configuration supplied at compile time.
///
/// Values come from `--dart-define` or `--dart-define-from-file` and are read
/// with [String.fromEnvironment]. Call [Env.fromEnvironment] once at start-up;
/// call [Env.parse] directly from tests and tooling.
///
/// This file depends only on `dart:core`, so command-line tools can validate a
/// configuration file without the Flutter SDK.
final class Env {
  const Env._({
    required this.environment,
    required this.apiBaseUrl,
    required this.appName,
    required this.enableLogging,
    required this.featureFlags,
  });

  /// Reads the compile-time defines and validates them.
  ///
  /// Throws an [EnvConfigException] listing every invalid value.
  factory Env.fromEnvironment() {
    return Env.parse(
      appEnv: const String.fromEnvironment(appEnvKey),
      apiBaseUrl: const String.fromEnvironment(apiBaseUrlKey),
      appName: const String.fromEnvironment(appNameKey),
      enableLogging: const String.fromEnvironment(enableLoggingKey),
      featureFlags: const String.fromEnvironment(featureFlagsKey),
    );
  }

  /// Name of the define that selects the environment.
  static const appEnvKey = 'APP_ENV';

  /// Name of the define that holds the API base URL.
  static const apiBaseUrlKey = 'API_BASE_URL';

  /// Name of the define that holds the display name.
  static const appNameKey = 'APP_NAME';

  /// Name of the define that switches logging on or off.
  static const enableLoggingKey = 'ENABLE_LOGGING';

  /// Name of the define that lists enabled feature flags.
  static const featureFlagsKey = 'FEATURE_FLAGS';

  /// API base URL used only when the environment is development and
  /// `API_BASE_URL` is not supplied. Staging and production never fall back.
  static final Uri developmentApiBaseUrl = Uri.parse('http://localhost:8080');

  /// Display name used when `APP_NAME` is not supplied.
  static const defaultAppName = 'Proxy Care';

  static final RegExp _featureFlagPattern = RegExp(r'^[a-z][a-z0-9_]*$');

  static final RegExp _trailingSlashes = RegExp(r'/+$');

  static const Set<String> _loopbackHosts = {
    'localhost',
    '127.0.0.1',
    '0.0.0.0',
    '::1',
    '10.0.2.2',
  };

  /// The environment this build targets.
  final AppEnvironment environment;

  /// Base URL for API requests, without a trailing slash.
  final Uri apiBaseUrl;

  /// Display name of the application.
  final String appName;

  /// Whether application logging is enabled.
  final bool enableLogging;

  /// Names of the feature flags switched on for this build. Unmodifiable.
  final Set<String> featureFlags;

  /// Whether this is a production build.
  bool get isProduction => environment == AppEnvironment.production;

  /// Whether the feature flag [name] is switched on.
  bool isFeatureEnabled(String name) => featureFlags.contains(name);

  /// Validates raw define values and builds an [Env].
  ///
  /// An empty string means the define was not supplied. Every value is
  /// checked before throwing, so one failed build reports every problem.
  ///
  /// Rules:
  /// * `APP_ENV`: `development`, `staging` or `production` (any case);
  ///   defaults to `development`.
  /// * `API_BASE_URL`: absolute http(s) URL without query or fragment.
  ///   Required, and must use https, in staging and production; production
  ///   must not point to a local host. Defaults to [developmentApiBaseUrl]
  ///   only in development.
  /// * `APP_NAME`: defaults to [defaultAppName].
  /// * `ENABLE_LOGGING`: `true` or `false`; defaults to `false` in
  ///   production and `true` elsewhere.
  /// * `FEATURE_FLAGS`: comma-separated snake_case names; defaults to none.
  static Env parse({
    required String appEnv,
    required String apiBaseUrl,
    required String appName,
    required String enableLogging,
    required String featureFlags,
  }) {
    final errors = <String>[];

    final environment = _parseEnvironment(appEnv, errors);
    // An unknown APP_ENV is checked against the strictest (production) rules
    // so that no other problem is hidden behind it.
    final rules = environment ?? AppEnvironment.production;
    final baseUrl = _parseApiBaseUrl(apiBaseUrl, rules, errors);
    final logging = _parseLogging(enableLogging, rules, errors);
    final flags = _parseFeatureFlags(featureFlags, errors);

    if (errors.isNotEmpty) {
      throw EnvConfigException(List.unmodifiable(errors));
    }

    // Every null result above records an error, so none are null here.
    return Env._(
      environment: environment!,
      apiBaseUrl: baseUrl!,
      appName: _parseAppName(appName),
      enableLogging: logging!,
      featureFlags: flags,
    );
  }

  static AppEnvironment? _parseEnvironment(String raw, List<String> errors) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) {
      return AppEnvironment.development;
    }
    final environment = AppEnvironment.values.asNameMap()[value];
    if (environment == null) {
      final allowed = AppEnvironment.values.map((e) => e.name).join(', ');
      errors.add('$appEnvKey must be one of $allowed; got "$raw".');
    }
    return environment;
  }

  static Uri? _parseApiBaseUrl(
    String raw,
    AppEnvironment environment,
    List<String> errors,
  ) {
    final value = raw.trim();
    if (value.isEmpty) {
      if (environment == AppEnvironment.development) {
        return developmentApiBaseUrl;
      }
      errors.add(
        '$apiBaseUrlKey is required when $appEnvKey is ${environment.name}.',
      );
      return null;
    }

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      errors.add('$apiBaseUrlKey must be an absolute URL; got "$value".');
      return null;
    }
    if (!uri.isScheme('http') && !uri.isScheme('https')) {
      errors.add('$apiBaseUrlKey must use http or https; got "$value".');
      return null;
    }
    if (uri.hasQuery || uri.hasFragment) {
      errors.add('$apiBaseUrlKey must not contain a query or fragment.');
      return null;
    }
    if (environment != AppEnvironment.development) {
      if (!uri.isScheme('https')) {
        errors.add('$apiBaseUrlKey must use https in ${environment.name}.');
        return null;
      }
      if (environment == AppEnvironment.production &&
          _loopbackHosts.contains(uri.host)) {
        errors.add(
          '$apiBaseUrlKey must not point to ${uri.host} in production.',
        );
        return null;
      }
    }
    return uri.replace(path: uri.path.replaceFirst(_trailingSlashes, ''));
  }

  static String _parseAppName(String raw) {
    final value = raw.trim();
    return value.isEmpty ? defaultAppName : value;
  }

  static bool? _parseLogging(
    String raw,
    AppEnvironment environment,
    List<String> errors,
  ) {
    switch (raw.trim().toLowerCase()) {
      case '':
        return environment != AppEnvironment.production;
      case 'true':
        return true;
      case 'false':
        return false;
    }
    errors.add('$enableLoggingKey must be "true" or "false"; got "$raw".');
    return null;
  }

  static Set<String> _parseFeatureFlags(String raw, List<String> errors) {
    final flags = <String>{};
    for (final entry in raw.split(',')) {
      final flag = entry.trim();
      if (flag.isEmpty) {
        continue;
      }
      if (_featureFlagPattern.hasMatch(flag)) {
        flags.add(flag);
      } else {
        errors.add(
          '$featureFlagsKey entry "$flag" must be snake_case (a-z, 0-9, _).',
        );
      }
    }
    return Set.unmodifiable(flags);
  }

  @override
  bool operator ==(Object other) {
    return other is Env &&
        other.environment == environment &&
        other.apiBaseUrl == apiBaseUrl &&
        other.appName == appName &&
        other.enableLogging == enableLogging &&
        other.featureFlags.length == featureFlags.length &&
        other.featureFlags.containsAll(featureFlags);
  }

  @override
  int get hashCode {
    return Object.hash(
      environment,
      apiBaseUrl,
      appName,
      enableLogging,
      Object.hashAllUnordered(featureFlags),
    );
  }

  @override
  String toString() {
    return 'Env(environment: ${environment.name}, apiBaseUrl: $apiBaseUrl, '
        'appName: $appName, enableLogging: $enableLogging, '
        'featureFlags: $featureFlags)';
  }
}
