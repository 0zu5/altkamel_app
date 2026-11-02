import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Hosts only the HTTPS checkout URL issued by Laravel. Card details are
/// entered on pay.altkamel.ly; Flutter never receives them.
class PaymentCheckoutScreen extends StatefulWidget {
  final Uri checkoutUrl;

  const PaymentCheckoutScreen({super.key, required this.checkoutUrl});

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen> {
  late final WebViewController _webView;
  int _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _webView = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            // Laravel returns to the app's custom scheme only after the
            // gateway page has finished. Close the sheet and let the caller
            // query the authoritative API state.
            if (uri != null && uri.scheme != 'https' && uri.scheme != 'http') {
              Navigator.of(context).pop(true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) {
              setState(() => _error = 'تعذر تحميل صفحة الدفع الآمنة.');
            }
          },
        ),
      )
      ..loadRequest(widget.checkoutUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدفع الآمن'),
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(value: _progress / 100),
              )
            : null,
      ),
      body: _error == null
          ? WebViewWidget(controller: _webView)
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 44),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() => _error = null);
                        _webView.loadRequest(widget.checkoutUrl);
                      },
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
