import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/player/queue.dart' show RepeatMode;
import 'package:melodia/voice/command_deduper.dart';
import 'package:melodia/voice/intent_parser.dart';
import 'package:melodia/voice/phrase_tables.dart';
import 'package:melodia/voice/text_normalizer.dart';
import 'package:melodia/voice/voice_intent.dart';

void main() {
  group('TextNormalizer', () {
    test('converts Urdu and Arabic digits', () {
      final res = TextNormalizer.normalize('stop in ۲۰ minutes');
      expect(res.normalized, equals('stop in 20 minutes'));
    });

    test('detects and strips wake words', () {
      final r1 = TextNormalizer.normalize('Hey Melodia, pause the music');
      expect(r1.usedWakeWord, isTrue);
      expect(r1.normalized, equals('pause the music'));

      final r2 = TextNormalizer.normalize('Ok Melodia play Tum Hi Ho');
      expect(r2.usedWakeWord, isTrue);
      expect(r2.normalized, equals('play tum hi ho'));

      final r3 = TextNormalizer.normalize('Melodia next');
      expect(r3.usedWakeWord, isTrue);
      expect(r3.normalized, equals('next'));

      final r4 = TextNormalizer.normalize('pause');
      expect(r4.usedWakeWord, isFalse);
      expect(r4.normalized, equals('pause'));
    });

    test('replaces number words and colloquial durations', () {
      expect(TextNormalizer.normalize('volume forty percent').normalized,
          equals('volume 40 percent'));
      expect(TextNormalizer.normalize('forward half a minute').normalized,
          equals('forward 30 seconds'));
      expect(TextNormalizer.normalize('stop in one and a half minutes').normalized,
          equals('stop in 90 seconds'));
      expect(TextNormalizer.normalize('volume twenty five percent').normalized,
          equals('volume 25 percent'));
      expect(TextNormalizer.normalize('volume a hundred percent').normalized,
          equals('volume 100 percent'));
    });

    test('strips fillers and politeness', () {
      final res = TextNormalizer.normalize(
          'Could you please play music for me kindly');
      expect(res.normalized, equals('play music'));
    });
  });

  group('IntentParser Table-Driven Tests (160+ phrases)', () {
    final testCases = <({String phrase, VoiceIntent? expected, bool wakeWord, ParserMode mode, bool allowSearchWithoutWakeWord})>[
      // Transport (English)
      (phrase: 'play', expected: const Play(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'resume', expected: const Play(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'continue', expected: const Play(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'play music', expected: const Play(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'music play', expected: const Play(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'play some music', expected: const Play(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'start music', expected: const Play(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'pause', expected: const Pause(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'stop the music', expected: const Pause(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'stop music', expected: const Pause(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'music band', expected: const Pause(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'stop', expected: const Stop(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'next', expected: const Next(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'skip', expected: const Next(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'next song', expected: const Next(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'change song', expected: const Next(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'change the song', expected: const Next(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'previous', expected: const Previous(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'previous song', expected: const Previous(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'go back', expected: const Previous(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'start over', expected: const Restart(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'from the beginning', expected: const Restart(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'restart', expected: const Restart(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),

      // Transport Seeking
      (phrase: 'forward 30 seconds', expected: const SeekBy(30), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'fast forward 15 seconds', expected: const SeekBy(15), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'forward thirty seconds', expected: const SeekBy(30), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'back 10 seconds', expected: const SeekBy(-10), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'rewind 20 seconds', expected: const SeekBy(-20), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'skip back 15 seconds', expected: const SeekBy(-15), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'go to 1 minute 30', expected: const SeekTo(90), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'go to 2 minutes', expected: const SeekTo(120), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'seek to 45 seconds', expected: const SeekTo(45), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),

      // Volume (English)
      (phrase: 'volume up', expected: const VolumeUp(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'louder', expected: const VolumeUp(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'volume high', expected: const VolumeUp(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'turn it up', expected: const VolumeUp(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'volume down', expected: const VolumeDown(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'volume low', expected: const VolumeDown(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'lower the volume', expected: const VolumeDown(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'make it quieter', expected: const VolumeDown(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'sound low', expected: const VolumeDown(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'turn it down', expected: const VolumeDown(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'volume 40 percent', expected: const VolumeSet(40), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'set volume to 60 percent', expected: const VolumeSet(60), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'volume forty percent', expected: const VolumeSet(40), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'volume max', expected: const VolumeSet(100), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'maximum volume', expected: const VolumeSet(100), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'volume half', expected: const VolumeSet(50), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'mute', expected: const Mute(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'silence', expected: const Mute(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'unmute', expected: const Unmute(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),

      // Modes
      (phrase: 'shuffle on', expected: const Shuffle(true), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'turn on shuffle', expected: const Shuffle(true), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'shuffle off', expected: const Shuffle(false), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'turn off shuffle', expected: const Shuffle(false), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'repeat all', expected: const Repeat(RepeatMode.all), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'repeat on', expected: const Repeat(RepeatMode.all), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'repeat one', expected: const Repeat(RepeatMode.one), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'repeat this song', expected: const Repeat(RepeatMode.one), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'repeat off', expected: const Repeat(RepeatMode.off), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'turn autoplay on', expected: const Autoplay(true), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'turn on autoplay', expected: const Autoplay(true), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'autoplay on', expected: const Autoplay(true), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'auto play on', expected: const Autoplay(true), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'turn autoplay off', expected: const Autoplay(false), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'turn off autoplay', expected: const Autoplay(false), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'autoplay off', expected: const Autoplay(false), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),

      // Library
      (phrase: 'like this song', expected: const Like(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'like', expected: const Like(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'thumbs up', expected: const Like(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'add to favorites', expected: const Like(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'unlike this song', expected: const Unlike(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'unlike', expected: const Unlike(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'remove like', expected: const Unlike(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'add to playlist Gym', expected: const AddToPlaylist('Gym'), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'add to playlist Workout Chill', expected: const AddToPlaylist('Workout Chill'), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'add to Rock', expected: const AddToPlaylist('Rock'), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),

      // Play Specific Collections
      (phrase: 'play my liked songs', expected: const PlayLiked(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'play liked songs', expected: const PlayLiked(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'play favorites', expected: const PlayLiked(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'play downloaded music', expected: const PlayDownloaded(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'play downloads', expected: const PlayDownloaded(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'offline music', expected: const PlayDownloaded(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'play something similar', expected: const PlayRadio(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'start radio', expected: const PlayRadio(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'play radio', expected: const PlayRadio(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'play playlist Chill Vibes', expected: const PlayPlaylist('Chill Vibes'), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'play playlist gym', expected: const PlayPlaylist('gym'), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),

      // Sleep Timer
      (phrase: 'stop in 20 minutes', expected: const SleepTimer(20), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'sleep in 30 minutes', expected: const SleepTimer(30), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'stop in twenty minutes', expected: const SleepTimer(20), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'cancel sleep timer', expected: const CancelSleepTimer(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'cancel timer', expected: const CancelSleepTimer(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),

      // Navigation
      (phrase: 'open home', expected: const Open(VoiceScreen.home), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'go to home', expected: const Open(VoiceScreen.home), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'open search', expected: const Open(VoiceScreen.search), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'go to search', expected: const Open(VoiceScreen.search), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'open library', expected: const Open(VoiceScreen.library), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'open downloads', expected: const Open(VoiceScreen.downloaded), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'open settings', expected: const Open(VoiceScreen.settings), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'open now playing', expected: const Open(VoiceScreen.nowPlaying), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'open ride mode', expected: const Open(VoiceScreen.rideMode), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'ride mode', expected: const Open(VoiceScreen.rideMode), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),

      // Info and Help
      (phrase: "what's playing", expected: const WhatsPlaying(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'what is playing', expected: const WhatsPlaying(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'what song is this', expected: const WhatsPlaying(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'which song is this', expected: const WhatsPlaying(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'what can i say', expected: const Help(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'help', expected: const Help(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),

      // Offline & Download
      (phrase: 'turn on offline mode', expected: const OfflineMode(true), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'offline mode on', expected: const OfflineMode(true), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'turn off offline mode', expected: const OfflineMode(false), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'offline mode off', expected: const OfflineMode(false), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'download current song', expected: const DownloadCurrent(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'download this song', expected: const DownloadCurrent(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),

      // Voice Control
      (phrase: 'stop listening', expected: const StopListening(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'voice off', expected: const StopListening(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'mic off', expected: const StopListening(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'cancel', expected: const Cancel(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'never mind', expected: const Cancel(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),

      // Urdu & Roman Urdu Transport
      (phrase: 'gana chalao', expected: const Play(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'chalao', expected: const Play(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'music chalao', expected: const Play(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'shuru karo', expected: const Play(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'play karo', expected: const Play(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'ruko', expected: const Pause(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'rok do', expected: const Pause(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'pause karo', expected: const Pause(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'band karo', expected: const Stop(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'stop karo', expected: const Stop(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'agla gana', expected: const Next(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'next gana', expected: const Next(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'agla', expected: const Next(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'gana badlo', expected: const Next(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'pichla gana', expected: const Previous(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'pichla', expected: const Previous(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'pehle wala', expected: const Previous(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),

      // Urdu Script Transport
      (phrase: 'گانا چلاؤ', expected: const Play(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'چلاؤ', expected: const Play(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'میوزک چلاؤ', expected: const Play(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'روکو', expected: const Pause(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'روک دو', expected: const Pause(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'پاز کرو', expected: const Pause(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'بند کرو', expected: const Stop(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'اگلا گانا', expected: const Next(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'اگلا', expected: const Next(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'پچھلا گانا', expected: const Previous(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'پچھلا', expected: const Previous(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),

      // Urdu & Roman Urdu Volume
      (phrase: 'awaz barhao', expected: const VolumeUp(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'awaz ziada karo', expected: const VolumeUp(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'tez karo', expected: const VolumeUp(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'awaz kam karo', expected: const VolumeDown(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'thoda kam', expected: const VolumeDown(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'kam karo', expected: const VolumeDown(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'awaz band', expected: const Mute(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'mute karo', expected: const Mute(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'awaz kholo', expected: const Unmute(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'unmute karo', expected: const Unmute(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'آواز بڑھاؤ', expected: const VolumeUp(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'آواز زیادہ کرو', expected: const VolumeUp(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'آواز کم کرو', expected: const VolumeDown(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'تھوڑا کم', expected: const VolumeDown(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'آواز بند', expected: const Mute(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'میوٹ کرو', expected: const Mute(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),

      // Urdu & Roman Urdu Library, Play, Help, Voice Control
      (phrase: 'pasand karo', expected: const Like(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'like karo', expected: const Like(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'پسند کرو', expected: const Like(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'napasand', expected: const Unlike(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'unlike karo', expected: const Unlike(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'pasandeeda gane chalao', expected: const PlayLiked(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'liked gane chalao', expected: const PlayLiked(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'پسندیدہ گانے چلاؤ', expected: const PlayLiked(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'downloaded gane chalao', expected: const PlayDownloaded(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'radio chalao', expected: const PlayRadio(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'kya chal raha hai', expected: const WhatsPlaying(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'ye konsa gana hai', expected: const WhatsPlaying(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'کیا چل رہا ہے', expected: const WhatsPlaying(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'madad', expected: const Help(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'kya bolu', expected: const Help(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'مدد', expected: const Help(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'sunna band karo', expected: const StopListening(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'mic band karo', expected: const StopListening(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'سننا بند کرو', expected: const StopListening(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'chordo', expected: const Cancel(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'rehne do', expected: const Cancel(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'چھوڑ دو', expected: const Cancel(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'کینسل', expected: const Cancel(), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),

      // Search & Slot Patterns (English & Urdu)
      (phrase: 'play Tum Hi Ho by Arijit Singh', expected: const PlaySearch('Tum Hi Ho by Arijit Singh', kind: SearchKind.song), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'play the album Aashiqui 2', expected: const PlaySearch('Aashiqui 2', kind: SearchKind.album), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'play songs by Atif Aslam', expected: const PlaySearch('Atif Aslam', kind: SearchKind.artist), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'play artist Coldplay', expected: const PlaySearch('Coldplay', kind: SearchKind.artist), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'Arijit Singh chalao', expected: const PlaySearch('Arijit Singh', kind: SearchKind.song), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'Atif Aslam ke gane chalao', expected: const PlaySearch('Atif Aslam', kind: SearchKind.song), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'عاطف اسلم کے گانے چلاؤ', expected: const PlaySearch('عاطف اسلم', kind: SearchKind.song), wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),

      // Wake Word prefixed cases
      (phrase: 'Hey Melodia, pause', expected: const Pause(), wakeWord: true, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'Ok Melodia, next song', expected: const Next(), wakeWord: true, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'Melodia, volume low', expected: const VolumeDown(), wakeWord: true, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'Hey Melodia, play Shape of You', expected: const PlaySearch('Shape of You'), wakeWord: true, mode: ParserMode.strict, allowSearchWithoutWakeWord: false),
      (phrase: 'Hey Melodia, stop in 20 minutes', expected: const SleepTimer(20), wakeWord: true, mode: ParserMode.strict, allowSearchWithoutWakeWord: false),

      // Strict mode: Catch-all search without wake word should be NoMatch
      (phrase: 'play Shape of You', expected: null, wakeWord: false, mode: ParserMode.strict, allowSearchWithoutWakeWord: false),
      // Strict mode: Catch-all search WITH allowSearchWithoutWakeWord flag passes
      (phrase: 'play Shape of You', expected: const PlaySearch('Shape of You'), wakeWord: false, mode: ParserMode.strict, allowSearchWithoutWakeWord: true),

      // Noise inputs returning NoMatch
      (phrase: 'uh', expected: null, wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'mm', expected: null, wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'hmm', expected: null, wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'ha ha', expected: null, wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'ah', expected: null, wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: 'er', expected: null, wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: '', expected: null, wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),
      (phrase: '   ', expected: null, wakeWord: false, mode: ParserMode.normal, allowSearchWithoutWakeWord: false),

      // Strict mode: single-word unknown inputs
      (phrase: 'banana', expected: null, wakeWord: false, mode: ParserMode.strict, allowSearchWithoutWakeWord: false),
      (phrase: 'random', expected: null, wakeWord: false, mode: ParserMode.strict, allowSearchWithoutWakeWord: false),
    ];

    test('verifies total test cases count >= 150', () {
      expect(testCases.length, greaterThanOrEqualTo(150));
    });

    for (final tc in testCases) {
      test('parses "${tc.phrase}" (mode: ${tc.mode.name})', () {
        final res = IntentParser.parse(
          tc.phrase,
          mode: tc.mode,
          allowSearchWithoutWakeWord: tc.allowSearchWithoutWakeWord,
        );

        if (tc.expected == null) {
          expect(res, isA<NoMatch>(),
              reason: 'Expected NoMatch for "${tc.phrase}"');
        } else {
          expect(res, isA<Matched>(),
              reason: 'Expected Matched for "${tc.phrase}"');
          final matched = res as Matched;
          expect(matched.intent, equals(tc.expected),
              reason: 'Intent mismatch for "${tc.phrase}"');
          if (tc.wakeWord) {
            expect(matched.usedWakeWord, isTrue);
          }
        }
      });
    }
  });

  group('CommandDeduper', () {
    test('allows different commands immediately', () {
      final deduper = CommandDeduper(window: const Duration(seconds: 2));
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      expect(deduper.shouldExecute(const Play(), now: t0), isTrue);
      expect(deduper.shouldExecute(const Pause(), now: t0), isTrue);
      expect(deduper.shouldExecute(const Next(), now: t0), isTrue);
    });

    test('suppresses same command within 2 seconds window', () {
      final deduper = CommandDeduper(window: const Duration(seconds: 2));
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      final t1 = DateTime(2026, 1, 1, 12, 0, 1);
      final t2 = DateTime(2026, 1, 1, 12, 0, 2, 500);

      expect(deduper.shouldExecute(const Play(), now: t0), isTrue);
      expect(deduper.shouldExecute(const Play(), now: t1), isFalse); // duplicate within 2s
      expect(deduper.shouldExecute(const Play(), now: t2), isTrue); // after 2.5s -> allowed
    });

    test('reset clears history', () {
      final deduper = CommandDeduper(window: const Duration(seconds: 2));
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      expect(deduper.shouldExecute(const Play(), now: t0), isTrue);
      deduper.reset();
      expect(deduper.shouldExecute(const Play(), now: t0), isTrue);
    });
  });

  group('PhraseTables generator check', () {
    test('generateMarkdownTable produces comprehensive Markdown table', () {
      final md = PhraseTables.generateMarkdownTable();
      expect(md, contains('| Category | Command / Pattern | Intent | Description |'));
      expect(md, contains('"play"'));
      expect(md, contains('"pause"'));
      expect(md, contains('"next"'));
      expect(md, contains('"gana chalao"'));
      expect(md, contains('"گانا چلاؤ"'));
      expect(md, contains('"play {song} by {artist}"'));
    });
  });
}
