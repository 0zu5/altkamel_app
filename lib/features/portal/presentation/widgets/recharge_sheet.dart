import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/portal_models.dart';
import '../portal_controller.dart';

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
  final _amountController = TextEditingController(text: '10');
  Timer? _poller;
  String? _error;
  bool _openingCheckout = false;

  PortalController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      unawaited(_refreshStatus());
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
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      setState(() => _openingCheckout = false);
      if (!opened) {
        setState(() => _error = 'تعذر فتح المتصفح لإتمام عملية الدفع.');
        return;
      }
      _startPolling();
    } catch (e) {
      if (mounted) {
        setState(() => _error = _messageOf(e));
      }
    }
  }

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_refreshStatus());
    });
  }

  Future<void> _refreshStatus() async {
    try {
      final recharge = await controller.refreshCardRecharge();
      if (recharge?.isFinal == true) _poller?.cancel();
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
                    'ستُفتح صفحة دفع مواملة الآمنة في المتصفح. لا تدخل بيانات بطاقتك داخل التطبيق.',
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
                  if (_error != null) ...[
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
