import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/api/discovery_models.dart';
import 'package:melodia/player/lyrics_sync.dart';

void main() {
  group('Lyrics Sync - findCurrentLyricIndex', () {
    final lines = [
      const LyricLine(startMs: 1000, text: 'First line'),
      const LyricLine(startMs: 3000, text: 'Second line'),
      const LyricLine(startMs: 6000, text: 'Third line'),
      const LyricLine(startMs: 10000, text: 'Final line'),
    ];

    test('returns -1 for empty list', () {
      expect(findCurrentLyricIndex([], 2000), equals(-1));
    });

    test('returns -1 before the first line starts', () {
      expect(findCurrentLyricIndex(lines, 0), equals(-1));
      expect(findCurrentLyricIndex(lines, 999), equals(-1));
    });

    test('exact match on first line', () {
      expect(findCurrentLyricIndex(lines, 1000), equals(0));
    });

    test('between first and second line', () {
      expect(findCurrentLyricIndex(lines, 2500), equals(0));
    });

    test('exact match on second line', () {
      expect(findCurrentLyricIndex(lines, 3000), equals(1));
    });

    test('between second and third line', () {
      expect(findCurrentLyricIndex(lines, 4500), equals(1));
    });

    test('exact match on third line', () {
      expect(findCurrentLyricIndex(lines, 6000), equals(2));
    });

    test('exact match on last line', () {
      expect(findCurrentLyricIndex(lines, 10000), equals(3));
    });

    test('after the last line', () {
      expect(findCurrentLyricIndex(lines, 15000), equals(3));
    });

    test('handles single line list', () {
      final single = [const LyricLine(startMs: 2000, text: 'Only line')];
      expect(findCurrentLyricIndex(single, 1000), equals(-1));
      expect(findCurrentLyricIndex(single, 2000), equals(0));
      expect(findCurrentLyricIndex(single, 5000), equals(0));
    });
  });
}
