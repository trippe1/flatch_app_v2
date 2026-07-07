// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flatch/blocs/admin_farts/admin_farts_bloc.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/enums/fart_filters.dart';
import 'package:flatch/common/logics/sorting_logics.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/audio_cache_service.dart';
import 'package:flatch/common/services/share_service.dart';
import 'package:flatch/common/services/sound_library_services.dart';
import 'package:flatch/common/services/toast_service.dart';
import 'package:flatch/common/widgets/category_scroller.dart';
import 'package:flatch/common/widgets/fart_card.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:flatch/cubits/fetch_farts/fetch_farts_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_audio_output/flutter_audio_output.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:toastification/toastification.dart';

class AdminFetchFarts extends StatefulWidget {
  const AdminFetchFarts({super.key});

  @override
  State<AdminFetchFarts> createState() => _AdminFetchFartsState();
}

class _AdminFetchFartsState extends State<AdminFetchFarts> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerSub;
  String? _currentlyPlayingUrl;
  FartFilter _currentFilter = FartFilter.sortBy;

  @override
  void initState() {
    super.initState();

    final selectedCategory =
        context.read<FetchFartsCubit>().state.selectedCategory;
    context.read<AdminFartsBloc>().add(
      FetchAdminFartsEvent(category: selectedCategory),
    );

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
      if (mounted) setState(() => _currentlyPlayingUrl = null);
    } else {
      if (mounted) setState(() => _currentlyPlayingUrl = url);
      try {
        await FlutterAudioOutput.changeToSpeaker();
        final localPath = await getOrDownloadFart(url);
        await _player.setFilePath(localPath);
        await _player.play();
      } catch (e) {
        debugPrint('Audio error: $e');
        if (mounted) setState(() => _currentlyPlayingUrl = null);
      }
    }
  }

  void _showFilterMenu(BuildContext context) async {
    final selected = await showMenu<FartFilter>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 0, 0),
      items: const [
        PopupMenuItem(value: FartFilter.all, child: Text("All")),
        PopupMenuItem(value: FartFilter.popular, child: Text("Popular")),
        PopupMenuItem(value: FartFilter.newest, child: Text("Newest")),
        PopupMenuItem(value: FartFilter.oldest, child: Text("Oldest")),
        PopupMenuItem(
          value: FartFilter.controversial,
          child: Text("Controversial"),
        ),
        PopupMenuItem(value: FartFilter.flagged, child: Text("Flagged")),
      ],
    );
    if (selected != null) {
      setState(() {
        _currentFilter = selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.goNamed(AppRoute.home.name);
        },
        label: const Text("Go to App"),
        icon: const Icon(Icons.dashboard_customize),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        elevation: 6,
        hoverElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      appBar: AppBar(
        toolbarHeight: 120,
        title: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 8),
                TextWidget(
                  text: 'Admin Panel',
                  size: 24,
                  color: AppColors.primary,
                  weight: FontWeight.bold,
                ),
              ],
            ),
            Gap(20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.dashboard),
                    label: const Text("Delete Sounds"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary),
                      foregroundColor: AppColors.primary,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      context.pushNamed(AppRoute.assignUserRole.name);
                    },
                    icon: const Icon(Icons.person),
                    label: const Text("Assign Roles"),
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          BlocBuilder<FetchFartsCubit, FetchFartsCubitState>(
            builder: (context, cubitState) {
              return TopFartScroller(
                selectedCategory: cubitState.selectedCategory,
                onCategorySelected: (category) {
                  final fartsCubit = context.read<FetchFartsCubit>();
                  final fartsBloc = context.read<AdminFartsBloc>();

                  fartsCubit.clearFarts();

                  if (cubitState.selectedCategory == category) {
                    fartsCubit.selectCategory('');
                    fartsBloc.add(const FetchAdminFartsEvent(category: null));
                  } else {
                    fartsCubit.selectCategory(category);
                    fartsBloc.add(FetchAdminFartsEvent(category: category));
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

          // Filter row
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: const Text(
                  'Top Farts Worldwide',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                child: Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Text(
                    AppLogics.instance.getFilterDisplayName(_currentFilter),
                  ),
                ),
              ),
              Gap(20),
            ],
          ),

          Expanded(
            child: BlocBuilder<AdminFartsBloc, AdminFartsState>(
              builder: (context, state) {
                if (state is AdminFartsLoading || state is AdminFartsInitial) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is AdminFartsError) {
                  return Center(child: Text("Error: ${state.message}"));
                } else if (state is AdminFartsLoaded) {
                  final hasMore = state.hasMore;

                  final farts =
                      state.farts
                         ;

                  final sortedFarts = AppLogics.instance.applyFilter(
                    farts,
                    _currentFilter,
                  );

                  if (sortedFarts.isEmpty) {
                    return const Center(child: Text("No farts found."));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 200),
                    itemCount: sortedFarts.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == sortedFarts.length && hasMore) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: ElevatedButton(
                              onPressed: () {
                                context.read<AdminFartsBloc>().add(
                                  FetchAdminFartsEvent(
                                    lastDoc: state.lastDoc,
                                    category:
                                        context
                                            .read<FetchFartsCubit>()
                                            .state
                                            .selectedCategory,
                                  ),
                                );
                              },
                              child: const Text("Load More"),
                            ),
                          ),
                        );
                      }


                      final fart = sortedFarts[index];
                      final isPlaying = _currentlyPlayingUrl == fart.fileUrl;

                      return FartCard(
                        uid: fart.uid,
                        commentCount: fart.commentCount,
                        onFartTab: () {
                          context.pushNamed(
                            AppRoute.commentFart.name,
                            extra: fart,
                            queryParameters: {'isAdmin': 'true'},
                          );
                        },
                        onShare: () async {
                          await ShareService.instance.shareFart(
                            fartId: fart.id,
                            title: 'Listen to this fart!',
                          );
                        },
                        reportCount: fart.reportCount,
                        onReport: () {},
                        onCommentsTap: () {
                          context.pushNamed(
                            AppRoute.commentFart.name,
                            extra: fart,
                             queryParameters: {'isAdmin': 'true'},
                          );
                        },
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
                                              borderRadius:
                                                  BorderRadius.circular(
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
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed:
                                              () => Navigator.of(
                                                context,
                                              ).pop(true),
                                          child: const Text(
                                            'Delete',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                          );

                          if (confirm == true) {
                            context.read<AdminFartsBloc>().add(
                              DeleteFartEvent(fartId: fart.id),
                            );
                            showToast(
                              context: context,
                              message: 'Fart deleted successfully',
                              type: ToastificationType.success,
                            );
                          }
                        },
                        onUserTap: () {
                          context.pushNamed(
                            AppRoute.userProfileScreen.name,
                            extra: fart.uid,
                             queryParameters: {'isAdmin': 'true'},
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

                       onDownload:
                            () => SoundLibraryService.saveToLibrary(
                              context: context,
                             fart: fart,
                              source: 'community',
                            ),

                      );
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}
