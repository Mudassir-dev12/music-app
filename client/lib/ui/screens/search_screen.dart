import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/discovery_api.dart';
import '../../api/discovery_models.dart';
import '../../api/errors.dart';
import '../../api/models.dart';
import '../../data/user_data_providers.dart';
import '../../downloads/offline_mode.dart';
import '../../player/player_controller.dart';
import '../../theme/tokens.dart';
import '../voice/mic_button.dart';
import '../widgets/busy_banner.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/media_item_card.dart';
import '../widgets/pill_button.dart';
import '../widgets/shelf_section.dart';
import '../widgets/skeleton.dart';
import '../widgets/top_result_card.dart';
import '../widgets/track_more_menu.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  bool _isLoading = false;
  String? _errorMessage;
  int? _busyRetryAfter;

  String _selectedFilter = 'All';
  final List<String> _filters = const ['All', 'Songs', 'Albums', 'Artists', 'Playlists'];

  List<String> _suggestions = [];
  bool _showSuggestions = false;

  SearchGrouped? _groupedResults;
  List<MediaItem> _filteredResults = [];
  List<Track> _songResults = [];
  List<String> _recentSearches = [];

  static const String _kRecentSearchesKey = 'recent_searches_list';

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _recentSearches = prefs.getStringList(_kRecentSearchesKey) ?? [];
    });
  }

  Future<void> _saveRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final updated = [
      trimmed,
      ..._recentSearches.where((q) => q.toLowerCase() != trimmed.toLowerCase()),
    ].take(8).toList();
    await prefs.setStringList(_kRecentSearchesKey, updated);
    if (!mounted) return;
    setState(() {
      _recentSearches = updated;
    });
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRecentSearchesKey);
    if (!mounted) return;
    setState(() {
      _recentSearches = [];
    });
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _busyRetryAfter = null;
        _suggestions = [];
        _showSuggestions = false;
        _groupedResults = null;
        _filteredResults = [];
        _songResults = [];
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      try {
        final discoveryApi = ref.read(discoveryApiProvider);
        final listFuture = discoveryApi.getSuggestions(trimmed);
        final songFuture = discoveryApi.searchFilter(trimmed, 'songs');

        final list = await listFuture;
        final songs = await songFuture;

        if (mounted && _searchController.text.trim() == trimmed) {
          setState(() {
            _suggestions = list;
            _songResults = songs.results.map((m) => m.toTrack()).toList();
            _showSuggestions = true;
          });
        }
      } catch (_) {}
    });
  }

  void _onAppendSuggestion(String suggestion) {
    _searchController.text = suggestion;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    _onQueryChanged(suggestion);
  }

  void _onSubmitted(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _showSuggestions = false;
    });
    _saveRecentSearch(trimmed);
    _performSearch(trimmed, _selectedFilter);
  }

  void _onSelectSuggestion(String suggestion) {
    _searchController.text = suggestion;
    _searchFocusNode.unfocus();
    setState(() {
      _showSuggestions = false;
    });
    _saveRecentSearch(suggestion);
    _performSearch(suggestion, _selectedFilter);
  }

  void _onFilterChanged(String filter) {
    if (_selectedFilter == filter) return;
    setState(() {
      _selectedFilter = filter;
    });
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      _performSearch(query, filter);
    }
  }

  Future<void> _performSearch(String query, String filter) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _busyRetryAfter = null;
      _showSuggestions = false;
    });

    final discoveryApi = ref.read(discoveryApiProvider);

    try {
      if (filter == 'All') {
        final grouped = await discoveryApi.searchGrouped(query);
        if (!mounted) return;
        setState(() {
          _groupedResults = grouped;
          _isLoading = false;
        });
      } else if (filter == 'Songs') {
        final res = await discoveryApi.searchFilter(query, 'songs');
        if (!mounted) return;
        setState(() {
          _songResults = res.results.map((m) => m.toTrack()).toList();
          _isLoading = false;
        });
      } else {
        final filterKey = filter.toLowerCase();
        final res = await discoveryApi.searchFilter(query, filterKey);
        if (!mounted) return;
        setState(() {
          _filteredResults = res.results;
          _isLoading = false;
        });
      }
    } on UpstreamBusyError catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _busyRetryAfter = e.retryAfterSeconds;
      });
    } on RateLimitError catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _busyRetryAfter = e.retryAfterSeconds;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred while searching.';
      });
    }
  }

  void _cancelSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _isLoading = false;
      _errorMessage = null;
      _busyRetryAfter = null;
      _suggestions = [];
      _showSuggestions = false;
      _groupedResults = null;
      _filteredResults = [];
      _songResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final isOffline = ref.watch(isOfflineModeProvider);
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final playerState = ref.watch(playerControllerProvider);
    final currentVid = playerState.queue.currentTrack?.videoId;
    final isPlaying = playerState.isPlaying;
    final likedIds = ref.watch(likedIdsProvider).valueOrNull ?? const <String>{};

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // 1. Search Bar with Back button (Pic 4)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  MelodiaTokens.spacingSm,
                  MelodiaTokens.spacingSm,
                  MelodiaTokens.spacingLg,
                  MelodiaTokens.spacingSm,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: tokens.text,
                        size: 24,
                      ),
                      onPressed: () {
                        if (_searchFocusNode.hasFocus || _searchController.text.isNotEmpty) {
                          _cancelSearch();
                        } else if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/listen-now');
                        }
                      },
                    ),
                    const SizedBox(width: MelodiaTokens.spacingXs),
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: tokens.surface2,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded, color: tokens.textSecondary, size: 20),
                            const SizedBox(width: MelodiaTokens.spacingSm),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                style: MelodiaTokens.body.copyWith(color: tokens.text),
                                decoration: InputDecoration(
                                  hintText: 'Artists, songs, lyrics, and more',
                                  hintStyle: MelodiaTokens.body.copyWith(color: tokens.textTertiary),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: _onQueryChanged,
                                onSubmitted: _onSubmitted,
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  _onQueryChanged('');
                                },
                                child: Icon(Icons.cancel_rounded, color: tokens.textSecondary, size: 20),
                              )
                            else
                              const MicButton(iconSize: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (isOffline)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: "You're offline",
                  subtitle: 'Search requires an internet connection.',
                  action: PillButton(
                    label: 'Go to Downloads',
                    icon: Icons.download_done_rounded,
                    onTap: () => context.push('/downloaded'),
                  ),
                ),
              )
            else ...[
              // 2. Filter Pills (when query exists and not typing suggestions)
            if (hasQuery && !_showSuggestions)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MelodiaTokens.spacingLg,
                      vertical: MelodiaTokens.spacingXs,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: MelodiaTokens.spacingSm),
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isSelected = _selectedFilter == filter;
                      return GestureDetector(
                        onTap: () => _onFilterChanged(filter),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: MelodiaTokens.spacingMd,
                            vertical: MelodiaTokens.spacingXs,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? tokens.accent : tokens.surface2,
                            borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            filter,
                            style: MelodiaTokens.subhead.copyWith(
                              color: tokens.text,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // 3. Busy Banner
            if (_busyRetryAfter != null)
              SliverToBoxAdapter(
                child: BusyBanner(
                  retryAfterSeconds: _busyRetryAfter!,
                  onRetry: () {
                    final query = _searchController.text.trim();
                    if (query.isNotEmpty) _performSearch(query, _selectedFilter);
                  },
                ),
              ),

            // 4. Suggestions and real-time songs (Pic 4)
            if (_showSuggestions && (_suggestions.isNotEmpty || _songResults.isNotEmpty)) ...[
              if (_suggestions.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final suggestion = _suggestions[index];
                      final isRecent = _recentSearches
                          .any((r) => r.toLowerCase() == suggestion.toLowerCase());
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isRecent ? Icons.history_rounded : Icons.search_rounded,
                          color: tokens.textSecondary,
                          size: 20,
                        ),
                        title: Text(
                          suggestion,
                          style: MelodiaTokens.body.copyWith(color: tokens.text),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.north_west_rounded,
                            color: tokens.textTertiary,
                            size: 18,
                          ),
                          onPressed: () => _onAppendSuggestion(suggestion),
                        ),
                        onTap: () => _onSelectSuggestion(suggestion),
                      );
                    },
                    childCount: _suggestions.length > 5 ? 5 : _suggestions.length,
                  ),
                ),
              if (_songResults.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = _songResults[index];
                      return _buildSongResultRow(
                        context,
                        track,
                        index,
                        tokens,
                        currentVid,
                        isPlaying,
                        likedIds,
                        _songResults,
                      );
                    },
                    childCount: _songResults.length,
                  ),
                ),
            ]

            // 5. Loading State
            else if (_isLoading)
              const SliverFillRemaining(
                child: SkeletonTrackList(count: 6),
              )

            // 6. Error State
            else if (_errorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(
                  message: _errorMessage!,
                  onRetry: () => _performSearch(_searchController.text.trim(), _selectedFilter),
                ),
              )

            // 7. No Query -> Recent Searches
            else if (!hasQuery)
              _buildRecentSearches(tokens)

            // 8. Submitted Search Results
            else
              ..._buildResultsSlivers(tokens, currentVid, isPlaying, likedIds),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSearches(MelodiaTokens tokens) {
    if (_recentSearches.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.search_rounded,
          title: 'Search Melodia',
          subtitle: 'Find your favourite songs, artists, albums and playlists.',
        ),
      );
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MelodiaTokens.spacingLg,
            vertical: MelodiaTokens.spacingMd,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: MelodiaTokens.headline.copyWith(color: tokens.text),
              ),
              GestureDetector(
                onTap: _clearRecentSearches,
                child: Text(
                  'Clear',
                  style: MelodiaTokens.subhead.copyWith(color: tokens.accent),
                ),
              ),
            ],
          ),
        ),
        ..._recentSearches.map((query) => ListTile(
              leading: Icon(Icons.history_rounded, color: tokens.textSecondary),
              title: Text(
                query,
                style: MelodiaTokens.body.copyWith(color: tokens.text),
              ),
              onTap: () {
                _searchController.text = query;
                _searchFocusNode.unfocus();
                _performSearch(query, _selectedFilter);
              },
            )),
      ]),
    );
  }

  List<Widget> _buildResultsSlivers(
    MelodiaTokens tokens,
    String? currentVid,
    bool isPlaying,
    Set<String> likedIds,
  ) {
    // A. "All" Filter -> Grouped results
    if (_selectedFilter == 'All') {
      if (_groupedResults == null ||
          (_groupedResults!.topResult == null && _groupedResults!.sections.isEmpty)) {
        return [
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.music_off_rounded,
              title: 'No Results Found',
              subtitle: 'Try searching for something else.',
            ),
          )
        ];
      }

      final widgets = <Widget>[];

      // Top result card
      if (_groupedResults!.topResult != null) {
        widgets.add(TopResultCard(item: _groupedResults!.topResult!));
        widgets.add(const SizedBox(height: MelodiaTokens.spacingMd));
      }

      // Grouped shelves
      for (final section in _groupedResults!.sections) {
        widgets.add(
          ShelfSection(
            shelf: section,
            onSeeAll: () {
              // Switch to corresponding filter
              final title = section.title.toLowerCase();
              if (title.contains('song')) {
                _onFilterChanged('Songs');
              } else if (title.contains('album')) {
                _onFilterChanged('Albums');
              } else if (title.contains('artist')) {
                _onFilterChanged('Artists');
              } else if (title.contains('playlist')) {
                _onFilterChanged('Playlists');
              }
            },
          ),
        );
      }

      return [SliverList(delegate: SliverChildListDelegate(widgets))];
    }

    // B. "Songs" Filter
    if (_selectedFilter == 'Songs') {
      if (_songResults.isEmpty) {
        return [
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.music_off_rounded,
              title: 'No Songs Found',
              subtitle: 'Try searching for a different song.',
            ),
          )
        ];
      }

      return [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final track = _songResults[index];
              return _buildSongResultRow(
                context,
                track,
                index,
                tokens,
                currentVid,
                isPlaying,
                likedIds,
                _songResults,
              );
            },
            childCount: _songResults.length,
          ),
        )
      ];
    }

    // C. "Albums", "Artists", "Playlists"
    if (_filteredResults.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.music_off_rounded,
            title: 'No $_selectedFilter Found',
            subtitle: 'Try searching for something else.',
          ),
        )
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(
          horizontal: MelodiaTokens.spacingLg,
          vertical: MelodiaTokens.spacingMd,
        ),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: MelodiaTokens.spacingLg,
            crossAxisSpacing: MelodiaTokens.spacingLg,
            childAspectRatio: 0.72,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = _filteredResults[index];
              return MediaItemCard(item: item, width: 170);
            },
            childCount: _filteredResults.length,
          ),
        ),
      )
    ];
  }

  Widget _buildSongResultRow(
    BuildContext context,
    Track track,
    int index,
    MelodiaTokens tokens,
    String? currentVid,
    bool isPlaying,
    Set<String> likedIds,
    List<Track> queue,
  ) {
    final isCurrent = track.videoId == currentVid;
    final isLiked = likedIds.contains(track.videoId);

    return Material(
      color: tokens.transparent,
      child: InkWell(
        onTap: () {
          ref.read(playerControllerProvider.notifier).playQueue(
                queue,
                initialIndex: index,
              );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MelodiaTokens.spacingLg,
            vertical: MelodiaTokens.spacingSm,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(MelodiaTokens.radiusArtworkSm),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: track.thumbnail != null && track.thumbnail!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: track.thumbnail!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: tokens.surface2),
                          errorWidget: (_, __, ___) => Container(
                            color: tokens.surface2,
                            child: Icon(Icons.music_note_rounded, color: tokens.textTertiary, size: 24),
                          ),
                        )
                      : Container(
                          color: tokens.surface2,
                          child: Icon(Icons.music_note_rounded, color: tokens.textTertiary, size: 24),
                        ),
                ),
              ),
              const SizedBox(width: MelodiaTokens.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isCurrent && isPlaying) ...[
                          Icon(Icons.equalizer_rounded, color: tokens.statusOnline, size: 18),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MelodiaTokens.body.copyWith(
                              color: (isCurrent && isPlaying) ? tokens.statusOnline : tokens.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Song • ${track.artist}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MelodiaTokens.footnote.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: tokens.textSecondary,
                  size: 20,
                ),
                onPressed: () => showTrackMoreMenu(
                  context: context,
                  ref: ref,
                  track: track,
                ),
              ),
              IconButton(
                icon: Icon(
                  isLiked ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                  color: isLiked ? tokens.statusOnline : tokens.textSecondary,
                  size: 22,
                ),
                onPressed: () {
                  ref.read(likedIdsProvider.notifier).toggleLike(track.videoId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
