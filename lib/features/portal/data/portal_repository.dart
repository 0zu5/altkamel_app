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

/// Reads the customer portal exclusively from the Altkamel Laravel API.
class PortalRepository {
  final ApiClient apiClient;
  Map<String, dynamic>? _portalCache;
  Future<Map<String, dynamic>>? _pendingPortal;

  PortalRepository({required this.apiClient});

  void invalidatePortalCache() {
    _portalCache = null;
  }

  Future<UserResult> getUser() async {
    try {
      final results = await Future.wait([
        apiClient.dio.get('/auth/me'),
        _portal(),
      ]);
      final response = results[0] as Response<dynamic>;
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (data is! Map) throw Exception(SasMessages.fetchUserError);
      final account = _account(results[1] as Map<String, dynamic>);
      final subscription = _map(account['subscription']);
      final package = _map(subscription['package']);
      return UserResult(
        user: UserProfile.fromJson({
          ...data,
          'username': data['phone'] ?? '',
          'profile_id': subscription['profile_id'] ?? package['id'],
        }),
        permissions: const <String>[],
      );
    } on DioException catch (e) {
      throw Exception(_friendlyError(e, SasMessages.fetchUserError));
    }
  }

  Future<BalanceInfo> getBalance() async {
    try {
      final billing = _map(_account(await _portal())['billing']);
      return BalanceInfo.fromJson(billing);
    } on DioException catch (e) {
      throw Exception(_friendlyError(e, SasMessages.fetchBalanceError));
    }
  }

  /// The live source of truth for the running subscription. The website
  /// treats a failure here as non-fatal (it falls back to `/user`'s
  /// `profile_id`), so callers may want to swallow the exception.
  Future<ServiceInfo> getCurrentService() async {
    try {
      final subscription = _map(_account(await _portal())['subscription']);
      if (subscription.isEmpty) throw Exception(SasMessages.fetchServiceError);
      final package = _map(subscription['package']);
      return ServiceInfo.fromJson({
        'profile_id': subscription['profile_id'] ?? package['id'],
        'profile_name': package['name'],
        'expiration': subscription['expires_at'],
        'status': subscription['status']?.toString().toLowerCase() == 'active',
        'price': subscription['price'] ?? package['price'],
      });
    } on DioException catch (e) {
      throw Exception(_friendlyError(e, SasMessages.fetchServiceError));
    }
  }

  Future<List<PackageInfo>> getPackages() async {
    try {
      final list = (await _portal())['packages'];
      if (list is! List) throw Exception(SasMessages.fetchPackagesError);
      return list.whereType<Map>().map((e) => PackageInfo.fromJson(e)).toList();
    } on DioException catch (e) {
      throw Exception(_friendlyError(e, SasMessages.fetchPackagesError));
    }
  }

  Future<InvoicesPage> getInvoices({int page = 1, int count = 10}) async {
    try {
      final list = _account(await _portal())['invoices'];
      if (list is! List) throw Exception(SasMessages.fetchInvoicesError);
      return InvoicesPage(
        invoices: list
            .whereType<Map>()
            .map((e) => InvoiceInfo.fromJson(e))
            .toList(),
        currentPage: page,
        lastPage: 1,
        total: list.length,
      );
    } on DioException catch (e) {
      throw Exception(_friendlyError(e, SasMessages.fetchInvoicesError));
    }
  }

  /// Today's usage is returned from Laravel's local snapshot, not SAS.
  Future<({num? rxMb, num? txMb})> getUserTraffic() async {
    try {
      final usage = _map(_account(await _portal())['usage']);
      final today = _map(usage['today']);
      final rxBytes = today['rx_bytes'];
      final txBytes = today['tx_bytes'];
      return (
        rxMb: rxBytes == null ? null : _num(rxBytes) / (1024 * 1024),
        txMb: txBytes == null ? null : _num(txBytes) / (1024 * 1024),
      );
    } catch (_) {
      return (rxMb: null, txMb: null);
    }
  }

  /// Mutating portal features are intentionally unavailable until Laravel
  /// implements and audits their dedicated endpoints.
  Future<void> redeemCode(String pin) async {
    throw UnsupportedError('Voucher redemption is not available yet.');
  }

  /// POST /user/activate — activates the subscription, deducting balance.
  Future<void> activateSubscription() async {
    throw UnsupportedError('Subscription activation is not available yet.');
  }

  /// POST /user — flips the `auto_renew` flag.
  Future<void> toggleAutoRenew(bool enable) async {
    throw UnsupportedError('Auto-renew changes are not available yet.');
  }

  /// POST /user — changes the account password. Unlike the other actions,
  /// `current_password` here really is the user's current password (used
  /// by the server to confirm identity), not a boolean flag.
  Future<void> changePassword({
    required String newPassword,
    required String currentPassword,
  }) async {
    throw UnsupportedError('Password changes are not available yet.');
  }

  /// POST /service — requests a package change. A 200 response is the
  /// server accepting the request; it does not guarantee the subscription
  /// has actually switched yet (see [verifyProfileChange]).
  Future<void> changeSubscription(String targetProfileId) async {
    throw UnsupportedError('Package changes are not available yet.');
  }

  /// Polls `/service` and `/user` a few times after [changeSubscription] to
  /// confirm the new package actually landed on the server (it can take a
  /// moment to apply) — mirrors the website's `verifyProfileChange`.
  Future<bool> verifyProfileChange(
    String targetProfileId, {
    int attempts = 3,
  }) async {
    return false;
  }

  /// Pulls a human-readable message out of a failed response, translating
  /// known SAS response codes (e.g. `rsp_insufficient_balance`) to Arabic
  /// and never returning a blank string.
  String _friendlyError(DioException e, String fallback) {
    if (e.response?.statusCode == 401) return SasMessages.sessionExpired;
    final data = e.response?.data;
    if (data is Map) return SasMessages.translate(data, fallback);
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return SasMessages.networkError;
    }
    return fallback;
  }

  num _num(dynamic v) => v is num ? v : (num.tryParse(v.toString()) ?? 0);

  Future<Map<String, dynamic>> _portal() {
    if (_portalCache != null) return Future.value(_portalCache);
    if (_pendingPortal != null) return _pendingPortal!;

    _pendingPortal = apiClient.dio
        .get('/portal')
        .then((response) {
          final body = response.data;
          final data = body is Map ? body['data'] : null;
          if (data is! Map) throw Exception('تعذر تحميل بيانات الحساب.');
          final portal = Map<String, dynamic>.from(data);
          _portalCache = portal;
          return portal;
        })
        .whenComplete(() => _pendingPortal = null);
    return _pendingPortal!;
  }

  Map<String, dynamic> _account(Map<String, dynamic> portal) {
    final accounts = portal['accounts'];
    if (accounts is! List || accounts.isEmpty || accounts.first is! Map) {
      throw Exception('لا يوجد حساب مرتبط بالتطبيق.');
    }
    return Map<String, dynamic>.from(accounts.first as Map);
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}
