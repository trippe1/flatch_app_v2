import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';



class BLEHome extends StatefulWidget {
  const BLEHome({super.key});

  @override
  State<BLEHome> createState() => _BLEHomeState();
}

class _BLEHomeState extends State<BLEHome> {
  BluetoothDevice? connectedDevice;

  BluetoothCharacteristic? cmdChar;
  BluetoothCharacteristic? dataChar;
  BluetoothCharacteristic? statusChar;

  bool isScanning = false;
  bool isReady = false;

  List<ScanResult> devices = [];

  String connectionStatus = " Tap Bluetooth icon to scan";
  double uploadProgress = 0.0;
  double downloadProgress = 0.0;

  static const String serviceUuid = "0000abcd-0000-1000-8000-00805f9b34fb";
  static const String cmdUuid = "0000abce-0000-1000-8000-00805f9b34fb";
  static const String dataUuid = "0000abcf-0000-1000-8000-00805f9b34fb";
  static const String statusUuid = "0000abd0-0000-1000-8000-00805f9b34fb";

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _statusNotifySub;
  StreamSubscription<List<int>>? _dataNotifySub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  List<int> availableSlots = [];
  int mtu = 185;

  bool downloading = false;
  int dlSlot = 0;
  int dlExpected = 0;
  int dlReceived = 0;
  final BytesBuilder dlBuffer = BytesBuilder(copy: false);

  Completer<List<int>>? _listCompleter;

  static const String _authSecret = "CHANGE_ME_TO_STRONG_SECRET_123";
  bool _authed = false;
  Completer<void>? _authCompleter;
  String? _challengeHex;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _initBLE();

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;

      results.sort((a, b) {
        final aHas = a.advertisementData.serviceUuids.contains(
          serviceUuid.toLowerCase(),
        );
        final bHas = b.advertisementData.serviceUuids.contains(
          serviceUuid.toLowerCase(),
        );
        if (aHas == bHas) return 0;
        return aHas ? -1 : 1;
      });

      setState(() => devices = results);
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _statusNotifySub?.cancel();
    _dataNotifySub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = true;
   
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    if (mounted) {
     
    }
  }

  Future<void> _initBLE() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on && mounted) {
        setState(
          () => connectionStatus = " Bluetooth is OFF. Please turn it ON.",
        );
      }
    } catch (_) {}
  }

  Future<void> _scanDevices() async {
    devices.clear();
    setState(() {
      isScanning = true;
      connectionStatus = " Scanning for BLE devices...";
    });

    await FlutterBluePlus.stopScan();

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 6),
      withServices: [Guid(serviceUuid)],
      androidScanMode: AndroidScanMode.lowLatency,
    );

    await Future.delayed(const Duration(seconds: 6));
    await FlutterBluePlus.stopScan();

    if (!mounted) return;
    setState(() {
      isScanning = false;
      connectionStatus =
          devices.isEmpty
              ? "No devices found (check permissions / advertising)"
              : "Select a device";
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();

    setState(() {
      connectionStatus =
          "⏳ Connecting to ${device.platformName.isEmpty ? "ESP32 Device" : device.platformName}...";
      connectedDevice = device;
      isReady = false;
      _authed = false;

      cmdChar = null;
      dataChar = null;
      statusChar = null;

      uploadProgress = 0;
      downloadProgress = 0;
      availableSlots = [];
      _resetDownloadState();
    });

    await _connSub?.cancel();
    _connSub = device.connectionState.listen((state) {
      if (!mounted) return;
      if (state == BluetoothConnectionState.disconnected) {
        setState(() {
          isReady = false;
          _authed = false;
          connectionStatus = "Disconnected";
        });
      }
    });

    try {
      await device
          .connect(timeout: const Duration(seconds: 10), autoConnect: false)
          .catchError((_) {});
      if (!mounted) return;
      setState(() => connectionStatus = "Connected. Discovering services...");
    } catch (e) {
      if (!mounted) return;
      setState(() => connectionStatus = " Connection failed: $e");
      return;
    }

    try {
      mtu = await device.requestMtu(185);
    } catch (_) {}

    List<BluetoothService> services = [];
    BluetoothService? targetService;

    for (int attempt = 1; attempt <= 6; attempt++) {
      try {
        services = await device.discoverServices();
      } catch (e) {
        if (!mounted) return;
        setState(() => connectionStatus = " Service discovery failed: $e");
        await _disconnectDevice();
        return;
      }

      for (final s in services) {
        if (s.uuid == Guid(serviceUuid)) {
          targetService = s;
          break;
        }
      }
      if (targetService != null) break;

      if (!mounted) return;
      setState(
        () => connectionStatus = "Service not found... retry $attempt/6",
      );
      await Future.delayed(const Duration(milliseconds: 650));
    }

    if (targetService == null) {
      if (!mounted) return;
      setState(() {
        connectionStatus =
            " Service not found.\nFound:\n${services.map((e) => e.uuid).join("\n")}";
      });
      await _disconnectDevice();
      return;
    }

    final service = targetService;

    BluetoothCharacteristic? _cmd, _data, _status;
    for (final c in service.characteristics) {
      if (c.uuid == Guid(cmdUuid)) _cmd = c;
      if (c.uuid == Guid(dataUuid)) _data = c;
      if (c.uuid == Guid(statusUuid)) _status = c;
    }

    if (_cmd == null || _data == null || _status == null) {
      if (!mounted) return;
      setState(() {
        connectionStatus =
            "Missing characteristics.\nFound:\n${service.characteristics.map((e) => e.uuid).join("\n")}";
      });
      await _disconnectDevice();
      return;
    }

    cmdChar = _cmd;
    dataChar = _data;
    statusChar = _status;

    try {
      await statusChar!.setNotifyValue(true);
    } catch (_) {}
    await _statusNotifySub?.cancel();
    _statusNotifySub = statusChar!.onValueReceived.listen((value) {
      final msg = utf8.decode(value, allowMalformed: true).trim();
      _handleStatus(msg);
    });

    try {
      await dataChar!.setNotifyValue(true);
    } catch (_) {}
    await _dataNotifySub?.cancel();
    _dataNotifySub = dataChar!.onValueReceived.listen(_handleDataNotify);

    if (!mounted) return;
    setState(() {
      isReady = true;
      connectionStatus = " Connected (MTU=$mtu) — Authenticating...";
    });

    try {
      await _doAuthHandshake();
      if (!mounted) return;
      setState(() => connectionStatus = "AUTH OK  Ready");
      await requestListReliable();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _authed = false;
        connectionStatus = " AUTH FAILED. Check secret / build / ESP32 logs.";
      });
    }
  }

  Future<void> _doAuthHandshake() async {
    if (!isReady || cmdChar == null) throw Exception("Not ready");
    _authed = false;
    _challengeHex = null;

    _authCompleter = Completer<void>();

    await _sendCmdRaw("AUTH_HELLO");
    await _authCompleter!.future.timeout(const Duration(seconds: 4));
  }

  void _onChallenge(String hexChal) async {
    _challengeHex = hexChal;

    final chalBytes = _hexToBytes(hexChal);
    final hmac = Hmac(sha256, utf8.encode(_authSecret));
    final digest = hmac.convert(chalBytes);
    final respHex =
        digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    await _sendCmdRaw("AUTH_RESP:$respHex");
  }

  static Uint8List _hexToBytes(String hex) {
    final clean = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    final out = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < out.length; i++) {
      out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  void _handleStatus(String msg) {
    if (!mounted) return;

    if (msg.startsWith("AUTH_CHAL:")) {
      final hexChal = msg.substring("AUTH_CHAL:".length).trim();
      _onChallenge(hexChal);
      setState(() => connectionStatus = "AUTH challenge received...");
      return;
    }
    if (msg == "AUTH_OK") {
      _authed = true;
      if (_authCompleter != null && !_authCompleter!.isCompleted) {
        _authCompleter!.complete();
      }
      setState(() => connectionStatus = " AUTH OK");
      return;
    }
    if (msg.startsWith("AUTH_FAIL") || msg == "ERR:NOT_AUTH") {
      _authed = false;
      if (_authCompleter != null && !_authCompleter!.isCompleted) {
        _authCompleter!.completeError("AUTH_FAILED");
      }
      setState(() => connectionStatus = " AUTH FAILED ($msg)");
      return;
    }

    setState(() {
      connectionStatus = "ESP32: $msg";
    });

    if (msg.startsWith("PROG:")) {
      final p = msg.substring(5);
      final parts = p.split("/");
      if (parts.length == 2) {
        final w = int.tryParse(parts[0]) ?? 0;
        final t = int.tryParse(parts[1]) ?? 1;
        setState(() => uploadProgress = (t == 0) ? 0 : (w / t).clamp(0.0, 1.0));
      }
      return;
    }

    if (msg.startsWith("LIST:")) {
      final slots = _parseSlotsFromListMsg(msg);
      setState(() => availableSlots = slots);

      if (_listCompleter != null && !_listCompleter!.isCompleted) {
        _listCompleter!.complete(slots);
      }
      return;
    }

    if (msg.startsWith("DL_BEGIN:")) {
      final body = msg.substring(9);
      final parts = body.split(",");
      if (parts.length == 2) {
        dlSlot = int.tryParse(parts[0]) ?? 0;
        dlExpected = int.tryParse(parts[1]) ?? 0;
        dlReceived = 0;
        dlBuffer.clear();
        downloading = true;
        downloadProgress = 0.0;
        setState(() => connectionStatus = "Downloading slot $dlSlot...");
      }
      return;
    }

    if (msg.startsWith("DL_END:")) {
      if (downloading) {
        _finalizeDownload(force: true);
      }
      return;
    }
  }

  List<int> _parseSlotsFromListMsg(String msg) {
    final listStr = msg.substring(5).trim();
    final slots = <int>[];
    if (listStr.isNotEmpty) {
      for (final s in listStr.split(",")) {
        final v = int.tryParse(s.trim());
        if (v != null) slots.add(v);
      }
    }
    slots.sort();
    return slots;
  }

  Future<List<int>> requestListReliable({
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    if (!isReady || cmdChar == null || statusChar == null) {
      return availableSlots;
    }

    if (!_authed) return availableSlots;

    if (_listCompleter != null && !_listCompleter!.isCompleted) {
      _listCompleter!.complete(availableSlots);
    }
    _listCompleter = Completer<List<int>>();

    await _sendCmd("LIST");

    try {
      final slots = await _listCompleter!.future.timeout(timeout);
      return slots;
    } catch (_) {}

    try {
      final raw = await statusChar!.read();
      final msg = utf8.decode(raw, allowMalformed: true).trim();
      if (msg.startsWith("LIST:")) {
        final slots = _parseSlotsFromListMsg(msg);
        if (mounted) setState(() => availableSlots = slots);
        return slots;
      }
    } catch (_) {}

    return availableSlots;
  }

  void _handleDataNotify(List<int> chunk) {
    if (!downloading) return;
    if (dlExpected <= 0) return;
    if (chunk.isEmpty) return;

    dlBuffer.add(chunk);
    dlReceived += chunk.length;

    final prog = (dlReceived / dlExpected).clamp(0.0, 1.0);
    setState(() {
      downloadProgress = prog;
      connectionStatus = "Downloading slot $dlSlot... $dlReceived/$dlExpected";
    });

    if (dlReceived >= dlExpected) {
      _finalizeDownload();
    }
  }

  void _resetDownloadState() {
    downloading = false;
    dlSlot = 0;
    dlExpected = 0;
    dlReceived = 0;
    dlBuffer.clear();
    downloadProgress = 0.0;
  }

  Future<void> _finalizeDownload({bool force = false}) async {
    if (!downloading) return;
    if (!force && dlReceived < dlExpected) return;

    downloading = false;

    final bytes = dlBuffer.takeBytes();
    final fileName = "sound$dlSlot.wav";

    final String? savePath = await FilePicker.platform.saveFile(
      dialogTitle: "Save $fileName",
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ["wav"],
    );

    if (savePath == null) {
      setState(() {
        connectionStatus = "Download completed, but save cancelled.";
        downloadProgress = 0;
      });
      _resetDownloadState();
      return;
    }

    try {
      await File(savePath).writeAsBytes(bytes, flush: true);
      setState(() {
        connectionStatus = " Saved: $savePath";
        downloadProgress = 0;
      });
    } catch (e) {
      setState(() {
        connectionStatus = " Save failed: $e";
        downloadProgress = 0;
      });
    }

    _resetDownloadState();
  }

  Future<void> _sendCmd(String cmd) async {
    if (!_authed) {
      if (!mounted) return;
      setState(() => connectionStatus = " Not authenticated yet");
      return;
    }
    await _sendCmdRaw(cmd);
  }

  Future<void> _sendCmdRaw(String cmd) async {
    if (!isReady || cmdChar == null) return;
    try {
      await cmdChar!.write(utf8.encode(cmd), withoutResponse: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => connectionStatus = " CMD write failed: $e");
    }
  }

  Future<void> _playSlot(int slot) async => _sendCmd("PLAY:$slot");

  Future<void> _deleteSlot(int slot) async {
    await _sendCmd("DELETE:$slot");
    await requestListReliable();
  }

  Future<void> _downloadSlot(int slot) async {
    if (downloading) return;
    _resetDownloadState();
    await _sendCmd("DOWNLOAD:$slot");
  }

  int _chunkSize() => (mtu >= 247) ? 240 : 180;

  Future<void> _uploadWav() async {
    if (!isReady || cmdChar == null || dataChar == null) return;
    if (!_authed) {
      setState(() => connectionStatus = " Not authenticated yet");
      return;
    }

    final int? slot = await _pickSlotDialog();
    if (slot == null) return;

    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["wav"],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;

    final bytes = res.files.first.bytes;
    if (bytes == null) return;

    if (bytes.length < 44 ||
        String.fromCharCodes(bytes.sublist(0, 4)) != "RIFF" ||
        String.fromCharCodes(bytes.sublist(8, 12)) != "WAVE") {
      if (!mounted) return;
      setState(() => connectionStatus = " Not a valid WAV file.");
      return;
    }

    setState(() {
      uploadProgress = 0.0;
      connectionStatus = " Uploading to slot $slot...";
    });

    final total = bytes.length;

    await _sendCmd("UPLOAD_BEGIN:$slot,$total");
    await Future.delayed(const Duration(milliseconds: 180));

    final cs = _chunkSize();
    int offset = 0;

    try {
      while (offset < total) {
        final end = (offset + cs > total) ? total : offset + cs;
        final chunk = bytes.sublist(offset, end);

        await dataChar!.write(Uint8List.fromList(chunk), withoutResponse: true);

        offset = end;
        setState(() => uploadProgress = (offset / total).clamp(0.0, 1.0));

        await Future.delayed(const Duration(milliseconds: 2));
      }

      await _sendCmd("UPLOAD_END");
      await requestListReliable();

      if (!mounted) return;
      setState(() => connectionStatus = " Upload finished.");
    } catch (e) {
      if (!mounted) return;
      setState(() => connectionStatus = " Upload error: $e");
    }
  }

  Future<void> _deleteFromListDialog() async {
    if (!isReady || !_authed) return;

    final slots = await requestListReliable();
    if (!mounted) return;

    if (slots.isEmpty) {
      setState(() => connectionStatus = "No sounds to delete.");
      return;
    }

    final slot = await showDialog<int>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Delete which slot?"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: slots.length,
                itemBuilder: (context, i) {
                  final s = slots[i];
                  return ListTile(
                    title: Text("sound$s.wav (Slot $s)"),
                    trailing: const Icon(Icons.delete),
                    onTap: () => Navigator.pop(context, s),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
            ],
          ),
    );

    if (slot != null) await _deleteSlot(slot);
  }

  Future<void> _downloadFromListDialog() async {
    if (!isReady || !_authed) return;

    final slots = await requestListReliable();
    if (!mounted) return;

    if (slots.isEmpty) {
      setState(() => connectionStatus = "No sounds to download.");
      return;
    }

    final slot = await showDialog<int>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Download which slot?"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: slots.length,
                itemBuilder: (context, i) {
                  final s = slots[i];
                  return ListTile(
                    title: Text("sound$s.wav (Slot $s)"),
                    trailing: const Icon(Icons.download),
                    onTap: () => Navigator.pop(context, s),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
            ],
          ),
    );

    if (slot != null) await _downloadSlot(slot);
  }

  Future<void> _openReorderDialog() async {
    if (!isReady || !_authed) return;

    final slots = await requestListReliable();
    if (!mounted) return;

    if (slots.isEmpty) {
      setState(() => connectionStatus = "No sounds to reorder.");
      return;
    }

    final List<int> mapNewToOld = List<int>.filled(9, 0);
    for (int i = 0; i < 9; i++) {
      final newSlot = i + 1;
      mapNewToOld[i] = slots.contains(newSlot) ? newSlot : 0;
    }

    final List<int> options = [0, ...slots];

    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSt) {
            return AlertDialog(
              title: const Text("Reorder / Rearrange Slots"),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: 9,
                  itemBuilder: (context, i) {
                    final newSlot = i + 1;
                    return Row(
                      children: [
                        SizedBox(width: 70, child: Text("New $newSlot")),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: mapNewToOld[i],
                            items:
                                options.map((v) {
                                  final label =
                                      (v == 0) ? "EMPTY" : "From old slot $v";
                                  return DropdownMenuItem<int>(
                                    value: v,
                                    child: Text(label),
                                  );
                                }).toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setSt(() => mapNewToOld[i] = v);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, mapNewToOld),
                  child: const Text("Apply"),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    final cmd = "REORDER:${result.join(",")}";
    await _sendCmd(cmd);
    await requestListReliable();

    if (!mounted) return;
    setState(() => connectionStatus = "Reorder applied.");
  }

  Future<int?> _pickSlotDialog() async {
    int temp = 1;
    return showDialog<int>(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder:
                (context, setSt) => AlertDialog(
                  title: const Text("Select Slot"),
                  content: DropdownButton<int>(
                    value: temp,
                    items:
                        List.generate(9, (i) => i + 1)
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text("Slot $s"),
                              ),
                            )
                            .toList(),
                    onChanged: (v) => setSt(() => temp = v ?? 1),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, temp),
                      child: const Text("OK"),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _disconnectDevice() async {
    try {
      await connectedDevice?.disconnect();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      connectedDevice = null;
      cmdChar = null;
      dataChar = null;
      statusChar = null;
      isReady = false;
      _authed = false;
      connectionStatus = " Tap Bluetooth icon to scan devices";
      uploadProgress = 0;
      downloadProgress = 0;
      availableSlots = [];
      _resetDownloadState();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade800,
        title: const Text("Flatch V5", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          if (connectedDevice != null)
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled, color: Colors.white),
              onPressed: _disconnectDevice,
            )
          else
            IconButton(
              icon: const Icon(Icons.bluetooth, color: Colors.white),
              onPressed: _scanDevices,
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body:
          connectedDevice == null
              ? _buildScannerUI()
              : !isReady
              ? _buildLockedUI()
              : _buildMainUI(),
    );
  }

  Widget _buildScannerUI() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            connectionStatus,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (isScanning) const CircularProgressIndicator(),
          if (!isScanning)
            Expanded(
              child: ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final r = devices[index];
                  final d = r.device;
                  final name =
                      d.platformName.isEmpty
                          ? "(Unnamed BLE device)"
                          : d.platformName;
                  final rssi = r.rssi;

                  return Card(
                    child: ListTile(
                      title: Text(name),
                      subtitle: Text("${d.remoteId.str}  |  RSSI: $rssi"),
                      trailing: ElevatedButton(
                        onPressed: () => _connectToDevice(d),
                        child: const Text("Connect"),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLockedUI() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock, size: 80, color: Colors.red),
          SizedBox(height: 20),
          Text(
            "Connecting...\nPlease wait",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMainUI() {
    const int totalButtons = 10;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            _authed ? "Tap a number to PLAY that slot" : " Authenticating...",
           
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: uploadProgress),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: downloading ? downloadProgress : 0),
          const SizedBox(height: 10),
          Text(connectionStatus),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemCount: totalButtons,
              itemBuilder: (context, index) {
                final num = index + 1;
                return GestureDetector(
                  onTap: () => _playSlot(num),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.shade700,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        "$num",
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _uploadWav,
                icon: const Icon(Icons.upload_file),
                label: const Text("UPLOAD"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _deleteFromListDialog,
                icon: const Icon(Icons.delete),
                label: const Text("DELETE"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _downloadFromListDialog,
                icon: const Icon(Icons.download),
                label: const Text("DOWNLOAD"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openReorderDialog,
            icon: const Icon(Icons.swap_vert),
            label: const Text("Refresh List (Reorder)"),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
