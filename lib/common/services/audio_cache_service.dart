import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

Future<String> getOrDownloadFart(String url) async {
  final dir = await getApplicationDocumentsDirectory();
  final filename = Uri.parse(url).pathSegments.last;
  final localFile = File(p.join(dir.path, 'farts_cache', filename));

  if (await localFile.exists()) return localFile.path;

  try {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      await localFile.create(recursive: true);
      await localFile.writeAsBytes(response.bodyBytes);
      return localFile.path;
    } else {
      throw Exception("Failed to download: HTTP ${response.statusCode}");
    }
  } on SocketException catch (e) {
    debugPrint('Socket error: $e');
    rethrow;
  } on TimeoutException {
    debugPrint('Download timed out');
    rethrow;
  } catch (e) {
    debugPrint('Unexpected error: $e');
    rethrow;
  }
}
