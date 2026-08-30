/// Arabic user-facing messages for the SAS API, ported from the website's
/// `composables/sas-messages.json` so both apps show identical wording.
class SasMessages {
  SasMessages._();

  static const networkError = 'تعذّر الاتصال بالخادم. تحقق من الإنترنت وحاول مجدداً.';
  static const unexpectedError = 'حدث خطأ غير متوقع. يرجى إعادة المحاولة.';
  static const sessionExpired = 'انتهت صلاحية الجلسة.';
  static const genericError = 'حدث خطأ. حاول مجدداً.';
  static const fetchUserError = 'تعذّر جلب بيانات الحساب.';
  static const fetchBalanceError = 'تعذّر جلب بيانات الرصيد.';
  static const fetchPackagesError = 'تعذّر جلب الباقات.';
  static const fetchInvoicesError = 'تعذّر جلب الفواتير.';
  static const fetchServiceError = 'تعذّر جلب بيانات الاشتراك الحالي.';
  static const changeSubError = 'فشل تغيير الباقة.';
  static const changeSubSuccess = 'تم تغيير الباقة بنجاح.';
  static const changeSubForbidden = 'لا تملك صلاحية تغيير الباقة من البوابة. يرجى التواصل مع الدعم الفني.';
  static const changeSubSamePackage = 'أنت تستخدم هذه الباقة حالياً.';
  static const autoRenewError = 'عذراً، لا تملك صلاحية تغيير التجديد التلقائي.';
  static const autoRenewOn = 'تم تفعيل التجديد التلقائي.';
  static const autoRenewOff = 'تم إيقاف التجديد التلقائي.';
  static const redeemSuccess = 'تم شحن الرصيد بنجاح!';
  static const redeemInvalidError = 'فشل استرداد الكرت. تحقق من صحة الرمز.';
  static const activateSuccess = 'تم تفعيل الاشتراك بنجاح!';
  static const activateError = 'فشل تفعيل الاشتراك.';
  static const passwordSuccess = 'تم تغيير كلمة المرور بنجاح.';
  static const passwordWrong = 'كلمة المرور الحالية غير صحيحة.';
  static const passwordError = 'فشل تغيير كلمة المرور.';

  /// Server response codes (e.g. `rsp_invalid_username_or_password`) mapped
  /// to their Arabic explanation.
  static const Map<String, String> errors = {
    'rsp_invalid_username_or_password': 'اسم المستخدم أو كلمة المرور غير صحيحة.',
    'rsp_user_disabled': 'الحساب موقوف. تواصل مع الدعم الفني.',
    'rsp_user_not_found': 'المستخدم غير موجود.',
    'rsp_invalid_payload': 'خطأ في التشفير.',
    'rsp_account_expired': 'انتهت صلاحية الحساب.',
    'rsp_unauthenticated': 'انتهت صلاحية الجلسة.',
    'rsp_service_change_success': 'تم تغيير الباقة بنجاح.',
    'rsp_success': 'تمت العملية بنجاح.',
    'rsp_invalid_pin': 'رمز البطاقة غير صحيح أو مستخدم مسبقاً.',
    'rsp_invalid_card': 'رمز الكرت غير صحيح أو تم استخدامه مسبقاً.',
    'rsp_card_already_used': 'هذا الكرت تم استخدامه مسبقاً.',
    'rsp_card_expired': 'انتهت صلاحية هذا الكرت.',
    'rsp_insufficient_balance': 'الرصيد غير كافٍ لإتمام العملية.',
    'rsp_voucher_already_used': 'هذا الكرت تم استخدامه مسبقاً.',
  };

  /// Pulls a code (`error`/`message`/`code` field) out of a decoded SAS JSON
  /// response and returns its Arabic translation, falling back to
  /// [fallback] when the code isn't one we recognize.
  static String translate(Map? response, String fallback) {
    final code = response?['error'] ?? response?['message'] ?? response?['code'];
    if (code is String && errors.containsKey(code)) return errors[code]!;
    return fallback;
  }
}
