import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class AuthRepository {
  final ApiClient apiClient;
  final FlutterSecureStorage storage;

  AuthRepository({required this.apiClient, required this.storage});

  Future<bool> login(String username, String password) async {
    try {
      final installationId = await _installationId();
      final response = await apiClient.dio.post(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
          'installation_id': installationId,
          'platform': _platform,
          'app_version': '1.0.0',
          'os_version': Platform.operatingSystemVersion,
          'locale': Platform.localeName.split('.').first,
        },
      );

      if (response.statusCode == 201) {
        final data = response.data;
        if (data is Map) {
          final session = data['data']?['session'];
          final token = session is Map ? session['access_token'] : null;
          final refreshToken = session is Map ? session['refresh_token'] : null;
          if (token != null && refreshToken != null) {
            await storage.write(key: 'auth_token', value: token.toString());
            await storage.write(
              key: 'refresh_token',
              value: refreshToken.toString(),
            );
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
    try {
      final token = await storage
          .read(key: 'auth_token')
          .timeout(ApiConstants.secureStorageTimeout);
      return token != null && token.isNotEmpty;
    } on TimeoutException {
      // A keychain/storage problem must show the login screen, never an
      // indefinite startup loader. It does not delete the existing session.
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await apiClient.dio.post('/auth/logout');
    } finally {
      await storage.delete(key: 'auth_token');
      await storage.delete(key: 'refresh_token');
    }
  }

  Future<String> _installationId() async {
    final existing = await storage.read(key: 'installation_id');
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String part(int from, int to) => bytes
        .sublist(from, to)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final created =
        '${part(0, 4)}-${part(4, 6)}-${part(6, 8)}-${part(8, 10)}-${part(10, 16)}';
    await storage.write(key: 'installation_id', value: created);
    return created;
  }

  String get _platform => Platform.isIOS ? 'ios' : 'android';

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
