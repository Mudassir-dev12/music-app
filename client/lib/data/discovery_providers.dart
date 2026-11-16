import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/discovery_api.dart';
import '../api/discovery_models.dart';
import '../api/models.dart';

/// Suggestions for the given search query.
final searchSuggestionsProvider =
    FutureProvider.family<List<String>, String>((ref, query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return const [];
  return ref.watch(discoveryApiProvider).getSuggestions(trimmed);
});

/// Grouped search results (no filter)
final searchGroupedProvider =
    FutureProvider.family<SearchGrouped, String>((ref, query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return const SearchGrouped(query: '', sections: []);
  }
  return ref.watch(discoveryApiProvider).searchGrouped(trimmed);
});

/// Filtered search results
final searchFilterProvider =
    FutureProvider.family<SearchFilter, ({String query, String filter})>(
        (ref, arg) async {
  final trimmed = arg.query.trim();
  if (trimmed.isEmpty) {
    return SearchFilter(query: '', filter: arg.filter, results: const []);
  }
  return ref.watch(discoveryApiProvider).searchFilter(trimmed, arg.filter);
});

/// Listen Now / Home feed shelves
final homeFeedProvider = FutureProvider<List<Shelf>>((ref) async {
  return ref.watch(discoveryApiProvider).getHome();
});

/// Charts shelves
final chartsProvider =
    FutureProvider.family<List<Shelf>, String?>((ref, country) async {
  return ref.watch(discoveryApiProvider).getCharts(country);
});

/// Browse moods & genres categories
final moodsProvider = FutureProvider<MoodsResponse>((ref) async {
  return ref.watch(discoveryApiProvider).getMoods();
});

/// Playlists for a specific mood/genre
final moodPlaylistsProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, params) async {
  return ref.watch(discoveryApiProvider).getMoodPlaylists(params);
});

/// Album detail & track list
final albumDetailProvider =
    FutureProvider.family<AlbumDetail, String>((ref, browseId) async {
  return ref.watch(discoveryApiProvider).getAlbum(browseId);
});

/// Artist detail, top songs, albums, related
final artistDetailProvider =
    FutureProvider.family<ArtistDetail, String>((ref, channelId) async {
  return ref.watch(discoveryApiProvider).getArtist(channelId);
});

/// Public YouTube playlist detail & tracks
final ytPlaylistDetailProvider =
    FutureProvider.family<YtPlaylistDetail, String>((ref, playlistId) async {
  return ref.watch(discoveryApiProvider).getYtPlaylist(playlistId);
});

/// Radio queue for a seed videoId
final watchRadioProvider =
    FutureProvider.family<List<Track>, String>((ref, videoId) async {
  return ref.watch(discoveryApiProvider).getWatchRadio(videoId);
});

/// Lyrics for a track
final lyricsProvider =
    FutureProvider.family<Lyrics?, String>((ref, videoId) async {
  return ref.watch(discoveryApiProvider).getLyrics(videoId);
});
