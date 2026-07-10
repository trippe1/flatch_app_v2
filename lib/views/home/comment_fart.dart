// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flatch/blocs/admin_farts/admin_farts_bloc.dart';
import 'package:flatch/blocs/fetch_farts/fetch_farts_bloc.dart';
import 'package:flatch/common/app_helpers/app_helper.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/enums/comment_filter_enum.dart';
import 'package:flatch/common/logics/sorting_logics.dart';
import 'package:flatch/common/models/comment_model.dart';
import 'package:flatch/common/models/fart_model.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/audio_cache_service.dart';
import 'package:flatch/common/services/share_service.dart';
import 'package:flatch/common/services/sound_library_services.dart';
import 'package:flatch/common/services/toast_service.dart';
import 'package:flatch/common/widgets/fart_card.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:flatch/cubits/fetch_farts/fetch_farts_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flatch/common/services/audio_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart' show Gap;
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:toastification/toastification.dart';

class FartDetailScreen extends StatefulWidget {
  final FartModel fart;
  final bool isAdmin;

  const FartDetailScreen({super.key, required this.fart, this.isAdmin = false});

  @override
  State<FartDetailScreen> createState() => _FartDetailScreenState();
}

class _FartDetailScreenState extends State<FartDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerSub;
  String? _currentlyPlayingUrl;
  CommentModel? _replyingTo;
  final Map<String, bool> _expandedReplies = {};
  CommentFilter _commentFilter = CommentFilter.sortBy;
  String? _mentionText;
  bool _isSettingMention = false;

  @override
  void initState() {
    super.initState();

    _playerSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) setState(() => _currentlyPlayingUrl = null);
      }
    });

    context.read<FetchFartsBloc>().add(
      FetchCommentsFart(fartId: widget.fart.id),
    );

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100) {
        final state = context.read<FetchFartsBloc>().state;
        if (state is FetchCommentsSuccess && state.hasMore) {
          context.read<FetchFartsBloc>().add(
            FetchMoreCommentsFart(fartId: widget.fart.id),
          );
        }
      }
    });
    _commentController.addListener(() {
      if (_isSettingMention) {
        _isSettingMention = false;
        return;
      }

      if (_mentionText != null) {
        final text = _commentController.text;

        if (!text.startsWith(_mentionText!)) {
          _commentController.text = "";
          _mentionText = null;
          _replyingTo = null;

          _commentController.selection = TextSelection.fromPosition(
            TextPosition(offset: 0),
          );
        }
      }
    });
  }

  Future<void> _handlePlayPause(String url) async {
    if (!mounted) return;

    if (_currentlyPlayingUrl == url) {
      await _player.pause();
      setState(() => _currentlyPlayingUrl = null);
    } else {
      setState(() => _currentlyPlayingUrl = url);
      try {
        await AudioRoute.toSpeakerUnlessHeadphones();
        final localPath = await getOrDownloadFart(url);
        await _player.setFilePath(localPath);
        await _player.play();
      } catch (e) {
        debugPrint('Audio error: $e');
        setState(() => _currentlyPlayingUrl = null);
      }
    }
  }

  void _addComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    context.read<FetchFartsBloc>().add(
      AddCommentFart(
        fartId: widget.fart.id,
        text: text,
        parentCommentId: _replyingTo?.id,
      ),
    );

    _commentController.clear();
    setState(() {
      _replyingTo = null;
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
      context.read<FetchFartsBloc>().add(
        VoteFart(fartId: fart.id, voteType: 'remove'),
      );
    } else {
      context.read<FetchFartsBloc>().add(
        VoteFart(fartId: fart.id, voteType: updatedVote),
      );
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

    showDialog(
      context: context,
      builder: (context) {
        String? selectedReason;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Report Sound'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Why are you reporting this sound?'),
                  const SizedBox(height: 12),
                  RadioGroup<String>(
                    groupValue: selectedReason,
                    onChanged: (val) => setState(() => selectedReason = val),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          value: 'Inappropriate',
                          title: const Text('Inappropriate'),
                        ),
                        RadioListTile<String>(
                          value: 'Offensive',
                          title: const Text('Offensive'),
                        ),
                        RadioListTile<String>(
                          value: 'Spam',
                          title: const Text('Spam or misleading'),
                        ),
                        RadioListTile<String>(
                          value: 'Other',
                          title: const Text('Other'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (selectedReason != null) {
                      Navigator.pop(context);
                      _submitReport(context, fart, selectedReason!);
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCommentReportDialog(
    BuildContext context,
    CommentModel comment,
  ) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final reportDoc =
        await FirebaseFirestore.instance
            .collection('user_farts')
            .doc(comment.fartId)
            .collection('comments')
            .doc(comment.id)
            .collection('reports')
            .doc(currentUserId)
            .get();

    if (reportDoc.exists) {
      final reason = reportDoc.data()?['reason'] ?? '';
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text('Undo Report'),
              content: Text(
                'You already reported this comment${reason.isNotEmpty ? ": \"$reason\"" : ""}. Do you want to unreport it?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _submitCommentReport(context, comment, reason);
                  },
                  child: const Text('Unreport'),
                ),
              ],
            ),
      );
      return;
    }

    // User hasn't reported yet → show input dialog
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Report Comment'),
            content: TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Reason for reporting this comment',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final reason = reasonController.text.trim();
                  if (reason.isNotEmpty) {
                    Navigator.pop(context);
                    _submitCommentReport(context, comment, reason);
                  }
                },
                child: const Text('Report'),
              ),
            ],
          ),
    );
  }

  void _submitCommentReport(
    BuildContext context,
    CommentModel comment,
    String reason,
  ) {
    context.read<FetchFartsBloc>().add(
      ReportCommentFart(
        fartId: comment.fartId,
        commentId: comment.id,
        reason: reason,
      ),
    );
  }

  void _showEditCommentDialog(BuildContext context, CommentModel comment) {
    final controller = TextEditingController(text: comment.text);

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Edit Comment'),
            content: TextField(controller: controller, maxLines: null),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<FetchFartsBloc>().add(
                    EditCommentFart(
                      fartId: comment.fartId,
                      commentId: comment.id,
                      newText: controller.text.trim(),
                    ),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _showFilterMenu(BuildContext context) async {
    final selected = await showMenu<CommentFilter>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 0, 0),
      items: const [
        PopupMenuItem(value: CommentFilter.all, child: Text("All")),
        PopupMenuItem(value: CommentFilter.popular, child: Text("Popular")),
        PopupMenuItem(value: CommentFilter.newest, child: Text("Newest")),
        PopupMenuItem(value: CommentFilter.oldest, child: Text("Oldest")),
        PopupMenuItem(
          value: CommentFilter.controversial,
          child: Text("Controversial"),
        ),
      ],
    );

    if (selected != null) {
      setState(() {
        _commentFilter = selected;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('c/${widget.fart.category}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: BlocBuilder<FetchFartsCubit, FetchFartsCubitState>(
              builder: (context, cubitState) {
                final updatedFart = cubitState.farts.firstWhere(
                  (f) => f.id == widget.fart.id,
                  orElse: () => widget.fart,
                );

                final isPlaying = _currentlyPlayingUrl == updatedFart.fileUrl;

                return widget.isAdmin
                    ? FartCard(
                      onShare: () async {
                        await ShareService.instance.shareFart(
                          fartId: updatedFart.id,

                          title: 'Listen to this fart!',
                        );
                      },
                      uid: updatedFart.uid,
                      username: updatedFart.userName,
                      title: updatedFart.title,
                      fileUrl: updatedFart.fileUrl,
                      isPlaying: isPlaying,
                      commentCount: updatedFart.commentCount,
                      duration: updatedFart.duration,
                      upvotes: updatedFart.upvotes,
                      downvotes: updatedFart.downvotes,
                      userVote: updatedFart.userVote ?? '',
                      onDelete: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Delete Fart'),
                                content: const Text(
                                  'Are you sure you want to delete this fart?',
                                ),
                                actions: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: AppColors.primary,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ), // ✅ radius 10
                                          ),
                                        ),
                                        onPressed:
                                            () => Navigator.of(
                                              context,
                                            ).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        onPressed:
                                            () =>
                                                Navigator.of(context).pop(true),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                        );

                        if (confirm == true) {
                          context.read<AdminFartsBloc>().add(
                            DeleteFartEvent(fartId: updatedFart.id),
                          );
                          showToast(
                            context: context,
                            message: 'Fart deleted successfully',
                            type: ToastificationType.success,
                          );
                          Future.delayed(const Duration(milliseconds: 1000));
                          Navigator.pop(context);
                        }
                      },
                      onUpvote: () {
                        _handleVoteChange(context, updatedFart, 'upvote');
                      },
                      onDownvote: () {
                        _handleVoteChange(context, updatedFart, 'downvote');
                      },
                      onDownload:
                          () => SoundLibraryService.saveToLibrary(
                            context: context,
                            fart: updatedFart,
                            source: 'community',
                          ),

                      onReport: () => _showReportDialog(context, updatedFart),

                      onPlayPause: () => _handlePlayPause(updatedFart.fileUrl),
                      alreadyReported: updatedFart.userReported ?? false,
                      onUserTap: () {
                        context.pushNamed(
                          AppRoute.userProfileScreen.name,
                          extra: updatedFart.uid,
                          queryParameters: {'isAdmin': 'true'},
                        );
                      },
                    )
                    : FartCard(
                      onShare: () async {
                        await ShareService.instance.shareFart(
                          fartId: updatedFart.id,

                          title: 'Listen to this fart!',
                        );
                      },
                      uid: updatedFart.uid,
                      username: updatedFart.userName,
                      title: updatedFart.title,
                      fileUrl: updatedFart.fileUrl,
                      isPlaying: isPlaying,
                      commentCount: updatedFart.commentCount,
                      duration: updatedFart.duration,
                      upvotes: updatedFart.upvotes,
                      downvotes: updatedFart.downvotes,
                      userVote: updatedFart.userVote ?? '',
                      onUpvote: () {
                        _handleVoteChange(context, updatedFart, 'upvote');
                      },
                      onDownvote: () {
                        _handleVoteChange(context, updatedFart, 'downvote');
                      },
                      onDownload:
                          () => SoundLibraryService.saveToLibrary(
                            context: context,
                            fart: updatedFart,
                            source: 'community',
                          ),
                      onReport: () => _showReportDialog(context, updatedFart),

                      onPlayPause: () => _handlePlayPause(updatedFart.fileUrl),
                      alreadyReported: updatedFart.userReported ?? false,
                      onUserTap: () {
                        context.pushNamed(
                          AppRoute.userProfileScreen.name,
                          extra: updatedFart.uid,
                        );
                      },
                    );
              },
            ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.sort),
                onPressed: () => _showFilterMenu(context),
                tooltip: "Sort by",
              ),
              Gap(5),
              GestureDetector(
                onTap: () => _showFilterMenu(context),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Text(
                      AppLogics.instance.getCommentFilterDisplayName(
                        _commentFilter,
                      ),
                    ),
                  ),
                ),
              ),
              Gap(20),
            ],
          ),

          Expanded(
            child: BlocBuilder<FetchFartsBloc, FetchFartsState>(
              builder: (context, state) {
                if (state is CommentsLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is FetchCommentsSuccess) {
                  final comments = state.comments;
                  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
                  final organizedComments = buildCommentTree(
                    AppLogics.instance.applyCommentFilter(
                      state.comments,
                      _commentFilter,
                    ),
                  );

                  if (comments.isEmpty) {
                    return const Center(child: Text('No comments yet'));
                  }

                  return ListView(
                    padding: EdgeInsets.only(left: 20),
                    controller: _scrollController,
                    children: [
                      ...organizedComments.map(
                        (comment) =>
                            _buildCommentItem(context, comment, currentUserId),
                      ),
                      if (state.hasMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  );
                } else if (state is FetchCommentsFailure) {
                  return Center(child: Text('Error: ${state.error}'));
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 50, left: 10, right: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(
    BuildContext context,
    CommentModel comment,
    String currentUserId, {
    int depth = 0,
  }) {
    final userUpvoted = comment.isUpvotedBy(currentUserId);
    final userDownvoted = comment.isDownvotedBy(currentUserId);
    final hasReplies = comment.replies.isNotEmpty;
    final isExpanded = _expandedReplies[comment.id] ?? false;

    // Customize indent and line for replies
    Widget commentContent = Container(
      padding: EdgeInsets.only(
        left: depth == 0 ? 0 : 8,
        right: 8,
        top: 12,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: depth > 0 ? Colors.grey.withAlpha(56) : Colors.transparent,
            width: depth > 0 ? 2 : 0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextRichWidget(
                texts: [
                  'By: u/${comment.userName}. ',
                  AppHelper.timeAgo(comment.updatedAt),
                ],
                fontSize: [12, 15],
                colors: [
                  Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                  Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                ],
              ),
              // No reply icon here!
            ],
          ),
          const SizedBox(height: 4),
          // Comment text
          Text(comment.text),
          const SizedBox(height: 6),
          // Like/Dislike row
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  context.read<FetchFartsBloc>().add(
                    VoteCommentFart(
                      userId: currentUserId,
                      fartId: comment.fartId,
                      commentId: comment.id,
                      voteType: userUpvoted ? 'remove_upvote' : 'upvote',
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text('${comment.upvotes}'),
                    const SizedBox(width: 4),
                    Icon(
                      userUpvoted ? Icons.thumb_up : Icons.thumb_up_outlined,
                      color: userUpvoted ? AppColors.primary : null,
                      size: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  context.read<FetchFartsBloc>().add(
                    VoteCommentFart(
                      userId: currentUserId,
                      fartId: comment.fartId,
                      commentId: comment.id,
                      voteType: userDownvoted ? 'remove_downvote' : 'downvote',
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text('${comment.downvotes}'),
                    const SizedBox(width: 4),
                    Icon(
                      userDownvoted
                          ? Icons.thumb_down
                          : Icons.thumb_down_outlined,
                      color: userDownvoted ? Colors.red : null,
                      size: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _replyingTo = comment;
                    _isSettingMention = true;
                    _mentionText = '@${comment.userName} ';
                    _commentController.text = _mentionText!;
                  });
                },
                child: Text(
                  'Reply',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          // Show/Hide replies
          if (hasReplies)
            GestureDetector(
              onTap: () {
                setState(() {
                  _expandedReplies[comment.id] = !isExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Text(
                  isExpanded
                      ? 'Hide replies'
                      : 'Show replies (${comment.replies.length})',
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          // Replies
          if (hasReplies && isExpanded)
            ...comment.replies.map(
              (reply) => _buildCommentItem(
                context,
                reply,
                currentUserId,
                depth: depth + 1,
              ),
            ),
        ],
      ),
    );

    if (depth == 0) {
      commentContent = Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Material(color: Colors.transparent, child: commentContent),
      );
    }

    return GestureDetector(
      onLongPress: () {
        final isAdmin = widget.isAdmin;
        final isOwner = comment.uid == currentUserId;

        if (isAdmin || isOwner) {
          showCupertinoModalPopup(
            context: context,
            builder:
                (_) => CupertinoActionSheet(
                  title: const Text('Comment Options'),
                  actions: [
                    if (isOwner)
                      CupertinoActionSheetAction(
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditCommentDialog(context, comment);
                        },
                        child: const Text('Edit'),
                      ),
                    CupertinoActionSheetAction(
                      isDestructiveAction: true,
                      onPressed: () {
                        Navigator.pop(context);

                        showCupertinoDialog(
                          context: context,
                          builder:
                              (_) => CupertinoAlertDialog(
                                title: const Text('Delete Comment'),
                                content: const Text(
                                  'Are you sure you want to delete this comment?',
                                ),
                                actions: [
                                  CupertinoDialogAction(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  CupertinoDialogAction(
                                    isDestructiveAction: true,
                                    onPressed: () {
                                      Navigator.pop(context);
                                      context.read<FetchFartsBloc>().add(
                                        DeleteCommentFart(
                                          fartId: comment.fartId,
                                          commentId: comment.id,
                                          isAdmin: isAdmin,
                                        ),
                                      );
                                    },
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                        );
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                  cancelButton: CupertinoActionSheetAction(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
          );
        } else {
          _showCommentReportDialog(context, comment);
        }
      },

      child: commentContent,
    );
  }

  List<CommentModel> buildCommentTree(List<CommentModel> comments) {
    final Map<String, CommentModel> map = {
      for (var c in comments) c.id: c.copyWith(replies: []),
    };

    List<CommentModel> topLevel = [];

    for (var c in comments) {
      if (c.parentCommentId == null) {
        topLevel.add(map[c.id]!);
      } else {
        final parent = map[c.parentCommentId];
        if (parent != null) {
          parent.replies.add(map[c.id]!);
        }
      }
    }

    return topLevel;
  }
}
