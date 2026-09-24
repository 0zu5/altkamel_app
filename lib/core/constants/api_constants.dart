class ApiConstants {
  /// The mobile app talks only to the Altkamel Laravel API.
  ///
  /// Local and CI builds use staging unless an explicit build-time value is
  /// supplied. Release builds must set API_BASE_URL to api.altkamel.ly.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api-staging.altkamel.ly/api/v1',
  );
}
