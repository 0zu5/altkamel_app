import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_interceptor.dart';
import 'encryption_interceptor.dart';
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

    // Order matters: encrypt the plain-JSON body first, then attach the
    // auth header (the header itself isn't part of the encrypted payload).
    dio.interceptors.add(EncryptionInterceptor());
    dio.interceptors.add(AuthInterceptor(storage));
  }
}
