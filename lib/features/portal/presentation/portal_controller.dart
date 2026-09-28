import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/constants/sas_messages.dart';
import '../data/portal_models.dart';
import '../data/portal_repository.dart';

/// Shared state for every portal tab (dashboard, packages, invoices,
/// account) — loaded once and reused across tabs instead of each screen
/// re-fetching the same `/user` / `/service` / `/packages` data, the way
/// the website's separate pages each do their own `onMounted` fetch.
class PortalController extends ChangeNotifier {
  final PortalRepository repository;

  PortalController({required this.repository});

  // A freshly constructed controller has not started any work yet. Starting
  // false prevents a blank permanent spinner if Flutter ever restores the
  // shell without running its initial lifecycle callback.
  bool isLoading = false;
  String? loadError;
  int _loadAttempt = 0;

  UserProfile? user;
  List<String> permissions = const [];
  BalanceInfo balance = const BalanceInfo();
  ServiceInfo? service;
  List<PackageInfo> packages = const [];

  bool invoicesLoading = false;
  List<InvoiceInfo> invoices = const [];

  ({num? rxMb, num? txMb}) trafficToday = (rxMb: null, txMb: null);

  /// Generic busy flag for one-off actions (redeem, activate, toggle,
  /// password change) so screens can disable their buttons while a
  /// request is in flight.
  bool actionLoading = false;

  /// Separate from [actionLoading] so normal account actions remain usable
  /// while the user is completing card checkout in their browser.
  bool rechargeLoading = false;
  CardRecharge? latestRecharge;

  bool antennaLocationLoading = false;
  bool antennaLocationSaved = false;

  /// True once the session looks invalid (401 from a core call) so the UI
  /// can send the user back to the login screen.
  bool sessionExpired = false;

  /// The subscription actually running on the server, preferring the live
  /// `/service` value and falling back to `/user`'s `profile_id`.
  dynamic get effectiveProfileId => service?.profileId ?? user?.profileId;

  PackageInfo? get currentPackage {
    if (packages.isEmpty || effectiveProfileId == null) return null;
    for (final p in packages) {
      if (p.id.toString() == effectiveProfileId.toString()) return p;
    }
    return null;
  }

  String get currentPackageName {
    if (currentPackage?.name.isNotEmpty == true) return currentPackage!.name;
    if (service?.profileName?.isNotEmpty == true) return service!.profileName!;
    if (effectiveProfileId != null) return 'باقة #$effectiveProfileId';
    return 'غير متوفر';
  }

  num get currentPackagePrice => currentPackage?.price ?? service?.price ?? 0;

  bool isCurrentPackage(PackageInfo pkg) =>
      pkg.id.toString() == effectiveProfileId?.toString();

  int get remainingDays =>
      balance.remainingDays < 0 ? 0 : balance.remainingDays;

  bool get isAccountActive => remainingDays > 0 || (service?.status ?? false);

  Future<void> loadAll() async {
    final attempt = ++_loadAttempt;
    isLoading = true;
    loadError = null;
    sessionExpired = false;
    repository.invalidatePortalCache();
    notifyListeners();

    // This deliberately sits outside the repository future. It is the final
    // UI safety net for Android platform or plugin failures that prevent a
    // future's own timeout callback from being delivered. A customer must
    // always receive a retry affordance instead of an infinite loader.
    final watchdog = Timer(const Duration(seconds: 18), () {
      if (attempt != _loadAttempt || !isLoading) return;
      isLoading = false;
      loadError =
          'استغرق تحميل بيانات الحساب وقتاً أطول من المتوقع. تحقق من الاتصال ثم أعد المحاولة.';
      notifyListeners();
    });

    try {
      final initial = await repository.getInitialData().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException(
          'تعذر تحميل بيانات الحساب في الوقت المحدد. تحقق من الاتصال ثم أعد المحاولة.',
        ),
      );
      user = initial.userResult.user;
      permissions = initial.userResult.permissions;
      balance = initial.balance;
      packages = initial.packages;
      antennaLocationSaved = initial.antennaLocationSaved;
      service = initial.service;
    } catch (e, stackTrace) {
      debugPrint('Portal initial load failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      if (message == SasMessages.sessionExpired) {
        sessionExpired = true;
      } else {
        loadError = message.isNotEmpty ? message : SasMessages.unexpectedError;
      }
    } finally {
      watchdog.cancel();
      if (attempt == _loadAttempt) {
        isLoading = false;
        notifyListeners();
      }
    }

    // Fetched separately so the main screen isn't blocked on them.
    unawaited(loadInvoices());
    unawaited(loadTraffic());
  }

  Future<void> loadTraffic() async {
    trafficToday = await repository.getUserTraffic();
    notifyListeners();
  }

  Future<void> loadInvoices() async {
    invoicesLoading = true;
    notifyListeners();
    try {
      final page = await repository.getInvoices();
      invoices = page.invoices;
    } catch (_) {
      // Non-fatal — the dashboard/account screens still work without them.
    } finally {
      invoicesLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes balance + packages in the background (e.g. after redeeming
  /// a code or changing a package) without showing the full loading state.
  Future<void> refreshAccountData() async {
    try {
      repository.invalidatePortalCache();
      final results = await Future.wait([
        repository.getBalance(),
        repository.getPackages(),
      ]);
      balance = results[0] as BalanceInfo;
      packages = results[1] as List<PackageInfo>;
      notifyListeners();
    } catch (_) {
      // Best-effort refresh — ignore failures.
    }
    loadInvoices();
  }

  Future<CardRecharge?> createCardRecharge(int amountLyd) async {
    rechargeLoading = true;
    notifyListeners();
    try {
      final recharge = await repository.createCardRecharge(
        amountLyd: amountLyd,
        idempotencyKey: _uuidV4(),
      );
      latestRecharge = recharge;
      return recharge;
    } catch (_) {
      rethrow;
    } finally {
      rechargeLoading = false;
      notifyListeners();
    }
  }

  /// Poll Laravel, rather than trusting the gateway browser return page.
  Future<CardRecharge?> refreshCardRecharge() async {
    final id = latestRecharge?.id;
    if (id == null || id.isEmpty) return null;
    rechargeLoading = true;
    notifyListeners();
    try {
      final recharge = await repository.getCardRecharge(id);
      latestRecharge = recharge;
      if (recharge.state == 'credited') {
        unawaited(refreshAccountData());
      }
      return recharge;
    } finally {
      rechargeLoading = false;
      notifyListeners();
    }
  }

  void clearLatestRecharge() {
    latestRecharge = null;
    notifyListeners();
  }

  Future<String> saveAntennaLocation({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
  }) async {
    antennaLocationLoading = true;
    notifyListeners();
    try {
      await repository.saveAntennaLocation(
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracyMeters,
      );
      antennaLocationSaved = true;
      return 'تم حفظ موقع الهوائي لتسهيل خدمة الدعم.';
    } catch (e) {
      return _messageOf(e, 'تعذر حفظ موقع الهوائي الآن.');
    } finally {
      antennaLocationLoading = false;
      notifyListeners();
    }
  }

  Future<String> removeAntennaLocation() async {
    antennaLocationLoading = true;
    notifyListeners();
    try {
      await repository.removeAntennaLocation();
      antennaLocationSaved = false;
      return 'تمت إزالة موقع الهوائي من حسابك ومن شاشة الدعم.';
    } catch (e) {
      return _messageOf(e, 'تعذر إزالة موقع الهوائي الآن.');
    } finally {
      antennaLocationLoading = false;
      notifyListeners();
    }
  }

  /// Returns an Arabic success/error message on completion.
  Future<String> redeemCode(String pin) async {
    actionLoading = true;
    notifyListeners();
    try {
      await repository.redeemCode(pin);
      await refreshAccountData();
      return SasMessages.redeemSuccess;
    } catch (e) {
      return _messageOf(e, SasMessages.redeemInvalidError);
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }

  Future<String> activateSubscription() async {
    if (currentPackagePrice > 0 && balance.balance < currentPackagePrice) {
      return 'الرصيد غير كافٍ. يرجى تعبئة الرصيد أولاً.';
    }
    actionLoading = true;
    notifyListeners();
    try {
      await repository.activateSubscription();
      await loadAll();
      return SasMessages.activateSuccess;
    } catch (e) {
      return _messageOf(e, SasMessages.activateError);
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }

  Future<String> toggleAutoRenew(bool enable) async {
    if (user == null) return SasMessages.unexpectedError;

    if (enable &&
        currentPackagePrice > 0 &&
        balance.balance < currentPackagePrice) {
      return 'الرصيد غير كافٍ للتجديد التلقائي. يرجى تعبئة الرصيد أولاً.';
    }

    final previous = user!.autoRenew;
    user = user!.copyWith(autoRenew: enable); // optimistic UI
    notifyListeners();

    try {
      await repository.toggleAutoRenew(enable);
      return enable ? SasMessages.autoRenewOn : SasMessages.autoRenewOff;
    } catch (e) {
      user = user!.copyWith(autoRenew: previous); // revert on failure
      notifyListeners();
      return _messageOf(e, SasMessages.autoRenewError);
    }
  }

  Future<String> changePassword({
    required String newPassword,
    required String currentPassword,
  }) async {
    actionLoading = true;
    notifyListeners();
    try {
      await repository.changePassword(
        newPassword: newPassword,
        currentPassword: currentPassword,
      );
      return SasMessages.passwordSuccess;
    } catch (e) {
      return _messageOf(e, SasMessages.passwordError);
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }

  /// Requests a package change, then polls the server to confirm it
  /// actually took — mirrors the website's `handlePkgChange` flow.
  Future<ChangeSubscriptionResult> changeSubscription(
    PackageInfo target,
  ) async {
    final targetId = target.id.toString();
    actionLoading = true;
    notifyListeners();

    try {
      await repository.changeSubscription(targetId);
    } catch (e) {
      actionLoading = false;
      notifyListeners();
      return ChangeSubscriptionResult(
        success: false,
        message: _messageOf(e, SasMessages.changeSubError),
      );
    }

    final verified = await repository.verifyProfileChange(targetId);
    if (verified && user != null) {
      user = user!.copyWith(profileId: targetId);
    }
    actionLoading = false;
    notifyListeners();
    refreshAccountData();

    return ChangeSubscriptionResult(
      success: true,
      message: verified
          ? 'تم التغيير إلى ${target.name} بنجاح ✓'
          : 'تم إرسال طلب التغيير إلى ${target.name}. لم نتمكن من تأكيد التحديث فوراً.',
    );
  }

  String _messageOf(Object e, String fallback) {
    final message = e.toString().replaceFirst('Exception: ', '').trim();
    return message.isNotEmpty ? message : fallback;
  }

  String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
