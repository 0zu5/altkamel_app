import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import 'portal_controller.dart';
import 'widgets/portal_card.dart';

/// Billing history — POST /index/invoice, same data the website lists on
/// its dashboard page.
class InvoicesTab extends StatelessWidget {
  final PortalController controller;

  const InvoicesTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.invoicesLoading && controller.invoices.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: controller.loadInvoices,
          child: controller.invoices.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: const [
                    SizedBox(height: 80),
                    Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.slate400),
                    SizedBox(height: 12),
                    Text('لا توجد فواتير بعد.', textAlign: TextAlign.center),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  itemCount: controller.invoices.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          'الفواتير',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.slate900),
                        ),
                      );
                    }
                    final invoice = controller.invoices[index - 1];
                    return PortalCard(
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: (invoice.paid ? const Color(0xFF0F766E) : AppColors.rose700)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              invoice.paid ? Icons.check_circle_outline : Icons.schedule_rounded,
                              color: invoice.paid ? const Color(0xFF0F766E) : AppColors.rose700,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  invoice.invoiceNumber.isNotEmpty
                                      ? invoice.invoiceNumber
                                      : 'فاتورة #${invoice.id}',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  Formatters.arabicDate(invoice.createdAt),
                                  style: const TextStyle(color: AppColors.slate500, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('LD ${invoice.amount}',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                              Text(
                                invoice.paid ? 'مدفوعة' : 'غير مدفوعة',
                                style: TextStyle(
                                  color: invoice.paid ? const Color(0xFF0F766E) : AppColors.rose700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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
