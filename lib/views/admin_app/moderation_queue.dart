import 'package:flatch/blocs/moderation_queue/moderation_queue_bloc.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

class ModerationQueuePage extends StatelessWidget {
  const ModerationQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Content Moderation')),
      body: BlocBuilder<ModerationQueueBloc, ModerationQueueState>(
        builder: (context, state) {
          if (state is ModerationQueueLoading ||
              state is ModerationQueueInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ModerationQueueError) {
            return _CenterMessage(
              icon: Icons.error_outline,
              title: "Couldn't load the queue",
              subtitle: state.message,
              onRetry:
                  () => context.read<ModerationQueueBloc>().add(
                    const FetchModerationQueue(),
                  ),
            );
          }
          final items = (state as ModerationQueueLoaded).items;
          if (items.isEmpty) {
            return const _CenterMessage(
              icon: Icons.verified_user_outlined,
              title: 'The queue is clear.',
              subtitle: 'No submissions require review. The record reflects this.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              context.read<ModerationQueueBloc>().add(
                const FetchModerationQueue(),
              );
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _ModerationCard(item: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ModerationCard extends StatelessWidget {
  final ModerationItem item;
  const _ModerationCard({required this.item});

  ({Color color, String label}) _statusChip() {
    switch (item.status) {
      case 'auto_blocked':
        return (color: Colors.red, label: 'Auto-hidden');
      case 'pending_review':
        return (color: Colors.orange, label: 'Needs review');
      default:
        return (color: Colors.grey, label: 'Scan error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final chip = _statusChip();
    final pct = (item.confidence * 100).round();
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: chip.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    chip.label,
                    style: TextStyle(
                      color: chip.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '$pct% confidence',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.title.isEmpty ? '(untitled clip)' : item.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (item.category.isNotEmpty || item.reason.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (item.category.isNotEmpty) item.category,
                  if (item.reason.isNotEmpty) item.reason,
                ].join(' — '),
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            _AudioPreview(url: item.fileUrl),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green[700],
                      side: BorderSide(color: Colors.green.shade300),
                    ),
                    onPressed: () {
                      context.read<ModerationQueueBloc>().add(
                        ApproveModerationItem(item.fartId),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: const Text('Remove'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _confirmRemove(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final bloc = context.read<ModerationQueueBloc>();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Remove this clip?'),
            content: const Text(
              'This permanently deletes the clip and its audio file. This '
              'cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
    if (ok == true) {
      bloc.add(RemoveModerationItem(item.fartId, item.fileUrl));
    }
  }
}

class _AudioPreview extends StatefulWidget {
  final String url;
  const _AudioPreview({required this.url});

  @override
  State<_AudioPreview> createState() => _AudioPreviewState();
}

class _AudioPreviewState extends State<_AudioPreview> {
  final AudioPlayer _player = AudioPlayer();
  bool _loading = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (widget.url.isEmpty) return;
    try {
      if (_player.playing) {
        await _player.pause();
        setState(() {});
        return;
      }
      if (_player.audioSource == null) {
        setState(() => _loading = true);
        await _player.setUrl(widget.url);
        setState(() => _loading = false);
      }
      await _player.seek(Duration.zero);
      _player.play();
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snap) {
        final playing = snap.data?.playing ?? false;
        return OutlinedButton.icon(
          onPressed: widget.url.isEmpty ? null : _toggle,
          icon:
              _loading
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Icon(playing ? Icons.stop : Icons.play_arrow),
          label: Text(playing ? 'Stop' : 'Listen'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary),
          ),
        );
      },
    );
  }
}

class _CenterMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;
  const _CenterMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
