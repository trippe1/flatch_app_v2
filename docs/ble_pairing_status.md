# Flatch BLE Pairing — Implementation Status

Tracks the pairing brief (`flatch_ble_pairing_brief_2.md`) against what's been
built. **App-side discovery is done and verified in code; the native pairing
frameworks and all firmware work require hardware + the firmware team and are
NOT done.**

## ✅ Done (Flutter app, this session — compiles + tests pass)
- **Scan is now filtered to Flatch only.** `startScan(withServices:[serviceUuid])`
  + a secondary service/name filter in the results listener. No unrelated
  Bluetooth devices ever appear. (Brief §1, acceptance ✔ "Only Flatch devices…")
- **Shared UUID constants** — `lib/common/constants/flatch_ble_constants.dart`
  (`FlatchBle`), now the single source of truth referenced by the BLE cubit.
  Must be kept in sync with `esp32/src/main.cp` and any native code.
- **Multi-device handling** — results sorted by **RSSI (closest first)** with a
  3-bar **signal-strength indicator** + "move closer" hint. (Brief §1)
- **Clean device naming** — shows the advertised per-unit name (e.g.
  `Flatch-1A2B`); falls back to "Flatch" for the legacy `Latch …` name. Fixed
  the old `startsWith('latch')` label bug.
- **Guest-mode pairing** — the device tab (and pairing) is reachable with no
  account; no PII analytics fire in guest mode. (Brief §5, acceptance ✔)
- **Android scan permission** — `BLUETOOTH_SCAN` now has
  `usesPermissionFlags="neverForLocation"`; legacy `BLUETOOTH*` + `ACCESS_FINE_LOCATION`
  scoped to `maxSdkVersion=30`; runtime gate no longer *requires* location.
- **BLE permissions are requested in-context** (only when scanning), never at
  app launch. (Earlier work.)

## ⛔ NOT done — needs firmware team + hardware (cannot be verified from here)

### Firmware (ESP32) — Brief §4 + §1
- **Bonding** (LE Just Works), bond-on-first-connect, silent reconnect.
- **Max bonded peers → 8**, **LRU eviction** when full.
- **Bonds in NVS**, survive power-cycle **and** OTA (OTA must not touch NVS).
- **App-level handshake still gates all custom GATT writes** (bonded ≠ authorized).
- **Advertise `Flatch-XXXX`** per-unit local name (end-of-line serial provisioning).
- Stack: prefer **NimBLE**; current firmware uses **Bluedroid** (`BLEDevice.h`) —
  **DECISION NEEDED**: migrate to NimBLE, or stay on Bluedroid? (Brief §4 asks to
  flag this — flagging it.)
- Firmware currently `BLEDevice::init("Latch V8")` and advertises service
  `0000abcd` — the app filter already keys on that UUID, so discovery works today.

### iOS native — Brief §2 (major native effort)
- **AccessorySetupKit** (iOS 18+) as primary pairing; **CoreBluetooth** fallback
  (iOS ≤17) behind one `DevicePairingService`; CoreBluetooth **state restoration**.
- Today the app uses `flutter_blue_plus` (works, filtered), not the native picker.

### Android native — Brief §3 (major native effort)
- **CompanionDeviceManager** association (system dialog filtered to the service
  UUID) for persistent association + background reconnect.

### Pairing UX states — Brief §5 — ✅ DONE (Flutter)
- **Pre-scan**: instruction card ("turn on your Flatch, hold the button until it
  blinks; pair in-app, not Settings") + a "Scan for my Flatch" button.
- **Scanning**: ~15s scan, live filtered list, "Scanning…" button state.
- **No devices**: troubleshooting tips (on? in range? charged?) + Scan again.
- **Connecting**: shows attempt count; **retry with backoff, 3 attempts, 10s
  each** (cubit `connectDevice` → `_attemptConnect`) before failing.
- **Failure**: human error + "pair in the app, not Settings" hint + Forget-Device
  recovery steps + Scan again.
- **Success**: routes into the sound UI (existing).

### Future hooks — Brief §6 (stub only, not built)
- Google Fast Pair seam; retail demo-mode "has ever been paired" bit.

## 🔀 Decisions — RESOLVED (2026-07-11)
1. **minSdk → KEEP 24.** Modern Android (31+) already gets the clean, no-location
   experience via `neverForLocation`; only Android ≤11 still shows a location
   prompt (an unavoidable OS requirement on those versions). Keeping 24 preserves
   Android 7–11 buyers rather than dropping them for a prompt older phones need
   anyway.
2. **Service UUID → MIGRATED** to random 128-bit
   `b88599a1-30f2-4618-b1f1-a8a5a2d10a60` (app `FlatchBle.serviceUuid` +
   firmware `SERVICE_UUID`). **COORDINATED**: the firmware carrying this UUID must
   be flashed in lockstep with the app build carrying it — an app on the new UUID
   will not discover a device still on `0xABCD`, and vice versa. Bundle with the
   next firmware+app release.
3. **Bluetooth stack → KEEP Bluedroid.** Current firmware is built on Bluedroid
   (`BLEDevice.h`); NimBLE's only material win here is a smaller RAM/flash
   footprint, and bonding is achievable on Bluedroid too. Not worth a firmware
   BLE-layer rewrite unless the ESP32 later runs short on memory.

## Acceptance checklist
- [x] Only Flatch devices ever appear in the app's pairing list
- [x] Pairing works in guest mode with zero sign-in
- [ ] iOS 18 uses AccessorySetupKit; iOS 17 falls back cleanly *(native, TODO)*
- [~] Android never requests location permission *(31+ yes; ≤30 pending minSdk decision)*
- [x] Two Flatch units in range: both listed (closest first) *(needs hardware to confirm connect)*
- [ ] Reconnection after app kill + relaunch is automatic *(firmware bonding + state restoration)*
- [ ] System-settings pairing attempt does not brick the in-app flow *(needs hardware)*
- [ ] Unauthorized BLE client cannot trigger sounds *(app handshake exists; verify on firmware)*
- [x] All timeout/failure states have copy + retry *(pre-scan/scanning/no-device/connecting-retry/failure done)*
- [ ] Bonded iPhone reconnects across private-address rotations *(firmware bonding)*
- [ ] 8 phones bond; 9th evicts LRU *(firmware)*
- [ ] Bond survives power cycle AND OTA *(firmware NVS)*
