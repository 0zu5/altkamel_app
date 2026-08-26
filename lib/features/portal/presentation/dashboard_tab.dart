import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import 'portal_controller.dart';
import 'widgets/portal_card.dart';
import 'widgets/redeem_dialog.dart';

/// The main landing tab: balance, subscription status, today's usage, and
/// quick actions — mirrors the top section of the website's dashboard.vue.
class DashboardTab extends StatelessWidget {
  final PortalController controller;
  final VoidCallback onGoToPackages;

  const DashboardTab({
    super.key,
    required this.controller,
    required this.onGoToPackages,
  });

  Future<void> _openRedeemDialog(BuildContext context) async {
    final message = await showRedeemDialog(context, controller);
    if (message != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _confirmActivate(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تفعيل الاشتراك'),
        content: const Text(
          'سيتم خصم قيمة الباقة الحالية من رصيدك. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تفعيل'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final message = await controller.activateSubscription();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isLoading && controller.user == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.loadError != null && controller.user == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 48,
                    color: AppColors.slate400,
                  ),
                  const SizedBox(height: 12),
                  Text(controller.loadError!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: controller.loadAll,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.loadAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text(
                'مرحباً، ${controller.user?.displayName ?? ''}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 20),
              _BalanceCard(controller: controller),
              const SizedBox(height: 16),
              _CurrentPackageCard(
                controller: controller,
                onChangePackage: onGoToPackages,
              ),
              const SizedBox(height: 16),
              _UsageCard(controller: controller),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openRedeemDialog(context),
                      icon: const Icon(Icons.card_giftcard_outlined),
                      label: const Text('شحن رصيد'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmActivate(context),
                      icon: const Icon(Icons.power_settings_new_rounded),
                      label: const Text('تفعيل الاشتراك'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final PortalController controller;

  const _BalanceCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final days = controller.remainingDays;
    final Color urgencyColor;
    final String urgencyLabel;
    if (days <= 3) {
      urgencyColor = AppColors.rose700;
      urgencyLabel = 'حرج';
    } else if (days <= 7) {
      urgencyColor = const Color(0xFFB45309);
      urgencyLabel = 'قريب';
    } else {
      urgencyColor = const Color(0xFF0F766E);
      urgencyLabel = 'جيد';
    }

    return PortalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الرصيد الحالي',
                style: TextStyle(
                  color: AppColors.slate500,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: urgencyColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$days يوم متبقٍ · $urgencyLabel',
                  style: TextStyle(
                    color: urgencyColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'LD ${controller.balance.balance}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.slate900,
            ),
          ),
          if (controller.balance.unpaidInvoices > 0) ...[
            const SizedBox(height: 8),
            Text(
              'لديك ${controller.balance.unpaidInvoices} فاتورة غير مدفوعة',
              style: const TextStyle(
                color: AppColors.rose700,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CurrentPackageCard extends StatelessWidget {
  final PortalController controller;
  final VoidCallback onChangePackage;

  const _CurrentPackageCard({
    required this.controller,
    required this.onChangePackage,
  });

  @override
  Widget build(BuildContext context) {
    return PortalCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppGradients.button,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.wifi_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'باقتك الحالية',
                  style: TextStyle(
                    color: AppColors.slate500,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  controller.currentPackageName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (controller.currentPackagePrice > 0)
                  Text(
                    'LD ${controller.currentPackagePrice} / شهرياً',
                    style: const TextStyle(
                      color: AppColors.slate500,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(onPressed: onChangePackage, child: const Text('تغيير')),
        ],
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  final PortalController controller;

  const _UsageCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final rx = controller.trafficToday.rxMb;
    final tx = controller.trafficToday.txMb;
    final total = (rx != null && tx != null) ? rx + tx : null;

    return PortalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'استهلاك اليوم',
            style: TextStyle(
              color: AppColors.slate500,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _UsageStat(
                label: 'تنزيل',
                value: Formatters.formatGb(rx),
                icon: Icons.arrow_downward_rounded,
              ),
              const SizedBox(width: 12),
              _UsageStat(
                label: 'رفع',
                value: Formatters.formatGb(tx),
                icon: Icons.arrow_upward_rounded,
              ),
              const SizedBox(width: 12),
              _UsageStat(
                label: 'الإجمالي',
                value: Formatters.formatGb(total),
                icon: Icons.data_usage_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UsageStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _UsageStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.indigo, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.slate500, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
