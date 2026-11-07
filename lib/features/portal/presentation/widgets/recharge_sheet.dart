import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/portal_models.dart';
import '../portal_controller.dart';
import 'payment_checkout_screen.dart';
import 'redeem_dialog.dart';

/// Lets the customer deliberately choose a recharge method. Voucher codes
/// stay inside the app; card payments always continue to the trusted gateway.
Future<void> showRechargeOptionsSheet(
  BuildContext context,
  PortalController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'اختر طريقة الشحن',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner_rounded),
              title: const Text('قسيمة شحن'),
              subtitle: const Text('أدخل رمز القسيمة أو امسح رمز QR'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final message = await showRedeemDialog(context, controller);
                if (message != null && context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.credit_card_rounded),
              title: const Text('دفع بالبطاقة'),
              subtitle: const Text('إتمام الدفع الآمن عبر مواملة'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showRechargeSheet(context, controller);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// Starts a card recharge through Laravel, then keeps the payment status in
/// view while the browser-hosted Moamalat checkout is completing.
Future<void> showRechargeSheet(
  BuildContext context,
  PortalController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RechargeSheet(controller: controller),
  );
}

class _RechargeSheet extends StatefulWidget {
  final PortalController controller;

  const _RechargeSheet({required this.controller});

  @override
  State<_RechargeSheet> createState() => _RechargeSheetState();
}

class _RechargeSheetState extends State<_RechargeSheet>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 5);
  static const _maximumAutomaticPolls = 24;

  final _amountController = TextEditingController(text: '10');
  Timer? _poller;
  String? _error;
  bool _openingCheckout = false;
  int _automaticPolls = 0;

  PortalController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restorePendingRecharge());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        controller.latestRecharge != null) {
      // The payment return URL opens the app, but it is not itself proof of
      // settlement. Query Laravel immediately when the browser gives focus
      // back, rather than waiting for the next periodic tick.
      _startPolling();
    }
  }

  Future<void> _startCheckout() async {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount < 1) {
      setState(() => _error = 'أدخل مبلغاً صحيحاً يبدأ من 1 دينار ليبي.');
      return;
    }

    setState(() => _error = null);
    try {
      final recharge = await controller.createCardRecharge(amount);
      if (!mounted || recharge == null) return;
      final url = recharge.checkoutUrl;
      if (url == null ||
          url.scheme != 'https' ||
          url.host != 'pay.altkamel.ly') {
        setState(() => _error = 'تعذر فتح صفحة الدفع الآمنة.');
        return;
      }

      setState(() => _openingCheckout = true);
      // Start the first status check before opening the hosted checkout.
      _startPolling();
      final returned = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentCheckoutScreen(checkoutUrl: url),
        ),
      );
      if (!mounted) return;
      setState(() => _openingCheckout = false);
      _handleCheckoutClosed(returned);
    } catch (e) {
      if (mounted) {
        setState(() => _error = _messageOf(e));
      }
    }
  }

  void _startPolling() {
    _poller?.cancel();
    _automaticPolls = 0;
    unawaited(_pollOnce());
    _poller = Timer.periodic(_pollInterval, (_) {
      unawaited(_pollOnce());
    });
  }

  Future<void> _restorePendingRecharge() async {
    await controller.restorePendingCardRecharge();
    await controller.recoverOpenCardRecharge();
    if (!mounted || controller.latestRecharge?.isFinal == true) return;
    if (controller.latestRecharge != null) _startPolling();
  }

  Future<void> _pollOnce() async {
    if (!mounted || controller.latestRecharge?.isFinal == true) {
      _poller?.cancel();
      return;
    }

    _automaticPolls++;
    await _refreshStatus();

    if (!mounted || controller.latestRecharge?.isFinal == true) {
      _poller?.cancel();
      return;
    }

    if (_automaticPolls >= _maximumAutomaticPolls) {
      _poller?.cancel();
      setState(() {
        _error =
            'لم يصل تأكيد الدفع بعد. يمكنك التحقق مرة أخرى لاحقاً؛ لن يتم خصم الرصيد مرتين.';
      });
    }
  }

  Future<void> _refreshStatus() async {
    try {
      final recharge = await controller.refreshCardRecharge();
      if (recharge?.isFinal == true) {
        _poller?.cancel();
        // A prior network/polling warning no longer applies once Laravel has
        // confirmed the terminal, authoritative payment state.
        if (mounted && _error != null) setState(() => _error = null);
      }
    } catch (e) {
      if (mounted) setState(() => _error = _messageOf(e));
    }
  }

  String _messageOf(Object error) => error
      .toString()
      .replaceFirst('Exception: ', '')
      .trim()
      .replaceFirst('DioException [unknown]: ', '');

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      duration: const Duration(milliseconds: 150),
      child: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final recharge = controller.latestRecharge;
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'شحن الرصيد بالبطاقة',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ستفتح صفحة مواملة الآمنة داخل التطبيق. لا تدخل بيانات بطاقتك إلا في صفحة الدفع.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.slate500),
                  ),
                  const SizedBox(height: 20),
                  if (recharge == null) ...[
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'المبلغ بالدينار الليبي',
                        prefixText: 'LYD ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: controller.rechargeLoading
                          ? null
                          : _startCheckout,
                      icon: const Icon(Icons.credit_card_rounded),
                      label: Text(
                        controller.rechargeLoading
                            ? 'جارٍ تجهيز الدفع…'
                            : 'المتابعة إلى الدفع الآمن',
                      ),
                    ),
                  ] else ...[
                    _PaymentStatus(recharge: recharge),
                    const SizedBox(height: 14),
                    if (!recharge.isFinal && recharge.checkoutUrl != null) ...[
                      FilledButton.icon(
                        onPressed: _openingCheckout
                            ? null
                            : _openExistingCheckout,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('متابعة الدفع الآمن'),
                      ),
                      const SizedBox(height: 10),
                    ],
                    OutlinedButton.icon(
                      onPressed: controller.rechargeLoading
                          ? null
                          : _refreshStatus,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(
                        controller.rechargeLoading
                            ? 'جارٍ التحقق…'
                            : 'التحقق من حالة الدفع',
                      ),
                    ),
                    if (!recharge.isFinal) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: controller.rechargeLoading
                            ? null
                            : _confirmAbandonCheckout,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('إلغاء عملية الدفع المعلقة'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('العودة للرئيسية'),
                      ),
                    ],
                    if (recharge.isFinal) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: controller.clearLatestRecharge,
                        child: const Text('بدء عملية شحن جديدة'),
                      ),
                    ],
                    if (_openingCheckout) ...[
                      const SizedBox(height: 12),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                  if (_error != null && recharge?.isFinal != true) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.rose700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openExistingCheckout() async {
    final url = controller.latestRecharge?.checkoutUrl;
    if (url == null || url.scheme != 'https' || url.host != 'pay.altkamel.ly') {
      setState(() => _error = 'تعذر استعادة صفحة الدفع الآمنة.');
      return;
    }
    setState(() => _openingCheckout = true);
    _startPolling();
    final returned = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentCheckoutScreen(checkoutUrl: url),
      ),
    );
    if (!mounted) return;
    setState(() => _openingCheckout = false);
    _handleCheckoutClosed(returned);
  }

  Future<void> _handleCheckoutClosed(bool? returned) async {
    if (returned == true) {
      _startPolling();
      return;
    }

    _poller?.cancel();
    await _refreshStatus();
    if (mounted && controller.latestRecharge?.isFinal != true) {
      setState(() {
        _error =
            'تم حفظ عملية الدفع. يمكنك المتابعة لاحقاً أو العودة للرئيسية دون إنشاء عملية جديدة.';
      });
    }
  }

  Future<void> _confirmAbandonCheckout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء متابعة الدفع؟'),
        content: const Text(
          'لن تظهر هذه العملية مرة أخرى في التطبيق. إذا أكدت بوابة الدفع العملية لاحقاً، سيظل رصيدك محمياً وسيُعالج التأكيد تلقائياً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('الاحتفاظ بالعملية'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('إلغاء المتابعة'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await controller.abandonLatestCardRecharge();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = _messageOf(e));
    }
  }
}

class _PaymentStatus extends StatelessWidget {
  final CardRecharge recharge;

  const _PaymentStatus({required this.recharge});

  @override
  Widget build(BuildContext context) {
    final (label, color, detail) = switch (recharge.state) {
      'credited' => (
        'تمت إضافة الرصيد',
        const Color(0xFF0F766E),
        'تم تأكيد الإيداع في حسابك.',
      ),
      'declined' => (
        'تم رفض الدفع',
        AppColors.rose700,
        'لم يتم خصم أو إضافة أي رصيد.',
      ),
      'cancelled' => (
        'تم إلغاء الدفع',
        AppColors.slate500,
        'يمكنك بدء عملية شحن جديدة عند الحاجة.',
      ),
      'credit_pending' => (
        'الدفع مؤكد',
        const Color(0xFFB45309),
        'جارٍ إضافة الرصيد إلى الحساب.',
      ),
      'settled' => (
        'الدفع مؤكد',
        const Color(0xFFB45309),
        'جارٍ تأكيد إضافة الرصيد.',
      ),
      'pending_review' => (
        'قيد المراجعة',
        const Color(0xFFB45309),
        'سنحدّث الحالة بعد التحقق من الدفع.',
      ),
      _ => (
        'بانتظار إتمام الدفع',
        AppColors.indigo,
        'أكمل الدفع في المتصفح ثم تحقق من الحالة.',
      ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            'LYD ${recharge.amountLyd.toStringAsFixed(3)}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.slate500),
          ),
        ],
      ),
    );
  }
}
