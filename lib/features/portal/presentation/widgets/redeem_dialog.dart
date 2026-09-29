import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../portal_controller.dart';

/// Shows the "redeem a top-up card" dialog (12-digit PIN) and returns the
/// resulting Arabic success/error message once the dialog is closed, or
/// null if the user cancelled without submitting.
Future<String?> showRedeemDialog(
  BuildContext context,
  PortalController controller,
) {
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

          Future<void> scanVoucher() async {
            final scannedCode = await Navigator.of(context).push<String>(
              MaterialPageRoute(builder: (_) => const _VoucherQrScanner()),
            );
            if (scannedCode == null || !context.mounted) return;
            pinController.text = scannedCode;
            setState(() => fieldError = null);
          }

          return AlertDialog(
            title: const Text('شحن الرصيد'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أدخل رمز قسيمة الشحن المكوّن من 12 رقماً أو امسح رمز QR.',
                ),
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
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: scanVoucher,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('مسح رمز QR للقسيمة'),
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

class _VoucherQrScanner extends StatefulWidget {
  const _VoucherQrScanner();

  @override
  State<_VoucherQrScanner> createState() => _VoucherQrScannerState();
}

class _VoucherQrScannerState extends State<_VoucherQrScanner> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _handled = false;
  String? _error;

  String? _voucherCode(String value) {
    final match = RegExp(r'(?<!\\d)(\\d{12})(?!\\d)').firstMatch(value);
    return match?.group(1);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    final code = _voucherCode(raw);
    if (code == null) {
      setState(() => _error = 'لم نعثر على رمز قسيمة صالح مكوّن من 12 رقماً.');
      return;
    }

    _handled = true;
    _scannerController.stop();
    Navigator.of(context).pop(code);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مسح رمز قسيمة الشحن')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _scannerController, onDetect: _onDetect),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'وجّه الكاميرا إلى رمز QR الموجود على القسيمة.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (_error != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
