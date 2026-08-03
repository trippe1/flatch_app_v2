part of 'flatch_ble_cubit.dart';

class FlatchBleState extends Equatable {
  final bool isBluetoothOn;
  // Explicitly OFF (adapter reported off) — distinct from "not yet determined"
  // (unknown/unauthorized), which on iOS is the state before BLE is first used.
  // Only show "Bluetooth is disabled" when this is true.
  final bool isBluetoothOff;
  final bool isLoading;
  final String? error;

  final List<BluetoothDevice> devices;
  // Signal strength (RSSI, dBm) per device, keyed by remoteId — for the
  // signal indicator and closest-first ordering in the pairing list.
  final Map<String, int> deviceRssi;
  final BluetoothDevice? connectedDevice;

  // Local downloaded sounds
  final List<File> soundFiles;

  // Auth
  final bool isCodeVerified;
  final Map<int, String> downloadedFilePaths;

  // ESP32 slots
  final List<int> availableSlots;
  final double uploadProgress;
  final double downloadProgress;
  final String statusMessage;
  final bool isDownloading;
  final int? downloadingSlot;
  final bool isConnecting;
  final String? connectingDeviceId;
  final List<File> queuedLibrarySounds;

  // Bluetooth access was requested and refused. `permanently` means the OS will
  // no longer show a prompt, so the only route left is app settings.
  final bool blePermissionDenied;
  final bool blePermissionPermanentlyDenied;




  const FlatchBleState({
    this.blePermissionDenied = false,
    this.blePermissionPermanentlyDenied = false,
    this.isBluetoothOn = false,
    this.isBluetoothOff = false,
    this.isLoading = false,
    this.error,
    this.devices = const [],
    this.deviceRssi = const {},
    this.connectedDevice,
    this.soundFiles = const [],
    this.isCodeVerified = false,
    this.availableSlots = const [],
    this.uploadProgress = 0,
    this.downloadProgress = 0,
    this.statusMessage = '',
     this.isDownloading = false,
    this.downloadingSlot,
    this.isConnecting = false,
    this.connectingDeviceId,
       this.downloadedFilePaths = const {},
       this.queuedLibrarySounds = const [],

  });

  FlatchBleState copyWith({
    bool? blePermissionDenied,
    bool? blePermissionPermanentlyDenied,
    bool? isBluetoothOn,
    bool? isBluetoothOff,
    bool? isLoading,
    String? error,
    List<BluetoothDevice>? devices,
    Map<String, int>? deviceRssi,
    BluetoothDevice? connectedDevice,
    List<File>? soundFiles,
    bool? isCodeVerified,
    List<int>? availableSlots,
    double? uploadProgress,
    double? downloadProgress,
    String? statusMessage,
    bool? isDownloading,
    int? downloadingSlot,
    bool? isConnecting,
    String? connectingDeviceId,
     Map<int, String>? downloadedFilePaths,
     List<File>? queuedLibrarySounds,

  }) {
    return FlatchBleState(
      blePermissionDenied: blePermissionDenied ?? this.blePermissionDenied,
      blePermissionPermanentlyDenied:
          blePermissionPermanentlyDenied ?? this.blePermissionPermanentlyDenied,
      isBluetoothOn: isBluetoothOn ?? this.isBluetoothOn,
      isBluetoothOff: isBluetoothOff ?? this.isBluetoothOff,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      devices: devices ?? this.devices,
      deviceRssi: deviceRssi ?? this.deviceRssi,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      soundFiles: soundFiles ?? this.soundFiles,
      isCodeVerified: isCodeVerified ?? this.isCodeVerified,
      availableSlots: availableSlots ?? this.availableSlots,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      statusMessage: statusMessage ?? this.statusMessage,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadingSlot: downloadingSlot ?? this.downloadingSlot,
      isConnecting: isConnecting ?? this.isConnecting,
      connectingDeviceId: connectingDeviceId ?? this.connectingDeviceId,
      downloadedFilePaths: downloadedFilePaths ?? this.downloadedFilePaths,
      queuedLibrarySounds: queuedLibrarySounds ?? this.queuedLibrarySounds
      
    );
  }

  @override
  List<Object?> get props => [
    blePermissionDenied,
    blePermissionPermanentlyDenied,
    isBluetoothOn,
    isBluetoothOff,
    isLoading,
    error,
    devices,
    deviceRssi,
    connectedDevice,
    soundFiles,
    isCodeVerified,
    availableSlots,
    uploadProgress,
    downloadProgress,
    statusMessage,
    isDownloading,
    downloadingSlot,
    isConnecting,
  connectingDeviceId,
  downloadedFilePaths,
  queuedLibrarySounds
  ];
}
