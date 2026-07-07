import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ShopifyCheckoutPage extends StatefulWidget {
  final String checkoutUrl;

  const ShopifyCheckoutPage({super.key, required this.checkoutUrl});

  @override
  State<ShopifyCheckoutPage> createState() => _ShopifyCheckoutPageState();
}

class _ShopifyCheckoutPageState extends State<ShopifyCheckoutPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (progress) {
                // Optionally show loading progress
              },
              onPageStarted: (url) {
                debugPrint("Page started loading: $url");
              },
              onPageFinished: (url) {
                debugPrint("Page finished loading: $url");
              },
              onNavigationRequest: (request) {
                // You can intercept navigation here if needed
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Complete Purchase")),
      body: WebViewWidget(controller: _controller),
    );
  }
}
