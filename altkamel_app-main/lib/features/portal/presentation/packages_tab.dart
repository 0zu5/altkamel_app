import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/portal_models.dart';
import 'portal_controller.dart';
import 'widgets/portal_card.dart';

/// Browse available packages and switch the subscription — mirrors the
/// website's standalone `/portal/packages` page.
class PackagesTab extends StatelessWidget {
  final PortalController controller;

  const PackagesTab({super.key, required this.controller});

  Future<void> _confirmChange(BuildContext context, PackageInfo pkg) async {
    if (controller.isCurrentPackage(pkg)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أنت تستخدم هذه الباقة حالياً.')),
      );
      return;
    }

    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmChangeDialog(controller: controller, target: pkg),
    );
    if (agreed != true || !context.mounted) return;

    final result = await controller.changeSubscription(pkg);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? '')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isLoading && controller.packages.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.packages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.slate400),
                  const SizedBox(height: 12),
                  const Text('تعذّر جلب الباقات.', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: controller.loadAll, child: const Text('إعادة المحاولة')),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.loadAll,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            itemCount: controller.packages.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'الباقات المتاحة',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.slate900),
                  ),
                );
              }
              final pkg = controller.packages[index - 1];
              final isCurrent = controller.isCurrentPackage(pkg);
              return PortalCard(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppColors.indigo
                            : AppColors.indigo.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.wifi_rounded,
                        color: isCurrent ? Colors.white : AppColors.indigo,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pkg.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text('LD ${pkg.price} / شهرياً',
                              style: const TextStyle(color: AppColors.slate500, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.indigo.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'باقتك الحالية',
                          style: TextStyle(color: AppColors.indigo, fontWeight: FontWeight.w800, fontSize: 11),
                        ),
                      )
                    else
                      OutlinedButton(
                        onPressed: controller.actionLoading ? null : () => _confirmChange(context, pkg),
                        child: const Text('تغيير'),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ConfirmChangeDialog extends StatefulWidget {
  final PortalController controller;
  final PackageInfo target;

  const _ConfirmChangeDialog({required this.controller, required this.target});

  @override
  State<_ConfirmChangeDialog> createState() => _ConfirmChangeDialogState();
}

class _ConfirmChangeDialogState extends State<_ConfirmChangeDialog> {
  bool _agree = false;

  @override
  Widget build(BuildContext context) {
    final delta = widget.target.price - widget.controller.currentPackagePrice;
    return AlertDialog(
      title: const Text('تأكيد تغيير الباقة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('سيتم تحويل اشتراكك إلى "${widget.target.name}" بسعر LD ${widget.target.price} شهرياً.'),
          if (delta != 0) ...[
            const SizedBox(height: 8),
            Text(
              delta > 0
                  ? 'أغلى من باقتك الحالية بـ LD ${delta.abs()}.'
                  : 'أرخص من باقتك الحالية بـ LD ${delta.abs()}.',
              style: const TextStyle(color: AppColors.slate500, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'ملاحظة: تغيير الباقة لا يفعّلها تلقائياً — يمكنك تفعيل الاشتراك لاحقاً من الصفحة الرئيسية.',
            style: TextStyle(color: AppColors.slate500, fontSize: 12),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _agree,
            onChanged: (v) => setState(() => _agree = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('أوافق على تغيير باقتي', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _agree ? () => Navigator.of(context).pop(true) : null,
          child: const Text('تأكيد'),
        ),
      ],
    );
  }
}
