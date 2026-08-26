import 'dart:convert';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../utils/crypto_utils.dart';

class EncryptionInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Only intercept POST requests with a body
    if (options.method == 'POST' && options.data != null) {
      // 1. Convert the original payload (Map) to a JSON string
      final String rawJson = jsonEncode(options.data);

      // 2. Encrypt the JSON string
      final String encryptedPayload = CryptoUtils.encryptAESCryptoJS(
        rawJson,
        ApiConstants.aesKey,
      );

      // 3. Wrap it in the payload structure expected by the backend
      options.data = {'payload': encryptedPayload};
    }

    handler.next(options);
  }
}
