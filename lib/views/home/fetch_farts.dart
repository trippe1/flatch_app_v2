import 'dart:async';

import 'package:flatch/blocs/fetch_farts/fetch_farts_bloc.dart';
import 'package:flatch/common/enums/fart_filters.dart';
import 'package:flatch/common/logics/sorting_logics.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/audio_cache_service.dart';
import 'package:flatch/common/services/email_verification_gate.dart';
import 'package:flatch/common/services/share_service.dart';
import 'package:flatch/common/services/sound_library_services.dart';
import 'package:flatch/cubits/fetch_farts/fetch_farts_cubit.dart';
import 'package:flatch/common/extensions/media_query_extension.dart';
import 'package:flatch/common/models/fart_model.dart';
import 'package:flatch/common/widgets/fart_card.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/services/age_gate_service.dart';
import 'package:flatch/views/home/stock_sounds_screen.dart';
import 'package:flatch/views/home/top_ten_list.dart';
import 'package:flatch/views/profile/my_uploads.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flatch/common/services/audio_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<PlayerState>? _playerSub;
  String? _currentlyPlayingUrl;
  FartFilter _currentFilter = FartFilter.popular;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  // Guards against re-dispatching FetchMoreFarts for a page already requested
  // (the scroll listener fires many times near the bottom).
  String? _lastRequestedDocId;

  // Stock Farts is the default, guest-accessible category. It stays selected
  // until the user opens a community category.
  bool _showStock = true;
  // Community "Top Ten" tab (real-time upvote leaderboard).
  bool _showTopTen = false;
  // "My Fart Library" tab, pinned at the far right (signed-in users only).
  bool _showMyLibrary = false;
  // The single "Community Farts" feed (all public farts).
  bool _showCommunity = false;


  @override
  void initState() {
    super.initState();

    // Community farts load lazily — only when the user opens a community
    // category (see _onCommunityTap). Guests default to Stock Farts and never
    // hit the (auth-required) feed query.
    _playerSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() => _currentlyPlayingUrl = null);
        }
      }
    });

    // Infinite scroll: load the next page as the user nears the bottom.
    _scrollController.addListener(() {
      if (_scrollController.position.pixels <
          _scrollController.position.maxScrollExtent - 300) {
        return;
      }
      final bloc = context.read<FetchFartsBloc>();
      final state = bloc.state;
      if (state is FetchFartsSuccess &&
          state.hasMore &&
          state.lastDoc != null &&
          state.lastDoc!.id != _lastRequestedDocId) {
        _lastRequestedDocId = state.lastDoc!.id;
        bloc.add(FetchMoreFarts(state.lastDoc!));
      }
    });
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _player.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
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
      // The trigger is the product's soul — give it a physical beat.
      HapticFeedback.mediumImpact();
      try {
        await AudioRoute.toSpeakerUnlessHeadphones();
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
  ) async {
    // Votes drive the community ranking, so they need a verified account.
    if (!await EmailVerificationGate.ensureVerified(context, action: 'vote')) {
      return;
    }
    if (!context.mounted) return;

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
      if (!mounted) return;
      setState(() {
        _currentFilter = selected;
        // New query ordering → let pagination start fresh.
        _lastRequestedDocId = null;
      });
      // Re-run the query with the chosen sort so we page the globally-correct
      // set from Firestore, not just re-sort the current page client-side.
      context.read<FetchFartsCubit>().clearFarts();
      context.read<FetchFartsBloc>().add(
        FetchTopFarts(searchQuery: _searchQuery, filter: selected),
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
              content: RadioGroup<String>(
                groupValue: selectedReason,
                onChanged: (val) => setState(() => selectedReason = val),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Why are you reporting this sound?'),
                    const SizedBox(height: 12),
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
        // Taller bar so the enlarged wordmark isn't clipped by the default
        // toolbar height.
        toolbarHeight: height * 0.13,
        title: Image.asset(
          'assets/images/flatch_logo.png',
          height: height * 0.12,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        initialData: FirebaseAuth.instance.currentUser,
        builder: (context, snap) {
          if (snap.data == null) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            heroTag: 'fwbFab',
            backgroundColor: AppColors.primary,
            onPressed: () => context.pushNamed(AppRoute.fwbHome.name),
            icon: const Icon(Icons.groups_rounded, color: Colors.white),
            label: const Text('FWB', style: TextStyle(color: Colors.white)),
          );
        },
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
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          initialData: FirebaseAuth.instance.currentUser,
          builder: (context, snap) {
            final bool signedIn = snap.data != null;
            // Guests are pinned to Stock Farts; community farts stay hidden
            // behind the gate until an account (with age verification) exists.
            final bool showStock = _showStock || !signedIn;
            return Column(
              children: [
                _buildCategoryBar(
                  context,
                  signedIn: signedIn,
                  showStock: showStock,
                ),
                if (showStock)
                  const Expanded(child: StockSoundsList())
                else if (_showTopTen)
                  const Expanded(child: TopTenList())
                else if (_showMyLibrary)
                  // Not `embedded` — this fills the tab, so it owns its own
                  // scroll view and infinite-scroll paging.
                  const Expanded(child: MyUploadsListView())
                else ...[
                  // Search across fart names, usernames and comment text.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search farts, people, comments',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon:
                            _searchQuery.isEmpty
                                ? null
                                : IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Spacer(),

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
                              AppLogics.instance.getFilterDisplayName(
                                _currentFilter,
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
                        if (state is FetchFartsLoading ||
                            state is FetchFartsInitial) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        } else if (state is FetchFartsFailure) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.wifi_off_rounded, size: 48),
                                const SizedBox(height: 12),
                                const Text("Couldn't load the feed"),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed:
                                      () => context.read<FetchFartsBloc>().add(
                                        FetchTopFarts(
                                          searchQuery: _searchQuery,
                                          filter: _currentFilter,
                                        ),
                                      ),
                                  child: const Text("Retry"),
                                ),
                              ],
                            ),
                          );
                        }

                        return BlocBuilder<
                          FetchFartsCubit,
                          FetchFartsCubitState
                        >(
                          builder: (context, cubitState) {
                            if (cubitState.farts.isEmpty) {
                              return const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.graphic_eq_rounded, size: 48),
                                    SizedBox(height: 12),
                                    Text("No submissions on record."),
                                    SizedBox(height: 4),
                                    Text(
                                      "The feed is empty. The record reflects this.",
                                    ),
                                  ],
                                ),
                              );
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
                              controller: _scrollController,
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

                                      title: 'For your review.',
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
                                  onPlayPause:
                                      () => _handlePlayPause(fart.fileUrl),
                                  onUpvote: () {
                                    _handleVoteChange(context, fart, 'upvote');
                                  },
                                  onDownvote: () {
                                    _handleVoteChange(
                                      context,
                                      fart,
                                      'downvote',
                                    );
                                  },
                                  onDownload:
                                      () => SoundLibraryService.saveToLibrary(
                                        context: context,
                                        fart: fart,
                                        source: 'community',
                                      ),

                                  onReport:
                                      () => _showReportDialog(context, fart),
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
              ],
            );
          },
        ),
      ),
    );
  }

  /// Top category bar: Stock Farts pinned at the far left; to its right the
  /// community category chips (signed-in) or the "create an account" gate
  /// (guests). Stock Farts never moves; the rest carousel horizontally.
  Widget _buildCategoryBar(
    BuildContext context, {
    required bool signedIn,
    required bool showStock,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String stockAsset =
        isDark
            ? 'assets/images/flatch_stock_darkmode_t.png'
            : 'assets/images/flatch_stock_lightmode_t.png';

    // Four chips, no scrolling. Every chip is Expanded so the Row hands out an
    // equal share and NOTHING can measure wider than that share — the previous
    // version let each label be `size + 8` wide, which overflowed the row and
    // pushed the last chip off the right edge.
    const double sideInset = 14;
    const double gap = 8;
    final double available =
        MediaQuery.of(context).size.width - (sideInset * 2) - (gap * 3);
    // Leave a little slack inside each share so the selected chip's glow, which
    // paints outside the tile, isn't clipped at the screen edges.
    final double tile = ((available / 4) - 4).clamp(48.0, 96.0);

    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
      required Widget image,
    }) => Expanded(
      child: _categoryChip(
        label: label,
        selected: selected,
        onTap: onTap,
        image: image,
        size: tile,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(sideInset, 12, sideInset, 4),
      child: SizedBox(
        height: tile + 46, // tile + two label lines + spacing
        child:
            signedIn
                ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    chip(
                      label: 'Stock Farts',
                      selected: showStock,
                      onTap:
                          () => setState(() {
                            _showStock = true;
                            _showTopTen = false;
                            _showMyLibrary = false;
                            _showCommunity = false;
                          }),
                      image: Image.asset(stockAsset, fit: BoxFit.contain),
                    ),
                    const SizedBox(width: gap),
                    chip(
                      label: 'Top Ten',
                      selected: _showTopTen,
                      onTap:
                          () => setState(() {
                            _showStock = false;
                            _showTopTen = true;
                            _showMyLibrary = false;
                            _showCommunity = false;
                          }),
                      image: _iconTile('assets/svgs/top_ten_cup.svg'),
                    ),
                    const SizedBox(width: gap),
                    chip(
                      label: 'Community Farts',
                      selected: _showCommunity && !showStock,
                      onTap: () => _onCommunityTap(context),
                      image: _iconTile(
                        isDark
                            ? 'assets/svgs/community_farts_flat.svg'
                            : 'assets/svgs/community_farts_flat_light.svg',
                      ),
                    ),
                    const SizedBox(width: gap),
                    chip(
                      label: 'My Fart Library',
                      selected: _showMyLibrary,
                      onTap:
                          () => setState(() {
                            _showStock = false;
                            _showTopTen = false;
                            _showCommunity = false;
                            _showMyLibrary = true;
                          }),
                      image: _iconTile(
                        isDark
                            ? 'assets/svgs/my_library_cauldron_flat.svg'
                            : 'assets/svgs/my_library_cauldron_flat_light.svg',
                      ),
                    ),
                  ],
                )
                : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _categoryChip(
                      label: 'Stock Farts',
                      selected: showStock,
                      size: tile,
                      onTap: () => setState(() => _showStock = true),
                      image: Image.asset(stockAsset, fit: BoxFit.contain),
                    ),
                    const SizedBox(width: gap),
                    Expanded(child: _guestGate(context, isDark: isDark)),
                  ],
                ),
      ),
    );
  }

  /// Chip artwork with NO background plate — the icons sit directly on the
  /// page. Light/dark variants exist because the cream figures and cauldron rim
  /// are invisible on a light background once the dark plate is removed.
  Widget _iconTile(String asset) => Padding(
    padding: const EdgeInsets.all(4),
    child: SvgPicture.asset(asset, fit: BoxFit.contain),
  );

  /// Opens the single "Community Farts" feed — every public fart, ranked by the
  /// Reddit-style hot score by default.
  void _onCommunityTap(BuildContext context) {
    if (_showCommunity) return; // already here
    setState(() {
      _showStock = false;
      _showTopTen = false;
      _showMyLibrary = false;
      _showCommunity = true;
    });
    context.read<FetchFartsCubit>().clearFarts();
    _lastRequestedDocId = null;
    context.read<FetchFartsBloc>().add(
      FetchTopFarts(searchQuery: _searchQuery, filter: _currentFilter),
    );
  }

  /// Re-runs the feed query as the user types (debounced).
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value.trim();
        _lastRequestedDocId = null;
      });
      context.read<FetchFartsCubit>().clearFarts();
      context.read<FetchFartsBloc>().add(
        FetchTopFarts(searchQuery: _searchQuery, filter: _currentFilter),
      );
    });
  }

  /// Guest gate: the holding-cell chip + an arrow pointing back at it with the
  /// "create an account" caption. Tapping opens the age-gate / sign-up flow.
  /// Age-blocked devices see a neutral, CTA-free message.
  Widget _guestGate(BuildContext context, {required bool isDark}) {
    final bool blocked = AgeGateService.instance.isBlockedCached;
    final String cellAsset =
        isDark
            ? 'assets/svgs/flatch_holding_cell_dark.svg'
            : 'assets/svgs/flatch_holding_cell_light.svg';

    final cellChip = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.primary.withOpacity(0.06),
          ),
          child: SvgPicture.asset(cellAsset),
        ),
        const SizedBox(height: 8),
        const SizedBox(
          width: 96,
          child: Text(
            'Community',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );

    return GestureDetector(
      onTap: blocked ? null : () => context.pushNamed(AppRoute.ageGate.name),
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cellChip,
            const SizedBox(width: 10),
            SizedBox(
              width: 180,
              height: 96,
              child: Row(
                children: [
                  const Icon(Icons.arrow_back_rounded, size: 22),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      blocked
                          ? "Community farts aren't available on this device."
                          : 'Create an account to access community farts',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Widget image,
    double size = 96,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              // A thicker ring plus an outer glow — the old 3px border was easy
              // to miss against the dark artwork.
              border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: selected ? 4 : 0,
              ),
              boxShadow:
                  selected
                      ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.55),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                      : null,
            ),
            child: ClipRRect(
              // Inset so the artwork doesn't bleed over the ring.
              borderRadius: BorderRadius.circular(selected ? 12 : 16),
              child: image,
            ),
          ),
          const SizedBox(height: 6),
          // No fixed width: the label wraps inside whatever the parent Expanded
          // allots. A `size + 8` box here is what made each chip wider than its
          // tile and overflowed the row.
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: size < 72 ? 10.5 : 12,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
