import 'dart:math';

import 'package:dio/dio.dart';

import '../../../core/constants/sas_messages.dart';
import '../../../core/network/api_client.dart';
import 'portal_models.dart';

class UserResult {
  final UserProfile user;
  final List<String> permissions;

  const UserResult({required this.user, required this.permissions});
}

class InvoicesPage {
  final List<InvoiceInfo> invoices;
  final int currentPage;
  final int lastPage;
  final int total;

  const InvoicesPage({
    required this.invoices,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
  });
}

/// Result of a package-change request: whether the server accepted it,
/// and whether we could confirm (via [PortalRepository.verifyProfileChange])
/// that it actually took effect.
class ChangeSubscriptionResult {
  final bool success;
  final String? message;

  const ChangeSubscriptionResult({required this.success, this.message});
}

/// Talks to the same SASv4 endpoints the website's `useSas.js` composable
/// uses (see sas-api-reference.md / api-user.md in the website repo), with
/// requests encrypted and authenticated the same way the login call is.
class PortalRepository {
  final ApiClient apiClient;

  PortalRepository({required this.apiClient});

  Future<UserResult> getUser() async {
    try {
      final response = await apiClient.dio.get('/user');
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (data is! Map) throw Exception(SasMessages.fetchUserError);
      final permissions = (body['permissions'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      return UserResult(
        user: UserProfile.fromJson(data),
        permissions: permissions,
      );
    } on DioException catch (e) {
      throw Exception(_friendlyError(e, SasMessages.fetchUserError));
    }
  }

  Future<BalanceInfo> getBalance() async {
    try {
      final response = await apiClient.dio.get('/dashboard');
      final data = response.data is Map ? response.data['data'] : null;
      if (data is! Map) throw Exception(SasMessages.fetchBalanceError);
      return BalanceInfo.fromJson(data);
    } on DioException catch (e) {
      throw Exception(_friendlyError(e, SasMessages.fetchBalanceError));
    }
  }

  /// The live source of truth for the running subscription. The website
  /// treats a failure here as non-fatal (it falls back to `/user`'s
  /// `profile_id`), so callers may want to swallow the exception.
  Future<ServiceInfo> getCurrentService() async {
    try {
      final response = await apiClient.dio.get('/service');
      final data = response.data is Map ? response.data['data'] : null;
      if (data is! Map) throw Exception(SasMessages.fetchServiceError);
      return ServiceInfo.fromJson(data);
    } on DioException catch (e) {
      throw Exception(_friendlyError(e, SasMessages.fetchServiceError));
    }
  }

  Future<List<PackageInfo>> getPackages() async {
    try {
      final response = await apiClient.dio.get('/packages');
      final body = response.data;
      final list = body is List ? body : (body is Map ? body['data'] : null);
      if (list is! List) throw Exception(SasMessages.fetchPackagesError);
      return list
          .whereType<Map>()
          .map((e) => PackageInfo.fromJson(e))
          .toList();
    } on DioException catch (e) {
      throw Exception(_friendlyError(e, SasMessages.fetchPackagesError));
    }
  }

  Future<InvoicesPage> getInvoices({int page = 1, int count = 10}) async {
    try {
      final response = await apiClient.dio.post(
        '/index/invoice',
        data: {'page': page, 'count': count, 'sortBy': 'id', 'direction': 'desc'},
      );
      final body = response.data;
      final list = body is Map ? body['data'] : null;
      if (list is! List) throw Exception(SasMessages.fetchInvoicesError);
      return InvoicesPage(
        invoices: list.whereType<Map>().map((e) => InvoiceInfo.fromJson(e)).toList(),
        currentPage: _asInt(body['current_page'], page),
        lastPage: _asInt(body['last_page'], 1),
        total: _asInt(body['total'], list.length),
      );
    } on DioException catch (e) {
      throw Exception(_friendlyError(e, SasMessages.fetchInvoicesError));
    }
  }

  /// POST /traffic — today's data usage. Soft-fails to `(null, null)`
  /// instead of throwing, mirroring the website's `getUserTraffic` (the
  /// dashboard shouldn't break just because this one stat is unavailable).
  Future<({num? rxMb, num? txMb})> getUserTraffic() async {
    try {
      final now = DateTime.now();
      final todayIndex = now.day - 1; // API array is 0-indexed.
      final response = await apiClient.dio.post(
        '/traffic',
        data: {
          'report_type': 'daily',
          'month': now.month,
          'year': now.year,
          'user_id': null,
        },
      );
      final data = response.data is Map ? response.data['data'] : null;
      final rx = data is Map ? data['rx'] : null;
      final tx = data is Map ? data['tx'] : null;
      final rxBytes = rx is List && todayIndex < rx.length ? rx[todayIndex] : null;
      final txBytes = tx is List && todayIndex < tx.length ? tx[todayIndex] : null;
      return (
        rxMb: rxBytes == null ? null : _num(rxBytes) / (1024 * 1024),
        txMb: txBytes == null ? null : _num(txBytes) / (1024 * 1024),
      );
    } catch (_) {
      return (rxMb: null, txMb: null);
    }
  }

  /// POST /redeem — tops up the balance with a 12-digit voucher code.
  Future<void> redeemCode(String pin) async {
    try {
      await apiClient.dio.post('/redeem', data: {'pin': pin});
    } on DioException catch (e) {
      throw Exception(_friendlyError(e, SasMessages.redeemInvalidError));
    }
  }

  /// POST /user/activate — activates the subscription, deducting balance.
  Future<void> activateSubscription() async {
    try {
      await apiClient.dio.post(
        '/user/activate',
        data: {'uuid': _generateUuid(), 'current_password': true},
      );
    } on DioException catch (e) {
      throw Exception(_friendlyError(e, SasMessages.activateError));
    }
  }

  /// POST /user — flips the `auto_renew` flag.
  Future<void> toggleAutoRenew(bool enable) async {
    try {
      await apiClient.dio.post(
        '/user',
        data: {
          'key': 'auto_renew',
          'value': enable ? '1' : '0',
          'current_password': true,
        },
      );
    } on DioException catch (e) {
      throw Exception(_friendlyError(e, SasMessages.autoRenewError));
    }
  }

  /// POST /user — changes the account password. Unlike the other actions,
  /// `current_password` here really is the user's current password (used
  /// by the server to confirm identity), not a boolean flag.
  Future<void> changePassword({
    required String newPassword,
    required String currentPassword,
  }) async {
    try {
      await apiClient.dio.post(
        '/user',
        data: {
          'key': 'password',
          'value': newPassword,
          'current_password': currentPassword,
        },
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 401) {
        throw Exception(SasMessages.passwordWrong);
      }
      throw Exception(
        data is Map
            ? SasMessages.translate(data, SasMessages.passwordError)
            : SasMessages.passwordError,
      );
    }
  }

  /// POST /service — requests a package change. A 200 response is the
  /// server accepting the request; it does not guarantee the subscription
  /// has actually switched yet (see [verifyProfileChange]).
  Future<void> changeSubscription(String targetProfileId) async {
    try {
      await apiClient.dio.post(
        '/service',
        data: {'new_service': targetProfileId, 'current_password': true},
      );
    } on DioException catch (e) {
      throw Exception(_friendlyError(e, SasMessages.changeSubError));
    }
  }

  /// Polls `/service` and `/user` a few times after [changeSubscription] to
  /// confirm the new package actually landed on the server (it can take a
  /// moment to apply) — mirrors the website's `verifyProfileChange`.
  Future<bool> verifyProfileChange(String targetProfileId, {int attempts = 3}) async {
    for (var i = 0; i < attempts; i++) {
      await Future.delayed(Duration(milliseconds: 700 * (i + 1)));
      try {
        final results = await Future.wait([getCurrentService(), getUser()]);
        final service = results[0] as ServiceInfo;
        final user = (results[1] as UserResult).user;
        if (service.profileId?.toString() == targetProfileId ||
            user.profileId?.toString() == targetProfileId) {
          return true;
        }
      } catch (_) {
        // Keep retrying — a transient failure here shouldn't abort the
        // whole verification loop.
      }
    }
    return false;
  }

  /// Pulls a human-readable message out of a failed response, translating
  /// known SAS response codes (e.g. `rsp_insufficient_balance`) to Arabic
  /// and never returning a blank string.
  String _friendlyError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) return SasMessages.translate(data, fallback);
    if (e.response?.statusCode == 401) return SasMessages.sessionExpired;
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return SasMessages.networkError;
    }
    return fallback;
  }

  num _num(dynamic v) => v is num ? v : (num.tryParse(v.toString()) ?? 0);

  int _asInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  String _generateUuid() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // variant 10xx
    String hex(int start, int end) =>
        bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }
}
