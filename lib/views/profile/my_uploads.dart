// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flatch/blocs/my_uploads/my_uploads_bloc.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/services/library_order_service.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/audio_cache_service.dart';
import 'package:flatch/common/services/share_service.dart';
import 'package:flatch/common/widgets/fart_card.dart';
import 'package:flutter/material.dart';
import 'package:flatch/common/services/audio_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:go_router/go_router.dart';

import 'package:flatch/common/models/fart_model.dart';

/// Standalone route: My Fart Library with its own app bar. The list body lives
/// in [MyUploadsListView] so it can also be embedded (e.g. under the upload
/// tiles in the + module).
class MyUploadsScreen extends StatelessWidget {
  const MyUploadsScreen({super.key});

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
      body: const MyUploadsListView(),
    );
  }
}

/// The My Fart Library list. Full feature set — play/pause, rename (mine),
/// delete (mine), share, comments, pagination.
///
/// * Standalone (`embedded: false`): owns its scroll + infinite-scroll paging.
/// * Embedded (`embedded: true`): lays out inline inside a parent scroll view
///   (shrink-wrapped, no inner scroll) and pages via a "Load more" button.
class MyUploadsListView extends StatefulWidget {
  final bool embedded;
  const MyUploadsListView({super.key, this.embedded = false});

  @override
  State<MyUploadsListView> createState() => _MyUploadsListViewState();
}

class _MyUploadsListViewState extends State<MyUploadsListView> {
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerSub;
  String? _currentlyPlayingUrl;

  // The user's hand-arranged order (fart ids). Empty until loaded / until they
  // have actually dragged something.
  List<String> _order = const [];

  @override
  void initState() {
    super.initState();
    context.read<MyUploadsBloc>().add(FetcnInitialUploads());

    LibraryOrderService.load().then((o) {
      if (mounted && o.isNotEmpty) setState(() => _order = o);
    });

    _playerSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() => _currentlyPlayingUrl = null);
        }
      }
    });

    // Infinite scroll only makes sense when we own the scroll view.
    if (!widget.embedded) {
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
        await AudioRoute.toSpeakerUnlessHeadphones();
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

  /// Commits a drag. Persists the new arrangement so it survives app restarts,
  /// merging with any ordered-but-not-yet-loaded items so pagination doesn't
  /// quietly discard their positions.
  Future<void> _onReorder(List<FartModel> visible, int oldIndex, int newIndex) async {
    // ReorderableListView reports the target index BEFORE the item is removed.
    if (newIndex > oldIndex) newIndex -= 1;
    final reordered = [...visible];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    final merged = LibraryOrderService.merge(
      reordered.map((f) => f.id).toList(),
      _order,
    );
    setState(() => _order = merged);
    await LibraryOrderService.save(merged);
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
              if (isMine)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit sound',
                      onPressed:
                          () => context.pushNamed(
                            AppRoute.editFart.name,
                            extra: fart,
                          ),
                      icon: Icon(Icons.tune_rounded, color: AppColors.primary),
                    ),
                    IconButton(
                      tooltip: 'Rename',
                      onPressed: () => _showEditNameDialog(context, fart),
                      icon: Icon(Icons.edit, color: AppColors.primary),
                    ),
                  ],
                )
              else
                const SizedBox.shrink(),
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
              title: 'For your review.',
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
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final ownPublic = fart.uid == currentUid && fart.isPublic;

    final outlined = OutlinedButton.styleFrom(
      side: BorderSide(color: AppColors.primary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
    final danger = ElevatedButton.styleFrom(
      backgroundColor: Colors.red,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );

    // A public fart that you own is live in the community — offer to remove it
    // from your library only, or delete it everywhere.
    if (ownPublic) {
      final choice = await showDialog<String>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Delete public fart'),
              content: const Text(
                "This fart is live in the community. Remove it from your "
                'library only, or delete it everywhere?',
              ),
              actionsPadding: const EdgeInsets.only(
                right: 12,
                left: 12,
                bottom: 8,
              ),
              actions: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton(
                      style: outlined,
                      onPressed: () => Navigator.of(ctx).pop('library'),
                      child: const Text('Remove from my library only'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: danger,
                      onPressed: () => Navigator.of(ctx).pop('everywhere'),
                      child: const Text(
                        'Delete everywhere',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop('cancel'),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
      );
      if (choice == 'library') {
        context.read<MyUploadsBloc>().add(
          DeleteUpload(id: fart.id, libraryOnly: true),
        );
      } else if (choice == 'everywhere') {
        context.read<MyUploadsBloc>().add(DeleteUpload(id: fart.id));
      }
      return;
    }

    // Private / not-owned: a simple confirm.
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
                    style: outlined,
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: danger,
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
    return BlocBuilder<MyUploadsBloc, MyUploadsState>(
      builder: (context, state) {
        if (state is MyUploadsLoading) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (state is MyUploadsError) {
          // Don't surface raw Firestore exceptions (e.g. transient
          // "unavailable") — show a friendly message with a retry.
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 40,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Couldn't load your library.",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary),
                    ),
                    onPressed:
                        () => context.read<MyUploadsBloc>().add(
                          FetcnInitialUploads(),
                        ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        } else if (state is MyUploadsLoaded) {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          // Default arrangement: the user's own sounds first. Once they have
          // dragged anything, their order wins outright — re-grouping would
          // fight the arrangement they just made.
          final defaultOrder = [
            ...state.uploads.where((f) => f.uid == uid),
            ...state.uploads.where((f) => f.uid != uid),
          ];
          final sortedUploads = LibraryOrderService.apply<FartModel>(
            defaultOrder,
            _order,
            (f) => f.id,
          );
          if (sortedUploads.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No uploads found.')),
            );
          }

          if (widget.embedded) {
            // Lay out inline inside the parent scroll view.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...sortedUploads.map(_buildItem),
                if (state.hasMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primary),
                      ),
                      onPressed:
                          () => context.read<MyUploadsBloc>().add(
                            FetchMoreUploads(state.lastDoc!),
                          ),
                      child: const Text('Load more'),
                    ),
                  ),
              ],
            );
          }

          return ReorderableListView.builder(
            scrollController: _scrollController,
            // Only the handle starts a drag; a long-press anywhere would
            // collide with playing/expanding a card.
            buildDefaultDragHandles: false,
            footer:
                state.hasMore
                    ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                    : null,
            onReorder:
                (oldIndex, newIndex) =>
                    _onReorder(sortedUploads, oldIndex, newIndex),
            itemCount: sortedUploads.length,
            itemBuilder: (context, index) {
              final fart = sortedUploads[index];
              return _reorderable(fart, index);
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  /// A library row plus its drag handle. Keyed by fart id so Flutter tracks the
  /// right widget as rows move.
  Widget _reorderable(FartModel fart, int index) {
    return Row(
      key: ValueKey(fart.id),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ReorderableDragStartListener(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(left: 6, right: 2),
            child: Tooltip(
              message: 'Hold and drag to reorder',
              child: Icon(
                Icons.drag_indicator,
                color: AppColors.primary.withValues(alpha: 0.55),
                size: 26,
              ),
            ),
          ),
        ),
        Expanded(child: _buildItem(fart)),
      ],
    );
  }
}
