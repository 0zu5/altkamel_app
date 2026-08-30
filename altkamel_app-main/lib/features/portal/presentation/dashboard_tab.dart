import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import 'portal_controller.dart';
import 'widgets/portal_card.dart';
import 'widgets/redeem_dialog.dart';

class DashboardTab extends StatelessWidget {
  final PortalController controller;
  final VoidCallback onGoToPackages;

  const DashboardTab({
    super.key,
    required this.controller,
    required this.onGoToPackages,
  });

  // 1. إجراء الاتصال الهاتفي بالدعم الفني
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  // 2. فتح موقع فحص السرعة
  Future<void> _openSpeedTest() async {
    final Uri url = Uri.parse('https://fast.com');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // 3. فتح نافذة الشحن مسح البطاقات
  Future<void> _openRedeemDialog(BuildContext context) async {
    final message = await showRedeemDialog(context, controller);
    if (message != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  Future<void> _confirmActivate(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.bolt_rounded, color: AppColors.indigo),
            SizedBox(width: 8),
            Text('تفعيل الاشتراك', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'سيتم تفعيل الباقة الحالية وخصم قيمتها مباشرة من رصيدك المتاح. هل ترغب في الاستمرار؟',
          style: TextStyle(color: AppColors.slate700, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.slate500, fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.indigo,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تفعيل الآن', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final message = await controller.activateSubscription();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isLoading && controller.user == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.indigo, strokeWidth: 3),
          );
        }

        if (controller.loadError != null && controller.user == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.rose700.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.rose700),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    controller.loadError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate700, fontSize: 15),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: controller.loadAll,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('إعادة المحاولة'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.indigo,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.loadAll,
          color: AppColors.indigo,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildHeader(context),
              const SizedBox(height: 18),

              _HeroBalanceCard(controller: controller),
              const SizedBox(height: 16),

              _PackageStatusCard(
                controller: controller,
                onChangePackage: onGoToPackages,
              ),
              const SizedBox(height: 16),

              _DailyUsageCard(controller: controller),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _GradientActionButton(
                      label: 'تفعيل الاشتراك',
                      icon: Icons.bolt_rounded,
                      gradient: AppGradients.button,
                      textColor: Colors.white,
                      onTap: () => _confirmActivate(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GradientActionButton(
                      label: 'شحن رصيد',
                      icon: Icons.add_card_rounded,
                      backgroundColor: Colors.white,
                      textColor: AppColors.slate900,
                      borderColor: const Color(0xFFE2E8F0),
                      onTap: () => _openRedeemDialog(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'الخدمات السريعة',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.slate900),
              ),
              const SizedBox(height: 12),
              
              // شبكة الخدمات المربوطة بالأفعال الحقيقية
              _QuickServicesGrid(
                onSupportTap: () => _makePhoneCall('0923339798'),
                onSpeedTestTap: _openSpeedTest,
                onRedeemTap: () => _openRedeemDialog(context),
              ),
              const SizedBox(height: 24),

              const Text(
                'آخر النشاطات',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.slate900),
              ),
              const SizedBox(height: 12),
              const _RecentActivitySection(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'مرحباً بك 👋',
              style: TextStyle(fontSize: 13, color: AppColors.slate500, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              controller.user?.displayName ?? 'المشترك',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.slate900,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: AppColors.slate700, size: 22),
            onPressed: () {},
          ),
        ),
      ],
    );
  }
}

class _HeroBalanceCard extends StatelessWidget {
  final PortalController controller;

  const _HeroBalanceCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final days = controller.remainingDays;
    final Color badgeBg;
    final Color badgeText;
    final String statusLabel;

    if (days <= 3) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFFDC2626);
      statusLabel = 'حرج جداً';
    } else if (days <= 7) {
      badgeBg = const Color(0xFFFEF3C7);
      badgeText = const Color(0xFFD97706);
      statusLabel = 'قريب ينتهي';
    } else {
      badgeBg = const Color(0xFFECFDF5);
      badgeText = const Color(0xFF10B981);
      statusLabel = 'نشط';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.indigo.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            left: -30,
            child: CircleAvatar(
              radius: 70,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Positioned(
            bottom: -20,
            right: -20,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'الرصيد المتاح',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: badgeText, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$days يوم · $statusLabel',
                            style: TextStyle(
                              color: badgeText,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${controller.balance.balance}',
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'د.ل',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                if (controller.balance.unpaidInvoices > 0) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'لديك ${controller.balance.unpaidInvoices} فاتورة غير مدفوعة',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageStatusCard extends StatelessWidget {
  final PortalController controller;
  final VoidCallback onChangePackage;

  const _PackageStatusCard({
    required this.controller,
    required this.onChangePackage,
  });

  @override
  Widget build(BuildContext context) {
    return PortalCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.indigo.withValues(alpha: 0.15), AppColors.indigo.withValues(alpha: 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.wifi_rounded, color: AppColors.indigo, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الاشتراك الحالي',
                  style: TextStyle(
                    color: AppColors.slate500,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  controller.currentPackageName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AppColors.slate900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (controller.currentPackagePrice > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${controller.currentPackagePrice} د.ل / شهرياً',
                    style: const TextStyle(
                      color: AppColors.slate500,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onChangePackage,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'تغيير',
              style: TextStyle(color: AppColors.indigo, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyUsageCard extends StatelessWidget {
  final PortalController controller;

  const _DailyUsageCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final rx = controller.trafficToday.rxMb;
    final tx = controller.trafficToday.txMb;
    final total = (rx != null && tx != null) ? rx + tx : 0.0;

    return PortalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'استهلاك اليوم',
                style: TextStyle(
                  color: AppColors.slate900,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.indigo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'مباشر',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.indigo),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 0.65,
                      strokeWidth: 7,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.indigo),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            Formatters.formatGb(total),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate900),
                          ),
                          const Text(
                            'الإجمالي',
                            style: TextStyle(fontSize: 8, color: AppColors.slate500, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    _UsageDetailRow(
                      label: 'بيانات التنزيل',
                      value: Formatters.formatGb(rx),
                      icon: Icons.arrow_downward_rounded,
                      color: const Color(0xFF10B981),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                    ),
                    _UsageDetailRow(
                      label: 'بيانات الرفع',
                      value: Formatters.formatGb(tx),
                      icon: Icons.arrow_upward_rounded,
                      color: const Color(0xFF3B82F6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UsageDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _UsageDetailRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.slate900),
        ),
      ],
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final LinearGradient? gradient;
  final Color? backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _GradientActionButton({
    required this.label,
    required this.icon,
    this.gradient,
    this.backgroundColor,
    required this.textColor,
    this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: borderColor != null ? Border.all(color: borderColor!) : null,
          boxShadow: gradient != null
              ? [
                  BoxShadow(
                    color: AppColors.indigo.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: textColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickServicesGrid extends StatelessWidget {
  final VoidCallback onSupportTap;
  final VoidCallback onSpeedTestTap;
  final VoidCallback onRedeemTap;

  const _QuickServicesGrid({
    required this.onSupportTap,
    required this.onSpeedTestTap,
    required this.onRedeemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildServiceItem(
          icon: Icons.headset_mic_rounded,
          title: 'الدعم الفني',
          color: AppColors.indigo,
          onTap: onSupportTap,
        ),
        const SizedBox(width: 10),
        _buildServiceItem(
          icon: Icons.speed_rounded,
          title: 'فحص السرعة',
          color: const Color(0xFF10B981),
          onTap: onSpeedTestTap,
        ),
        const SizedBox(width: 10),
        _buildServiceItem(
          icon: Icons.qr_code_scanner_rounded,
          title: 'مسح كروت',
          color: const Color(0xFFF59E0B),
          onTap: onRedeemTap,
        ),
      ],
    );
  }

  Widget _buildServiceItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildActivityTile(
            icon: Icons.add_card_rounded,
            iconBg: const Color(0xFFECFDF5),
            iconColor: const Color(0xFF10B981),
            title: 'شحن حساب عبر كرت',
            subtitle: 'اليوم، 10:30 صباحاً',
            amount: '+20 د.ل',
            amountColor: const Color(0xFF10B981),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          _buildActivityTile(
            icon: Icons.bolt_rounded,
            iconBg: AppColors.indigo.withValues(alpha: 0.08),
            iconColor: AppColors.indigo,
            title: 'تفعيل اشتراك شهر جديد',
            subtitle: 'أمس، 04:15 مساءً',
            amount: '-50 د.ل',
            amountColor: AppColors.slate900,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String amount,
    required Color amountColor,
  }) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate900),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const Spacer(),
          Text(
            amount,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: amountColor),
          ),
        ],
      ),
    );
  }
}