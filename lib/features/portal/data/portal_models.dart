/// Data models for the SASv4 user-portal endpoints, matching the shapes
/// documented in the website's `api-user.md` / `sas-api-reference.md` and
/// consumed by its `useSas.js` composable.
library;

num _toNum(dynamic v, [num fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v;
  return num.tryParse(v.toString()) ?? fallback;
}

bool _toBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase();
  return s == 'true' || s == '1';
}

String? _toStringOrNull(dynamic v) => v?.toString();

class LoanInfo {
  final num? rxMb;
  final num? txMb;
  final num? rxtxMb;
  final num? days;

  const LoanInfo({this.rxMb, this.txMb, this.rxtxMb, this.days});

  factory LoanInfo.fromJson(Map? json) {
    if (json == null) return const LoanInfo();
    return LoanInfo(
      rxMb: json['rx_mb'] == null ? null : _toNum(json['rx_mb']),
      txMb: json['tx_mb'] == null ? null : _toNum(json['tx_mb']),
      rxtxMb: json['rxtx_mb'] == null ? null : _toNum(json['rxtx_mb']),
      days: json['days'] == null ? null : _toNum(json['days']),
    );
  }
}

/// GET /user
class UserProfile {
  final int? id;
  final String username;
  final String? name;
  final String? firstname;
  final String? lastname;
  final String? email;
  final String? phone;
  final num balance;
  final bool autoRenew;
  final dynamic profileId;
  final String? registeredOn;

  const UserProfile({
    this.id,
    required this.username,
    this.name,
    this.firstname,
    this.lastname,
    this.email,
    this.phone,
    this.balance = 0,
    this.autoRenew = false,
    this.profileId,
    this.registeredOn,
  });

  factory UserProfile.fromJson(Map json) {
    return UserProfile(
      id: json['id'] == null ? null : _toNum(json['id']).toInt(),
      username: (json['username'] ?? '').toString(),
      name: _toStringOrNull(json['name']),
      firstname: _toStringOrNull(json['firstname']),
      lastname: _toStringOrNull(json['lastname']),
      email: _toStringOrNull(json['email']),
      phone: _toStringOrNull(json['phone']),
      balance: _toNum(json['balance']),
      autoRenew: _toBool(json['auto_renew']),
      profileId: json['profile_id'],
      registeredOn: _toStringOrNull(json['registered_on']?['date']),
    );
  }

  UserProfile copyWith({dynamic profileId, bool? autoRenew}) {
    return UserProfile(
      id: id,
      username: username,
      name: name,
      firstname: firstname,
      lastname: lastname,
      email: email,
      phone: phone,
      balance: balance,
      autoRenew: autoRenew ?? this.autoRenew,
      profileId: profileId ?? this.profileId,
      registeredOn: registeredOn,
    );
  }

  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    if ((firstname ?? '').isNotEmpty || (lastname ?? '').isNotEmpty) {
      return '${firstname ?? ''} ${lastname ?? ''}'.trim();
    }
    return username;
  }
}

/// GET /dashboard
class BalanceInfo {
  final num balance;
  final int remainingDays;
  final int unpaidInvoices;
  final String remainingTraffic;
  final String remainingUptime;
  final LoanInfo loan;

  const BalanceInfo({
    this.balance = 0,
    this.remainingDays = 0,
    this.unpaidInvoices = 0,
    this.remainingTraffic = '_',
    this.remainingUptime = '_',
    this.loan = const LoanInfo(),
  });

  factory BalanceInfo.fromJson(Map json) {
    return BalanceInfo(
      balance: _toNum(json['balance']),
      remainingDays: _toNum(json['remaining_days']).toInt(),
      unpaidInvoices: _toNum(json['unpaid_invoices']).toInt(),
      remainingTraffic: (json['remaining_traffic'] ?? '_').toString(),
      remainingUptime: (json['remaining_uptime'] ?? '_').toString(),
      loan: LoanInfo.fromJson(json['loan'] as Map?),
    );
  }
}

/// GET /service — the live source of truth for the running subscription.
class ServiceInfo {
  final dynamic profileId;
  final String? profileName;
  final String? expiration;
  final bool status;
  final num price;

  const ServiceInfo({
    this.profileId,
    this.profileName,
    this.expiration,
    this.status = false,
    this.price = 0,
  });

  factory ServiceInfo.fromJson(Map json) {
    return ServiceInfo(
      profileId: json['profile_id'],
      profileName: _toStringOrNull(json['profile_name']),
      expiration: _toStringOrNull(json['expiration']),
      status: _toBool(json['status']),
      price: _toNum(json['price']),
    );
  }
}

/// One entry from GET /packages
class PackageInfo {
  final dynamic id;
  final String name;
  final num price;

  const PackageInfo({required this.id, required this.name, this.price = 0});

  factory PackageInfo.fromJson(Map json) {
    return PackageInfo(
      id: json['id'],
      name: (json['name'] ?? '').toString(),
      price: _toNum(json['price']),
    );
  }
}

/// One entry from POST /index/invoice
class InvoiceInfo {
  final int id;
  final String invoiceNumber;
  final String? type;
  final num amount;
  final String? description;
  final bool paid;
  final String? createdAt;
  final String? paymentMethod;
  final String? dueDate;

  const InvoiceInfo({
    required this.id,
    required this.invoiceNumber,
    this.type,
    this.amount = 0,
    this.description,
    this.paid = false,
    this.createdAt,
    this.paymentMethod,
    this.dueDate,
  });

  factory InvoiceInfo.fromJson(Map json) {
    return InvoiceInfo(
      id: _toNum(json['id']).toInt(),
      invoiceNumber: (json['invoice_number'] ?? '').toString(),
      type: _toStringOrNull(json['type']),
      amount: _toNum(json['amount']),
      description: _toStringOrNull(json['description']),
      paid: _toBool(json['paid']),
      createdAt: _toStringOrNull(json['created_at'] ?? json['issued_at']),
      paymentMethod: _toStringOrNull(json['payment_method']),
      dueDate: _toStringOrNull(json['due_date'] ?? json['due_at']),
    );
  }
}

/// A mobile card-recharge transaction owned by the Laravel API.
///
/// The checkout URL is intentionally returned only after Laravel has created
/// the payment record. The app must never construct a gateway URL itself or
/// send card data to any service other than the browser checkout.
class CardRecharge {
  final String id;
  final String state;
  final int amountMinor;
  final String currency;
  final Uri? checkoutUrl;
  final DateTime? settledAt;
  final DateTime? sasCreditedAt;

  const CardRecharge({
    required this.id,
    required this.state,
    required this.amountMinor,
    required this.currency,
    this.checkoutUrl,
    this.settledAt,
    this.sasCreditedAt,
  });

  factory CardRecharge.fromJson(Map json) {
    final rawCheckoutUrl = _toStringOrNull(json['checkout_url']);
    return CardRecharge(
      id: (json['id'] ?? '').toString(),
      state: (json['state'] ?? 'pending_review').toString(),
      amountMinor: _toNum(json['amount_minor']).toInt(),
      currency: (json['currency'] ?? 'LYD').toString(),
      checkoutUrl: rawCheckoutUrl == null || rawCheckoutUrl.isEmpty
          ? null
          : Uri.tryParse(rawCheckoutUrl),
      settledAt: DateTime.tryParse(_toStringOrNull(json['settled_at']) ?? ''),
      sasCreditedAt: DateTime.tryParse(
        _toStringOrNull(json['sas_credited_at']) ?? '',
      ),
    );
  }

  num get amountLyd => amountMinor / 1000;

  bool get isFinal =>
      const {'credited', 'declined', 'cancelled'}.contains(state);
}
