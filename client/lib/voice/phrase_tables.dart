import '../player/queue.dart' show RepeatMode;
import 'voice_intent.dart';

/// Phrase definition for voice commands.
class PhraseEntry {
  const PhraseEntry({
    required this.phrase,
    required this.intent,
    this.category = 'General',
    this.description,
  });

  final String phrase;
  final VoiceIntent intent;
  final String category;
  final String? description;
}

class SlotPatternEntry {
  const SlotPatternEntry({
    required this.pattern,
    required this.category,
    required this.example,
    required this.description,
  });

  /// Pattern regex or format string, e.g. "play {query}".
  final String pattern;
  final String category;
  final String example;
  final String description;
}

/// Static data tables for English and Urdu voice commands.
/// No business logic resides in this file.
class PhraseTables {
  const PhraseTables._();

  // ---------------------------------------------------------------------------
  // English Exact Commands
  // ---------------------------------------------------------------------------
  static const List<PhraseEntry> englishExact = [
    // Transport
    PhraseEntry(phrase: 'play', intent: Play(), category: 'Transport', description: 'Resume playback'),
    PhraseEntry(phrase: 'resume', intent: Play(), category: 'Transport', description: 'Resume playback'),
    PhraseEntry(phrase: 'continue', intent: Play(), category: 'Transport', description: 'Resume playback'),
    PhraseEntry(phrase: 'play music', intent: Play(), category: 'Transport', description: 'Start playback'),
    PhraseEntry(phrase: 'music play', intent: Play(), category: 'Transport', description: 'Start playback'),
    PhraseEntry(phrase: 'play some music', intent: Play(), category: 'Transport', description: 'Start playback'),
    PhraseEntry(phrase: 'start music', intent: Play(), category: 'Transport', description: 'Start playback'),
    PhraseEntry(phrase: 'pause', intent: Pause(), category: 'Transport', description: 'Pause music'),
    PhraseEntry(phrase: 'stop the music', intent: Pause(), category: 'Transport', description: 'Pause music'),
    PhraseEntry(phrase: 'stop music', intent: Pause(), category: 'Transport', description: 'Pause music'),
    PhraseEntry(phrase: 'music band', intent: Pause(), category: 'Transport', description: 'Pause music'),
    PhraseEntry(phrase: 'stop', intent: Stop(), category: 'Transport', description: 'Stop playback and keep position'),
    PhraseEntry(phrase: 'next', intent: Next(), category: 'Transport', description: 'Skip to next track'),
    PhraseEntry(phrase: 'skip', intent: Next(), category: 'Transport', description: 'Skip to next track'),
    PhraseEntry(phrase: 'next song', intent: Next(), category: 'Transport', description: 'Skip to next track'),
    PhraseEntry(phrase: 'change song', intent: Next(), category: 'Transport', description: 'Change current song'),
    PhraseEntry(phrase: 'change the song', intent: Next(), category: 'Transport', description: 'Change current song'),
    PhraseEntry(phrase: 'previous', intent: Previous(), category: 'Transport', description: 'Go to previous track'),
    PhraseEntry(phrase: 'previous song', intent: Previous(), category: 'Transport', description: 'Go to previous track'),
    PhraseEntry(phrase: 'go back', intent: Previous(), category: 'Transport', description: 'Go back to previous track'),
    PhraseEntry(phrase: 'start over', intent: Restart(), category: 'Transport', description: 'Restart song from beginning'),
    PhraseEntry(phrase: 'from the beginning', intent: Restart(), category: 'Transport', description: 'Restart song from beginning'),
    PhraseEntry(phrase: 'restart', intent: Restart(), category: 'Transport', description: 'Restart song from beginning'),

    // Volume
    PhraseEntry(phrase: 'volume up', intent: VolumeUp(), category: 'Volume', description: 'Increase volume by 10%'),
    PhraseEntry(phrase: 'louder', intent: VolumeUp(), category: 'Volume', description: 'Increase volume by 10%'),
    PhraseEntry(phrase: 'volume high', intent: VolumeUp(), category: 'Volume', description: 'Increase volume by 10%'),
    PhraseEntry(phrase: 'turn it up', intent: VolumeUp(), category: 'Volume', description: 'Increase volume by 10%'),
    PhraseEntry(phrase: 'volume down', intent: VolumeDown(), category: 'Volume', description: 'Decrease volume by 10%'),
    PhraseEntry(phrase: 'volume low', intent: VolumeDown(), category: 'Volume', description: 'Decrease volume by 10%'),
    PhraseEntry(phrase: 'lower the volume', intent: VolumeDown(), category: 'Volume', description: 'Decrease volume by 10%'),
    PhraseEntry(phrase: 'make it quieter', intent: VolumeDown(), category: 'Volume', description: 'Decrease volume by 10%'),
    PhraseEntry(phrase: 'sound low', intent: VolumeDown(), category: 'Volume', description: 'Decrease volume by 10%'),
    PhraseEntry(phrase: 'turn it down', intent: VolumeDown(), category: 'Volume', description: 'Decrease volume by 10%'),
    PhraseEntry(phrase: 'volume max', intent: VolumeSet(100), category: 'Volume', description: 'Set volume to 100%'),
    PhraseEntry(phrase: 'maximum volume', intent: VolumeSet(100), category: 'Volume', description: 'Set volume to 100%'),
    PhraseEntry(phrase: 'volume half', intent: VolumeSet(50), category: 'Volume', description: 'Set volume to 50%'),
    PhraseEntry(phrase: 'mute', intent: Mute(), category: 'Volume', description: 'Mute player audio'),
    PhraseEntry(phrase: 'silence', intent: Mute(), category: 'Volume', description: 'Mute player audio'),
    PhraseEntry(phrase: 'unmute', intent: Unmute(), category: 'Volume', description: 'Restore player volume'),

    // Modes
    PhraseEntry(phrase: 'shuffle on', intent: Shuffle(true), category: 'Modes', description: 'Turn shuffle on'),
    PhraseEntry(phrase: 'turn on shuffle', intent: Shuffle(true), category: 'Modes', description: 'Turn shuffle on'),
    PhraseEntry(phrase: 'enable shuffle', intent: Shuffle(true), category: 'Modes', description: 'Turn shuffle on'),
    PhraseEntry(phrase: 'shuffle off', intent: Shuffle(false), category: 'Modes', description: 'Turn shuffle off'),
    PhraseEntry(phrase: 'turn off shuffle', intent: Shuffle(false), category: 'Modes', description: 'Turn shuffle off'),
    PhraseEntry(phrase: 'repeat all', intent: Repeat(RepeatMode.all), category: 'Modes', description: 'Repeat queue'),
    PhraseEntry(phrase: 'repeat on', intent: Repeat(RepeatMode.all), category: 'Modes', description: 'Repeat queue'),
    PhraseEntry(phrase: 'repeat one', intent: Repeat(RepeatMode.one), category: 'Modes', description: 'Repeat current song'),
    PhraseEntry(phrase: 'repeat 1', intent: Repeat(RepeatMode.one), category: 'Modes', description: 'Repeat current song'),
    PhraseEntry(phrase: 'repeat this song', intent: Repeat(RepeatMode.one), category: 'Modes', description: 'Repeat current song'),
    PhraseEntry(phrase: 'repeat off', intent: Repeat(RepeatMode.off), category: 'Modes', description: 'Turn repeat off'),
    PhraseEntry(phrase: 'turn autoplay on', intent: Autoplay(true), category: 'Modes', description: 'Enable continuous autoplay'),
    PhraseEntry(phrase: 'turn on autoplay', intent: Autoplay(true), category: 'Modes', description: 'Enable continuous autoplay'),
    PhraseEntry(phrase: 'autoplay on', intent: Autoplay(true), category: 'Modes', description: 'Enable continuous autoplay'),
    PhraseEntry(phrase: 'turn autoplay off', intent: Autoplay(false), category: 'Modes', description: 'Disable autoplay'),
    PhraseEntry(phrase: 'turn off autoplay', intent: Autoplay(false), category: 'Modes', description: 'Disable autoplay'),
    PhraseEntry(phrase: 'autoplay off', intent: Autoplay(false), category: 'Modes', description: 'Disable autoplay'),

    // Library
    PhraseEntry(phrase: 'like this song', intent: Like(), category: 'Library', description: 'Like current song'),
    PhraseEntry(phrase: 'like', intent: Like(), category: 'Library', description: 'Like current song'),
    PhraseEntry(phrase: 'thumbs up', intent: Like(), category: 'Library', description: 'Like current song'),
    PhraseEntry(phrase: 'add to favorites', intent: Like(), category: 'Library', description: 'Like current song'),
    PhraseEntry(phrase: 'unlike this song', intent: Unlike(), category: 'Library', description: 'Unlike current song'),
    PhraseEntry(phrase: 'unlike', intent: Unlike(), category: 'Library', description: 'Unlike current song'),
    PhraseEntry(phrase: 'remove like', intent: Unlike(), category: 'Library', description: 'Unlike current song'),

    // Play Collections
    PhraseEntry(phrase: 'play my liked songs', intent: PlayLiked(), category: 'Play', description: 'Play Liked Songs'),
    PhraseEntry(phrase: 'play liked songs', intent: PlayLiked(), category: 'Play', description: 'Play Liked Songs'),
    PhraseEntry(phrase: 'play favorites', intent: PlayLiked(), category: 'Play', description: 'Play Liked Songs'),
    PhraseEntry(phrase: 'play downloaded music', intent: PlayDownloaded(), category: 'Play', description: 'Play downloaded music'),
    PhraseEntry(phrase: 'play downloads', intent: PlayDownloaded(), category: 'Play', description: 'Play downloaded music'),
    PhraseEntry(phrase: 'offline music', intent: PlayDownloaded(), category: 'Play', description: 'Play downloaded music'),
    PhraseEntry(phrase: 'play something similar', intent: PlayRadio(), category: 'Play', description: 'Start track radio'),
    PhraseEntry(phrase: 'start radio', intent: PlayRadio(), category: 'Play', description: 'Start track radio'),
    PhraseEntry(phrase: 'play radio', intent: PlayRadio(), category: 'Play', description: 'Start track radio'),

    // Sleep Timer
    PhraseEntry(phrase: 'cancel sleep timer', intent: CancelSleepTimer(), category: 'Sleep Timer', description: 'Cancel sleep timer'),
    PhraseEntry(phrase: 'cancel timer', intent: CancelSleepTimer(), category: 'Sleep Timer', description: 'Cancel sleep timer'),

    // Navigation
    PhraseEntry(phrase: 'open home', intent: Open(VoiceScreen.home), category: 'Navigation', description: 'Go to Home / Listen Now'),
    PhraseEntry(phrase: 'go to home', intent: Open(VoiceScreen.home), category: 'Navigation', description: 'Go to Home / Listen Now'),
    PhraseEntry(phrase: 'open search', intent: Open(VoiceScreen.search), category: 'Navigation', description: 'Go to Search'),
    PhraseEntry(phrase: 'go to search', intent: Open(VoiceScreen.search), category: 'Navigation', description: 'Go to Search'),
    PhraseEntry(phrase: 'open library', intent: Open(VoiceScreen.library), category: 'Navigation', description: 'Go to Library'),
    PhraseEntry(phrase: 'go to library', intent: Open(VoiceScreen.library), category: 'Navigation', description: 'Go to Library'),
    PhraseEntry(phrase: 'open downloads', intent: Open(VoiceScreen.downloaded), category: 'Navigation', description: 'Go to Downloads'),
    PhraseEntry(phrase: 'go to downloads', intent: Open(VoiceScreen.downloaded), category: 'Navigation', description: 'Go to Downloads'),
    PhraseEntry(phrase: 'open settings', intent: Open(VoiceScreen.settings), category: 'Navigation', description: 'Go to Settings'),
    PhraseEntry(phrase: 'go to settings', intent: Open(VoiceScreen.settings), category: 'Navigation', description: 'Go to Settings'),
    PhraseEntry(phrase: 'open now playing', intent: Open(VoiceScreen.nowPlaying), category: 'Navigation', description: 'Open Now Playing screen'),
    PhraseEntry(phrase: 'now playing', intent: Open(VoiceScreen.nowPlaying), category: 'Navigation', description: 'Open Now Playing screen'),
    PhraseEntry(phrase: 'open ride mode', intent: Open(VoiceScreen.rideMode), category: 'Navigation', description: 'Switch to Ride mode'),
    PhraseEntry(phrase: 'ride mode', intent: Open(VoiceScreen.rideMode), category: 'Navigation', description: 'Switch to Ride mode'),

    // Info and Help
    PhraseEntry(phrase: "what's playing", intent: WhatsPlaying(), category: 'Info & Help', description: 'Spoken confirmation of current song'),
    PhraseEntry(phrase: 'what is playing', intent: WhatsPlaying(), category: 'Info & Help', description: 'Spoken confirmation of current song'),
    PhraseEntry(phrase: 'what song is this', intent: WhatsPlaying(), category: 'Info & Help', description: 'Spoken confirmation of current song'),
    PhraseEntry(phrase: 'which song is this', intent: WhatsPlaying(), category: 'Info & Help', description: 'Spoken confirmation of current song'),
    PhraseEntry(phrase: 'what can i say', intent: Help(), category: 'Info & Help', description: 'Show voice command help'),
    PhraseEntry(phrase: 'help', intent: Help(), category: 'Info & Help', description: 'Show voice command help'),

    // Offline & Download
    PhraseEntry(phrase: 'turn on offline mode', intent: OfflineMode(true), category: 'Offline', description: 'Enable offline mode'),
    PhraseEntry(phrase: 'offline mode on', intent: OfflineMode(true), category: 'Offline', description: 'Enable offline mode'),
    PhraseEntry(phrase: 'turn off offline mode', intent: OfflineMode(false), category: 'Offline', description: 'Disable offline mode'),
    PhraseEntry(phrase: 'offline mode off', intent: OfflineMode(false), category: 'Offline', description: 'Disable offline mode'),
    PhraseEntry(phrase: 'download current song', intent: DownloadCurrent(), category: 'Downloads', description: 'Download current song'),
    PhraseEntry(phrase: 'download this song', intent: DownloadCurrent(), category: 'Downloads', description: 'Download current song'),
    PhraseEntry(phrase: 'download track', intent: DownloadCurrent(), category: 'Downloads', description: 'Download current song'),

    // Voice Control
    PhraseEntry(phrase: 'stop listening', intent: StopListening(), category: 'Voice Control', description: 'Turn off continuous listening'),
    PhraseEntry(phrase: 'voice off', intent: StopListening(), category: 'Voice Control', description: 'Turn off continuous listening'),
    PhraseEntry(phrase: 'mic off', intent: StopListening(), category: 'Voice Control', description: 'Turn off continuous listening'),
    PhraseEntry(phrase: 'cancel', intent: Cancel(), category: 'Voice Control', description: 'Cancel current voice command'),
    PhraseEntry(phrase: 'never mind', intent: Cancel(), category: 'Voice Control', description: 'Cancel current voice command'),
  ];

  // ---------------------------------------------------------------------------
  // Urdu Exact Commands (Urdu Script & Roman Urdu)
  // ---------------------------------------------------------------------------
  static const List<PhraseEntry> urduExact = [
    // Transport - Roman Urdu
    PhraseEntry(phrase: 'gana chalao', intent: Play(), category: 'Transport', description: 'گانا چلائیں'),
    PhraseEntry(phrase: 'chalao', intent: Play(), category: 'Transport', description: 'چلائیں'),
    PhraseEntry(phrase: 'music chalao', intent: Play(), category: 'Transport', description: 'میوزک چلائیں'),
    PhraseEntry(phrase: 'shuru karo', intent: Play(), category: 'Transport', description: 'شروع کریں'),
    PhraseEntry(phrase: 'play karo', intent: Play(), category: 'Transport', description: 'پلے کریں'),
    PhraseEntry(phrase: 'ruko', intent: Pause(), category: 'Transport', description: 'روک دیں'),
    PhraseEntry(phrase: 'rok do', intent: Pause(), category: 'Transport', description: 'روک دیں'),
    PhraseEntry(phrase: 'pause karo', intent: Pause(), category: 'Transport', description: 'پاز کریں'),
    PhraseEntry(phrase: 'music band', intent: Pause(), category: 'Transport', description: 'میوزک بند کریں'),
    PhraseEntry(phrase: 'band karo', intent: Stop(), category: 'Transport', description: 'بند کریں'),
    PhraseEntry(phrase: 'stop karo', intent: Stop(), category: 'Transport', description: 'سٹاپ کریں'),
    PhraseEntry(phrase: 'agla gana', intent: Next(), category: 'Transport', description: 'اگلا گانا'),
    PhraseEntry(phrase: 'next gana', intent: Next(), category: 'Transport', description: 'اگلا گانا'),
    PhraseEntry(phrase: 'agla', intent: Next(), category: 'Transport', description: 'اگلا'),
    PhraseEntry(phrase: 'gana badlo', intent: Next(), category: 'Transport', description: 'گانا تبدیل کریں'),
    PhraseEntry(phrase: 'pichla gana', intent: Previous(), category: 'Transport', description: 'پچھلا گانا'),
    PhraseEntry(phrase: 'pichla', intent: Previous(), category: 'Transport', description: 'پچھلا'),
    PhraseEntry(phrase: 'pehle wala', intent: Previous(), category: 'Transport', description: 'پہلے والا'),

    // Transport - Urdu Script
    PhraseEntry(phrase: 'گانا چلاؤ', intent: Play(), category: 'Transport', description: 'گانا چلائیں'),
    PhraseEntry(phrase: 'چلاؤ', intent: Play(), category: 'Transport', description: 'چلائیں'),
    PhraseEntry(phrase: 'میوزک چلاؤ', intent: Play(), category: 'Transport', description: 'میوزک چلائیں'),
    PhraseEntry(phrase: 'روکو', intent: Pause(), category: 'Transport', description: 'روک دیں'),
    PhraseEntry(phrase: 'روک دو', intent: Pause(), category: 'Transport', description: 'روک دیں'),
    PhraseEntry(phrase: 'پاز کرو', intent: Pause(), category: 'Transport', description: 'پاز کریں'),
    PhraseEntry(phrase: 'بند کرو', intent: Stop(), category: 'Transport', description: 'بند کریں'),
    PhraseEntry(phrase: 'اگلا گانا', intent: Next(), category: 'Transport', description: 'اگلا گانا'),
    PhraseEntry(phrase: 'اگلا', intent: Next(), category: 'Transport', description: 'اگلا'),
    PhraseEntry(phrase: 'پچھلا گانا', intent: Previous(), category: 'Transport', description: 'پچھلا گانا'),
    PhraseEntry(phrase: 'پچھلا', intent: Previous(), category: 'Transport', description: 'پچھلا'),

    // Volume - Roman Urdu
    PhraseEntry(phrase: 'awaz barhao', intent: VolumeUp(), category: 'Volume', description: 'آواز بڑھائیں'),
    PhraseEntry(phrase: 'awaz ziada karo', intent: VolumeUp(), category: 'Volume', description: 'آواز زیادہ کریں'),
    PhraseEntry(phrase: 'tez karo', intent: VolumeUp(), category: 'Volume', description: 'آواز تیز کریں'),
    PhraseEntry(phrase: 'awaz kam karo', intent: VolumeDown(), category: 'Volume', description: 'آواز کم کریں'),
    PhraseEntry(phrase: 'thoda kam', intent: VolumeDown(), category: 'Volume', description: 'تھوڑا کم کریں'),
    PhraseEntry(phrase: 'kam karo', intent: VolumeDown(), category: 'Volume', description: 'آواز کم کریں'),
    PhraseEntry(phrase: 'awaz band', intent: Mute(), category: 'Volume', description: 'آواز بند کریں'),
    PhraseEntry(phrase: 'mute karo', intent: Mute(), category: 'Volume', description: 'میوٹ کریں'),
    PhraseEntry(phrase: 'awaz kholo', intent: Unmute(), category: 'Volume', description: 'آواز کھولیں'),
    PhraseEntry(phrase: 'unmute karo', intent: Unmute(), category: 'Volume', description: 'ان میوٹ کریں'),

    // Volume - Urdu Script
    PhraseEntry(phrase: 'آواز بڑھاؤ', intent: VolumeUp(), category: 'Volume', description: 'آواز بڑھائیں'),
    PhraseEntry(phrase: 'آواز زیادہ کرو', intent: VolumeUp(), category: 'Volume', description: 'آواز زیادہ کریں'),
    PhraseEntry(phrase: 'آواز کم کرو', intent: VolumeDown(), category: 'Volume', description: 'آواز کم کریں'),
    PhraseEntry(phrase: 'تھوڑا کم', intent: VolumeDown(), category: 'Volume', description: 'تھوڑا کم کریں'),
    PhraseEntry(phrase: 'آواز بند', intent: Mute(), category: 'Volume', description: 'آواز بند کریں'),
    PhraseEntry(phrase: 'میوٹ کرو', intent: Mute(), category: 'Volume', description: 'میوٹ کریں'),

    // Modes & Library - Roman Urdu & Urdu Script
    PhraseEntry(phrase: 'pasand karo', intent: Like(), category: 'Library', description: 'پسندیدہ میں شامل کریں'),
    PhraseEntry(phrase: 'like karo', intent: Like(), category: 'Library', description: 'پسندیدہ میں شامل کریں'),
    PhraseEntry(phrase: 'پسند کرو', intent: Like(), category: 'Library', description: 'پسندیدہ میں شامل کریں'),
    PhraseEntry(phrase: 'napasand', intent: Unlike(), category: 'Library', description: 'پسندیدہ سے ہٹائیں'),
    PhraseEntry(phrase: 'unlike karo', intent: Unlike(), category: 'Library', description: 'پسندیدہ سے ہٹائیں'),
    PhraseEntry(phrase: 'pasandeeda gane chalao', intent: PlayLiked(), category: 'Play', description: 'پسندیدہ گانے چلائیں'),
    PhraseEntry(phrase: 'liked gane chalao', intent: PlayLiked(), category: 'Play', description: 'پسندیدہ گانے چلائیں'),
    PhraseEntry(phrase: 'پسندیدہ گانے چلاؤ', intent: PlayLiked(), category: 'Play', description: 'پسندیدہ گانے چلائیں'),
    PhraseEntry(phrase: 'downloaded gane chalao', intent: PlayDownloaded(), category: 'Play', description: 'ڈاؤن لوڈ شدہ گانے'),
    PhraseEntry(phrase: 'radio chalao', intent: PlayRadio(), category: 'Play', description: 'ریڈیو چلائیں'),

    // Info & Voice Control - Roman Urdu & Urdu Script
    PhraseEntry(phrase: 'kya chal raha hai', intent: WhatsPlaying(), category: 'Info & Help', description: 'چلنے والا گانا بتائیں'),
    PhraseEntry(phrase: 'ye konsa gana hai', intent: WhatsPlaying(), category: 'Info & Help', description: 'چلنے والا گانا بتائیں'),
    PhraseEntry(phrase: 'کیا چل رہا ہے', intent: WhatsPlaying(), category: 'Info & Help', description: 'چلنے والا گانا بتائیں'),
    PhraseEntry(phrase: 'madad', intent: Help(), category: 'Info & Help', description: 'مدد حاصل کریں'),
    PhraseEntry(phrase: 'kya bolu', intent: Help(), category: 'Info & Help', description: 'کمانڈز کی فہرست'),
    PhraseEntry(phrase: 'مدد', intent: Help(), category: 'Info & Help', description: 'مدد حاصل کریں'),
    PhraseEntry(phrase: 'sunna band karo', intent: StopListening(), category: 'Voice Control', description: 'سننا بند کریں'),
    PhraseEntry(phrase: 'mic band karo', intent: StopListening(), category: 'Voice Control', description: 'مائک بند کریں'),
    PhraseEntry(phrase: 'سننا بند کرو', intent: StopListening(), category: 'Voice Control', description: 'سننا بند کریں'),
    PhraseEntry(phrase: 'chordo', intent: Cancel(), category: 'Voice Control', description: 'منسوخ کریں'),
    PhraseEntry(phrase: 'rehne do', intent: Cancel(), category: 'Voice Control', description: 'منسوخ کریں'),
    PhraseEntry(phrase: 'چھوڑ دو', intent: Cancel(), category: 'Voice Control', description: 'منسوخ کریں'),
    PhraseEntry(phrase: 'کینسل', intent: Cancel(), category: 'Voice Control', description: 'منسوخ کریں'),
  ];

  // ---------------------------------------------------------------------------
  // Slot Patterns (English & Urdu)
  // ---------------------------------------------------------------------------
  static const List<SlotPatternEntry> slotPatterns = [
    SlotPatternEntry(
      pattern: 'play {song} by {artist}',
      category: 'Play',
      example: 'play Tum Hi Ho by Arijit Singh',
      description: 'Plays a specific song by an artist',
    ),
    SlotPatternEntry(
      pattern: 'play album {album}',
      category: 'Play',
      example: 'play the album Aashiqui 2',
      description: 'Searches and plays an album',
    ),
    SlotPatternEntry(
      pattern: 'play songs by {artist}',
      category: 'Play',
      example: 'play songs by Atif Aslam',
      description: 'Plays top songs from an artist',
    ),
    SlotPatternEntry(
      pattern: 'play playlist {name}',
      category: 'Play',
      example: 'play playlist Gym',
      description: 'Plays a user playlist matching the name',
    ),
    SlotPatternEntry(
      pattern: 'add to playlist {name}',
      category: 'Library',
      example: 'add to playlist Workout',
      description: 'Adds the currently playing song to a playlist',
    ),
    SlotPatternEntry(
      pattern: 'volume {percent} percent',
      category: 'Volume',
      example: 'volume 40 percent',
      description: 'Sets player volume to specific level (0-100%)',
    ),
    SlotPatternEntry(
      pattern: 'stop in {minutes} minutes',
      category: 'Sleep Timer',
      example: 'stop in 20 minutes',
      description: 'Sets sleep timer to fade out and pause playback',
    ),
    SlotPatternEntry(
      pattern: 'forward {seconds} seconds',
      category: 'Transport',
      example: 'forward 30 seconds',
      description: 'Seeks forward in the current song',
    ),
    SlotPatternEntry(
      pattern: 'back {seconds} seconds',
      category: 'Transport',
      example: 'back 15 seconds',
      description: 'Seeks backward in the current song',
    ),
    SlotPatternEntry(
      pattern: 'go to {minute} {second}',
      category: 'Transport',
      example: 'go to 1 minute 30',
      description: 'Seeks to an exact position in the track',
    ),
    SlotPatternEntry(
      pattern: '{query} chalao / sunao / lagao',
      category: 'Urdu',
      example: 'Arijit Singh ke gane chalao',
      description: 'Urdu search and play pattern',
    ),
  ];

  /// Generates Markdown documentation for README.md.
  static String generateMarkdownTable() {
    final sb = StringBuffer();
    sb.writeln('| Category | Command / Pattern | Intent | Description |');
    sb.writeln('|---|---|---|---|');

    for (final e in englishExact) {
      sb.writeln('| ${e.category} | "${e.phrase}" | `${e.intent.type}` | ${e.description ?? ""} |');
    }

    for (final e in urduExact) {
      sb.writeln('| Urdu (${e.category}) | "${e.phrase}" | `${e.intent.type}` | ${e.description ?? ""} |');
    }

    for (final s in slotPatterns) {
      sb.writeln('| Pattern (${s.category}) | "${s.pattern}" (e.g. "${s.example}") | Dynamic | ${s.description} |');
    }

    return sb.toString();
  }
}
