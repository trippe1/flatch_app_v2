import 'package:flatch/views/home/shopify_checkout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class FlatchPurchasePage extends StatelessWidget {
  const FlatchPurchasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          style: ButtonStyle().copyWith(
            backgroundColor: WidgetStatePropertyAll(Colors.transparent),
            side: WidgetStatePropertyAll(BorderSide.none),
          ),
          onPressed: () => GoRouter.of(context).pop(),
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Image.asset('assets/images/flatch_logo.png', height: 150),
            const SizedBox(height: 20),
            const Text(
              "Get your own Flatch device to enjoy custom sounds and full control via the app.",
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            Gap(20),
            ElevatedButton.icon(
              icon: SvgPicture.asset(
                'assets/svgs/amazon.svg',
                height: 60,
                width: 60,
                // ignore: deprecated_member_use
                color: Theme.of(context).iconTheme.color,
              ),
              label: const Text("Buy on Amazon"),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ShopifyCheckoutPage(
                            checkoutUrl:
                                'https://www.amazon.com/FLIK-Car-Office-Light-Accessories/dp/B0D3448YK7/',
                          ),
                    ),
                  ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: SvgPicture.asset(
                'assets/svgs/shopify.svg',
                height: 24,
                width: 24,
              ),
              label: const Text("         Buy on Shopify"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ShopifyCheckoutPage(
                          checkoutUrl: 'https://flik.me/products/flatch',
                        ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
