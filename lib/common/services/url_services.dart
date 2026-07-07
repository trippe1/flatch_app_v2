// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flatch/common/dialogues/error_dialog.dart';
import 'package:flatch/common/dialogues/loading_dialog.dart';
import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

class UrlLauncherService {
  UrlLauncherService._();
  static final instance = UrlLauncherService._();

  Future<void> launchAmazon(BuildContext context, String link) async {
    try {
      showDialog(context: context, builder: (context) => const LoadingDialog());
      print(link);
      final String url = link;
      bool canLaunch = await canLaunchUrl(Uri.parse(url));
      if (canLaunch) {
        Navigator.pop(context);
        await launchUrl(
          Uri.parse(url),
          browserConfiguration: const BrowserConfiguration(showTitle: true),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => ErrorDialog(error: e.toString()),
      );
    }
  }

  Future<void> launchShopify(BuildContext context, String link) async {
    try {
      showDialog(context: context, builder: (context) => const LoadingDialog());
      print(link);
      final String url = link;
      bool canLaunch = await canLaunchUrl(Uri.parse(url));
      if (canLaunch) {
        Navigator.pop(context);
        await launchUrl(
          Uri.parse(url),
          browserConfiguration: const BrowserConfiguration(showTitle: true),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => ErrorDialog(error: e.toString()),
      );
    }
  }

  Future<void> launchTermsAndConditions(BuildContext context) async {
    String url = "https://flik.me/policies/terms-of-service";
    try {
      showDialog(context: context, builder: (context) => const LoadingDialog());
      bool canLaunch = await canLaunchUrl(Uri.parse(url));
      if (canLaunch) {
        Navigator.pop(context);
        await launchUrl(
          Uri.parse(url),
          browserConfiguration: const BrowserConfiguration(showTitle: true),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => ErrorDialog(error: e.toString()),
      );
    }
  }

  Future<void> deleteAccount(BuildContext context) async {
    String url = "https://abundantvisasaccount.netlify.app/";
    try {
      showDialog(context: context, builder: (context) => const LoadingDialog());
      bool canLaunch = await canLaunchUrl(Uri.parse(url));
      if (canLaunch) {
        Navigator.pop(context);
        await launchUrl(
          Uri.parse(url),
          browserConfiguration: const BrowserConfiguration(showTitle: true),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => ErrorDialog(error: e.toString()),
      );
    }
  }

  Future<void> launchPrivacyPolicy(BuildContext context) async {
    String url = "https://flik.me/pages/copy-of-privacy-policy";
    try {
      showDialog(context: context, builder: (context) => const LoadingDialog());
      bool canLaunch = await canLaunchUrl(Uri.parse(url));
      if (canLaunch) {
        Navigator.pop(context);
        await launchUrl(
          Uri.parse(url),
          browserConfiguration: const BrowserConfiguration(showTitle: true),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => ErrorDialog(error: e.toString()),
      );
    }
  }

  Future<void> launchContactUs(BuildContext context) async {
    try {
      showDialog(context: context, builder: (context) => const LoadingDialog());
      const String link = 'https://pinkelephants.ai/contact-us/';
      const String url = link;
      bool canLaunch = await canLaunchUrl(Uri.parse(url));
      if (canLaunch) {
        Navigator.pop(context);
        await launchUrl(
          Uri.parse(url),
          browserConfiguration: const BrowserConfiguration(showTitle: true),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => ErrorDialog(error: e.toString()),
      );
    }
  }
}
