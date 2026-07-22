import 'package:flutter/foundation.dart';

/// Environment types for the application.
enum Environment {
  /// Development environment, typically using localhost.
  development,

  /// Staging environment for testing.
  staging,

  /// Production environment for release.
  production,
}

/// Configuration for the application.
class AppConfig {
  /// Build-time API base URL override (`--dart-define=API_BASE_URL=/api`).
  static const String apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// Auto sign-in as local demo user when no saved session exists.
  static const bool autoGuestLogin = bool.fromEnvironment(
    'AUTO_GUEST_LOGIN',
    defaultValue: true,
  );

  /// The current application environment.
  final Environment environment;

  /// Base URL for the API.
  final String apiBaseUrl;

  /// Whether to enable logging.
  final bool enableLogging;

  /// Connection timeout in seconds.
  final int connectionTimeoutSeconds;

  /// Whether to use mock data when API fails.
  final bool useMockDataOnFailure;

  /// Default constructor
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    this.enableLogging = false,
    this.connectionTimeoutSeconds = 30,
    this.useMockDataOnFailure = true,
  });

  /// Development environment configuration.
  static const AppConfig development = AppConfig(
    environment: Environment.development,
    apiBaseUrl: 'http://127.0.0.1:8002/api',
    enableLogging: true,
    connectionTimeoutSeconds: 30,
    useMockDataOnFailure: true,
  );

  /// Bundled web build served from the same host as the API.
  static const AppConfig bundledWeb = AppConfig(
    environment: Environment.production,
    apiBaseUrl: '/api',
    enableLogging: false,
    connectionTimeoutSeconds: 60,
    useMockDataOnFailure: false,
  );

  /// Staging environment configuration.
  static const AppConfig staging = AppConfig(
    environment: Environment.staging,
    apiBaseUrl: 'https://api-staging.example.com/api',
    enableLogging: true,
    connectionTimeoutSeconds: 45,
    useMockDataOnFailure: true,
  );

  /// Production environment configuration.
  static const AppConfig production = AppConfig(
    environment: Environment.production,
    apiBaseUrl: 'https://api.example.com/api',
    enableLogging: false,
    connectionTimeoutSeconds: 60,
    useMockDataOnFailure: false,
  );

  /// The current configuration instance.
  static late final AppConfig current;

  /// Initialize the application configuration.
  static void initialize({Environment env = Environment.development}) {
    if (apiBaseUrlOverride.isNotEmpty) {
      current = AppConfig(
        environment: Environment.production,
        apiBaseUrl: apiBaseUrlOverride,
        enableLogging: kDebugMode,
        connectionTimeoutSeconds: 60,
        useMockDataOnFailure: false,
      );
    } else if (kIsWeb && !kDebugMode) {
      current = bundledWeb;
    } else {
      switch (env) {
        case Environment.development:
          current = development;
          break;
        case Environment.staging:
          current = staging;
          break;
        case Environment.production:
          current = production;
          break;
      }
    }

    if (current.enableLogging) {
      debugPrint('AppConfig initialized with environment: ${current.environment}');
      debugPrint('API Base URL: ${current.apiBaseUrl}');
    }
  }

  /// Returns true if the current environment is development.
  static bool get isDevelopment => current.environment == Environment.development;

  /// Returns true if the current environment is staging.
  static bool get isStaging => current.environment == Environment.staging;

  /// Returns true if the current environment is production.
  static bool get isProduction => current.environment == Environment.production;
}
