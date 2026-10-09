import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/constants.dart';

/// eSewa's `/api/epay/main/v2/form` endpoint only accepts an HTTP POST with
/// form fields. Opening it with launchUrl() sends a GET, which gives the
/// "405 Method Not Allowed" error. So we build a tiny auto-submitting HTML
/// form and load it in a WebView, which sends the POST for us.
class EsewaPaymentScreen extends StatefulWidget {
  final String gatewayUrl;
  final Map<String, String> formFields;

  const EsewaPaymentScreen({
    super.key,
    required this.gatewayUrl,
    required this.formFields,
  });

  @override
  State<EsewaPaymentScreen> createState() => _EsewaPaymentScreenState();
}

class _EsewaPaymentScreenState extends State<EsewaPaymentScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _finished = false;

  static String _esc(String v) => v
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  String _buildHtml() {
    final inputs = widget.formFields.entries
        .map((e) =>
            '<input type="hidden" name="${_esc(e.key)}" value="${_esc(e.value)}">')
        .join('\n');
    return '''
<!DOCTYPE html>
<html>
<head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body onload="document.getElementById('f').submit()">
  <form id="f" method="POST" action="${_esc(widget.gatewayUrl)}">
    $inputs
  </form>
  <p style="font-family:sans-serif;text-align:center;margin-top:40px">
    Redirecting to eSewa...
  </p>
</body>
</html>
''';
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            if (mounted) setState(() => _loading = false);
            // eSewa redirects back to your backend's success/failure URL.
            // Wait until that page has FINISHED loading so the backend has
            // finished verifying the payment, then close and refresh.
            if (!_finished && url.startsWith(ApiConstants.api)) {
              _finished = true;
              if (mounted) Navigator.of(context).pop(true);
            }
          },
        ),
      )
      ..loadHtmlString(_buildHtml());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay with eSewa'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
