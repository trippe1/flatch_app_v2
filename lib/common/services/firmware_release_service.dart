import 'package:cloud_firestore/cloud_firestore.dart';

/// A firmware release the device can update to. Published to Firestore at
/// `firmware/current` by whoever cuts firmware (Flicked LLC), pointing at a
/// hosted `.bin` the device downloads over Wi-Fi.
class FirmwareRelease {
  final String version; // semver, e.g. "13.1"
  final String url; // https download URL for the merged/app image
  final String sha256; // hex; the device verifies this
  final int sizeBytes; // the device verifies length too
  final int minBatteryPct; // refuse below this (spec: 30)
  final String notes; // optional changelog shown to the user

  const FirmwareRelease({
    required this.version,
    required this.url,
    required this.sha256,
    required this.sizeBytes,
    this.minBatteryPct = 30,
    this.notes = '',
  });

  bool get isValid =>
      version.isNotEmpty &&
      url.startsWith('https://') &&
      sha256.isNotEmpty &&
      sizeBytes > 0;

  static FirmwareRelease? fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    if (m == null) return null;
    final r = FirmwareRelease(
      version: (m['version'] ?? '').toString(),
      url: (m['url'] ?? '').toString(),
      sha256: (m['sha256'] ?? '').toString(),
      sizeBytes: (m['sizeBytes'] ?? 0) is int
          ? m['sizeBytes'] as int
          : int.tryParse('${m['sizeBytes']}') ?? 0,
      minBatteryPct: (m['minBatteryPct'] ?? 30) is int
          ? m['minBatteryPct'] as int
          : 30,
      notes: (m['notes'] ?? '').toString(),
    );
    return r.isValid ? r : null;
  }
}

class FirmwareReleaseService {
  FirmwareReleaseService._();

  static Future<FirmwareRelease?> current() async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('firmware').doc('current').get();
      return FirmwareRelease.fromDoc(doc);
    } catch (_) {
      return null;
    }
  }

  /// True if [available] is strictly newer than [current] (dotted numeric
  /// semver — "13.10" > "13.9"). Unparseable/empty current → treat as
  /// update-available so a device that never reported a version can still
  /// update.
  static bool isNewer(String available, String? current) {
    final a = _parts(available);
    if (a.isEmpty) return false;
    if (current == null || current.trim().isEmpty) return true;
    final c = _parts(current);
    if (c.isEmpty) return true;
    for (var i = 0; i < a.length || i < c.length; i++) {
      final ai = i < a.length ? a[i] : 0;
      final ci = i < c.length ? c[i] : 0;
      if (ai != ci) return ai > ci;
    }
    return false; // equal
  }

  static List<int> _parts(String v) => v
      .trim()
      .split(RegExp(r'[.\-+]'))
      .map((s) => int.tryParse(s))
      .whereType<int>()
      .toList();
}
