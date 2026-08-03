import 'dart:async';

import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/models/fwb_models.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/audio_route.dart';
import 'package:flatch/common/services/fwb_service.dart';
import 'package:flatch/common/services/toast_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';

class FwbChatScreen extends StatefulWidget {
  final String groupId;
  const FwbChatScreen({super.key, required this.groupId});

  @override
  State<FwbChatScreen> createState() => _FwbChatScreenState();
}

class _FwbChatScreenState extends State<FwbChatScreen> {
  final _msg = TextEditingController();
  final _scroll = ScrollController();
  final AudioPlayer _player = AudioPlayer();
  String? _playingUrl;

  bool _muted = false;
  StreamSubscription<Set<String>>? _mutedSub;

  String get _me => FwbService.uid ?? '';

  @override
  void initState() {
    super.initState();
    // Reflect this chat's mute state live (it lives on the user's settings doc).
    _mutedSub = FwbService.mutedGroups().listen((muted) {
      if (mounted) setState(() => _muted = muted.contains(widget.groupId));
    });
  }

  @override
  void dispose() {
    _mutedSub?.cancel();
    _msg.dispose();
    _scroll.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    setState(() => _muted = next); // optimistic; stream will confirm
    await FwbService.setGroupMuted(widget.groupId, next);
    if (mounted) {
      showToast(
        context: context,
        message: next
            ? 'Muted — you won\'t be notified about this chat.'
            : 'Unmuted — notifications are back on.',
        type: ToastificationType.success,
      );
    }
  }

  Future<void> _play(String url) async {
    if (_playingUrl == url) {
      await _player.pause();
      if (mounted) setState(() => _playingUrl = null);
      return;
    }
    setState(() => _playingUrl = url);
    try {
      await AudioRoute.toSpeakerUnlessHeadphones();
      await _player.setUrl(url);
      await _player.play();
      _player.playerStateStream.firstWhere(
        (s) => s.processingState == ProcessingState.completed,
      ).then((_) {
        if (mounted && _playingUrl == url) setState(() => _playingUrl = null);
      });
    } catch (_) {
      if (mounted) setState(() => _playingUrl = null);
    }
  }

  Future<void> _sendText() async {
    final t = _msg.text.trim();
    if (t.isEmpty) return;
    _msg.clear();
    await FwbService.sendText(widget.groupId, t);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FwbGroup?>(
      stream: FwbService.groupStream(widget.groupId),
      builder: (context, snap) {
        final group = snap.data;
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (group == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('This group no longer exists.')),
          );
        }
        final isCreator = group.isCreator(_me);
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        group.name,
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_muted)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.notifications_off, size: 16),
                      ),
                  ],
                ),
                if (group.anonymous)
                  const Text(
                    'Anonymous',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Members',
                icon: const Icon(Icons.people_alt_outlined),
                onPressed: () => _showMembers(context, group),
              ),
              PopupMenuButton<String>(
                onSelected: (v) => _onMenu(v, group),
                itemBuilder:
                    (_) => [
                      PopupMenuItem(
                        value: 'mute',
                        child: Row(
                          children: [
                            Icon(
                              _muted
                                  ? Icons.notifications_active_outlined
                                  : Icons.notifications_off_outlined,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(_muted ? 'Unmute chat' : 'Mute chat'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'invite',
                        child: Text('Invite buddies'),
                      ),
                      const PopupMenuItem(
                        value: 'leave',
                        child: Text('Leave group'),
                      ),
                      if (isCreator)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete group',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<FwbMessage>>(
                  stream: FwbService.messages(widget.groupId),
                  builder: (context, ms) {
                    final msgs = ms.data ?? const [];
                    if (msgs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No farts yet. Share one to get things going.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scroll.hasClients) {
                        _scroll.jumpTo(_scroll.position.maxScrollExtent);
                      }
                    });
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: msgs.length,
                      itemBuilder:
                          (context, i) => _bubble(msgs[i], group.anonymous),
                    );
                  },
                ),
              ),
              _inputBar(group),
            ],
          ),
        );
      },
    );
  }

  Widget _bubble(FwbMessage m, bool anonymous) {
    if (m.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Text(
            m.text ?? '',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      );
    }
    final isMe = m.senderUid == _me;
    final label =
        isMe
            ? 'You'
            : anonymous
            ? 'Anonymous'
            : null; // resolved via FutureBuilder below

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, right: 6, top: 6),
            child:
                label != null
                    ? Text(
                      label,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    )
                    : FutureBuilder<String>(
                      future: FwbService.displayName(m.senderUid),
                      builder:
                          (_, s) => Text(
                            s.data ?? '…',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                    ),
          ),
          Container(
            constraints: const BoxConstraints(maxWidth: 280),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color:
                  isMe
                      ? AppColors.primary.withOpacity(0.9)
                      : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child:
                m.isFart
                    ? _fartContent(m, isMe)
                    : Text(
                      m.text ?? '',
                      style: TextStyle(
                        color: isMe ? Colors.white : null,
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _fartContent(FwbMessage m, bool isMe) {
    final playing = _playingUrl == m.fileUrl;
    final fg = isMe ? Colors.white : AppColors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: m.fileUrl == null ? null : () => _play(m.fileUrl!),
          child: Icon(
            playing ? Icons.stop_circle : Icons.play_circle_fill,
            color: fg,
            size: 34,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            m.title?.isNotEmpty == true ? m.title! : 'Fart',
            style: TextStyle(
              color: isMe ? Colors.white : null,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _inputBar(FwbGroup group) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Share a fart',
              icon: const Icon(
                Icons.library_music_rounded,
                color: AppColors.primary,
              ),
              onPressed: () => _showFartPicker(context),
            ),
            Expanded(
              child: TextField(
                controller: _msg,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendText(),
                decoration: InputDecoration(
                  hintText: 'Message',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: AppColors.primary),
              onPressed: _sendText,
            ),
          ],
        ),
      ),
    );
  }

  void _showMembers(BuildContext context, FwbGroup group) {
    showModalBottomSheet<void>(
      context: context,
      builder:
          (_) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Members',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                ...group.members.map(
                  (uid) => FutureBuilder<String>(
                    future: FwbService.displayName(uid),
                    builder:
                        (_, s) => ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(s.data ?? '…'),
                          subtitle: uid == group.creatorUid
                              ? const Text('Creator')
                              : null,
                          trailing:
                              uid == _me ? null : const Icon(Icons.chevron_right),
                          onTap:
                              uid == _me
                                  ? null
                                  : () {
                                    Navigator.pop(context);
                                    context.pushNamed(
                                      AppRoute.userProfileScreen.name,
                                      extra: uid,
                                    );
                                  },
                        ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _showFartPicker(BuildContext context) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            builder:
                (_, controller) => FutureBuilder<List<Map<String, dynamic>>>(
                  future: FwbService.myLibrary(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final farts = snap.data!;
                    if (farts.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Your library is empty.'),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: controller,
                      itemCount: farts.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Share from your library',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }
                        final f = farts[i - 1];
                        final title = (f['title'] as String?)?.isNotEmpty == true
                            ? f['title'] as String
                            : 'Fart';
                        return ListTile(
                          leading: const Icon(
                            Icons.play_circle_fill,
                            color: AppColors.primary,
                          ),
                          title: Text(title),
                          onTap: () async {
                            Navigator.pop(context);
                            await FwbService.sendFart(
                              widget.groupId,
                              fileUrl: f['fileUrl'] ?? '',
                              title: title,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
          ),
    );
  }

  Future<void> _onMenu(String value, FwbGroup group) async {
    switch (value) {
      case 'mute':
        await _toggleMute();
        break;
      case 'invite':
        final me = await FwbService.displayName(_me);
        await SharePlus.instance.share(
          ShareParams(
            text:
                "Join $me's ${group.name} group on Farts with Buddies!\n"
                '${FwbService.linkFor(group.id)}',
          ),
        );
        break;
      case 'leave':
        final ok = await _confirm(
          'Leave group',
          'You can rejoin later with an invite link.',
          'Leave',
        );
        if (ok) {
          await FwbService.leaveGroup(group);
          if (mounted) context.pop();
        }
        break;
      case 'delete':
        final ok = await _confirm(
          'Delete group',
          'This deletes the group for everyone. This cannot be undone.',
          'Delete',
        );
        if (ok) {
          await FwbService.deleteGroup(group.id);
          if (mounted) {
            context.pop();
            showToast(
              context: context,
              message: 'Group deleted.',
              type: ToastificationType.success,
            );
          }
        }
        break;
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final r = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  action,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    return r ?? false;
  }
}
