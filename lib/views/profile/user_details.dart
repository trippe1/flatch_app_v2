// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flatch/blocs/fetch_farts/fetch_farts_bloc.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/models/app_user.dart';
import 'package:flatch/common/models/fart_model.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/audio_cache_service.dart';
import 'package:flatch/common/services/share_service.dart';
import 'package:flatch/common/services/sound_library_services.dart';
import 'package:flatch/common/services/toast_service.dart';
import 'package:flatch/common/widgets/avatar.dart';
import 'package:flatch/common/widgets/fart_card.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:flatch/cubits/fetch_farts/fetch_farts_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flatch/common/services/audio_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flatch/blocs/user_details/user_details_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:toastification/toastification.dart';

class UsersDetailsScreen extends StatefulWidget {
  final String userId;
  final bool isAdmin;

  const UsersDetailsScreen({
    super.key,
    required this.userId,
    this.isAdmin = false,
  });

  @override
  State<UsersDetailsScreen> createState() => _UsersDetailsScreenState();
}

class _UsersDetailsScreenState extends State<UsersDetailsScreen> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerSub;
  String? _currentlyPlayingUrl;

  @override
  void initState() {
    super.initState();
    BlocProvider.of<UserDetailsBloc>(
      context,
    ).add(FetchUserDetails(uid: widget.userId));
    _playerSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() => _currentlyPlayingUrl = null);
        }
      }
    });
  }

  void _handleVoteChange(
    BuildContext context,
    FartModel fart,
    String selectedVote,
  ) {
    final prevVote = fart.userVote;
    int newUpvotes = fart.upvotes;
    int newDownvotes = fart.downvotes;
    String? updatedVote;

    if (prevVote == selectedVote) {
      if (selectedVote == 'upvote') newUpvotes--;
      if (selectedVote == 'downvote') newDownvotes--;
      updatedVote = '';
    } else {
      if (prevVote == 'upvote') newUpvotes--;
      if (prevVote == 'downvote') newDownvotes--;
      if (selectedVote == 'upvote') newUpvotes++;
      if (selectedVote == 'downvote') newDownvotes++;
      updatedVote = selectedVote;
    }

    final updated = fart.copyWith(
      upvotes: newUpvotes,
      downvotes: newDownvotes,
      userVote: updatedVote,
    );

    context.read<FetchFartsCubit>().updateFart(updated);

    if (updatedVote == '') {
      context.read<UserDetailsBloc>().add(
        VoteUserVote(fartId: fart.id, voteType: 'remove'),
      );
    } else {
      context.read<UserDetailsBloc>().add(
        VoteUserVote(fartId: fart.id, voteType: updatedVote),
      );
    }
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

  void _submitReport(BuildContext context, FartModel fart, String reason) {
    final updated = fart.copyWith(
      userReported: !(fart.userReported ?? false),
      reportReason: reason,
    );

    context.read<FetchFartsCubit>().updateFart(updated);

    context.read<FetchFartsBloc>().add(
      ReportFart(fartId: fart.id, reason: reason),
    );
  }

  void _showReportDialog(BuildContext context, FartModel fart) {
    if (fart.userReported == true) {
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text('Undo Report'),
              content: Text(
                'You already reported this sound for "${fart.reportReason}". '
                'Do you want to unreport it?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _submitReport(context, fart, fart.reportReason ?? '');
                  },
                  child: const Text('Unreport'),
                ),
              ],
            ),
      );
      return;
    }
  }

  void _showBanUserDialog(BuildContext context, AppUser user) {
    final controller = TextEditingController();
    final isBanned = user.isBan == true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isBanned ? 'Reinstate User' : 'Ban User'),

          content:
              isBanned
                  ? const Text('Are you sure you want to reinstate this user?')
                  : TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Reason for ban',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),

            TextButton(
              onPressed: () {
                if (isBanned) {
                  // ✅ UN-BAN
                  context.read<FetchFartsCubit>().reinstateUser(user.uid);

                  showToast(
                    context: context,
                    message: 'User has been reinstated',
                    type: ToastificationType.success,
                  );
                } else {
                  // ✅ BAN
                  final reason = controller.text.trim();
                  if (reason.isEmpty) return;

                  context.read<FetchFartsCubit>().banUser(user.uid, reason);

                  showToast(
                    context: context,
                    message: 'User banned: $reason',
                    type: ToastificationType.warning,
                  );
                }

                Navigator.pop(dialogContext);
              },
              child: Text(isBanned ? 'Reinstate' : 'Ban'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserDetailsBloc, UserDetailsState>(
      builder: (context, state) {
        if (state is UserDetailsLoading || state is UserDetailsInitial) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is UserDetailsError) {
          return Scaffold(body: Center(child: Text('Error: ${state.message}')));
        }

        if (state is UserDetailsLoaded) {
          context.read<FetchFartsCubit>().setFarts(state.farts);
          final user = state.appUser;

          return Scaffold(
            appBar: AppBar(
              title: Text(
                style: TextStyle(fontWeight: FontWeight.w600),
                user.name.length > 30 ? user.name.substring(0, 30) : user.name,
              ),
              leading: IconButton(
                style: ButtonStyle().copyWith(
                  backgroundColor: WidgetStatePropertyAll(Colors.transparent),
                  side: WidgetStatePropertyAll(BorderSide.none),
                ),
                onPressed: () {
                  context.read<FetchFartsCubit>().selectCategory('');
                  context.read<FetchFartsBloc>().add(FetchTopFarts());
                  GoRouter.of(context).pop();
                },
                icon: const Icon(Icons.arrow_back),
              ),
              centerTitle: false,
              actions: [
                if (widget.isAdmin)
                  user.role == 'Admin'
                      ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextWidget(
                          text: "Admin",
                          color: AppColors.primary,
                          weight: FontWeight.w600,
                        ),
                      )
                      : Row(
                        children: [
                          TextWidget(
                            text:
                                user.isBan == true
                                    ? "Reinstate User"
                                    : "Ban User",
                          ),
                          IconButton(
                            style: ButtonStyle().copyWith(
                              backgroundColor: const WidgetStatePropertyAll(
                                Colors.transparent,
                              ),
                              side: const WidgetStatePropertyAll(
                                BorderSide.none,
                              ),
                            ),
                            onPressed: () => _showBanUserDialog(context, user),
                            icon: Icon(
                              user.isBan == true
                                  ? Icons.check_circle
                                  : Icons.block,
                              color:
                                  user.isBan == true
                                      ? Colors.green
                                      : Colors.red,
                            ),
                          ),
                        ],
                      ),
              ],
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Gap(10),
                      buildCircularUserAvatar(
                        context,
                        user.profileImage,
                        user.name,
                        MediaQuery.of(context).size.height * 0.08,
                      ),
                      const Gap(10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Bio: ${user.description ?? 'No bio available'}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(),
                BlocBuilder<FetchFartsCubit, FetchFartsCubitState>(
                  builder: (context, cubitState) {
                    final farts = cubitState.farts;
                    return Expanded(
                      child:
                          farts.isEmpty
                              ? const Center(
                                child: Text('No sounds uploaded yet'),
                              )
                              : ListView.builder(
                                itemCount: farts.length,
                                itemBuilder: (context, index) {
                                  final fart = farts[index];
                                  final isPlaying =
                                      _currentlyPlayingUrl == fart.fileUrl;
                                  return FartCard(
                                    fileUrl: fart.fileUrl,
                                    title: fart.title,
                                    onFartTab: () {
                                      context.pushNamed(
                                        AppRoute.commentFart.name,
                                        extra: fart,
                                      );
                                    },
                                    onPlayPause:
                                        () => _handlePlayPause(fart.fileUrl),
                                  onDownload:
                                        () => SoundLibraryService.saveToLibrary(
                                          context: context,
                                         fart: fart,
                                          source: 'community',
                                        ),

                                    onCommentsTap: () {
                                      context.pushNamed(
                                        AppRoute.commentFart.name,
                                        extra: fart,
                                      );
                                    },
                                    onShare: () async {
                                      await ShareService.instance.shareFart(
                                        fartId: fart.id,
                                        title: 'For your review.',
                                      );
                                    },
                                    commentCount: fart.commentCount,
                                    onDelete:
                                        widget.isAdmin
                                            ? () async {
                                              final confirm = await showDialog<
                                                bool
                                              >(
                                                context: context,
                                                builder:
                                                    (context) => AlertDialog(
                                                      title: const Text(
                                                        'Delete Fart',
                                                      ),
                                                      content: const Text(
                                                        'Are you sure you want to delete this fart?',
                                                      ),
                                                      actions: [
                                                        Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .stretch,
                                                          children: [
                                                            OutlinedButton(
                                                              style: OutlinedButton.styleFrom(
                                                                side: BorderSide(
                                                                  color:
                                                                      AppColors
                                                                          .primary,
                                                                ),
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        10,
                                                                      ),
                                                                ),
                                                              ),
                                                              onPressed:
                                                                  () =>
                                                                      Navigator.of(
                                                                        context,
                                                                      ).pop(
                                                                        false,
                                                                      ),
                                                              child: const Text(
                                                                'Cancel',
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 8,
                                                            ),
                                                            ElevatedButton(
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor:
                                                                    Colors.red,
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        10,
                                                                      ),
                                                                ),
                                                              ),
                                                              onPressed:
                                                                  () =>
                                                                      Navigator.of(
                                                                        context,
                                                                      ).pop(
                                                                        true,
                                                                      ),
                                                              child: const Text(
                                                                'Delete',
                                                                style: TextStyle(
                                                                  color:
                                                                      Colors
                                                                          .white,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                              );

                                              if (confirm == true) {
                                                context
                                                    .read<FetchFartsCubit>()
                                                    .deleteFart(fart.id);
                                                showToast(
                                                  context: context,
                                                  message:
                                                      'Fart deleted successfully',
                                                  type:
                                                      ToastificationType
                                                          .success,
                                                );
                                              }
                                            }
                                            : null,

                                    duration: fart.duration,
                                    upvotes: fart.upvotes,
                                    downvotes: fart.downvotes,
                                    username: fart.userName,
                                    userVote: fart.userVote ?? '',
                                    isPlaying: isPlaying,
                                    onUpvote: () {
                                      _handleVoteChange(
                                        context,
                                        fart,
                                        'upvote',
                                      );
                                    },
                                    onDownvote: () {
                                      _handleVoteChange(
                                        context,
                                        fart,
                                        'downvote',
                                      );
                                    },

                                    onReport:
                                        () => _showReportDialog(context, fart),
                                    alreadyReported: fart.userReported ?? false,
                                  );
                                },
                              ),
                    );
                  },
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
