// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flatch/blocs/my_uploads/my_uploads_bloc.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/audio_cache_service.dart';
import 'package:flatch/common/services/share_service.dart';
import 'package:flatch/common/widgets/fart_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_audio_output/flutter_audio_output.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:go_router/go_router.dart';

import 'package:flatch/common/models/fart_model.dart';

class MyUploadsScreen extends StatefulWidget {
  const MyUploadsScreen({super.key});

  @override
  State<MyUploadsScreen> createState() => _MyUploadsScreenState();
}

class _MyUploadsScreenState extends State<MyUploadsScreen> {
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerSub;
  String? _currentlyPlayingUrl;

  @override
  void initState() {
    super.initState();
    context.read<MyUploadsBloc>().add(FetcnInitialUploads());

    _playerSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() => _currentlyPlayingUrl = null);
        }
      }
    });

    _scrollController.addListener(() {
      final bloc = context.read<MyUploadsBloc>();
      final state = bloc.state;

      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (state is MyUploadsLoaded && state.hasMore) {
          bloc.add(FetchMoreUploads(state.lastDoc!));
        }
      }
    });
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _player.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handlePlayPause(String url) async {
    if (!mounted) return;

    if (_currentlyPlayingUrl == url) {
      await _player.pause();
      if (mounted) {
        setState(() => _currentlyPlayingUrl = null);
      }
    } else {
      if (mounted) {
        setState(() => _currentlyPlayingUrl = url);
      }
      try {
        final localPath = await getOrDownloadFart(url);

        await _player.setFilePath(localPath);
        await FlutterAudioOutput.changeToSpeaker();
        await _player.play();
      } catch (e) {
        debugPrint('Audio error: $e');
        if (mounted) {
          setState(() => _currentlyPlayingUrl = null);
        }
      }
    }
  }

  void _showEditNameDialog(BuildContext context, FartModel fart) {
    final controller = TextEditingController(text: fart.title);

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Edit Sound Name'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Enter new name'),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        context.read<MyUploadsBloc>().add(
                          EditUploadName(
                            id: fart.id,
                            newName: controller.text.trim(),
                          ),
                        );
                      },
                      child: const Text(
                        'Save',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }

  Widget _buildItem(FartModel fart) {
    final isPlaying = _currentlyPlayingUrl == fart.fileUrl;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isMine = fart.uid == currentUid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isMine ? 'My Fart' : 'Community Fart',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              isMine
                  ? IconButton(
                    onPressed:
                        isMine
                            ? () => _showEditNameDialog(context, fart)
                            : null,
                    icon: Icon(Icons.edit, color: AppColors.primary),
                  )
                  : SizedBox.shrink(),
            ],
          ),
        ),

        FartCard(
          title: fart.title,
          fileUrl: fart.fileUrl,
          duration: fart.duration,
          upvotes: fart.upvotes,
          downvotes: fart.downvotes,
          userVote: fart.userVote ?? '',
          commentCount: fart.commentCount,
          username: fart.userName,
          isPlaying: isPlaying,
          onPlayPause: () => _handlePlayPause(fart.fileUrl),
          onShare: () async {
            await ShareService.instance.shareFart(
              fartId: fart.id,
              title: 'Listen to this fart!',
            );
          },
          onCommentsTap: () {
            context.pushNamed(AppRoute.commentFart.name, extra: fart);
          },
          onFartTab: () {
            context.pushNamed(AppRoute.commentFart.name, extra: fart);
          },
          onDelete: () => _confirmAndDelete(context, fart),
        ),
      ],
    );
  }

  void _confirmAndDelete(BuildContext context, FartModel fart) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Fart'),
            content: const Text('Are you sure you want to delete this fart?'),
            actions: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
            actionsPadding: const EdgeInsets.only(
              right: 12,
              left: 12,
              bottom: 8,
            ),
          ),
    );

    if (confirmed == true) {
      context.read<MyUploadsBloc>().add(DeleteUpload(id: fart.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Fart Library'),
        leading: IconButton(
          style: ButtonStyle().copyWith(
            backgroundColor: WidgetStatePropertyAll(Colors.transparent),
            side: WidgetStatePropertyAll(BorderSide.none),
          ),
          onPressed: () => GoRouter.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: BlocBuilder<MyUploadsBloc, MyUploadsState>(
        builder: (context, state) {
          if (state is MyUploadsLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is MyUploadsError) {
            return Center(child: Text(state.message));
          } else if (state is MyUploadsLoaded) {
            final sortedUploads = [
              ...state.uploads.where(
                (f) => f.uid == FirebaseAuth.instance.currentUser?.uid,
              ),
              ...state.uploads.where(
                (f) => f.uid != FirebaseAuth.instance.currentUser?.uid,
              ),
            ];
            if (sortedUploads.isEmpty) {
              return const Center(child: Text('No uploads found.'));
            }

            return ListView.builder(
              controller: _scrollController,
              itemCount: sortedUploads.length + (state.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < sortedUploads.length) {
                  return _buildItem(sortedUploads[index]);
                } else {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
              },
            );
          }

          return const SizedBox();
        },
      ),
    );
  }
}
