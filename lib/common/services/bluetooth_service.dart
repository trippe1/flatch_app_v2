// File: lib/common/services/bluetooth_service.dart

// ignore_for_file: avoid_print

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class FlatchBluetoothService {
  /// Check current Bluetooth state
  Future<String> checkBluetooth() async {
    try {
      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on
          ? "Bluetooth is on"
          : "Bluetooth is off. Please turn on Bluetooth.";
    } catch (e) {
      return "Error checking Bluetooth: $e";
    }
  }

  Future<void> startScanning({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      await FlutterBluePlus.startScan(timeout: timeout);
    } catch (e) {
      print("Error starting scan: $e");
    }
  }

  Stream<List<ScanResult>> get scanResultsStream => FlutterBluePlus.scanResults;

  Future<void> stopScanning() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print("Error stopping scan: $e");
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: true);
      print(
        "Connected to ${device.platformName.isNotEmpty ? device.platformName : device.remoteId}",
      );
    } catch (e) {
      print("Error connecting to device: $e");
    }
  }

  /// Disconnect from a Bluetooth device
  Future<void> disconnectFromDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
      print(
        "Disconnected from ${device.platformName.isNotEmpty ? device.platformName : device.remoteId}",
      );
    } catch (e) {
      print("Error disconnecting from device: $e");
    }
  }

  /// Discover services from a connected device
  Future<List<BluetoothService>> discoverServices(
    BluetoothDevice device,
  ) async {
    try {
      return await device.discoverServices();
    } catch (e) {
      print("Error discovering services: $e");
      return [];
    }
  }

  /// Listen to adapter state changes
  Stream<BluetoothAdapterState> get bluetoothAdapterStateStream =>
      FlutterBluePlus.adapterState;
}
