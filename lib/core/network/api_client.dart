import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_interceptor.dart';
import '../constants/api_constants.dart';

class ApiClient {
  late final Dio dio;

  ApiClient({required FlutterSecureStorage storage}) {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Laravel accepts standard JSON over TLS. SAS payload encryption is
    // deliberately not part of the mobile app architecture.
    dio.interceptors.add(AuthInterceptor(storage, dio));
  }
}
