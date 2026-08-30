import 'package:flutter/material.dart';

import '../portal_controller.dart';

/// Shows the "redeem a top-up card" dialog (12-digit PIN) and returns the
/// resulting Arabic success/error message once the dialog is closed, or
/// null if the user cancelled without submitting.
Future<String?> showRedeemDialog(BuildContext context, PortalController controller) {
  final pinController = TextEditingController();
  String? fieldError;
  String? resultMessage;

  return showDialog<String?>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> submit() async {
            final clean = pinController.text.replaceAll(RegExp(r'\D'), '');
            if (clean.length != 12) {
              setState(() => fieldError = 'الرمز يجب أن يكون 12 رقماً بالضبط.');
              return;
            }
            setState(() => fieldError = null);
            final message = await controller.redeemCode(clean);
            resultMessage = message;
            if (context.mounted) Navigator.of(context).pop(resultMessage);
          }

          return AlertDialog(
            title: const Text('شحن الرصيد'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('أدخل رمز بطاقة الشحن المكوّن من 12 رقماً'),
                const SizedBox(height: 12),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  decoration: InputDecoration(
                    hintText: '000000000000',
                    errorText: fieldError,
                    counterText: '',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('إلغاء'),
              ),
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) => FilledButton(
                  onPressed: controller.actionLoading ? null : submit,
                  child: controller.actionLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('شحن'),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
