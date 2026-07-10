import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flatch/common/services/app_logger.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';

part 'flatch_ble_state.dart';

class FlatchBleCubit extends Cubit<FlatchBleState> {
  FlatchBleCubit() : super(const FlatchBleState()) {
    _init();
  }

  // ===================== CONFIG =====================

  static const String serviceUuid = "0000abcd-0000-1000-8000-00805f9b34fb";
  static const String cmdUuid = "0000abce-0000-1000-8000-00805f9b34fb";
  static const String dataUuid = "0000abcf-0000-1000-8000-00805f9b34fb";
  static const String statusUuid = "0000abd0-0000-1000-8000-00805f9b34fb";
  static const String flowControlUuid = "0000abd1-0000-1000-8000-00805f9b34fb";

  static const String _authSecret = "CHANGE_ME_TO_STRONG_SECRET_123";

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

  Future<void> _init() async {
    _soundDir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/flatch',
    );
    if (!await _soundDir.exists()) {
      await _soundDir.create(recursive: true);
    }

    _loadLocalFiles();

    FlutterBluePlus.adapterState.listen((s) async {
      final isOn = s == BluetoothAdapterState.on;

      emit(state.copyWith(isBluetoothOn: isOn));

      if (isOn) {
        await scanDevices();
      } else {
        emit(state.copyWith(devices: []));
      }
    });

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      emit(state.copyWith(devices: results.map((e) => e.device).toList()));
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
          emit(state.copyWith(statusMessage: "A queued file is missing"));
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
          emit(state.copyWith(statusMessage: "Upload stalled — please retry"));
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
          emit(state.copyWith(statusMessage: "Upload stalled — please retry"));
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
            statusMessage: "Sync cancelled",
          ),
        );
        return false;
      }

      emit(
        state.copyWith(
          queuedLibrarySounds: [],
          statusMessage: "Flatch Updated!",
        ),
      );

      appLogger.d('🟢 [SYNC] Completed successfully');
      return true;
    } catch (e, s) {
      appLogger.e('❌ [SYNC] FAILED');
      appLogger.e('Error: $e');
      appLogger.e('Stack: $s');

      emit(state.copyWith(statusMessage: "Error with Update"));
      return false;
    }
  }

  Future<void> playNextSound() async {
    if (!_authed || _cmd == null) {
      emit(state.copyWith(statusMessage: "Not connected"));
      return;
    }

    try {
      await _sendCmd("PLAY_STEP");
      emit(state.copyWith(statusMessage: "Playing next sound"));
    } catch (e) {
      emit(state.copyWith(statusMessage: "Play failed: $e"));
    }
  }

  Future<void> scanDevices() async {
    emit(state.copyWith(isLoading: true, devices: []));

    await FlutterBluePlus.stopScan();
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    await Future.delayed(const Duration(seconds: 10));
    await FlutterBluePlus.stopScan();

    emit(state.copyWith(isLoading: false));
  }

  // ===================== CONNECT =====================

  Future<void> connectDevice(BluetoothDevice device) async {
    emit(
      state.copyWith(
        isConnecting: true,
        statusMessage: "Connecting to device...",
      ),
    );

    try {
      // Stop scanning before connecting
      await FlutterBluePlus.stopScan();

      // Connect to the device
      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 8),
      );

      _connected = true;

      // Listen for disconnections
      _connSub?.cancel();
      _connSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _connected = false;
          _resetAll("Device disconnected");
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
          statusMessage: "Connected — Authenticating...",
        ),
      );

      await _authenticate();

      await requestSlotList();

      emit(state.copyWith(statusMessage: "Device ready", isConnecting: false));
    } catch (e) {
      _connected = false;
      emit(
        state.copyWith(
          isConnecting: false,
          isLoading: false,
          statusMessage: "Connection failed",
          error: e.toString(),
        ),
      );
    }
  }


  // ===================== AUTH =====================

  Future<void> _authenticate() async {
    _authed = false;
    _authCompleter = Completer<void>();
    await _sendCmdRaw("AUTH_HELLO");
    await _authCompleter!.future.timeout(const Duration(seconds: 4));
    emit(state.copyWith(isCodeVerified: true, statusMessage: "AUTH OK"));
  }

  void _handleAuthChallenge(String hex) async {
    final bytes = _hexToBytes(hex);
    final hmac = Hmac(sha256, utf8.encode(_authSecret));
    final digest = hmac.convert(bytes);
    final resp =
        digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _sendCmdRaw("AUTH_RESP:$resp");
  }

  static Uint8List _hexToBytes(String hex) {
    final clean = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    final out = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < out.length; i++) {
      out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
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
          statusMessage: "Downloading slot $_dlSlot...",
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
          statusMessage: "Download failed: no DL_BEGIN",
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
        statusMessage: "Slot $_dlSlot downloaded as '$fileName'",
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

    appLogger.d("Uploading to slot $slot");
    emit(state.copyWith(statusMessage: "Uploading to slot $slot"));

    await _sendCmd("UPLOAD_BEGIN:$slot,${bytes.length}");
    const int cs = 180;
    int off = 0;

    while (off < bytes.length) {
      final end = min(off + cs, bytes.length);
      await _data!.write(bytes.sublist(off, end), withoutResponse: true);
      off = end;

      emit(state.copyWith(uploadProgress: off / bytes.length));
    }

    await _sendCmd("UPLOAD_END");
    await requestSlotList();

    emit(state.copyWith(uploadProgress: 0, statusMessage: "Upload complete"));
  }
  // ===================== PLAY SLOT =====================

  Future<void> playSlot(int slot) async {
    if (!_authed || _cmd == null) {
      emit(
        state.copyWith(
          statusMessage: "Not authenticated or no command characteristic",
        ),
      );
      return;
    }

    appLogger.d('Attempting to play slot $slot');

    try {
      // Send the command to play the slot
      await _sendCmd("PLAY:$slot");
      appLogger.d('Command sent to play slot $slot');
      emit(state.copyWith(statusMessage: "Playing slot $slot"));
    } catch (e) {
      // Catch any exceptions that occur during the command send
      appLogger.e('Error occurred while playing slot $slot: $e');
      emit(state.copyWith(statusMessage: "Error playing slot $slot"));
    }
  }

  Future<void> deleteSlot(int slot, {bool silent = false}) async {
    if (!_authed || _cmd == null) {
      emit(
        state.copyWith(
          statusMessage: "Not authenticated or no command characteristic",
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

      emit(state.copyWith(statusMessage: "Slot $slot deleted"));
    } catch (e) {
      appLogger.e('Error occurred while deleting slot $slot: $e');
      emit(state.copyWith(statusMessage: "Error deleting slot $slot"));
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
      emit(state.copyWith(statusMessage: "Already downloading"));
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
        statusMessage: "Starting download for slot $slot",
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
          statusMessage: "Download failed to start",
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
          statusMessage: "Transfer cancelled",
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

    emit(state.copyWith(statusMessage: "Slots reordered successfully"));
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
