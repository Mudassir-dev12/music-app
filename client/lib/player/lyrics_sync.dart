import '../api/discovery_models.dart';

/// Pure Dart helper to locate the active lyric line index by current position in milliseconds.
int findCurrentLyricIndex(List<LyricLine> lines, int currentPositionMs) {
  if (lines.isEmpty) return -1;
  if (currentPositionMs < lines.first.startMs) return -1;
  if (currentPositionMs >= lines.last.startMs) return lines.length - 1;

  // Binary search for largest index where lines[index].startMs <= currentPositionMs
  int low = 0;
  int high = lines.length - 1;
  int result = 0;

  while (low <= high) {
    final mid = (low + high) ~/ 2;
    if (lines[mid].startMs <= currentPositionMs) {
      result = mid;
      low = mid + 1; // Try to find a later matching line
    } else {
      high = mid - 1;
    }
  }

  return result;
}
