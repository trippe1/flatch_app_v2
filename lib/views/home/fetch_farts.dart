import 'dart:async';

import 'package:flatch/blocs/fetch_farts/fetch_farts_bloc.dart';
import 'package:flatch/common/enums/fart_filters.dart';
import 'package:flatch/common/logics/sorting_logics.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/audio_cache_service.dart';
import 'package:flatch/common/services/share_service.dart';
import 'package:flatch/common/services/sound_library_services.dart';
import 'package:flatch/cubits/fetch_farts/fetch_farts_cubit.dart';
import 'package:flatch/common/extensions/media_query_extension.dart';
import 'package:flatch/common/models/fart_model.dart';
import 'package:flatch/common/services/download_sound.dart';
import 'package:flatch/common/widgets/category_scroller.dart';
import 'package:flatch/common/widgets/fart_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_audio_output/flutter_audio_output.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

class FartsPage extends StatefulWidget {
  const FartsPage({super.key});

  @override
  State<FartsPage> createState() => _FartsPageState();
}

class _FartsPageState extends State<FartsPage> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerSub;
  String? _currentlyPlayingUrl;
  FartFilter _currentFilter = FartFilter.sortBy;

  @override
  void initState() {
    super.initState();

    final selectedCategory =
        context.read<FetchFartsCubit>().state.selectedCategory;
    if (selectedCategory != null) {
      context.read<FetchFartsBloc>().add(
        FetchTopFarts(category: selectedCategory),
      );
    } else {
      context.read<FetchFartsBloc>().add(FetchTopFarts());
    }
    _playerSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() => _currentlyPlayingUrl = null);
        }
      }
    });
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _player.dispose();
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
        await FlutterAudioOutput.changeToSpeaker();
        final localPath = await getOrDownloadFart(url);
        await _player.setFilePath(localPath);
        await _player.play();
      } catch (e) {
        debugPrint('Audio error: $e');
        if (mounted) {
          setState(() => _currentlyPlayingUrl = null);
        }
      }
    }
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

  void _showFilterMenu(BuildContext context) async {
    final selected = await showMenu<FartFilter>(
      context: context,
      position: const RelativeRect.fromLTRB(
        100,
        100,
        0,
        0,
      ), // dropdown position
      items: const [
        PopupMenuItem(value: FartFilter.all, child: Text("All")),
        PopupMenuItem(value: FartFilter.popular, child: Text("Popular")),
        PopupMenuItem(value: FartFilter.newest, child: Text("Newest")),
        PopupMenuItem(value: FartFilter.oldest, child: Text("Oldest")),
        PopupMenuItem(
          value: FartFilter.controversial,
          child: Text("Controversial"),
        ),
      ],
    );

    if (selected != null) {
      setState(() {
        _currentFilter = selected;
      });
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
                  RadioListTile<String>(
                    value: 'Inappropriate',
                    groupValue: selectedReason,
                    title: const Text('Inappropriate'),
                    onChanged: (val) => setState(() => selectedReason = val),
                  ),
                  RadioListTile<String>(
                    value: 'Offensive',
                    groupValue: selectedReason,
                    title: const Text('Offensive'),
                    onChanged: (val) => setState(() => selectedReason = val),
                  ),
                  RadioListTile<String>(
                    value: 'Spam',
                    groupValue: selectedReason,
                    title: const Text('Spam or misleading'),
                    onChanged: (val) => setState(() => selectedReason = val),
                  ),
                  RadioListTile<String>(
                    value: 'Other',
                    groupValue: selectedReason,
                    title: const Text('Other'),
                    onChanged: (val) => setState(() => selectedReason = val),
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

  @override
  Widget build(BuildContext context) {
    double height = context.screenHeight;
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/flatch_logo.png',
          height: height * 0.08,
          width: height * 0.08,
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<FetchFartsBloc, FetchFartsState>(
            listener: (context, state) {
              if (state is FetchFartsSuccess) {
                context.read<FetchFartsCubit>().setFarts(state.farts);
              }
            },
          ),
        ],
        child: Column(
          children: [
            BlocBuilder<FetchFartsCubit, FetchFartsCubitState>(
              builder: (context, cubitState) {
                return TopFartScroller(
                  selectedCategory: cubitState.selectedCategory,
                  onCategorySelected: (category) {
                    final fartsCubit = context.read<FetchFartsCubit>();
                    final fartsBloc = context.read<FetchFartsBloc>();

                    fartsCubit.clearFarts();

                    if (cubitState.selectedCategory == category) {
                      fartsCubit.selectCategory('');
                      fartsBloc.add(const FetchTopFarts(category: null));
                    } else {
                      fartsCubit.selectCategory(category);
                      fartsBloc.add(FetchTopFarts(category: category));
                    }
                  },

                  categories: [
                    TopFartCategory(
                      title: 'Wet',
                      imageAsset: 'assets/images/wet.png',
                    ),
                    TopFartCategory(
                      title: 'Sneaky',
                      imageAsset: 'assets/images/sneaky.png',
                    ),
                    TopFartCategory(
                      title: 'Loud',
                      imageAsset: 'assets/images/loud.png',
                    ),
                    TopFartCategory(
                      title: 'Quick',
                      imageAsset: 'assets/images/quick.png',
                    ),
                    TopFartCategory(
                      title: 'Long',
                      imageAsset: 'assets/images/long.png',
                    ),
                    TopFartCategory(
                      title: 'Other',
                      imageAsset: 'assets/images/loud.png',
                    ),
                  ],
                );
              },
            ),
            Row(
              children: [
                Align(
                  alignment: Alignment.bottomLeft,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      'Top Farts Worldwide',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Spacer(),

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
                        AppLogics.instance.getFilterDisplayName(_currentFilter),
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
                  if (state is FetchFartsLoading ||
                      state is FetchFartsInitial) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is FetchFartsFailure) {
                    return Center(child: Text("Error: ${state.error}"));
                  }

                  return BlocBuilder<FetchFartsCubit, FetchFartsCubitState>(
                    builder: (context, cubitState) {
                      if (cubitState.farts.isEmpty) {
                        return const Center(child: Text("No farts found."));
                      }
                      final visibleFarts = AppLogics.instance.applyFilter(
                        cubitState.farts,
                        _currentFilter,
                      );
                      final sortedFarts =
                          visibleFarts
                              .where((f) => f.userReported != true)
                              .toList();

                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: sortedFarts.length,
                        itemBuilder: (context, index) {
                          final fart = sortedFarts[index];

                          final isPlaying =
                              _currentlyPlayingUrl == fart.fileUrl;

                          return FartCard(
                            uid: fart.uid,
                            commentCount: fart.commentCount,
                            onFartTab: () {
                              context.pushNamed(
                                AppRoute.commentFart.name,
                                extra: fart,
                              );
                            },
                            onShare: () async {
                              await ShareService.instance.shareFart(
                                fartId: fart.id,

                                title: 'Listen to this fart!',
                              );
                            },

                            onCommentsTap: () {
                              context.pushNamed(
                                AppRoute.commentFart.name,
                                extra: fart,
                              );
                            },
                            onUserTap: () {
                              context.pushNamed(
                                AppRoute.userProfileScreen.name,
                                extra: fart.uid,
                              );
                            },
                            title: fart.title,
                            fileUrl: fart.fileUrl,
                            duration: fart.duration,
                            upvotes: fart.upvotes,
                            downvotes: fart.downvotes,
                            username: fart.userName,
                            userVote: fart.userVote ?? '',
                            isPlaying: isPlaying,
                            onPlayPause: () => _handlePlayPause(fart.fileUrl),
                            onUpvote: () {
                              _handleVoteChange(context, fart, 'upvote');
                            },
                            onDownvote: () {
                              _handleVoteChange(context, fart, 'downvote');
                            },
                           onDownload:
                                () => SoundLibraryService.saveToLibrary(
                                  context: context,
                                 fart: fart,
                                  source: 'community',
                                ),

                            onReport: () => _showReportDialog(context, fart),
                            alreadyReported: fart.userReported ?? false,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
