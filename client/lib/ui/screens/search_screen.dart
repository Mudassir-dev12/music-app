import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/errors.dart';
import '../../api/models.dart';
import '../../api/music_api.dart';
import '../../player/player_controller.dart';
import '../../theme/tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/skeleton.dart';
import '../widgets/track_row.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _isLoading = false;
  String? _errorMessage;
  List<Track> _results = [];
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
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
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
    setState(() {
      _recentSearches = updated;
    });
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRecentSearchesKey);
    setState(() {
      _recentSearches = [];
    });
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _results = [];
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final musicApi = ref.read(musicApiProvider);
      final response = await musicApi.search(query, filter: 'songs', limit: 25);
      await _saveRecentSearch(query);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _results = response.results;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e is ApiError ? e.message : e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final playerState = ref.watch(playerControllerProvider);
    final currentVideoId = playerState.queue.currentTrack?.videoId;

    return ScreenScaffold(
      title: 'Search',
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MelodiaTokens.spacingLg,
              vertical: MelodiaTokens.spacingSm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: tokens.surface2,
                      borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: MelodiaTokens.spacingMd,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: tokens.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: MelodiaTokens.spacingSm),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onQueryChanged,
                            onSubmitted: (q) => _performSearch(q.trim()),
                            style: MelodiaTokens.body.copyWith(color: tokens.text),
                            decoration: InputDecoration(
                              hintText: 'Artists, Songs, Lyrics, and More',
                              hintStyle: MelodiaTokens.body.copyWith(
                                color: tokens.textTertiary,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _onQueryChanged('');
                            },
                            child: Icon(
                              Icons.cancel_rounded,
                              color: tokens.textSecondary,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty) ...[
                  const SizedBox(width: MelodiaTokens.spacingSm),
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      _onQueryChanged('');
                      FocusScope.of(context).unfocus();
                    },
                    child: Text(
                      'Cancel',
                      style: MelodiaTokens.body.copyWith(color: tokens.accent),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Body content
        if (_isLoading)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, __) => const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MelodiaTokens.spacingLg,
                  vertical: MelodiaTokens.spacingSm,
                ),
                child: Row(
                  children: [
                    SkeletonBox(
                      width: 48,
                      height: 48,
                      borderRadius: BorderRadius.all(
                        Radius.circular(MelodiaTokens.radiusArtworkSm),
                      ),
                    ),
                    SizedBox(width: MelodiaTokens.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 180, height: 16),
                          SizedBox(height: MelodiaTokens.spacingXs),
                          SkeletonBox(width: 120, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              childCount: 8,
            ),
          )
        else if (_errorMessage != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorState(
              message: _errorMessage!,
              onRetry: () => _performSearch(_searchController.text),
            ),
          )
        else if (_searchController.text.isEmpty)
          if (_recentSearches.isNotEmpty)
            SliverList(
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
                          style: MelodiaTokens.subhead.copyWith(
                            color: tokens.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ..._recentSearches.map((query) => ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: MelodiaTokens.spacingLg,
                      ),
                      leading: Icon(
                        Icons.history_rounded,
                        color: tokens.textTertiary,
                        size: 20,
                      ),
                      title: Text(
                        query,
                        style: MelodiaTokens.body.copyWith(color: tokens.text),
                      ),
                      onTap: () {
                        _searchController.text = query;
                        _performSearch(query);
                      },
                    )),
              ]),
            )
          else
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.search_rounded,
                title: 'Search for Music',
                subtitle: 'Find your favorite songs, artists, and albums.',
              ),
            )
        else if (_results.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No Results Found',
              subtitle: 'Try searching with different keywords.',
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final track = _results[index];
                final isCurrent = track.videoId == currentVideoId;
                final isPlaying = isCurrent && playerState.isPlaying;

                return TrackRow(
                  track: track,
                  index: index,
                  isCurrentTrack: isCurrent,
                  isPlaying: isPlaying,
                  onTap: () {
                    ref.read(playerControllerProvider.notifier).playList(
                          _results,
                          index,
                        );
                  },
                  onPlayNext: (t) {
                    ref.read(playerControllerProvider.notifier).enqueueNext(t);
                  },
                  onAddToQueue: (t) {
                    ref.read(playerControllerProvider.notifier).enqueueLast(t);
                  },
                );
              },
              childCount: _results.length,
            ),
          ),
      ],
    );
  }
}
