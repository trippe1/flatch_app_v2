import AVFoundation
import Flutter
import UIKit
import ffmpegkit

@main
@objc class AppDelegate: FlutterAppDelegate {

  private let USB_CHANNEL: String = "flatch.usb.channel"
  private let CONVERT_CHANNEL: String = "audio.converter"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    do {
      let session: AVAudioSession = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
      try session.setActive(true)

      // 🔑 Force built-in mic (fix for silent recordings)
      if let inputs: [AVAudioSessionPortDescription] = session.availableInputs {
        if let builtInMic: AVAudioSessionPortDescription = inputs.first(where: {
          $0.portType == .builtInMic
        }) {
          try session.setPreferredInput(builtInMic)
          print("🎤 Using built-in mic for recording")
        } else {
          print("⚠️ No built-in mic found")
        }
      }

      print("✅ AVAudioSession successfully set")
    } catch {
      print("❌ Failed to set up AVAudioSession: \(error)")
    }

    guard let controller = window?.rootViewController as? FlutterViewController else {
      assertionFailure("RootViewController is not FlutterViewController")
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    let usbChannel = FlutterMethodChannel(
      name: USB_CHANNEL, binaryMessenger: controller.binaryMessenger)
    usbChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }

      switch call.method {
      case "uploadFile":
        guard
          let args = call.arguments as? [String: Any],
          let srcPath = args["path"] as? String
        else {
          result(FlutterError(code: "INVALID_PATH", message: "Missing file path", details: nil))
          return
        }
        let srcURL = URL(fileURLWithPath: srcPath)
        let destURL = self.getUsbDir().appendingPathComponent(srcURL.lastPathComponent)
        do {
          if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
          }
          try FileManager.default.copyItem(at: srcURL, to: destURL)
          DispatchQueue.main.async { result(true) }
        } catch {
          DispatchQueue.main.async {
            result(
              FlutterError(
                code: "COPY_FAILED", message: "Copy failed: \(error.localizedDescription)",
                details: nil))
          }
        }

      case "listFiles":
        do {
          let files = try FileManager.default.contentsOfDirectory(atPath: self.getUsbDir().path)
          let paths = files.map { self.getUsbDir().appendingPathComponent($0).path }
          DispatchQueue.main.async { result(paths) }
        } catch {
          DispatchQueue.main.async { result([]) }
        }

      case "removeFile":
        guard
          let args = call.arguments as? [String: Any],
          let name = args["name"] as? String
        else {
          result(FlutterError(code: "INVALID_NAME", message: "Missing file name", details: nil))
          return
        }
        let fileURL = self.getUsbDir().appendingPathComponent(name)
        do {
          if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
          }
          DispatchQueue.main.async { result(true) }
        } catch {
          DispatchQueue.main.async { result(false) }
        }

      case "writeSequence":
        guard
          let args = call.arguments as? [String: Any],
          let sequence = args["sequence"] as? [String]
        else {
          result(FlutterError(code: "INVALID_SEQUENCE", message: "Missing list", details: nil))
          return
        }
        let baseDir = self.getUsbDir()
        do {
          for (index, path) in sequence.enumerated() {
            let srcURL = URL(fileURLWithPath: path)
            let destURL = baseDir.appendingPathComponent("\(index)_\(srcURL.lastPathComponent)")
            if FileManager.default.fileExists(atPath: destURL.path) {
              try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: srcURL, to: destURL)
          }
          DispatchQueue.main.async { result(true) }
        } catch {
          DispatchQueue.main.async {
            result(
              FlutterError(
                code: "SEQUENCE_WRITE_FAILED", message: error.localizedDescription, details: nil))
          }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let convertChannel = FlutterMethodChannel(
      name: CONVERT_CHANNEL, binaryMessenger: controller.binaryMessenger)
    convertChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }

      switch call.method {
      case "convertToMp3":
        guard
          let args = call.arguments as? [String: Any],
          let inputPath = args["inputPath"] as? String
        else {
          result(
            FlutterError(
              code: "INVALID_ARGS",
              message: "Missing input path",
              details: nil
            )
          )
          return
        }

        // Use extension from Flutter input (or default to mp3)
        let inputExt = (inputPath as NSString).pathExtension.lowercased()
        let outputExt = args["outputExt"] as? String ?? "mp3"  // optional
        let outputFile = self.getUsbDir().appendingPathComponent(
          "converted_\(Int(Date().timeIntervalSince1970)).\(outputExt)"
        )

        if FileManager.default.fileExists(atPath: outputFile.path) {
          try? FileManager.default.removeItem(at: outputFile)
        }

        // Choose codec dynamically
        var codecArg = "-c:a aac"  // default for m4a
        if outputFile.path.hasSuffix(".mp3") { codecArg = "-c:a libmp3lame -q:a 2" }
        if outputFile.path.hasSuffix(".wav") { codecArg = "-c:a pcm_s16le" }

        let command =
          "-y -i \"\(inputPath)\" -vn -map a:0? -ac 1 -ar 22050 -af loudnorm=I=-14:TP=-1.0:LRA=11 \(codecArg) \"\(outputFile.path)\""

        FFmpegKit.executeAsync(command) { session in
          let rc = session?.getReturnCode()
          if rc?.isValueSuccess() == true {
            DispatchQueue.main.async { result(outputFile.path) }
          } else {
            let failStack =
              (try? session?.getAllLogsAsString()) ?? (try? session?.getOutput()) ?? "Unknown error"
            DispatchQueue.main.async {
              result(
                FlutterError(code: "FFMPEG_ERROR", message: "Conversion failed", details: failStack)
              )
            }
          }
        }

      case "trimAudio":
        guard
          let args = call.arguments as? [String: Any],
          let inputPath = args["inputPath"] as? String
        else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing input path", details: nil))
          return
        }

        let start = args["start"] as? Double ?? 0.0
        let duration = args["duration"] as? Double ?? 5.0
        let inputExt = (inputPath as NSString).pathExtension.lowercased()

        // Keep output extension consistent with input
        let outputFile = self.getUsbDir().appendingPathComponent(
          "trimmed_\(Int(Date().timeIntervalSince1970)).\(inputExt)"
        )

        if FileManager.default.fileExists(atPath: outputFile.path) {
          try? FileManager.default.removeItem(at: outputFile)
        }

        // Choose codec dynamically
        var codecArg = "-c:a aac"
        if outputFile.path.hasSuffix(".mp3") { codecArg = "-c:a libmp3lame -q:a 2" }
        if outputFile.path.hasSuffix(".wav") { codecArg = "-c:a pcm_s16le" }

        let command =
          "-y -ss \(start) -t \(duration) -i \"\(inputPath)\" -vn -map a:0? -ac 1 -ar 22050 -af loudnorm=I=-14:TP=-1.0:LRA=11 \(codecArg) \"\(outputFile.path)\""

        FFmpegKit.executeAsync(command) { session in
          let rc = session?.getReturnCode()
          if rc?.isValueSuccess() == true {
            DispatchQueue.main.async { result(outputFile.path) }
          } else {
            let failStack =
              (try? session?.getAllLogsAsString()) ?? (try? session?.getOutput()) ?? "Unknown error"
            DispatchQueue.main.async {
              result(FlutterError(code: "FFMPEG_ERROR", message: "Trim failed", details: failStack))
            }
          }
        }

      case "applyAudioFilter":
        guard
          let args = call.arguments as? [String: Any],
          let inputPath = args["inputPath"] as? String,
          let filter = args["filter"] as? String
        else {
          result(
            FlutterError(code: "INVALID_ARGS", message: "Missing input path or filter", details: nil))
          return
        }
        let outputExt = args["outputExt"] as? String ?? "mp3"
        let outputFile = self.getUsbDir().appendingPathComponent(
          "fx_\(Int(Date().timeIntervalSince1970)).\(outputExt)"
        )
        if FileManager.default.fileExists(atPath: outputFile.path) {
          try? FileManager.default.removeItem(at: outputFile)
        }
        var fxCodec = "-c:a aac"
        if outputFile.path.hasSuffix(".mp3") { fxCodec = "-c:a libmp3lame -q:a 2" }
        if outputFile.path.hasSuffix(".wav") { fxCodec = "-c:a pcm_s16le" }
        let fxCommand =
          "-y -i \"\(inputPath)\" -vn -map a:0? -ac 1 -ar 22050 -af \"\(filter),loudnorm=I=-14:TP=-1.0:LRA=11\" \(fxCodec) \"\(outputFile.path)\""
        FFmpegKit.executeAsync(fxCommand) { session in
          let rc = session?.getReturnCode()
          if rc?.isValueSuccess() == true {
            DispatchQueue.main.async { result(outputFile.path) }
          } else {
            DispatchQueue.main.async {
              result(FlutterError(code: "FFMPEG_ERROR", message: "Effect failed", details: nil))
            }
          }
        }

      case "extractPcm":
        guard
          let args = call.arguments as? [String: Any],
          let inputPath = args["inputPath"] as? String
        else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing input path", details: nil))
          return
        }
        let sr = args["sampleRate"] as? Int ?? 8000
        let pcmFile = self.getUsbDir().appendingPathComponent(
          "wave_\(Int(Date().timeIntervalSince1970)).pcm"
        )
        if FileManager.default.fileExists(atPath: pcmFile.path) {
          try? FileManager.default.removeItem(at: pcmFile)
        }
        let pcmCommand =
          "-y -i \"\(inputPath)\" -vn -map a:0? -ac 1 -ar \(sr) -f s16le \"\(pcmFile.path)\""
        FFmpegKit.executeAsync(pcmCommand) { session in
          let rc = session?.getReturnCode()
          if rc?.isValueSuccess() == true {
            DispatchQueue.main.async { result(pcmFile.path) }
          } else {
            DispatchQueue.main.async {
              result(FlutterError(code: "FFMPEG_ERROR", message: "PCM extract failed", details: nil))
            }
          }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func getUsbDir() -> URL {
    let dir = FileManager.default
      .urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("flatch-usb")
    if !FileManager.default.fileExists(atPath: dir.path) {
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    return dir
  }
}
