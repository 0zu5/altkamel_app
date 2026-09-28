import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/constants/sas_messages.dart';
import '../../../core/network/api_client.dart';
import 'portal_models.dart';

class UserResult {
  final UserProfile user;
  final List<String> permissions;

  const UserResult({required this.user, required this.permissions});
}

/// Everything required to paint the first portal screen. Keeping this as one
/// result is intentional: `/portal` is a single Laravel response, so initial
/// navigation must not depend on several concurrent readers of the same
/// request completing in the right order.
class PortalInitialData {
  final UserResult userResult;
  final BalanceInfo balance;
  final ServiceInfo? service;
  final List<PackageInfo> packages;
  final bool antennaLocationSaved;

  const PortalInitialData({
    required this.userResult,
    required this.balance,
    required this.service,
    required this.packages,
    required this.antennaLocationSaved,
  });
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
    // A caller retrying after a platform-level stalled request must be able
    // to create a new request. The old request may still complete later, but
    // it can no longer keep the next screen load attached to it.
    _pendingPortal = null;
  }

  /// Loads the dashboard's essential data from one bounded `/portal` call.
  ///
  /// Do not use [getUser], [getBalance], and [getPackages] concurrently here:
  /// those are convenient individual accessors for later tabs, but fanning
  /// them out during Android startup made a failed shared request capable of
  /// leaving the shell on its loading state.
  Future<PortalInitialData> getInitialData() async {
    try {
      final portal = await _portal();
      final account = _account(portal);
      final customer = _map(account['customer']);
      final billing = _map(account['billing']);
      final subscription = _map(account['subscription']);
      final package = _map(subscription['package']);
      final rawPackages = portal['packages'];
      if (rawPackages is! List) {
        throw Exception(SasMessages.fetchPackagesError);
      }

      final user = UserProfile.fromJson({
        'id': customer['id'] ?? account['customer_id'],
        'username': customer['phone'] ?? account['username'] ?? '',
        'name': customer['name'] ?? account['name'] ?? account['username'],
        'email': customer['email'] ?? account['email'],
        'phone': customer['phone'] ?? account['phone'],
        'balance': billing['balance'],
        'auto_renew': account['auto_renew'],
        'profile_id': subscription['profile_id'] ?? package['id'],
        'registered_on': customer['created_at'] ?? account['created_at'],
      });
      final service = subscription.isEmpty
          ? null
          : ServiceInfo.fromJson({
              'profile_id': subscription['profile_id'] ?? package['id'],
              'profile_name': package['name'],
              'expiration': subscription['expires_at'],
              'status':
                  subscription['status']?.toString().toLowerCase() == 'active',
              'price': subscription['price'] ?? package['price'],
            });
      final location = _map(account['antenna_location']);

      return PortalInitialData(
        userResult: UserResult(user: user, permissions: const <String>[]),
        balance: BalanceInfo.fromJson(billing),
        service: service,
        packages: rawPackages
            .whereType<Map>()
            .map((item) => PackageInfo.fromJson(item))
            .toList(),
        antennaLocationSaved: location['saved'] == true,
      );
    } on DioException catch (e) {
      throw Exception(_friendlyError(e, SasMessages.fetchUserError));
    }
  }

  /// `/portal` is optimized for billing and subscription data. The signed-in
  /// customer identity is returned separately by Laravel and is refreshed in
  /// the background so a slow profile request never delays the dashboard.
  Future<UserProfile?> getAuthenticatedProfile() async {
    try {
      final response = await apiClient.dio
          .get('/auth/me')
          .timeout(const Duration(seconds: 5));
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (data is! Map) return null;
      return UserProfile.fromJson(Map<String, dynamic>.from(data));
    } on DioException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  Future<UserResult> getUser() async {
    try {
      // The portal payload is sufficient to render the dashboard. Some
      // Android installations have intermittently delayed `/auth/me` while
      // `/portal` already succeeds, so never let that optional profile call
      // block the customer after a successful sign-in.
      final account = _account(await _portal());
      final subscription = _map(account['subscription']);
      final package = _map(subscription['package']);

      Map? profile;
      try {
        final response = await apiClient.dio
            .get('/auth/me')
            .timeout(const Duration(seconds: 5));
        final body = response.data;
        final data = body is Map ? body['data'] : null;
        if (data is Map) profile = data;
      } catch (_) {
        // Fall through to the portal-based customer profile below.
      }

      final customer = _map(account['customer']);
      return UserResult(
        user: UserProfile.fromJson({
          ...?profile,
          'id': profile?['id'] ?? customer['id'] ?? account['customer_id'],
          'username':
              profile?['phone'] ??
              customer['phone'] ??
              account['username'] ??
              '',
          'name':
              profile?['name'] ??
              customer['name'] ??
              account['name'] ??
              account['username'],
          'email': profile?['email'] ?? customer['email'] ?? account['email'],
          'phone': profile?['phone'] ?? customer['phone'] ?? account['phone'],
          'balance': _map(account['billing'])['balance'],
          'auto_renew': account['auto_renew'],
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

  /// Only the existence and save time are exposed to the customer. Raw
  /// antenna coordinates remain unavailable outside the support workflow.
  Future<bool> hasSavedAntennaLocation() async {
    final location = _map(_account(await _portal())['antenna_location']);
    return location['saved'] == true;
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

  /// Creates a card-recharge order in Laravel. Laravel chooses and verifies
  /// the payment gateway session; Flutter only opens the returned HTTPS URL.
  Future<CardRecharge> createCardRecharge({
    required int amountLyd,
    required String idempotencyKey,
  }) async {
    try {
      final account = _account(await _portal());
      final sasAccountId = account['id'];
      if (sasAccountId is! num && int.tryParse('$sasAccountId') == null) {
        throw Exception('تعذر تحديد الحساب المراد شحنه.');
      }

      final response = await apiClient.dio.post(
        '/payments/card/checkout',
        data: {
          'sas_account_id': sasAccountId,
          'amount_lyd': amountLyd,
          'idempotency_key': idempotencyKey,
        },
      );
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (data is! Map) throw Exception('تعذر بدء عملية الشحن.');
      return CardRecharge.fromJson(data);
    } on DioException catch (e) {
      throw Exception(_friendlyPaymentError(e));
    }
  }

  /// Reads the Laravel payment record. This is the source of truth after a
  /// browser return; a return page alone never proves that a payment settled.
  Future<CardRecharge> getCardRecharge(String paymentId) async {
    try {
      final response = await apiClient.dio.get('/payments/$paymentId');
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (data is! Map) throw Exception('تعذر التحقق من حالة عملية الشحن.');
      return CardRecharge.fromJson(data);
    } on DioException catch (e) {
      throw Exception(_friendlyPaymentError(e));
    }
  }

  /// Stores a customer-confirmed antenna location for the signed-in account.
  /// Coordinates are acquired by the presentation layer only after explicit
  /// consent and a platform permission grant.
  Future<void> saveAntennaLocation({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
  }) async {
    try {
      final account = _account(await _portal());
      final sasAccountId = account['id'];
      if (sasAccountId is! num && int.tryParse('$sasAccountId') == null) {
        throw Exception('تعذر تحديد الحساب المراد حفظ موقعه.');
      }

      await apiClient.dio.post(
        '/accounts/$sasAccountId/antenna-location',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'accuracy_meters': accuracyMeters,
          'consent': true,
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception(SasMessages.sessionExpired);
      }
      if (e.response?.statusCode == 403) {
        throw Exception('لا تملك صلاحية حفظ موقع هذا الحساب.');
      }
      if (e.response?.statusCode == 422) {
        throw Exception('تعذر التحقق من بيانات الموقع. حاول مرة أخرى.');
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        throw Exception(SasMessages.networkError);
      }
      throw Exception('تعذر حفظ موقع الهوائي الآن. حاول مرة أخرى لاحقاً.');
    }
  }

  /// Removes the customer's active support location. Laravel retires it from
  /// support views immediately and applies the server-side retention policy.
  Future<void> removeAntennaLocation() async {
    try {
      final account = _account(await _portal());
      final sasAccountId = account['id'];
      if (sasAccountId is! num && int.tryParse('$sasAccountId') == null) {
        throw Exception('تعذر تحديد الحساب المراد إزالة موقعه.');
      }

      await apiClient.dio.delete('/accounts/$sasAccountId/antenna-location');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception(SasMessages.sessionExpired);
      }
      if (e.response?.statusCode == 403) {
        throw Exception('لا تملك صلاحية إزالة موقع هذا الحساب.');
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        throw Exception(SasMessages.networkError);
      }
      throw Exception('تعذر إزالة موقع الهوائي الآن. حاول مرة أخرى لاحقاً.');
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

  String _friendlyPaymentError(DioException e) {
    if (e.response?.statusCode == 401) return SasMessages.sessionExpired;
    if (e.response?.statusCode == 403) return 'لا تملك صلاحية شحن هذا الحساب.';
    if (e.response?.statusCode == 422) {
      return 'تحقق من مبلغ الشحن وحاول مرة أخرى.';
    }
    if (e.response?.statusCode == 503) {
      return 'خدمة الشحن بالبطاقة غير متاحة مؤقتاً.';
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return SasMessages.networkError;
    }
    return 'تعذر إكمال عملية الشحن الآن. حاول مرة أخرى لاحقاً.';
  }

  num _num(dynamic v) => v is num ? v : (num.tryParse(v.toString()) ?? 0);

  Future<Map<String, dynamic>> _portal() {
    if (_portalCache != null) return Future.value(_portalCache);
    if (_pendingPortal != null) return _pendingPortal!;

    // Dio's transport timeouts cover normal sockets, but iOS can leave a
    // request pending while the app resumes or its network stack changes.
    // This outer deadline guarantees the dashboard can leave its loading
    // state and offer a retry even in that platform-level failure mode.
    _pendingPortal = apiClient.dio
        .get('/portal')
        .timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw TimeoutException(
            'تعذر تحميل بيانات الحساب. تحقق من الاتصال ثم أعد المحاولة.',
          ),
        )
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
