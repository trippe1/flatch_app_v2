import 'package:flatch/common/services/sound_library_services.dart';
import 'package:flutter/material.dart';
import 'package:flatch/common/models/fart_model.dart';
import 'package:flatch/common/widgets/fart_card.dart';
import 'package:flatch/common/services/audio_cache_service.dart';
import 'package:flatch/common/services/download_sound.dart';
import 'package:flatch/common/services/share_service.dart';
import 'package:flutter_audio_output/flutter_audio_output.dart';
import 'package:just_audio/just_audio.dart';
import 'package:go_router/go_router.dart';

class FartPreviewScreen extends StatefulWidget {
  final FartModel fart;

  const FartPreviewScreen({super.key, required this.fart});

  @override
  State<FartPreviewScreen> createState() => _FartPreviewScreenState();
}

class _FartPreviewScreenState extends State<FartPreviewScreen> {
  final AudioPlayer _player = AudioPlayer();
  String? _currentlyPlayingUrl;

  Future<void> _handlePlayPause(String url) async {
    if (_currentlyPlayingUrl == url) {
      await _player.pause();
      setState(() => _currentlyPlayingUrl = null);
    } else {
      setState(() => _currentlyPlayingUrl = url);
      try {
         await FlutterAudioOutput.changeToSpeaker();
        final localPath = await getOrDownloadFart(url);
        await _player.setFilePath(localPath);
        await _player.play();
      } catch (e) {
        debugPrint('Audio error: $e');
        setState(() => _currentlyPlayingUrl = null);
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fart = widget.fart;
    final isPlaying = _currentlyPlayingUrl == fart.fileUrl;

    return Scaffold(
      appBar: AppBar(title: Text(fart.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FartCard(
          uid: fart.uid,
          title: fart.title,
          fileUrl: fart.fileUrl,
          isPlaying: isPlaying,
          duration: fart.duration,
          upvotes: fart.upvotes,
          downvotes: fart.downvotes,
          userVote: fart.userVote ?? '',
          commentCount: fart.commentCount,
          onPlayPause: () => _handlePlayPause(fart.fileUrl),
          onDownload:
         () => SoundLibraryService.saveToLibrary(
                context: context,
               fart: fart,
                source: 'community',
              ),

          onShare: () async {
            await ShareService.instance.shareFart(
              fartId: fart.id,
              title: 'Listen to this fart!',
            );
          },
          onUserTap: () {
            context.pushNamed("userProfileScreen", extra: fart.uid);
          },
          onUpvote: () {},
          onDownvote: () {},

          alreadyReported: false,
        ),
      ),
    );
  }
}
