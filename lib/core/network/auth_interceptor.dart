import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Attaches `Authorization: Bearer <token>` to every request once the user
/// is logged in. Every SAS endpoint except `/auth/login` requires it.
class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage storage;
  final Dio dio;
  bool _refreshing = false;

  AuthInterceptor(this.storage, this.dio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isSessionEndpoint(options.path)) {
      final token = await storage.read(key: 'auth_token');
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
        options.extra['retried_after_refresh'] != true &&
        !_refreshing;

    if (!canRetry) {
      handler.next(err);
      return;
    }

    final refreshToken = await storage.read(key: 'refresh_token');
    final installationId = await storage.read(key: 'installation_id');
    if (refreshToken == null || installationId == null) {
      handler.next(err);
      return;
    }

    _refreshing = true;
    try {
      final refreshClient = Dio(
        BaseOptions(
          baseUrl: dio.options.baseUrl,
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
        handler.next(err);
        return;
      }

      await storage.write(key: 'auth_token', value: accessToken);
      await storage.write(key: 'refresh_token', value: rotatedRefreshToken);
      options.headers['Authorization'] = 'Bearer $accessToken';
      options.extra['retried_after_refresh'] = true;
      handler.resolve(await dio.fetch(options));
    } on DioException {
      await storage.delete(key: 'auth_token');
      await storage.delete(key: 'refresh_token');
      handler.next(err);
    } finally {
      _refreshing = false;
    }
  }

  bool _isSessionEndpoint(String path) =>
      path.contains('/auth/login') || path.contains('/auth/refresh');
}
