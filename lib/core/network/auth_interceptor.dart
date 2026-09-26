import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/api_constants.dart';

/// Attaches `Authorization: Bearer <token>` to every request once the user
/// is logged in. Every SAS endpoint except `/auth/login` requires it.
class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage storage;
  final Dio dio;
  Future<String?>? _refreshInFlight;

  AuthInterceptor(this.storage, this.dio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isSessionEndpoint(options.path)) {
      String? token;
      try {
        token = await storage
            .read(key: 'auth_token')
            .timeout(ApiConstants.secureStorageTimeout);
      } on TimeoutException {
        // A damaged or blocked Android keystore must not leave every portal
        // request waiting indefinitely. Continue without a token so Laravel
        // returns a normal 401 and the UI can recover to sign-in.
        token = null;
      }
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final canRetry =
        err.response?.statusCode == 401 &&
        !_isSessionEndpoint(options.path) &&
        options.extra['retried_after_refresh'] != true;

    if (!canRetry) {
      handler.next(err);
      return;
    }

    final accessToken = await _refreshAccessToken();
    if (accessToken == null) {
      handler.next(err);
      return;
    }

    options.headers['Authorization'] = 'Bearer $accessToken';
    options.extra['retried_after_refresh'] = true;
    handler.resolve(await dio.fetch(options));
  }

  /// A browser checkout can outlive the 15-minute access token. When the
  /// app resumes, several requests may receive 401 together; all wait for
  /// one refresh instead of treating a concurrent request as a logout.
  Future<String?> _refreshAccessToken() async {
    final existing = _refreshInFlight;
    if (existing != null) return existing;

    final refresh = _performRefresh();
    _refreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    }
  }

  Future<String?> _performRefresh() async {
    String? refreshToken;
    String? installationId;
    try {
      refreshToken = await storage
          .read(key: 'refresh_token')
          .timeout(ApiConstants.secureStorageTimeout);
      installationId = await storage
          .read(key: 'installation_id')
          .timeout(ApiConstants.secureStorageTimeout);
    } on TimeoutException {
      return null;
    }
    if (refreshToken == null || installationId == null) return null;

    try {
      final refreshClient = Dio(
        BaseOptions(
          baseUrl: dio.options.baseUrl,
          connectTimeout: ApiConstants.requestTimeout,
          receiveTimeout: ApiConstants.requestTimeout,
          sendTimeout: ApiConstants.requestTimeout,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );
      final response = await refreshClient.post(
        '/auth/refresh',
        data: {
          'refresh_token': refreshToken,
          'installation_id': installationId,
        },
      );
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      final session = data is Map ? data['session'] : null;
      final accessToken = session is Map
          ? session['access_token']?.toString()
          : null;
      final rotatedRefreshToken = session is Map
          ? session['refresh_token']?.toString()
          : null;
      if (accessToken == null || rotatedRefreshToken == null) {
        return null;
      }

      await storage.write(key: 'auth_token', value: accessToken);
      await storage.write(key: 'refresh_token', value: rotatedRefreshToken);
      return accessToken;
    } on DioException {
      await storage.delete(key: 'auth_token');
      await storage.delete(key: 'refresh_token');
      return null;
    }
  }

  bool _isSessionEndpoint(String path) =>
      path.contains('/auth/login') || path.contains('/auth/refresh');
}
