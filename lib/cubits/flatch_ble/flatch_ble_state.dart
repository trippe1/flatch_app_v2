part of 'flatch_ble_cubit.dart';

class FlatchBleState extends Equatable {
  final bool isBluetoothOn;
  final bool isLoading;
  final String? error;

  final List<BluetoothDevice> devices;
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




  const FlatchBleState({
    this.isBluetoothOn = false,
    this.isLoading = false,
    this.error,
    this.devices = const [],
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
    bool? isBluetoothOn,
    bool? isLoading,
    String? error,
    List<BluetoothDevice>? devices,
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
      isBluetoothOn: isBluetoothOn ?? this.isBluetoothOn,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      devices: devices ?? this.devices,
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
    isBluetoothOn,
    isLoading,
    error,
    devices,
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
