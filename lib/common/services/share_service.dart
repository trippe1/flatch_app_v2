// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:share_plus/share_plus.dart';

class ShareService {
  ShareService._(); // private constructor
  static final ShareService instance = ShareService._();

  /// Default app install text
  final String defaultShareText = '''
Listen to this sound on Flatch!
Android: https://play.google.com/store/apps/details?id=com.example.flatch
iOS: https://apps.apple.com/app/idXXXXXXXXX
Click the link to listen inside the app!
''';

  /// Encode fart ID to a confidential string
  String encodeFartId(String fartId) {
    final bytes = utf8.encode(fartId);
    return base64Url.encode(bytes);
  }

  /// Decode the confidential string back to fart ID
  String decodeFartId(String encoded) {
    final bytes = base64Url.decode(encoded);
    return utf8.decode(bytes);
  }

  String generateShareLink(String fartId) {
    final encodedId = encodeFartId(fartId);
    return 'https://flatch.app/fart/$encodedId';
  }

  Future<void> shareFart({
    required String fartId,
    String subject = 'A sound for your review.',
    String title = 'Share Sound',
  }) async {
    try {
      final shareLink = generateShareLink(fartId);

      final shareText = '''
Listen to this sound on Flatch!
$shareLink

Android: https://play.google.com/store/apps/details?id=com.example.flatch
iOS: https://apps.apple.com/app/idXXXXXXXXX

Tap the link to listen inside the app!
''';

      final params = ShareParams(subject: subject, text: shareText);

      await SharePlus.instance.share(params);
    } catch (e) {
      print('Error sharing fart: $e');
    }
  }

  /// Share just the static text (app install links)
  Future<void> shareAppText({
    String subject = 'Flatch. A precision flatulence instrument.',
    String title = 'Share App',
  }) async {
    try {
      final params = ShareParams(subject: subject, title: title);

      await SharePlus.instance.share(params);
    } catch (e) {
      print('Error sharing text: $e');
    }
  }
}
