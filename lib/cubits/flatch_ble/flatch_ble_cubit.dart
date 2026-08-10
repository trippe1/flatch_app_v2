import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:flatch/common/constants/flatch_ble_constants.dart';
import 'package:flatch/common/constants/ota_protocol.dart';
import 'package:flatch/common/services/device_key_service.dart';
import 'package:flatch/common/services/firmware_release_service.dart';
import 'package:flatch/common/services/telemetry_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flatch/common/services/app_logger.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';

part 'flatch_ble_state.dart';

class FlatchBleCubit extends Cubit<FlatchBleState> {
  FlatchBleCubit() : super(const FlatchBleState()) {
    // Only local file setup here. Touching FlutterBluePlus instantiates the
    // platform BLE stack, which makes iOS show the "wants to use Bluetooth"
    // prompt — that must not happen at app launch, only when the user opens
    // the device page (see startBle()).
    _initLocal();
  }

  bool _bleStarted = false;

  // ===================== CONFIG =====================

  // Single source of truth lives in FlatchBle (shared with firmware + native).
  static const String serviceUuid = FlatchBle.serviceUuid;
  static const String cmdUuid = FlatchBle.cmdUuid;
  static const String dataUuid = FlatchBle.dataUuid;
  static const String statusUuid = FlatchBle.statusUuid;
  static const String flowControlUuid = FlatchBle.flowControlUuid;

  // ===================== BLE =====================

  BluetoothCharacteristic? _cmd;
  BluetoothCharacteristic? _data;
  BluetoothCharacteristic? _status;
  BluetoothCharacteristic? _flowControl;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _statusSub;
  StreamSubscription<List<int>>? _dataSub;
  StreamSubscription<List<int>>? _flowControlSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  bool _connected = false;
  bool _downloading = false;
  bool _cancelRequested = false;

  // ===================== AUTH =====================

  bool _authed = false;
  Completer<void>? _authCompleter;

  // ===================== DOWNLOAD =====================

  int _dlSlot = 0;
  int _dlExpected = 0;
  int _dlReceived = 0;
  final BytesBuilder _dlBuffer = BytesBuilder(copy: false);
  Timer? _ackTimer;

  Completer<List<int>>? _listCompleter;
  // Completes when the device sends a terminal command status ("OK" / "ERR:..."),
  // used to handshake multi-file uploads so we don't race the ESP32's flash work.
  Completer<String>? _ackCompleter;

  late Directory _soundDir;

  // ===================== INIT =====================

  Future<void> _initLocal() async {
    _soundDir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/flatch',
    );
    if (!await _soundDir.exists()) {
      await _soundDir.create(recursive: true);
    }

    _loadLocalFiles();
  }

  /// Bring up the BLE stack. Call this ONLY from the device-connection page —
  /// the first touch of FlutterBluePlus is what triggers the OS Bluetooth
  /// permission prompt, so it must be tied to the user opening that page.
  /// Idempotent.
  Future<void> startBle() async {
    if (_bleStarted) return;
    _bleStarted = true;

    // Reflect the current adapter state immediately. On iOS this can be
    // 'unknown' until BLE is first used — that is NOT "off", so we only flag
    // isBluetoothOff on an explicit off report.
    final now0 = FlutterBluePlus.adapterStateNow;
    emit(
      state.copyWith(
        isBluetoothOn: now0 == BluetoothAdapterState.on,
        isBluetoothOff: now0 == BluetoothAdapterState.off,
      ),
    );

    FlutterBluePlus.adapterState.listen((s) async {
      final isOn = s == BluetoothAdapterState.on;
      final isOff = s == BluetoothAdapterState.off;

      emit(state.copyWith(isBluetoothOn: isOn, isBluetoothOff: isOff));

      if (isOn) {
        await scanDevices();
      } else if (isOff) {
        emit(state.copyWith(devices: []));
      }
    });

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      // startScan is already filtered by the Flatch service UUID; this is a
      // belt-and-suspenders filter (some platforms omit service data in the
      // result) plus a sort so the CLOSEST Flatch is listed first.
      final flatch =
          results.where((r) {
              final advertisesService = r.advertisementData.serviceUuids
                  .contains(Guid(FlatchBle.serviceUuid));
              final name =
                  r.device.platformName.isNotEmpty
                      ? r.device.platformName
                      : r.advertisementData.advName;
              return advertisesService ||
                  FlatchBle.nameLooksLikeFlatch(name);
            }).toList()
            ..sort((a, b) => b.rssi.compareTo(a.rssi));
      emit(
        state.copyWith(
          devices: flatch.map((r) => r.device).toList(),
          deviceRssi: {
            for (final r in flatch) r.device.remoteId.str: r.rssi,
          },
        ),
      );
    });
  }

  void addFromLibrary(File sound) {
    final updated = List<File>.from(state.queuedLibrarySounds)..add(sound);
    appLogger.d("Added to queue: ${sound.path}");
    emit(state.copyWith(queuedLibrarySounds: updated));
  }

  Future<bool> syncToFlatch() async {
    appLogger.d('🔵 [SYNC] Started');

    try {
      if (!_authed || _cmd == null || _data == null) {
        appLogger.e('❌ [SYNC] Not ready');
        appLogger.d('   authed=$_authed, cmd=$_cmd, data=$_data');
        return false;
      }

      if (state.queuedLibrarySounds.isEmpty) {
        appLogger.d('⚠️ [SYNC] No queued library sounds to upload');
        return false;
      }

      _cancelRequested = false;

      // Additive sync: keep the tracks already on the device and only fill the
      // empty slots. The device has 9 slots total.
      const int maxSlots = 9;
      final freeSlots = <int>[];
      for (int s = 1; s <= maxSlots; s++) {
        if (!state.availableSlots.contains(s)) freeSlots.add(s);
      }

      final queued = state.queuedLibrarySounds;
      if (queued.length > freeSlots.length) {
        appLogger.e('❌ [SYNC] Not enough free slots');
        emit(
          state.copyWith(
            statusMessage:
                "Not enough space on Flatch: ${freeSlots.length} slot(s) free, "
                "${queued.length} queued. Remove some tracks first.",
          ),
        );
        return false;
      }

      appLogger.d(
        '📤 [SYNC] Uploading ${queued.length} sound(s) into free slots $freeSlots',
      );

      int uploaded = 0;
      for (int i = 0; i < queued.length; i++) {
        if (_cancelRequested) break;

        final file = queued[i];
        final slot = freeSlots[i];
        appLogger.d('📁 [SYNC] Uploading ${file.path} → slot $slot');

        if (!await file.exists()) {
          appLogger.e('❌ [SYNC] File does not exist: ${file.path}');
          emit(state.copyWith(statusMessage: "A queued file is missing from the record."));
          await requestSlotList();
          return false;
        }

        final bytes = await file.readAsBytes();

        // Wait for the device to acknowledge it opened the slot before streaming
        // data. Without this handshake, on a multi-file sync the next command
        // races the ESP32's flash work and gets dropped — only the first file
        // lands and BLE appears to freeze.
        if (!await _sendCmdAwaitAck("UPLOAD_BEGIN:$slot,${bytes.length}")) {
          appLogger.e('❌ [SYNC] No ack for UPLOAD_BEGIN (slot $slot)');
          emit(state.copyWith(statusMessage: "Transfer stalled. Retry."));
          await requestSlotList();
          emit(state.copyWith(queuedLibrarySounds: queued.sublist(uploaded)));
          return false;
        }

        const int cs = 180;
        int off = 0;
        int chunk = 0;
        while (off < bytes.length) {
          if (_cancelRequested) break;
          final end = min(off + cs, bytes.length);
          await _data!.write(bytes.sublist(off, end), withoutResponse: true);
          off = end;
          // Pace the stream so the ESP32's synchronous LittleFS writes keep up
          // and its BLE receive buffer doesn't overflow on sustained transfers.
          if (++chunk % 8 == 0) {
            await Future.delayed(const Duration(milliseconds: 6));
          }
        }
        if (_cancelRequested) {
          await _sendCmd("UPLOAD_END"); // let the device discard the partial
          break;
        }

        // Wait for the device to finish committing the slot (flash write +
        // rename) before starting the next file.
        if (!await _sendCmdAwaitAck("UPLOAD_END")) {
          appLogger.e('❌ [SYNC] No ack for UPLOAD_END (slot $slot)');
          emit(state.copyWith(statusMessage: "Transfer stalled. Retry."));
          await requestSlotList();
          emit(state.copyWith(queuedLibrarySounds: queued.sublist(uploaded)));
          return false;
        }
        uploaded++;

        // Small settle gap between files.
        await Future.delayed(const Duration(milliseconds: 120));
      }

      // Refresh the device slot list to reflect what actually landed.
      await requestSlotList();

      if (_cancelRequested) {
        appLogger.d('🟡 [SYNC] Cancelled after $uploaded upload(s)');
        // Drop the sounds that completed; keep the rest queued for a retry.
        emit(
          state.copyWith(
            queuedLibrarySounds: queued.sublist(uploaded),
            statusMessage: "Deployment cancelled.",
          ),
        );
        return false;
      }

      emit(
        state.copyWith(
          queuedLibrarySounds: [],
          statusMessage: "Flatch updated.",
        ),
      );

      appLogger.d('🟢 [SYNC] Completed successfully');
      return true;
    } catch (e, s) {
      appLogger.e('❌ [SYNC] FAILED');
      appLogger.e('Error: $e');
      appLogger.e('Stack: $s');

      emit(state.copyWith(statusMessage: "Update failed."));
      return false;
    }
  }

  Future<void> playNextSound() async {
    if (!_authed || _cmd == null) {
      emit(state.copyWith(statusMessage: "No device connected."));
      return;
    }

    try {
      await _sendCmd("PLAY_STEP");
      emit(state.copyWith(statusMessage: "Advancing to the next sound."));
    } catch (e) {
      emit(state.copyWith(statusMessage: "Play failed: $e"));
    }
  }

  /// User-driven "Allow Bluetooth" action from the device page: asks for the
  /// permission and, on Android, offers to switch the radio on — so the user
  /// never has to leave for system Settings unless they permanently denied it.
  /// Returns true when we're clear to scan.
  Future<bool> requestBleAccess() async {
    final granted = await _ensureBlePermissions();

    if (!granted) {
      final permanently =
          Platform.isAndroid
              ? await Permission.bluetoothScan.isPermanentlyDenied
              : await Permission.bluetooth.isPermanentlyDenied;
      emit(
        state.copyWith(
          blePermissionDenied: true,
          blePermissionPermanentlyDenied: permanently,
          statusMessage:
              permanently
                  ? 'Bluetooth access is off for Flatch. Turn it on in Settings '
                      'to connect your device.'
                  : 'Bluetooth access is needed to find your Flatch.',
        ),
      );
      return false;
    }

    emit(
      state.copyWith(
        blePermissionDenied: false,
        blePermissionPermanentlyDenied: false,
      ),
    );

    // Android can prompt to enable the radio in place; iOS cannot — there the
    // user has to flip it in Control Centre/Settings, so we just say so.
    if (Platform.isAndroid &&
        FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (_) {
        emit(
          state.copyWith(statusMessage: 'Please switch Bluetooth on to continue.'),
        );
        return false;
      }
    }

    await startBle();
    await scanDevices();
    return true;
  }

  /// Opens the OS settings page for Flatch — last resort when the permission
  /// was permanently denied and the system will no longer prompt.
  Future<void> openBleSettings() => openAppSettings();

  /// Request Bluetooth permissions in-context — only when the user is actually
  /// trying to connect to their Flatch device, never at app startup.
  Future<bool> _ensureBlePermissions() async {
    try {
      if (Platform.isAndroid) {
        // API 31+ : BLUETOOTH_SCAN (neverForLocation) + BLUETOOTH_CONNECT, no
        // location. API <=30 : location is requested too (best effort) because
        // legacy BLE scanning requires it there; only scan+connect are gating.
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.locationWhenInUse,
        ].request();
        final scan = await Permission.bluetoothScan.status;
        final connect = await Permission.bluetoothConnect.status;
        return scan.isGranted && connect.isGranted;
      }
      return (await Permission.bluetooth.request()).isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<void> scanDevices() async {
    if (!await _ensureBlePermissions()) {
      emit(
        state.copyWith(
          isLoading: false,
          statusMessage: 'Bluetooth access is required to locate the device.',
        ),
      );
      return;
    }
    emit(state.copyWith(isLoading: true, devices: []));

    await FlutterBluePlus.stopScan();
    // Only surface Flatch devices — filter the scan by the product-family
    // service UUID so no unrelated Bluetooth devices ever appear.
    await FlutterBluePlus.startScan(
      withServices: [Guid(FlatchBle.serviceUuid)],
      timeout: const Duration(seconds: 5),
    );

    await Future.delayed(const Duration(seconds: 10));
    await FlutterBluePlus.stopScan();

    emit(state.copyWith(isLoading: false));
  }

  // ===================== CONNECT =====================

  Future<void> connectDevice(BluetoothDevice device) async {
    emit(
      state.copyWith(
        isConnecting: true,
        error: null,
        statusMessage: "Connecting to your Flatch…",
      ),
    );

    // Up to 3 attempts, 10s each, with a short backoff (Brief §5.3).
    Object? lastError;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        if (attempt > 1) {
          emit(
            state.copyWith(
              statusMessage:
                  "Connecting to your Flatch… (attempt $attempt of 3)",
            ),
          );
          await Future.delayed(Duration(milliseconds: 400 * attempt));
        }
        await _attemptConnect(device);
        return; // success
      } catch (e) {
        lastError = e;
        try {
          await device.disconnect();
        } catch (_) {}
      }
    }
    _connected = false;
    emit(
      state.copyWith(
        isConnecting: false,
        isLoading: false,
        statusMessage: "The connection could not be established.",
        error: lastError.toString(),
      ),
    );
  }

  Future<void> _attemptConnect(BluetoothDevice device) async {
    // Stop scanning before connecting
    await FlutterBluePlus.stopScan();

    // Connect to the device
    await device.connect(
      autoConnect: false,
      timeout: const Duration(seconds: 10),
    );

    _connected = true;

      // Listen for disconnections
      _connSub?.cancel();
      _connSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _connected = false;
          _resetAll("The device has gone silent. Investigate.");
        }
      });

      // Request MTU size - only on Android
      if (Platform.isAndroid) {
        await device.requestMtu(185);
      }

      // Discover services
      final services = await device.discoverServices();
      final svc = services.firstWhere(
        (s) => s.uuid == Guid(serviceUuid),
        orElse: () => throw Exception("Service not found"),
      );

      // Find characteristics
      _cmd = null;
      _data = null;
      _status = null;
      _flowControl = null;

      for (final c in svc.characteristics) {
        if (c.uuid == Guid(cmdUuid)) _cmd = c;
        if (c.uuid == Guid(dataUuid)) _data = c;
        if (c.uuid == Guid(statusUuid)) _status = c;
        if (c.uuid == Guid(flowControlUuid)) _flowControl = c;
      }

      if (_cmd == null || _data == null || _status == null) {
        throw Exception("Required characteristics missing");
      }

      // Enable notifications for status and data characteristics
      await _status!.setNotifyValue(true);
      _statusSub?.cancel();
      _statusSub = _status!.onValueReceived.listen(_handleStatus);

      await _data!.setNotifyValue(true);
      _dataSub?.cancel();
      _dataSub = _data!.onValueReceived.listen(_handleData);

      emit(
        state.copyWith(
          connectedDevice: device,
          isLoading: false,
          statusMessage: "Link established. Verifying credentials…",
        ),
      );

      await _authenticate();

      await requestSlotList();

      // Ask for the firmware version so the app can offer OTA updates. Fire and
      // forget — the reply arrives on the status stream as VERSION:<semver>.
      try {
        await _sendCmdRaw(OtaProtocol.cmdGetVersion);
      } catch (_) {}

      emit(state.copyWith(statusMessage: "Device ready. Standing by.", isConnecting: false));
  }

  // ===================== OTA (firmware update) =====================

  /// Kick off an over-the-air firmware update to [release]. The device does the
  /// heavy lifting (WiFi + download + verify + install + rollback); the app
  /// just hands it the URL/hash and relays progress. [wifiSsid]/[wifiPassword]
  /// are optional — send them if the device isn't otherwise provisioned.
  ///
  /// Reports failures via the `otaError` state field; progress via
  /// `otaStateLabel` / `otaProgress`. See OtaProtocol / docs/OTA_PROTOCOL.md.
  Future<void> startOta(
    FirmwareRelease release, {
    String? wifiSsid,
    String? wifiPassword,
  }) async {
    if (!_authed || _cmd == null) {
      emit(state.copyWith(otaError: "Connect to your Flatch first."));
      return;
    }
    emit(
      state.copyWith(
        clearOtaState: true,
        otaStateLabel: 'Starting update…',
        otaProgress: 0.0,
      ),
    );

    try {
      // 1. WiFi (if provided).
      if (wifiSsid != null && wifiSsid.isNotEmpty) {
        await _sendCmdRaw(
          '${OtaProtocol.cmdWifiPrefix}$wifiSsid${OtaProtocol.sep}'
          '${wifiPassword ?? ''}',
        );
      }

      // 2. Send the URL in chunks (a signed URL can exceed the BLE MTU).
      await _sendCmdRaw(OtaProtocol.cmdUrlClear);
      final url = release.url;
      for (var i = 0; i < url.length; i += OtaProtocol.urlChunkSize) {
        final end = (i + OtaProtocol.urlChunkSize).clamp(0, url.length);
        await _sendCmdRaw(
          '${OtaProtocol.cmdUrlAppendPrefix}${url.substring(i, end)}',
        );
        await Future.delayed(const Duration(milliseconds: 20));
      }

      // 3. Start.
      await _sendCmdRaw(
        '${OtaProtocol.cmdStartPrefix}${release.sizeBytes},'
        '${release.sha256},${release.version}',
      );
    } catch (e) {
      emit(
        state.copyWith(
          clearOtaState: true,
          otaError: "Couldn't start the update. Try again.",
        ),
      );
    }
  }

  Future<void> abortOta() async {
    try {
      await _sendCmdRaw(OtaProtocol.cmdAbort);
    } catch (_) {}
    emit(state.copyWith(clearOtaState: true, otaProgress: 0.0));
  }

  void clearOtaError() => emit(state.copyWith(clearOtaState: true));


  // ===================== AUTH =====================

  Future<void> _authenticate() async {
    _authed = false;
    _authCompleter = Completer<void>();
    await _sendCmdRaw("AUTH_HELLO");
    await _authCompleter!.future.timeout(const Duration(seconds: 4));
    emit(state.copyWith(isCodeVerified: true, statusMessage: "AUTH OK"));
    Telemetry.instance.deviceConnected();
  }

  /// Handle `AUTH_CHAL:<challengeHex>,<MAC>`. The device authenticates with a
  /// PER-DEVICE key (not the old shared secret): we look up the key for the MAC
  /// it reported, then reply HMAC-SHA256(key, challenge) over the raw bytes of
  /// each. The MAC comes from the message, not from BLE, because iOS hides the
  /// hardware MAC behind a random peripheral UUID.
  void _handleAuthChallenge(String payload) async {
    final parsed = DeviceKeyService.parseChallenge(payload);
    if (parsed == null || parsed.challengeHex.isEmpty) {
      emit(state.copyWith(statusMessage: "Auth error: bad challenge."));
      return;
    }

    final resp = await DeviceKeyService.computeResponse(
      challengeHex: parsed.challengeHex,
      mac: parsed.mac,
    );

    if (resp == null) {
      // No key on file for this device.
      emit(
        state.copyWith(
          statusMessage:
              "This Flatch isn't recognized (${parsed.mac}). It may need to be "
              "registered.",
        ),
      );
      return;
    }
    await _sendCmdRaw("AUTH_RESP:$resp");
  }

  Future<void> _handleStatus(List<int> raw) async {
    final msg = utf8.decode(raw, allowMalformed: true).trim();
    emit(state.copyWith(statusMessage: msg));

    if (msg.startsWith("AUTH_CHAL:")) {
      _handleAuthChallenge(msg.substring(10));
      return;
    }

    if (msg == "AUTH_OK") {
      _authed = true;
      if (_authCompleter != null && !_authCompleter!.isCompleted) {
        _authCompleter!.complete();
      }
      return;
    }

    // ---- OTA / firmware ----
    if (msg.startsWith(OtaProtocol.sVersion)) {
      emit(
        state.copyWith(
          deviceFirmwareVersion:
              msg.substring(OtaProtocol.sVersion.length).trim(),
        ),
      );
      return;
    }
    if (msg.startsWith(OtaProtocol.sOtaState)) {
      final st = OtaDeviceState.parse(
        msg.substring(OtaProtocol.sOtaState.length),
      );
      if (st != null) emit(state.copyWith(otaStateLabel: st.label));
      return;
    }
    if (msg.startsWith(OtaProtocol.sOtaProgress)) {
      final p = msg.substring(OtaProtocol.sOtaProgress.length).split('/');
      final done = int.tryParse(p.first.trim()) ?? 0;
      final total = p.length > 1 ? (int.tryParse(p[1].trim()) ?? 0) : 0;
      if (total > 0) {
        emit(state.copyWith(otaProgress: (done / total).clamp(0.0, 1.0)));
      }
      return;
    }
    if (msg.startsWith(OtaProtocol.sOtaError)) {
      final err = OtaError.parse(msg.substring(OtaProtocol.sOtaError.length));
      emit(state.copyWith(clearOtaState: true, otaError: err.message));
      return;
    }
    if (msg == OtaProtocol.sOtaDone) {
      // Device installed the image and is rebooting; it will drop the BLE link,
      // re-advertise on the new firmware, and (on reconnect) report VERSION:.
      emit(
        state.copyWith(
          otaStateLabel: OtaDeviceState.rebooting.label,
          otaProgress: 1.0,
        ),
      );
      return;
    }

    if (msg.startsWith("LIST:")) {
      final rawSlots = msg.substring(5).trim();

      final slots =
          rawSlots.isEmpty
                ? <int>[]
                : rawSlots
                    .split(',')
                    .map((e) => int.tryParse(e.trim()))
                    .whereType<int>()
                    .toList()
            ..sort();

      emit(state.copyWith(availableSlots: slots));

      if (_listCompleter != null && !_listCompleter!.isCompleted) {
        _listCompleter!.complete(slots);
      }
      return;
    }

    // Terminal command acknowledgement — unblocks _sendCmdAwaitAck().
    if (msg == "OK" || msg.startsWith("ERR:")) {
      if (_ackCompleter != null && !_ackCompleter!.isCompleted) {
        _ackCompleter!.complete(msg == "OK" ? "OK" : msg);
      }
      return;
    }

    if (msg.startsWith("PROG:")) {
      final p = msg.substring(5).split('/');
      emit(state.copyWith(uploadProgress: int.parse(p[0]) / int.parse(p[1])));
      return;
    }

    if (msg.startsWith("DL_BEGIN:")) {
      final p = msg.substring(9).split(',');
      _dlSlot = int.parse(p[0]);
      _dlExpected = int.parse(p[1]);
      _dlReceived = 0;
      _dlBuffer.clear();
      _downloading = true;

      _startAckTimer();

      emit(
        state.copyWith(
          isDownloading: true,
          downloadingSlot: _dlSlot,
          downloadProgress: 0.0,
          statusMessage: "Retrieving slot $_dlSlot…",
        ),
      );
      return;
    }

    if (msg.startsWith("DL_PROG:")) {
      final p = msg.substring(8).split(',');
      final slot = int.parse(p[0]);
      final progress = int.parse(p[1]);

      if (slot == _dlSlot) {
        _dlReceived = progress;
        emit(
          state.copyWith(
            downloadProgress: (_dlReceived / _dlExpected).clamp(0.0, 1.0),
          ),
        );
      }
      return;
    }

    if (msg.startsWith("DL_END:")) {
      await _finishDownload();
      return;
    }
  }

  void _startAckTimer() {
    _ackTimer?.cancel();
    _ackTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_downloading && _dlReceived > 0) {
        _sendAcknowledgment(_dlReceived);
      }
    });
  }

  void _stopAckTimer() {
    _ackTimer?.cancel();
    _ackTimer = null;
  }

  Future<void> _sendAcknowledgment(int bytesReceived) async {
    if (_flowControl == null || !_connected) return;

    try {
      await _flowControl!.write(
        utf8.encode("ACK:$bytesReceived"),
        withoutResponse: true,
      );
      appLogger.d("📤 [ACK] Sent acknowledgement for $bytesReceived bytes");
    } catch (e) {
      appLogger.e("❌ Error sending ACK: $e");
    }
  }

  void _handleData(List<int> chunk) {
    if (!_downloading) {
      appLogger.d("⚠️ [DL] Ignored chunk (not downloading)");
      return;
    }

    if (_dlExpected <= 0) {
      appLogger.d("⚠️ [DL] Ignored chunk (DL_BEGIN not received yet)");
      return;
    }

    _dlBuffer.add(chunk);
    _dlReceived += chunk.length;

    appLogger.d("📦 [DL] Data chunk received: ${chunk.length} bytes");
    appLogger.d("📊 [DL] Progress: $_dlReceived / $_dlExpected");

    // Send immediate acknowledgment for important chunks
    if (_dlReceived % 2048 < 100) {
      _sendAcknowledgment(_dlReceived);
    }

    emit(
      state.copyWith(
        downloadProgress: (_dlReceived / _dlExpected).clamp(0.0, 1.0),
      ),
    );

    // Check if download is complete
    if (_dlReceived >= _dlExpected) {
      appLogger.d("✅ [DL] Download complete by byte count");
      _finishDownload();
    }
  }

  Future<void> _finishDownload() async {
    appLogger.d("🏁 [DL] Finish download called");
    appLogger.d("📊 [DL] Received $_dlReceived / $_dlExpected bytes");

    // Stop acknowledgment timer
    _stopAckTimer();

    // Send final acknowledgement
    await _sendAcknowledgment(_dlReceived);

    _downloading = false;

    if (_dlExpected <= 0) {
      appLogger.e("❌ [DL] ERROR: DL_END without DL_BEGIN");
      emit(
        state.copyWith(
          isDownloading: false,
          downloadingSlot: null,
          statusMessage: "Retrieval failed. No response from the device.",
        ),
      );
      return;
    }

    if (_dlReceived != _dlExpected) {
      appLogger.e("❌ [DL] ERROR: Size mismatch");
      emit(
        state.copyWith(
          isDownloading: false,
          downloadingSlot: null,
          statusMessage: "Download corrupted ($_dlReceived / $_dlExpected)",
        ),
      );
      return;
    }

    final bytes = _dlBuffer.takeBytes();

    // Guard against truncated transfers. The byte counter (_dlReceived) can be
    // inflated by DL_PROG status frames reporting the device's *sent* count, so
    // when chunks are dropped in transit the size check above still passes.
    // Validate the actual received buffer length here — a short/empty buffer
    // means data was lost, so surface a retry instead of saving 0-length audio.
    if (bytes.isEmpty || bytes.length != _dlExpected) {
      appLogger.e(
        '❌ [DL] Truncated: got ${bytes.length} of $_dlExpected bytes',
      );
      emit(
        state.copyWith(
          isDownloading: false,
          downloadingSlot: null,
          downloadProgress: 0,
          statusMessage:
              "Download incomplete (${bytes.length}/$_dlExpected bytes) — please retry",
        ),
      );
      return;
    }

    final fileName = 'sound$_dlSlot.wav';

    // Save to app directory
    final appFile = File('${_soundDir.path}/$fileName');
    await appFile.writeAsBytes(bytes, flush: true);

    // Also save to Downloads folder using your existing function
    // You'll need to pass the context, so this might need to be done in the UI
    // Or modify your cubit to accept a BuildContext

    // Update downloaded file paths map
    final updatedPaths = Map<int, String>.from(state.downloadedFilePaths);
    updatedPaths[_dlSlot] = appFile.path;

    emit(
      state.copyWith(
        isDownloading: false,
        downloadingSlot: null,
        downloadProgress: 0,
        soundFiles: _soundDir.listSync().whereType<File>().toList(),
        downloadedFilePaths: updatedPaths,
        statusMessage: "Slot $_dlSlot retrieved as '$fileName'.",
      ),
    );
  }

  // ===================== UPLOAD =====================

  Future<void> uploadWav() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    if (res == null) return;

    final bytes = res.files.first.bytes!;
    final slot = _firstEmptySlot();

    appLogger.d("Deploying to slot $slot.");
    emit(state.copyWith(statusMessage: "Deploying to slot $slot."));

    // Same handshake as the multi-file sync: wait for the device to ack each
    // command so we don't race its flash work.
    if (!await _sendCmdAwaitAck("UPLOAD_BEGIN:$slot,${bytes.length}")) {
      emit(
        state.copyWith(
          uploadProgress: 0,
          statusMessage: "Transfer stalled. Retry.",
        ),
      );
      await requestSlotList();
      return;
    }
    const int cs = 180;
    int off = 0;
    int chunk = 0;

    while (off < bytes.length) {
      final end = min(off + cs, bytes.length);
      await _data!.write(bytes.sublist(off, end), withoutResponse: true);
      off = end;

      emit(state.copyWith(uploadProgress: off / bytes.length));
      // Pace the stream so the ESP32's synchronous LittleFS writes keep up.
      if (++chunk % 8 == 0) {
        await Future.delayed(const Duration(milliseconds: 6));
      }
    }

    if (!await _sendCmdAwaitAck("UPLOAD_END")) {
      emit(
        state.copyWith(
          uploadProgress: 0,
          statusMessage: "Transfer stalled. Retry.",
        ),
      );
      await requestSlotList();
      return;
    }
    await requestSlotList();

    emit(state.copyWith(uploadProgress: 0, statusMessage: "Deployment complete."));
  }
  // ===================== PLAY SLOT =====================

  Future<void> playSlot(int slot) async {
    if (!_authed || _cmd == null) {
      emit(
        state.copyWith(
          statusMessage: "Not authorized. Complete the handshake first.",
        ),
      );
      return;
    }

    appLogger.d('Attempting to play slot $slot');

    try {
      // Send the command to play the slot
      await _sendCmd("PLAY:$slot");
      appLogger.d('Command sent to play slot $slot');
      emit(state.copyWith(statusMessage: "Deploying slot $slot."));
    } catch (e) {
      // Catch any exceptions that occur during the command send
      appLogger.e('Error occurred while playing slot $slot: $e');
      emit(state.copyWith(statusMessage: "Slot $slot failed to deploy."));
    }
  }

  Future<void> deleteSlot(int slot, {bool silent = false}) async {
    if (!_authed || _cmd == null) {
      emit(
        state.copyWith(
          statusMessage: "Not authorized. Complete the handshake first.",
        ),
      );
      return;
    }

    try {
      await _sendCmd("DELETE:$slot");
      appLogger.d('Command sent to delete slot $slot');

      final file = File('${_soundDir.path}/sound$slot.wav');
      if (await file.exists()) {
        await file.delete();
      }

      if (!silent) {
        await requestSlotList();
      }

      emit(state.copyWith(statusMessage: "Slot $slot cleared."));
    } catch (e) {
      appLogger.e('Error occurred while deleting slot $slot: $e');
      emit(state.copyWith(statusMessage: "Slot $slot could not be cleared."));
    }
  }

  Future<List<int>> requestSlotList() async {
    _listCompleter = Completer<List<int>>();

    await _sendCmd("LIST");

    try {
      return await _listCompleter!.future.timeout(const Duration(seconds: 2));
    } catch (e) {
      appLogger.e("Error while requesting slot list: $e");
      return [];
    }
  }

  Future<void> _sendCmd(String cmd) async {
    if (!_authed || _cmd == null) {
      return;
    }

    try {
      await _cmd!.write(utf8.encode(cmd), withoutResponse: false);
    } catch (e) {
      appLogger.e("Error sending command: $e");
    }
  }

  /// Sends a command and waits for the device's terminal status ("OK", or an
  /// "ERR:..."). This lets a multi-file upload wait for the ESP32 to finish its
  /// (slow, synchronous) flash work before the next command — without it, the
  /// next UPLOAD_BEGIN races ahead and is dropped, so only the first file lands
  /// and BLE appears to freeze. Returns true only on "OK".
  Future<bool> _sendCmdAwaitAck(
    String cmd, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    _ackCompleter = Completer<String>();
    await _sendCmd(cmd);
    try {
      final resp = await _ackCompleter!.future.timeout(timeout);
      return resp == "OK";
    } catch (e) {
      appLogger.e("⏱️ [BLE] No ack for '$cmd' (${e.runtimeType})");
      return false;
    } finally {
      _ackCompleter = null;
    }
  }

  Future<void> downloadSlot(int slot) async {
    if (_downloading) {
      emit(state.copyWith(statusMessage: "A retrieval is already in progress."));
      return;
    }

    // Reset download state
    _cancelRequested = false;
    _dlSlot = slot;
    _dlExpected = 0;
    _dlReceived = 0;
    _dlBuffer.clear();
    _downloading = true;

    emit(
      state.copyWith(
        isDownloading: true,
        downloadingSlot: slot,
        statusMessage: "Initiating retrieval of slot $slot…",
        downloadProgress: 0.0,
      ),
    );

    try {
      await _sendCmd("DOWNLOAD:$slot");
    } catch (e) {
      appLogger.e("Error starting download: $e");
      _downloading = false;
      emit(
        state.copyWith(
          isDownloading: false,
          downloadingSlot: null,
          statusMessage: "Retrieval could not be initiated.",
        ),
      );
    }
  }

  /// Cancels an in-progress transfer (an upload sync or a download).
  ///
  /// Uploads: the sync loop checks [_cancelRequested] between chunks and sends
  /// an early UPLOAD_END so the firmware discards the partial slot.
  /// Downloads: the client stops accumulating and frees the UI immediately.
  /// (The current firmware keeps streaming the remainder of a download — it
  /// can't be aborted mid-transfer without a firmware change — but the app now
  /// ignores those leftover chunks instead of hanging on the dialog.)
  void cancelTransfer() {
    _cancelRequested = true;
    if (_downloading) {
      // Tell the device to stop streaming (firmware honors CANCEL mid-download).
      _sendCmd("CANCEL").ignore();
      _downloading = false;
      _stopAckTimer();
      _dlBuffer.clear();
      _dlExpected = 0;
      _dlReceived = 0;
      emit(
        state.copyWith(
          isDownloading: false,
          downloadingSlot: null,
          downloadProgress: 0,
          statusMessage: "Transfer cancelled.",
        ),
      );
    }
  }

  // ===================== LOCAL FILES =====================

  void _loadLocalFiles() {
    if (!_soundDir.existsSync()) return;

    final files = _soundDir.listSync().whereType<File>().toList();
    final Map<int, String> filePaths = {};

    for (final file in files) {
      if (file.path.endsWith('.wav')) {
        final match = RegExp(
          r'sound(\d+)\.wav',
        ).firstMatch(file.path.split('/').last);
        if (match != null) {
          final slot = int.parse(match.group(1)!);
          filePaths[slot] = file.path;
        }
      }
    }

    emit(state.copyWith(soundFiles: files, downloadedFilePaths: filePaths));
  }

  int _firstEmptySlot() {
    for (int i = 1; i <= 9; i++) {
      if (!state.availableSlots.contains(i)) return i;
    }
    return 1;
  }

  // ===================== UTILS =====================

  Future<void> _sendCmdRaw(String cmd) async {
    try {
      await _cmd!.write(utf8.encode(cmd), withoutResponse: false, timeout: 5);
    } catch (e) {
      appLogger.e("Error sending raw command: $e");
    }
  }

  List<int> createValidSlotMap(List<int> availableSlots) {
    List<int> mapNewToOld = List<int>.filled(9, 0);

    for (int i = 0; i < availableSlots.length; i++) {
      mapNewToOld[i] = availableSlots[i];
    }

    return mapNewToOld;
  }

  void _resetAll(String msg) {
    _authed = false;
    _downloading = false;
    _dlBuffer.clear();
    _stopAckTimer();
    _connected = false;

    emit(
      FlatchBleState(isBluetoothOn: state.isBluetoothOn, statusMessage: msg),
    );
  }

  Future<void> reorderSlots(List<int> mapNewToOld) async {
    final expectedLength = state.availableSlots.length;

    if (mapNewToOld.length != expectedLength) {
      emit(
        state.copyWith(
          statusMessage:
              "Invalid reorder map, it should contain exactly $expectedLength elements",
        ),
      );
      return;
    }

    for (var slot in mapNewToOld) {
      if (!state.availableSlots.contains(slot)) {
        emit(
          state.copyWith(
            statusMessage: "Invalid slot number in the reorder map: $slot",
          ),
        );
        return;
      }
    }

    final cmd = "REORDER:${mapNewToOld.join(',')}";
    await _sendCmd(cmd);

    await requestSlotList();

    emit(state.copyWith(statusMessage: "Slot order updated."));
  }

  @override
  Future<void> close() {
    _scanSub?.cancel();
    _statusSub?.cancel();
    _dataSub?.cancel();
    _flowControlSub?.cancel();
    _connSub?.cancel();
    _stopAckTimer();
    return super.close();
  }
}
