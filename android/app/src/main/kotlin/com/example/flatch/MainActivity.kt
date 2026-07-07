package com.flatch.flicked_flatch

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.*
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.ReturnCode

class MainActivity : FlutterActivity() {

    private val BLE_CHANNEL = "flatch.ble.channel"
    private val CONVERT_CHANNEL = "audio.converter"
    

    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothGatt: BluetoothGatt? = null
    private var connectedDevice: BluetoothDevice? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter

        // ==================================================
        // 🔹 BLE CHANNEL — Wireless communication with board
        // ==================================================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BLE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // 🔍 Scan for nearby BLE devices
                    "startScan" -> {
                        startScan(result)
                    }

                    // 🔌 Connect to BLE device
                    "connectToDevice" -> {
                        val deviceId: String? = call.argument("deviceId")
                        if (deviceId.isNullOrEmpty()) {
                            result.error("INVALID_DEVICE", "Device ID required", null)
                            return@setMethodCallHandler
                        }
                        connectToDevice(deviceId, result)
                    }

                    // ✉️ Send a command (e.g. PLAY1, NEXT)
                    "sendCommand" -> {
                        val command: String? = call.argument("command")
                        if (command.isNullOrEmpty()) {
                            result.error("INVALID_COMMAND", "Command is empty", null)
                            return@setMethodCallHandler
                        }
                        sendCommand(command, result)
                    }

                    // 🔌 Disconnect BLE
                    "disconnect" -> {
                        disconnect()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }

        // ==================================================
        // 🎵 AUDIO CONVERSION CHANNEL — FFmpegKit operations
        // ==================================================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONVERT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // 🔄 Convert any audio to MP3 / WAV / AAC
                    "convertToMp3", "convertAudio" -> {
                        val inputPath: String? = call.argument<String>("inputPath")
                        val outputExt: String = call.argument<String>("outputExt") ?: "mp3"

                        if (inputPath.isNullOrEmpty()) {
                            result.error("INVALID_ARGS", "Missing input path", null)
                            return@setMethodCallHandler
                        }

                        val outputFile = File(getExternalFilesDir(null), "converted_${System.currentTimeMillis()}.$outputExt")
                        val codecArg = when {
                            outputExt.equals("mp3", true) -> "-c:a libmp3lame -q:a 2"
                            outputExt.equals("wav", true) -> "-c:a pcm_s16le"
                            else -> "-c:a aac"
                        }

                        val command =
                            "-y -i \"$inputPath\" -ac 1 -ar 44100 $codecArg \"${outputFile.absolutePath}\""

                        FFmpegKit.executeAsync(command) { session ->
                            val rc: ReturnCode = session.returnCode
                            if (rc.isValueSuccess) {
                                result.success(outputFile.absolutePath)
                            } else {
                                result.error("FFMPEG_ERROR", "Conversion failed", null)
                            }
                        }
                    }

                    // ✂️ Trim audio clip
                    "trimAudio" -> {
                        val inputPath: String? = call.argument<String>("inputPath")
                        val start: Double = call.argument<Double>("start") ?: 0.0
                        val duration: Double = call.argument<Double>("duration") ?: 5.0

                        if (inputPath.isNullOrEmpty()) {
                            result.error("INVALID_ARGS", "Missing input path", null)
                            return@setMethodCallHandler
                        }

                        val inputExt = File(inputPath).extension
                        val outputFile = File(getExternalFilesDir(null), "trimmed_${System.currentTimeMillis()}.$inputExt")
                        val codecArg = when {
                            inputExt.equals("mp3", true) -> "-c:a libmp3lame -q:a 2"
                            inputExt.equals("wav", true) -> "-c:a pcm_s16le"
                            else -> "-c:a aac"
                        }

                        val command =
                            "-y -ss $start -t $duration -i \"$inputPath\" -ac 1 -ar 44100 $codecArg \"${outputFile.absolutePath}\""

                        FFmpegKit.executeAsync(command) { session ->
                            val rc: ReturnCode = session.returnCode
                            if (rc.isValueSuccess) {
                                result.success(outputFile.absolutePath)
                            } else {
                                result.error("FFMPEG_ERROR", "Trim failed", null)
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ==================================================
    // 🔹 BLE: SCANNING
    // ==================================================
    private fun startScan(result: MethodChannel.Result) {
        val scanner = bluetoothAdapter?.bluetoothLeScanner
        if (scanner == null) {
            result.error("BLE_UNAVAILABLE", "Bluetooth not available", null)
            return
        }

        val scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, scanResult: ScanResult?) {
                val device = scanResult?.device ?: return
                Log.d("BLE_DEBUG", "Found device: ${device.name} - ${device.address}")
                if (device.name?.contains("JL") == true || device.name?.contains("Flatch") == true) {
                    connectedDevice = device
                    scanner.stopScan(this)
                    result.success(mapOf("name" to device.name, "id" to device.address))
                }
            }

            override fun onScanFailed(errorCode: Int) {
                result.error("SCAN_FAILED", "Error code: $errorCode", null)
            }
        }

        scanner.startScan(scanCallback)
        Log.d("BLE_DEBUG", "🔍 Scanning for BLE devices...")
    }

    // ==================================================
    // 🔹 BLE: CONNECT TO DEVICE
    // ==================================================
    private fun connectToDevice(deviceId: String, result: MethodChannel.Result) {
        try {
            val device = bluetoothAdapter?.getRemoteDevice(deviceId)
            connectedDevice = device
            bluetoothGatt = device?.connectGatt(this, false, gattCallback)
            result.success(true)
            Log.d("BLE_DEBUG", "🔌 Connecting to device $deviceId...")
        } catch (e: Exception) {
            result.error("CONNECTION_ERROR", e.localizedMessage, null)
        }
    }

    // ==================================================
    // 🔹 BLE: GATT CALLBACK
    // ==================================================
    private val gattCallback = object : BluetoothGattCallback() {

        override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    Log.d("BLE_DEBUG", "✅ Connected to BLE device.")
                    gatt?.discoverServices()
                }

                BluetoothProfile.STATE_DISCONNECTED -> {
                    Log.d("BLE_DEBUG", "❌ Disconnected from BLE device.")
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
            Log.d("BLE_DEBUG", "🧩 Services discovered:")
            gatt?.services?.forEach { service ->
                Log.d("BLE_DEBUG", "Service: ${service.uuid}")
                service.characteristics.forEach { char ->
                    Log.d("BLE_DEBUG", " → Characteristic: ${char.uuid}, props=${char.properties}")
                }
            }
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt?,
            characteristic: BluetoothGattCharacteristic?,
            status: Int
        ) {
            Log.d("BLE_DEBUG", "✉️ Command sent: status=$status")
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt?,
            characteristic: BluetoothGattCharacteristic?
        ) {
            val value = characteristic?.value?.toString(Charsets.UTF_8)
            Log.d("BLE_DEBUG", "📩 Notification: $value")
        }
    }

    // ==================================================
    // 🔹 BLE: SEND COMMAND
    // ==================================================
    private fun sendCommand(command: String, result: MethodChannel.Result) {
        val gatt = bluetoothGatt ?: run {
            result.error("NO_GATT", "Not connected to any BLE device", null)
            return
        }

        val service = gatt.services.firstOrNull()
        val characteristic = service?.characteristics?.firstOrNull {
            it.properties and BluetoothGattCharacteristic.PROPERTY_WRITE != 0
        }

        if (characteristic == null) {
            result.error("NO_WRITE_CHAR", "No writable characteristic found", null)
            return
        }

        characteristic.value = command.toByteArray(Charsets.UTF_8)
        val success = gatt.writeCharacteristic(characteristic)
        Log.d("BLE_DEBUG", "➡️ Sent command: $command ($success)")
        result.success(success)
    }

    // ==================================================
    // 🔹 BLE: DISCONNECT
    // ==================================================
    private fun disconnect() {
        bluetoothGatt?.close()
        bluetoothGatt = null
        connectedDevice = null
        Log.d("BLE_DEBUG", "🔌 BLE disconnected manually.")
    }
}
