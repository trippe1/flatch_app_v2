import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flatch/blocs/fetch_farts/fetch_farts_bloc.dart';
import 'package:flatch/common/models/fart_model.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/audio_cache_service.dart';
import 'package:flatch/common/services/audio_route.dart';
import 'package:flatch/common/services/share_service.dart';
import 'package:flatch/common/services/sound_library_services.dart';
import 'package:flatch/common/widgets/fart_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

/// Real-time Top Ten: the 10 public farts with the most upvotes, updated live
/// as votes change (a Firestore snapshot listener on the same isPublic+upvotes
/// query the "Popular" sort uses, so no new index is needed).
class TopTenList extends StatefulWidget {
  const TopTenList({super.key});

  @override
  State<TopTenList> createState() => _TopTenListState();
}

class _TopTenListState extends State<TopTenList> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String? _playingUrl;
  List<FartModel> _farts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _playerSub = _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && mounted) {
        setState(() => _playingUrl = null);
      }
    });
    _sub = FirebaseFirestore.instance
        .collection('user_farts')
        .where('isPublic', isEqualTo: true)
        .orderBy('upvotes', descending: true)
        .limit(10)
        .snapshots()
        .listen(_onSnapshot);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _playerSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final enriched = await Future.wait(
      snap.docs.map((d) async {
        final data = d.data();
        String? name;
        final authorUid = data['uid'];
        if (authorUid != null) {
          try {
            final u =
                await FirebaseFirestore.instance
                    .collection('app_users')
                    .doc(authorUid)
                    .get();
            name = u.data()?['name'];
          } catch (_) {}
        }
        String? vote;
        if (uid != null) {
          try {
            final v =
                await FirebaseFirestore.instance
                    .collection('user_farts')
                    .doc(d.id)
                    .collection('votes')
                    .doc(uid)
                    .get();
            vote = v.data()?['type'] as String?;
          } catch (_) {}
        }
        return FartModel.fromMap(
          data,
          userVote: vote,
        ).copyWith(id: d.id, userName: name);
      }),
    );
    if (mounted) {
      setState(() {
        _farts = enriched;
        _loading = false;
      });
    }
  }

  Future<void> _handlePlayPause(String url) async {
    if (!mounted) return;
    if (_playingUrl == url) {
      await _player.pause();
      if (mounted) setState(() => _playingUrl = null);
      return;
    }
    setState(() => _playingUrl = url);
    HapticFeedback.mediumImpact();
    try {
      await AudioRoute.toSpeakerUnlessHeadphones();
      final local = await getOrDownloadFart(url);
      await _player.setFilePath(local);
      await _player.play();
    } catch (_) {
      if (mounted) setState(() => _playingUrl = null);
    }
  }

  void _vote(FartModel fart, String type) {
    // Toggle off if re-tapping the same vote. The snapshot listener reflects the
    // new counts and re-ranks the board shortly after.
    final voteType = fart.userVote == type ? 'remove' : type;
    context.read<FetchFartsBloc>().add(
      VoteFart(fartId: fart.id, voteType: voteType),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_farts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No ranked farts yet. Upvote some to build the board.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
      itemCount: _farts.length,
      itemBuilder: (context, i) {
        final fart = _farts[i];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '${i + 1}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: FartCard(
                uid: fart.uid,
                title: fart.title,
                fileUrl: fart.fileUrl,
                duration: fart.duration,
                upvotes: fart.upvotes,
                downvotes: fart.downvotes,
                userVote: fart.userVote ?? '',
                commentCount: fart.commentCount,
                username: fart.userName,
                isPlaying: _playingUrl == fart.fileUrl,
                onPlayPause: () => _handlePlayPause(fart.fileUrl),
                onUpvote: () => _vote(fart, 'upvote'),
                onDownvote: () => _vote(fart, 'downvote'),
                onCommentsTap:
                    () => context.pushNamed(
                      AppRoute.commentFart.name,
                      extra: fart,
                    ),
                onFartTab:
                    () => context.pushNamed(
                      AppRoute.commentFart.name,
                      extra: fart,
                    ),
                onShare: () async {
                  await ShareService.instance.shareFart(
                    fartId: fart.id,
                    title: 'For your review.',
                  );
                },
                onDownload:
                    () => SoundLibraryService.saveToLibrary(
                      context: context,
                      fart: fart,
                      source: 'community',
                    ),
              ),
            ),
          ],
        );
      },
    );
  }
}
