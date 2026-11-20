import 'phrase_tables.dart';
import 'text_normalizer.dart';
import 'voice_intent.dart';

enum ParserMode {
  /// Strict mode for hands-free listening in Ride Mode:
  /// Requires exact commands or wake word for catch-all searches,
  /// suppresses noise and one-word ambiguous inputs.
  strict,

  /// Normal mode for manual push-to-talk sessions or typed text.
  normal,
}

sealed class ParseResult {
  const ParseResult();
}

final class Matched extends ParseResult {
  const Matched(this.intent, this.confidence, {this.usedWakeWord = false});
  final VoiceIntent intent;
  final double confidence;
  final bool usedWakeWord;

  @override
  String toString() =>
      'Matched(intent: $intent, confidence: $confidence, usedWakeWord: $usedWakeWord)';
}

final class Ambiguous extends ParseResult {
  const Ambiguous(this.candidates);
  final List<VoiceIntent> candidates;

  @override
  String toString() => 'Ambiguous(candidates: $candidates)';
}

final class NoMatch extends ParseResult {
  const NoMatch(this.normalizedText);
  final String normalizedText;

  @override
  String toString() => 'NoMatch("$normalizedText")';
}

class IntentParser {
  const IntentParser._();

  static const Set<String> _noiseTokens = {
    'uh',
    'um',
    'mm',
    'hmm',
    'ha',
    'haha',
    'ah',
    'oh',
    'eh',
    'er',
    'shh',
  };

  static const Set<String> _allowedSingleWordCommands = {
    'play',
    'pause',
    'stop',
    'next',
    'previous',
    'restart',
    'louder',
    'mute',
    'unmute',
    'like',
    'unlike',
    'help',
    'cancel',
    'chalao',
    'ruko',
    'agla',
    'pichla',
    'madad',
    'chordo',
    'روکو',
    'چلاؤ',
    'سٹاپ',
    'اگلا',
    'پچھلا',
    'مدد',
  };

  /// Parses raw input into a [ParseResult].
  static ParseResult parse(
    String rawInput, {
    String language = 'auto',
    ParserMode mode = ParserMode.normal,
    bool allowSearchWithoutWakeWord = false,
  }) {
    final normResult = TextNormalizer.normalize(rawInput);
    final norm = normResult.normalized;
    final usedWakeWord = normResult.usedWakeWord;
    final originalClean = normResult.originalText;

    if (norm.isEmpty) {
      return const NoMatch('');
    }

    // 1. Noise suppression
    final tokens = norm.split(' ');
    final isAllNoise = tokens.every((t) => _noiseTokens.contains(t));
    if (isAllNoise) {
      return NoMatch(norm);
    }

    // In strict mode: reject single words that are not recognized commands
    if (mode == ParserMode.strict && tokens.length < 2) {
      if (!_allowedSingleWordCommands.contains(norm)) {
        return NoMatch(norm);
      }
    }

    // 2. Exact matches (English + Urdu)
    final exact = _matchExact(norm);
    if (exact != null) {
      return Matched(exact, 1.0, usedWakeWord: usedWakeWord);
    }

    // 3. Slot Patterns
    // A. Volume Set
    final volMatch = RegExp(r'^(?:set\s+)?volume\s+(?:to\s+)?(\d+)(?:\s*percent)?$').firstMatch(norm);
    if (volMatch != null) {
      final pct = int.tryParse(volMatch.group(1)!) ?? 50;
      return Matched(VolumeSet(pct.clamp(0, 100)), 0.95, usedWakeWord: usedWakeWord);
    }

    // B. Sleep Timer
    final sleepMatch = RegExp(r'^(?:stop|sleep|pause)\s+in\s+(\d+)\s+minutes?$').firstMatch(norm);
    if (sleepMatch != null) {
      final mins = int.tryParse(sleepMatch.group(1)!) ?? 15;
      return Matched(SleepTimer(mins.clamp(1, 360)), 0.95, usedWakeWord: usedWakeWord);
    }

    // C. Seek by seconds
    final forwardMatch = RegExp(r'^(?:forward|fast\s+forward|skip\s+forward)\s+(\d+)\s+seconds?$').firstMatch(norm);
    if (forwardMatch != null) {
      final sec = int.tryParse(forwardMatch.group(1)!) ?? 15;
      return Matched(SeekBy(sec), 0.95, usedWakeWord: usedWakeWord);
    }
    final backMatch = RegExp(r'^(?:back|rewind|skip\s+back(?:ward)?)\s+(\d+)\s+seconds?$').firstMatch(norm);
    if (backMatch != null) {
      final sec = int.tryParse(backMatch.group(1)!) ?? 15;
      return Matched(SeekBy(-sec), 0.95, usedWakeWord: usedWakeWord);
    }

    // D. Seek to absolute position
    final seekToTimeMatch = RegExp(r'^(?:go\s+to|seek\s+to)\s+(\d+)\s+minutes?(?:\s+(?:and\s+)?(\d+)(?:\s*seconds?)?)?$').firstMatch(norm);
    if (seekToTimeMatch != null) {
      final mins = int.tryParse(seekToTimeMatch.group(1)!) ?? 0;
      final secs = int.tryParse(seekToTimeMatch.group(2) ?? '0') ?? 0;
      return Matched(SeekTo(mins * 60 + secs), 0.95, usedWakeWord: usedWakeWord);
    }
    final seekToSecMatch = RegExp(r'^(?:go\s+to|seek\s+to)\s+(\d+)\s+seconds?$').firstMatch(norm);
    if (seekToSecMatch != null) {
      final secs = int.tryParse(seekToSecMatch.group(1)!) ?? 0;
      return Matched(SeekTo(secs), 0.95, usedWakeWord: usedWakeWord);
    }

    // E. Play Playlist
    final playlistMatch = RegExp(r'^play\s+playlist\s+(.+)$').firstMatch(norm);
    if (playlistMatch != null) {
      final name = _extractOriginalQuery(originalClean, RegExp(r'^play\s+playlist\s+', caseSensitive: false));
      return Matched(PlayPlaylist(name), 0.9, usedWakeWord: usedWakeWord);
    }

    // F. Add to Playlist
    final addPlMatch = RegExp(r'^add\s+(?:this\s+song\s+)?to\s+(?:playlist\s+)?(.+)$').firstMatch(norm);
    if (addPlMatch != null) {
      final name = _extractOriginalQuery(originalClean, RegExp(r'^add\s+(?:this\s+song\s+)?to\s+(?:playlist\s+)?', caseSensitive: false));
      if (name.toLowerCase() != 'favorites' && name.toLowerCase() != 'queue') {
        return Matched(AddToPlaylist(name), 0.9, usedWakeWord: usedWakeWord);
      }
    }

    // G. Play Album
    final albumMatch = RegExp(r'^play\s+(?:the\s+)?album\s+(.+)$').firstMatch(norm);
    if (albumMatch != null) {
      final query = _extractOriginalQuery(originalClean, RegExp(r'^play\s+(?:the\s+)?album\s+', caseSensitive: false));
      return Matched(PlaySearch(query, kind: SearchKind.album), 0.85, usedWakeWord: usedWakeWord);
    }

    // H. Play Songs by Artist
    final artistMatch = RegExp(r'^play\s+(?:songs?\s+by|artist)\s+(.+)$').firstMatch(norm);
    if (artistMatch != null) {
      final query = _extractOriginalQuery(originalClean, RegExp(r'^play\s+(?:songs?\s+by|artist)\s+', caseSensitive: false));
      return Matched(PlaySearch(query, kind: SearchKind.artist), 0.85, usedWakeWord: usedWakeWord);
    }

    // I. Play Song by Artist ("play X by Y")
    final songByArtistMatch = RegExp(r'^play\s+(.+?)\s+by\s+(.+)$').firstMatch(norm);
    if (songByArtistMatch != null) {
      final query = _extractOriginalQuery(originalClean, RegExp(r'^play\s+', caseSensitive: false));
      return Matched(PlaySearch(query, kind: SearchKind.song), 0.85, usedWakeWord: usedWakeWord);
    }

    // J. Urdu Search Patterns ("X chalao", "X sunao", "X lagao")
    final urduSearchMatch = RegExp(r'^(.+?)\s+(?:ke\s+gane\s+)?(?:chalao|lagao|sunao)$').firstMatch(norm);
    if (urduSearchMatch != null) {
      final qCandidate = urduSearchMatch.group(1)!.trim();
      if (qCandidate.isNotEmpty && !_isUrduCommandWord(qCandidate)) {
        final query = _extractUrduQuery(originalClean);
        return Matched(PlaySearch(query, kind: SearchKind.song), 0.8, usedWakeWord: usedWakeWord);
      }
    }

    // Urdu Script Search Patterns ("X چلاؤ / لگاؤ / سناؤ")
    final urduScriptSearchMatch = RegExp(r'^(.+?)\s+(?:کے گانے\s+)?(?:چلاؤ|لگاؤ|سناؤ)$').firstMatch(norm);
    if (urduScriptSearchMatch != null) {
      final qCandidate = urduScriptSearchMatch.group(1)!.trim();
      if (qCandidate.isNotEmpty && !_isUrduCommandWord(qCandidate)) {
        final query = _extractUrduScriptQuery(originalClean);
        return Matched(PlaySearch(query, kind: SearchKind.song), 0.8, usedWakeWord: usedWakeWord);
      }
    }

    // K. Catch-all: "play <anything>"
    final playCatchAllMatch = RegExp(r'^play\s+(.+)$').firstMatch(norm);
    if (playCatchAllMatch != null) {
      final queryCandidate = playCatchAllMatch.group(1)!.trim();

      // In strict mode: require wake word OR allowSearchWithoutWakeWord
      if (mode == ParserMode.strict && !usedWakeWord && !allowSearchWithoutWakeWord) {
        return NoMatch(norm);
      }

      if (queryCandidate.isNotEmpty) {
        final query = _extractOriginalQuery(originalClean, RegExp(r'^play\s+', caseSensitive: false));
        return Matched(PlaySearch(query), 0.7, usedWakeWord: usedWakeWord);
      }
    }

    return NoMatch(norm);
  }

  static VoiceIntent? _matchExact(String norm) {
    for (final e in PhraseTables.englishExact) {
      if (e.phrase == norm) return e.intent;
    }
    for (final e in PhraseTables.urduExact) {
      if (e.phrase == norm) return e.intent;
    }
    return null;
  }

  static bool _isUrduCommandWord(String text) {
    const reserved = {'gana', 'music', 'agla', 'pichla', 'pasandeeda', 'liked', 'downloaded', 'radio'};
    return reserved.contains(text.toLowerCase());
  }

  static String _extractOriginalQuery(String original, RegExp prefixPattern) {
    String res = original.replaceFirst(prefixPattern, '').trim();
    // Strip trailing punctuation
    res = res.replaceAll(RegExp(r'[,\.!?;:]+$'), '').trim();
    return res.isNotEmpty ? res : original;
  }

  static String _extractUrduQuery(String original) {
    String res = original.replaceFirst(RegExp(r'\s+(?:ke\s+gane\s+)?(?:chalao|lagao|sunao)\b.*$', caseSensitive: false), '').trim();
    return res.isNotEmpty ? res : original;
  }

  static String _extractUrduScriptQuery(String original) {
    String res = original.replaceFirst(RegExp(r'\s+(?:کے گانے\s+)?(?:چلاؤ|لگاؤ|سناؤ)(?:\s+.*)?$'), '').trim();
    return res.isNotEmpty ? res : original;
  }
}
