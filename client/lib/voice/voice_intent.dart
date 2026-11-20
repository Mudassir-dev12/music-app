import '../player/queue.dart' show RepeatMode;

enum SearchKind { song, album, artist }

enum VoiceScreen {
  home,
  search,
  library,
  downloaded,
  downloadsQueue,
  settings,
  nowPlaying,
  rideMode,
}

/// Sealed class of all allowed VoiceIntents.
///
/// Under no circumstances should destructive actions (delete playlist, delete download,
/// remove account, reset database) exist in this hierarchy.
sealed class VoiceIntent {
  const VoiceIntent();

  String get type;
  Map<String, dynamic> toJson();

  static VoiceIntent? fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type == null) return null;

    switch (type) {
      // Transport
      case 'Play':
        return const Play();
      case 'Pause':
        return const Pause();
      case 'Stop':
        return const Stop();
      case 'Next':
        return const Next();
      case 'Previous':
        return const Previous();
      case 'Restart':
        return const Restart();
      case 'SeekTo':
        final sec = json['seconds'] as num?;
        if (sec == null || sec < 0) return null;
        return SeekTo(sec.toInt());
      case 'SeekBy':
        final sec = json['seconds'] as num?;
        if (sec == null) return null;
        return SeekBy(sec.toInt());

      // Volume
      case 'VolumeUp':
        return const VolumeUp();
      case 'VolumeDown':
        return const VolumeDown();
      case 'VolumeSet':
        final pct = json['percent'] as num?;
        if (pct == null || pct < 0 || pct > 100) return null;
        return VolumeSet(pct.toInt());
      case 'Mute':
        return const Mute();
      case 'Unmute':
        return const Unmute();

      // Modes
      case 'Shuffle':
        final enable = json['enable'] as bool? ?? true;
        return Shuffle(enable);
      case 'Repeat':
        final modeStr = json['mode'] as String?;
        final mode = RepeatMode.values.firstWhere(
          (m) => m.name == modeStr,
          orElse: () => RepeatMode.off,
        );
        return Repeat(mode);
      case 'Autoplay':
        final enable = json['enable'] as bool? ?? true;
        return Autoplay(enable);

      // Library
      case 'Like':
        return const Like();
      case 'Unlike':
        return const Unlike();
      case 'AddToPlaylist':
        final name = (json['playlistName'] as String?)?.trim();
        if (name == null || name.isEmpty) return null;
        return AddToPlaylist(name);

      // Play something
      case 'PlaySearch':
        final query = (json['query'] as String?)?.trim();
        if (query == null || query.isEmpty) return null;
        final kindStr = json['kind'] as String?;
        final kind = kindStr != null
            ? SearchKind.values.firstWhere(
                (k) => k.name == kindStr,
                orElse: () => SearchKind.song,
              )
            : null;
        return PlaySearch(query, kind: kind);
      case 'PlayLiked':
        return const PlayLiked();
      case 'PlayPlaylist':
        final name = (json['playlistName'] as String?)?.trim();
        if (name == null || name.isEmpty) return null;
        return PlayPlaylist(name);
      case 'PlayDownloaded':
        return const PlayDownloaded();
      case 'PlayRadio':
        return const PlayRadio();

      // Sleep timer
      case 'SleepTimer':
        final minutes = json['minutes'] as num?;
        if (minutes == null || minutes <= 0 || minutes > 360) return null;
        return SleepTimer(minutes.toInt());
      case 'CancelSleepTimer':
        return const CancelSleepTimer();

      // Navigation
      case 'Open':
        final scrStr = json['screen'] as String?;
        if (scrStr == null) return null;
        final scr = VoiceScreen.values.firstWhere(
          (s) => s.name == scrStr,
          orElse: () => VoiceScreen.home,
        );
        return Open(scr);

      // Info and help
      case 'WhatsPlaying':
        return const WhatsPlaying();
      case 'Help':
        return const Help();

      // Offline
      case 'OfflineMode':
        final enable = json['enable'] as bool? ?? true;
        return OfflineMode(enable);

      // Download
      case 'DownloadCurrent':
        return const DownloadCurrent();

      // Voice control
      case 'StopListening':
        return const StopListening();
      case 'Cancel':
        return const Cancel();

      default:
        return null;
    }
  }
}

// -----------------------------------------------------------------------------
// Transport
// -----------------------------------------------------------------------------
final class Play extends VoiceIntent {
  const Play();
  @override
  String get type => 'Play';
  @override
  Map<String, dynamic> toJson() => {'type': type};
  @override
  bool operator ==(Object other) => other is Play;
  @override
  int get hashCode => type.hashCode;
  @override
  String toString() => 'Play()';
}

final class Pause extends VoiceIntent {
  const Pause();
  @override
  String get type => 'Pause';
  @override
  Map<String, dynamic> toJson() => {'type': type};
  @override
  bool operator ==(Object other) => other is Pause;
  @override
  int get hashCode => type.hashCode;
  @override
  String toString() => 'Pause()';
}

final class Stop extends VoiceIntent {
  const Stop();
  @override
  String get type => 'Stop';
  @override
  Map<String, dynamic> toJson() => {'type': type};
  @override
  bool operator ==(Object other) => other is Stop;
  @override
  int get hashCode => type.hashCode;
  @override
  String toString() => 'Stop()';
}

final class Next extends VoiceIntent {
  const Next();
  @override
  String get type => 'Next';
  @override
  Map<String, dynamic> toJson() => {'type': type};
  @override
  bool operator ==(Object other) => other is Next;
  @override
  int get hashCode => type.hashCode;
  @override
  String toString() => 'Next()';
}

final class Previous extends VoiceIntent {
  const Previous();
  @override
  String get type => 'Previous';
  @override
  Map<String, dynamic> toJson() => {'type': type};
  @override
  bool operator ==(Object other) => other is Previous;
  @override
  int get hashCode => type.hashCode;
  @override
  String toString() => 'Previous()';
}

final class Restart extends VoiceIntent {
  const Restart();
  @override
  String get type => 'Restart';
  @override
  Map<String, dynamic> toJson() => {'type': type};
  @override
  bool operator ==(Object other) => other is Restart;
  @override
  int get hashCode => type.hashCode;
  @override
  String toString() => 'Restart()';
}

final class SeekTo extends VoiceIntent {
  const SeekTo(this.seconds);
  final int seconds;
  @override
  String get type => 'SeekTo';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'seconds': seconds};
  @override
  bool operator ==(Object other) => other is SeekTo && other.seconds == seconds;
  @override
  int get hashCode => Object.hash(type, seconds);
  @override
  String toString() => 'SeekTo($seconds s)';
}

final class SeekBy extends VoiceIntent {
  const SeekBy(this.seconds);
  final int seconds;
  @override
  String get type => 'SeekBy';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'seconds': seconds};
  @override
  bool operator ==(Object other) => other is SeekBy && other.seconds == seconds;
  @override
  int get hashCode => Object.hash(type, seconds);
  @override
  String toString() => 'SeekBy(${seconds >= 0 ? "+$seconds" : "$seconds"} s)';
}

// -----------------------------------------------------------------------------
// Volume
// -----------------------------------------------------------------------------
final class VolumeUp extends VoiceIntent {
  const VolumeUp();
  @override
  String get type => 'VolumeUp';
  @override
  Map<String, dynamic> toJson() => {'type': type};
  @override
  bool operator ==(Object other) => other is VolumeUp;
  @override
  int get hashCode => type.hashCode;
  @override
  String toString() => 'VolumeUp()';
}

final class VolumeDown extends VoiceIntent {
  const VolumeDown();
  @override
  String get type => 'VolumeDown';
  @override
  Map<String, dynamic> toJson() => {'type': type};
  @override
  bool operator ==(Object other) => other is VolumeDown;
  @override
  int get hashCode => type.hashCode;
  @override
  String toString() => 'VolumeDown()';
}

final class VolumeSet extends VoiceIntent {
  const VolumeSet(this.percent);
  final int percent;
  @override
  String get type => 'VolumeSet';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'percent': percent};
  @override
  bool operator ==(Object other) => other is VolumeSet && other.percent == percent;
  @override
  int get hashCode => Object.hash(type, percent);
  @override
  String toString() => 'VolumeSet($percent%)';
}

final class Mute extends VoiceIntent {
  const Mute();
  @override
  String get type => 'Mute';
  @override
  Map<String, dynamic> toJson() => {'type': type};
  @override
  bool operator ==(Object other) => other is Mute;
  @override
  int get hashCode => type.hashCode;
  @override
  String toString() => 'Mute()';
}

final class Unmute extends VoiceIntent {
  const Unmute();
  @override
  String get type => 'Unmute';
  @override
  Map<String, dynamic> toJson() => {'type': type};
  @override
  bool operator ==(Object other) => other is Unmute;
  @override
  int get hashCode => type.hashCode;
  @override
  String toString() => 'Unmute()';
}

// -----------------------------------------------------------------------------
// Modes
// -----------------------------------------------------------------------------
final class Shuffle extends VoiceIntent {
  const Shuffle(this.enable);
  final bool enable;
  @override
  String get type => 'Shuffle';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'enable': enable};
  @override
  bool operator ==(Object other) => other is Shuffle && other.enable == enable;
  @override
  int get hashCode => Object.hash(type, enable);
  @override
  String toString() => 'Shuffle($enable)';
}

final class Repeat extends VoiceIntent {
  const Repeat(this.mode);
  final RepeatMode mode;
  @override
  String get type => 'Repeat';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'mode': mode.name};
  @override
  bool operator ==(Object other) => other is Repeat && other.mode == mode;
  @override
  int get hashCode => Object.hash(type, mode);
  @override
  String toString() => 'Repeat(${mode.name})';
}

final class Autoplay extends VoiceIntent {
  const Autoplay(this.enable);
  final bool enable;
  @override
  String get type => 'Autoplay';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'enable': enable};
  @override
  bool operator ==(Object other) => other is Autoplay && other.enable == enable;
  @override
  int get hashCode => Object.hash(type, enable);
  @override
  String toString() => 'Autoplay($enable)';
}

// -----------------------------------------------------------------------------
// Library
// -----------------------------------------------------------------------------
final class Like extends VoiceIntent {
  const Like();
  @override
  String get type => 'Like';
  @override
  Map<String, dynamic> toJson() => {'type': type};
  @override
  bool operator ==(Object other) => other is Like;
  @override
  int get hashCode => type.hashCode;
  @override
  String toString() => 'Like()';
}

final class Unlike extends VoiceIntent {
  const Unlike();
  @override
  String get type => 'Unlike';
  @override
  Map<String, dynamic> toJson() => {'type': type};
  @override
  bool operator ==(Object other) => other is Unlike;
  @override
  int get hashCode => type.hashCode;
  @override
  String toString() => 'Unlike()';
}

final class AddToPlaylist extends VoiceIntent {
  const AddToPlaylist(this.playlistName);
  final String playlistName;
  @override
  String get type => 'AddToPlaylist';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'playlistName': playlistName};
  @override
  bool operator ==(Object other) =>
      other is AddToPlaylist && other.playlistName == playlistName;
  @override
  int get hashCode => Object.hash(type, playlistName);
  @override
  String toString() => 'AddToPlaylist("$playlistName")';
}

// -----------------------------------------------------------------------------
// Play Something
// -----------------------------------------------------------------------------
final class PlaySearch extends VoiceIntent {
  const PlaySearch(this.query, {this.kind});
  final String query;
  final SearchKind? kind;
  @override
  String get type => 'PlaySearch';
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'query': query,
        if (kind != null) 'kind': kind!.name,
      };
  @override
  bool operator ==(Object other) =>
      other is PlaySearch && other.query == query && other.kind == kind;
  @override
  int get hashCode => Object.hash(type, query, kind);
  @override
  String toString() =>
      'PlaySearch("$query"${kind != null ? ", kind: ${kind!.name}" : ""})';
}

final class PlayLiked extends VoiceIntent {
  const PlayLiked();
  @override
  String get type => 'PlayLiked';
  @override
  Map<String, dynamic> toJson() => {'type': type};
  @override
  bool operator ==(Object other) => other is PlayLiked;
  @override
  int get hashCode => type.hashCode;
  @override
  String toString() => 'PlayLiked()';
}

final class PlayPlaylist extends VoiceIntent {
  const PlayPlaylist(this.playlistName);
  final String playlistName;
  @override
  String get type => 'PlayPlaylist';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'playlistName': playlistName};
  @override
  bool operator ==(Object other) =>
      other is PlayPlaylist && other.playlistName == playlistName;
  @override
  int get hashCode => Object.hash(type, playlistName);
  @override
  String toString() => 'PlayPlaylist("$playlistName")';
}

final class PlayDownloaded extends VoiceIntent {
  const PlayDownloaded();
  @override
  String get type => 'PlayDownloaded';
  @override
  Map<String, dynamic> toJson() => {'type': type};
  @override
  bool operator ==(Object other) => other is PlayDownloaded;
  @override
  int get hashCode => type.hashCode;
  @override
  String toString() => 'PlayDownloaded()';
}

final class PlayRadio extends VoiceIntent {
  const PlayRadio();
  @override
  String get type => 'PlayRadio';
  @override
  Map<String, dynamic> toJson() => {'type': type};
  @override
  bool operator ==(Object other) => other is PlayRadio;
  @override
  int get hashCode => type.hashCode;
  @override
  String toString() => 'PlayRadio()';
}

// -----------------------------------------------------------------------------
// Sleep Timer
// -----------------------------------------------------------------------------
final class SleepTimer extends VoiceIntent {
  const SleepTimer(this.minutes);
  final int minutes;
  @override
  String get type => 'SleepTimer';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'minutes': minutes};
  @override
  bool operator ==(Object other) => other is SleepTimer && other.minutes == minutes;
  @override
  int get hashCode => Object.hash(type, minutes);
  @override
  String toString() => 'SleepTimer($minutes min)';
}

final class CancelSleepTimer extends VoiceIntent {
  const CancelSleepTimer();
  @override
  String get type => 'CancelSleepTimer';
  @override
  Map<String, dynamic> toJson() => {'type': type};
  @override
  bool operator ==(Object other) => other is CancelSleepTimer;
  @override
  int get hashCode => type.hashCode;
  @override
  String toString() => 'CancelSleepTimer()';
}

// -----------------------------------------------------------------------------
// Navigation
// -----------------------------------------------------------------------------
final class Open extends VoiceIntent {
  const Open(this.screen);
  final VoiceScreen screen;
  @override
  String get type => 'Open';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'screen': screen.name};
  @override
  bool operator ==(Object other) => other is Open && other.screen == screen;
  @override
  int get hashCode => Object.hash(type, screen);
  @override
  String toString() => 'Open(${screen.name})';
}

// -----------------------------------------------------------------------------
// Info and Help
// -----------------------------------------------------------------------------
final class WhatsPlaying extends VoiceIntent {
  const WhatsPlaying();
  @override
  String get type => 'WhatsPlaying';
  @override
  Map<String, dynamic> toJson() => {'type': type};
  @override
  bool operator ==(Object other) => other is WhatsPlaying;
  @override
  int get hashCode => type.hashCode;
  @override
  String toString() => 'WhatsPlaying()';
}

final class Help extends VoiceIntent {
  const Help();
  @override
  String get type => 'Help';
  @override
  Map<String, dynamic> toJson() => {'type': type};
  @override
  bool operator ==(Object other) => other is Help;
  @override
  int get hashCode => type.hashCode;
  @override
  String toString() => 'Help()';
}

// -----------------------------------------------------------------------------
// Offline
// -----------------------------------------------------------------------------
final class OfflineMode extends VoiceIntent {
  const OfflineMode(this.enable);
  final bool enable;
  @override
  String get type => 'OfflineMode';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'enable': enable};
  @override
  bool operator ==(Object other) => other is OfflineMode && other.enable == enable;
  @override
  int get hashCode => Object.hash(type, enable);
  @override
  String toString() => 'OfflineMode($enable)';
}

// -----------------------------------------------------------------------------
// Download
// -----------------------------------------------------------------------------
final class DownloadCurrent extends VoiceIntent {
  const DownloadCurrent();
  @override
  String get type => 'DownloadCurrent';
  @override
  Map<String, dynamic> toJson() => {'type': type};
  @override
  bool operator ==(Object other) => other is DownloadCurrent;
  @override
  int get hashCode => type.hashCode;
  @override
  String toString() => 'DownloadCurrent()';
}

// -----------------------------------------------------------------------------
// Voice Control
// -----------------------------------------------------------------------------
final class StopListening extends VoiceIntent {
  const StopListening();
  @override
  String get type => 'StopListening';
  @override
  Map<String, dynamic> toJson() => {'type': type};
  @override
  bool operator ==(Object other) => other is StopListening;
  @override
  int get hashCode => type.hashCode;
  @override
  String toString() => 'StopListening()';
}

final class Cancel extends VoiceIntent {
  const Cancel();
  @override
  String get type => 'Cancel';
  @override
  Map<String, dynamic> toJson() => {'type': type};
  @override
  bool operator ==(Object other) => other is Cancel;
  @override
  int get hashCode => type.hashCode;
  @override
  String toString() => 'Cancel()';
}
