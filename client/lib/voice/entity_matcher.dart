import '../api/models.dart';

class MatchedEntity<T> {
  const MatchedEntity({
    required this.item,
    required this.score,
    required this.name,
  });

  final T item;
  final double score; // 0.0 to 1.0
  final String name;
}

class EntityMatcher {
  const EntityMatcher._();

  /// Matches a user query against a list of playlists.
  /// Returns sorted list of matches above [threshold].
  static List<MatchedEntity<Playlist>> matchPlaylist(
    String query,
    List<Playlist> playlists, {
    double threshold = 0.5,
  }) {
    final cleanQ = query.trim().toLowerCase();
    if (cleanQ.isEmpty || playlists.isEmpty) return const [];

    final results = <MatchedEntity<Playlist>>[];

    for (final pl in playlists) {
      final nameLower = pl.name.trim().toLowerCase();

      // 1. Exact match
      if (nameLower == cleanQ) {
        results.add(MatchedEntity(item: pl, score: 1.0, name: pl.name));
        continue;
      }

      // 2. Starts with / Ends with
      if (nameLower.startsWith(cleanQ) || nameLower.endsWith(cleanQ)) {
        final score = 0.85 + (cleanQ.length / (nameLower.length * 2));
        results.add(MatchedEntity(item: pl, score: score.clamp(0.0, 0.95), name: pl.name));
        continue;
      }

      // 3. Substring
      if (nameLower.contains(cleanQ)) {
        final score = 0.7 + (cleanQ.length / (nameLower.length * 2));
        results.add(MatchedEntity(item: pl, score: score.clamp(0.0, 0.9), name: pl.name));
        continue;
      }

      // 4. Token overlap
      final qTokens = cleanQ.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();
      final pTokens = nameLower.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();
      final intersection = qTokens.intersection(pTokens);

      if (intersection.isNotEmpty) {
        final jaccard = intersection.length / qTokens.union(pTokens).length;
        if (jaccard >= threshold) {
          results.add(MatchedEntity(item: pl, score: jaccard, name: pl.name));
        }
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  /// Evaluates whether top 2 search results require disambiguation.
  /// If the top 2 candidates have very close scores and user said a short phrase, returns true.
  static bool requiresDisambiguation<T>({
    required List<MatchedEntity<T>> candidates,
    double differenceThreshold = 0.1,
  }) {
    if (candidates.length < 2) return false;
    final first = candidates[0];
    final second = candidates[1];
    return (first.score - second.score).abs() <= differenceThreshold &&
        first.score >= 0.7;
  }
}
