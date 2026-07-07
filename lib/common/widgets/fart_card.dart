// ignore_for_file: deprecated_member_use

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flatch/common/color/app_colors.dart';

class FartCard extends StatelessWidget {
  final String? uid;
  final String title;
  final String fileUrl;
  final bool isPlaying;
  final String? emoji;
  final int? duration;
  final int? upvotes;
  final int? downvotes;
  final String? userVote;
  final VoidCallback? onPlayPause;
  final VoidCallback? onUpvote;
  final VoidCallback? onDownvote;
  final VoidCallback? onReport;
  final VoidCallback? onDelete;
  final VoidCallback? onDownload;
  final bool? alreadyReported;
  final int? commentCount;
  final String? username;
  final String? userAvatarUrl;
  final VoidCallback? onUserTap;
  final VoidCallback? onCommentsTap;
  final VoidCallback? onFartTab;
  final VoidCallback? onShare;
  final int? reportCount;
  final bool? isReorderWidget;

  const FartCard({
    super.key,
    this.uid,
    required this.title,
    required this.fileUrl,
    required this.isPlaying,
    this.emoji,
    this.duration,
    this.upvotes,
    this.downvotes,
    this.userVote,
    this.onPlayPause,
    this.onUpvote,
    this.onDownvote,
    this.onReport,
    this.onDelete,
    this.onDownload,
    this.alreadyReported,
    this.commentCount,
    this.username,
    this.userAvatarUrl,
    this.onUserTap,
    this.onCommentsTap,
    this.onFartTab,
    this.onShare,
    this.reportCount,
    this.isReorderWidget = false,
  });

  String get formattedDuration {
    if (duration == null) return '';
    final d = Duration(milliseconds: duration!);
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onFartTab,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            Row(
              children: [
                isReorderWidget == true
                    ? const SizedBox(
                      width: 40,
                      child: Icon(Icons.drag_handle, color: Colors.grey),
                    )
                    : const SizedBox.shrink(),
                InkWell(
                  onTap: onPlayPause,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isPlaying ? Icons.pause_circle : Icons.volume_up,
                      size: 28,
                      color: Theme.of(context).iconTheme.color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (title.length > 15
                            ? 'f/${title.substring(0, 15)}'
                            : 'f/$title'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (uid != null)
                        SelectableText.rich(
                          TextSpan(
                            text: 'Uploaded by ',
                            style: const TextStyle(color: Colors.grey),
                            children: [
                              TextSpan(
                                text: 'u/${username ?? 'Anonymous'}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                                recognizer:
                                    TapGestureRecognizer()
                                      ..onTap = () {
                                        if (uid != null && onUserTap != null) {
                                          onUserTap!();
                                        }
                                      },
                              ),
                            ],
                          ),
                          showCursor: true,
                          cursorColor: AppColors.primary,
                          toolbarOptions: const ToolbarOptions(
                            copy: true,
                            selectAll: true,
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (duration != null)
                        Text(
                          formattedDuration,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            if (_showBottomSection) ...[
              const SizedBox(height: 8),
              Divider(color: Colors.black.withOpacity(0.2)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_showVotes)
                    Row(
                      children: [
                        _actionIcon(
                          icon:
                              userVote == 'upvote'
                                  ? Icons.thumb_up
                                  : Icons.thumb_up_alt_outlined,
                          label: '${upvotes ?? 0}',
                          color:
                              userVote == 'upvote'
                                  ? AppColors.upvote
                                  : Colors.grey.shade700,
                          onTap: onUpvote,
                        ),
                        const SizedBox(width: 12),
                        _actionIcon(
                          icon:
                              userVote == 'downvote'
                                  ? Icons.thumb_down
                                  : Icons.thumb_down_alt_outlined,
                          label: '${downvotes ?? 0}',
                          color:
                              userVote == 'downvote'
                                  ? AppColors.downvote
                                  : Colors.grey.shade700,
                          onTap: onDownvote,
                        ),
                      ],
                    ),

                  if (onCommentsTap != null)
                    _actionIcon(
                      icon: Icons.comment_outlined,
                      label: '${commentCount ?? 0}',
                      color: Theme.of(context).iconTheme.color!,
                      onTap: onCommentsTap,
                    ),
                  Row(
                    children: [
                      if (onDownload != null)
                        _iconButton(
                          context: context,
                          icon: Icons.bookmark_add_rounded,
                          onTap: onDownload!,
                        ),
                      if (onReport != null)
                        Row(
                          children: [
                            _iconButton(
                              context: context,
                              icon:
                                  alreadyReported ?? false
                                      ? Icons.flag
                                      : Icons.flag_outlined,
                              iconColor:
                                  alreadyReported ?? false
                                      ? Colors.red
                                      : Theme.of(context).iconTheme.color,
                              onTap: onReport!,
                            ),
                            // Show report count if greater than 0
                            if ((reportCount ?? 0) > 0)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 2.0,
                                  right: 4.0,
                                ),
                                child: Text(
                                  '$reportCount',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red[400],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),

                      if (onShare != null)
                        _iconButton(
                          context: context,
                          icon: Icons.share,
                          onTap: onShare!,
                        ),

                      if (onDelete != null)
                        _iconButton(
                          context: context,
                          icon: Icons.delete_outline,
                          onTap: onDelete!,
                          iconColor: Colors.red.shade400,
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
    required BuildContext context,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Icon(
            icon,
            size: 20,
            color: iconColor ?? Theme.of(context).iconTheme.color,
          ),
        ),
      ),
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  bool get _showVotes =>
      upvotes != null || downvotes != null || userVote != null;

  bool get _showBottomSection =>
      _showVotes || onReport != null || onDelete != null || onDownload != null;
}
