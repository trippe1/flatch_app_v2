import 'package:flutter_audio_output/flutter_audio_output.dart';

/// Playback audio routing.
class AudioRoute {
  /// Routes to the loudspeaker UNLESS wired headphones or a Bluetooth device is
  /// connected — then audio stays on that output instead of blasting the phone
  /// speaker. (Farts are meant to be heard out loud, but not over someone's
  /// earbuds.)
  static Future<void> toSpeakerUnlessHeadphones() async {
    try {
      final current = await FlutterAudioOutput.getCurrentOutput();
      if (current.port != AudioPort.headphones &&
          current.port != AudioPort.bluetooth) {
        await FlutterAudioOutput.changeToSpeaker();
      }
    } catch (_) {
      // best-effort routing; ignore failures
    }
  }
}
