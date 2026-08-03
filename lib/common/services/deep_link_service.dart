// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();

  factory DeepLinkService() => _instance;

  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  void startListening(GlobalKey<NavigatorState> navigatorKey) {
    _sub = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) _handleUri(uri, navigatorKey);
    }, onError: (err) => debugPrint("DeepLink error: $err"));
  }

  void _handleUri(Uri uri, GlobalKey<NavigatorState> navigatorKey) {
    debugPrint('🧭 Received deep link: $uri');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        // "Farts with Buddies" invite links. Handle both the https universal
        // link (https://flik.me/fwb/<id> → host "flik.me", path "/fwb/<id>")
        // and a custom-scheme form (flatch://fwb/<id> → host "fwb").
        final bool isHttp = uri.scheme == 'http' || uri.scheme == 'https';
        final segments = <String>[
          if (!isHttp && uri.host.isNotEmpty) uri.host,
          ...uri.pathSegments,
        ];
        final fwbIndex = segments.indexOf('fwb');
        if (fwbIndex != -1 && fwbIndex + 1 < segments.length) {
          final groupId = segments[fwbIndex + 1];
          debugPrint('📍 FWB invite → /fwb/$groupId');
          GoRouter.of(context).go('/fwb/$groupId');
          return;
        }

        String fullPath;
        if (uri.host.isNotEmpty) {
          fullPath = '/${uri.host}${uri.path}';
        } else {
          fullPath = uri.path.isEmpty ? '/' : uri.path;
        }

        if (uri.query.isNotEmpty) {
          fullPath += '?${uri.query}';
        }

        debugPrint('📍 Navigating to: $fullPath');
        GoRouter.of(context).go(fullPath);
      } else {
        debugPrint("⚠️ Navigator context is null, can't navigate.");
      }
    });
  }

  void dispose() {
    _sub?.cancel();
  }
}
