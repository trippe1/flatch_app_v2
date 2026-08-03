/// Canonical Flatch BLE identifiers — single source of truth for the Flutter
/// app. These MUST stay in sync with:
///   • firmware  → esp32/src/main.cp  (SERVICE_UUID / CMD_UUID / DATA_UUID / …)
///   • iOS native → any AccessorySetupKit / CoreBluetooth pairing code
///   • Android native → any CompanionDeviceManager association filter
///
/// The service UUID is the product-family identifier used for scan filtering
/// (common to ALL units). The advertised local name (Flatch-XXXX) is what's
/// unique per unit.
///
/// ⚠️ UUID MIGRATION — APPROVED BUT DEFERRED (do not activate app-only).
/// The canonical target is the random 128-bit UUID
/// `b88599a1-30f2-4618-b1f1-a8a5a2d10a60`. It is NOT active yet: switching to it
/// is a COORDINATED firmware+app change — an app on the new UUID cannot discover
/// a device still advertising the value below (which is what already-flashed
/// units broadcast). At the next firmware reflash, set BOTH this constant AND
/// esp32/src/main.cp SERVICE_UUID to the b88599 value together.
class FlatchBle {
  FlatchBle._();

  static const String serviceUuid = '0000abcd-0000-1000-8000-00805f9b34fb';
  static const String cmdUuid = '0000abce-0000-1000-8000-00805f9b34fb';
  static const String dataUuid = '0000abcf-0000-1000-8000-00805f9b34fb';
  static const String statusUuid = '0000abd0-0000-1000-8000-00805f9b34fb';
  static const String flowControlUuid =
      '0000abd1-0000-1000-8000-00805f9b34fb';

  /// Advertised-name prefixes we accept as a Flatch. Firmware currently
  /// advertises "Latch V8"; the target convention is "Flatch-XXXX" (per-unit
  /// serial). Accept both so the app keeps working across the firmware rename.
  static const List<String> namePrefixes = ['flatch', 'latch'];

  static bool nameLooksLikeFlatch(String name) {
    final n = name.toLowerCase();
    return namePrefixes.any(n.startsWith);
  }
}
