import 'dart:io';

import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/services/audio_route.dart';
import 'package:flatch/common/services/stock_sounds.dart';
import 'package:flatch/common/services/telemetry_service.dart';
import 'package:flatch/cubits/flatch_ble/flatch_ble_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// Standalone route wrapper (an app bar + the list). The list itself lives in
/// [StockSoundsList] so the community module can embed it without a nested
/// Scaffold.
class StockSoundsScreen extends StatelessWidget {
  const StockSoundsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Standard Issue Sounds')),
      body: const StockSoundsList(),
    );
  }
}

/// Guest-accessible library of built-in sounds. Anyone (no account) can preview
/// these and push them to the Flatch device. See [kStockSounds]. No community
/// features (comment / vote / share) apply to these — they are admin-curated
/// and shipped with the app.
class StockSoundsList extends StatefulWidget {
  const StockSoundsList({super.key});

  @override
  State<StockSoundsList> createState() => _StockSoundsListState();
}

class _StockSoundsListState extends State<StockSoundsList> {
  final AudioPlayer _player = AudioPlayer();
  String? _playingId;
  final Set<String> _adding = {};

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _preview(StockSound s) async {
    try {
      if (_playingId == s.id && _player.playing) {
        await _player.pause();
        setState(() => _playingId = null);
        return;
      }
      await AudioRoute.toSpeakerUnlessHeadphones();
      await _player.setAsset(s.assetPath);
      setState(() => _playingId = s.id);
      await _player.play();
      if (mounted && _playingId == s.id) setState(() => _playingId = null);
    } catch (_) {
      if (mounted) setState(() => _playingId = null);
    }
  }

  Future<File> _assetToTempFile(StockSound s) async {
    final data = await rootBundle.load(s.assetPath);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${s.id}.wav');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return file;
  }

  Future<void> _addToDevice(StockSound s) async {
    final ble = context.read<FlatchBleCubit>();
    if (ble.state.connectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect the device first.')),
      );
      return;
    }
    setState(() => _adding.add(s.id));
    try {
      final file = await _assetToTempFile(s);
      ble.addFromLibrary(file);
      Telemetry.instance.stockSoundSynced();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${s.name}" queued for deployment.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add that sound.')),
        );
      }
    } finally {
      if (mounted) setState(() => _adding.remove(s.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FlatchBleCubit, FlatchBleState>(
      builder: (context, ble) {
        final connected = ble.connectedDevice != null;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!connected)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/svgs/device_signal.svg',
                      width: 18,
                      height: 18,
                      colorFilter: const ColorFilter.mode(
                        AppColors.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Connect the device on the device tab to deploy '
                        'sounds. Preview is available without a connection.',
                      ),
                    ),
                  ],
                ),
              ),
            ...kStockSounds.map((s) => _tile(s, connected)),
          ],
        );
      },
    );
  }

  Widget _tile(StockSound s, bool connected) {
    final playing = _playingId == s.id;
    final adding = _adding.contains(s.id);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: IconButton(
          icon: Icon(playing ? Icons.stop_circle : Icons.play_circle_fill),
          color: AppColors.primary,
          iconSize: 34,
          onPressed: () => _preview(s),
        ),
        title: Text(
          s.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(s.category),
        trailing:
            adding
                ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Deploy'),
                  onPressed: () => _addToDevice(s),
                ),
      ),
    );
  }
}
