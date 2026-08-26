import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/api_client.dart';

class AuthRepository {
  final ApiClient apiClient;
  final FlutterSecureStorage storage;

  AuthRepository({required this.apiClient, required this.storage});

  Future<bool> login(String username, String password) async {
    try {
      // The EncryptionInterceptor will automatically encrypt this map!
      // NOTE: the SASv4 endpoint is `/auth/login` (not `/login`), and it
      // requires a `language` field on top of username/password — see
      // sas-api-reference.md in the website repo.
      final response = await apiClient.dio.post(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
          'language': 'en',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          final token = data['token'] ?? data['access_token'];
          if (token != null) {
            await storage.write(key: 'auth_token', value: token.toString());
            return true;
          }

          // HTTP 200 but no token: some SAS responses report failure this
          // way (e.g. {"status": 401, "message": "rsp_invalid_..."}).
          // Surface that message instead of a generic one when present.
          final serverMessage = data['message'] ?? data['error'];
          if (serverMessage is String && serverMessage.trim().isNotEmpty) {
            throw Exception(serverMessage);
          }
        }
      }
      return false;
    } on DioException catch (e) {
      debugPrint('=== LOGIN ERROR (Dio) ===');
      debugPrint('status: ${e.response?.statusCode}');
      debugPrint('body: ${e.response?.data}');
      throw Exception(_extractMessage(e));
    } catch (e) {
      throw Exception('حدث خطأ غير متوقع: $e');
    }
  }

  /// Whether a session token is already stored (used to skip straight to
  /// the portal on app start, mirroring the website's login-page check).
  Future<bool> isAuthenticated() async {
    final token = await storage.read(key: 'auth_token');
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    await storage.delete(key: 'auth_token');
  }

  /// Pulls a human-readable message out of a failed response, whatever its
  /// shape (JSON map, plain string/HTML, or nothing at all) — and never
  /// returns a blank string, which used to render as an empty error banner.
  String _extractMessage(DioException e) {
    const fallback = 'تعذر تسجيل الدخول، يرجى التحقق من بياناتك.';
    final data = e.response?.data;

    if (data is Map) {
      final message = data['message'] ?? data['error'];
      if (message is String && message.trim().isNotEmpty) return message;
    } else if (data is String) {
      final trimmed = data.trim();
      // Skip HTML error pages (e.g. a 404/500 page from the wrong host).
      if (trimmed.isNotEmpty && !trimmed.startsWith('<')) return trimmed;
    }

    return fallback;
  }
}
