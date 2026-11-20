class NormalizedText {
  const NormalizedText({
    required this.normalized,
    required this.usedWakeWord,
    required this.originalText,
  });

  /// Fully normalized text (lowercased, numbers converted, fillers and wake word stripped).
  final String normalized;

  /// True if the utterance began with an accepted wake word ("Hey Melodia", "Ok Melodia", etc.).
  final bool usedWakeWord;

  /// Original raw text, with wake word removed, suitable for extracting search queries with casing.
  final String originalText;

  @override
  String toString() =>
      'NormalizedText(normalized: "$normalized", usedWakeWord: $usedWakeWord)';
}

class TextNormalizer {
  const TextNormalizer._();

  static const List<String> _wakeWords = [
    'hey melodia',
    'ok melodia',
    'okay melodia',
    'hi melodia',
    'hello melodia',
    'melodia',
  ];

  static const List<String> _fillers = [
    'please',
    'can you',
    'could you',
    'would you',
    'kindly',
    'for me',
    'zara',
    'meherbani',
    'bhai',
    'plz',
  ];

  // Number words conversion
  static const Map<String, int> _numberWords = {
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fourty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
    'hundred': 100,
  };

  /// Normalizes an input transcript string.
  static NormalizedText normalize(String input) {
    if (input.trim().isEmpty) {
      return const NormalizedText(
        normalized: '',
        usedWakeWord: false,
        originalText: '',
      );
    }

    String working = input.trim();

    // 1. Convert Urdu and Eastern Arabic digits
    working = _convertIndicDigits(working);

    // 2. Check for wake word prefix
    bool wakeWordFound = false;
    String lower = working.toLowerCase();
    for (final wake in _wakeWords) {
      if (lower == wake) {
        wakeWordFound = true;
        working = '';
        lower = '';
        break;
      } else if (lower.startsWith('$wake ') ||
          lower.startsWith('$wake,') ||
          lower.startsWith('$wake.')) {
        wakeWordFound = true;
        working = working.substring(wake.length).trim();
        // Strip leading comma or period if left behind
        working = working.replaceFirst(RegExp(r'^[,\.\s]+'), '');
        lower = working.toLowerCase();
        break;
      }
    }

    final originalClean = working.trim();

    // 3. Lowercase and normalize common phonetics / variants
    String norm = lower;
    norm = norm.replaceAll(RegExp(r'\bauto[\s\-]play\b'), 'autoplay');

    // Remove punctuation
    norm = norm.replaceAll(RegExp(r'[,\.!?;:"\(\)\[\]\{\}\<\>/\\]'), ' ');

    // 4. Handle time phrases like "half a minute", "one and a half minutes"
    norm = norm.replaceAll('half a minute', '30 seconds');
    norm = norm.replaceAll('half an hour', '30 minutes');
    norm = norm.replaceAll('one and a half minutes', '90 seconds');
    norm = norm.replaceAll('one and a half hours', '90 minutes');

    // 5. Replace number words with digits (e.g., "twenty five" -> "25")
    norm = _replaceNumberWords(norm);

    // 6. Strip filler words
    norm = _stripFillers(norm);

    // 7. Collapse spaces
    norm = norm.replaceAll(RegExp(r'\s+'), ' ').trim();

    return NormalizedText(
      normalized: norm,
      usedWakeWord: wakeWordFound,
      originalText: originalClean,
    );
  }

  static String _convertIndicDigits(String str) {
    const indicDigits = {
      '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
      '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
      '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
      '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    };
    final sb = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      final ch = str[i];
      sb.write(indicDigits[ch] ?? ch);
    }
    return sb.toString();
  }

  static String _replaceNumberWords(String text) {
    final tokens = text.split(RegExp(r'\s+'));
    final result = <String>[];
    int i = 0;

    while (i < tokens.length) {
      final tok = tokens[i];
      if (_numberWords.containsKey(tok)) {
        int val = _numberWords[tok]!;
        // Check for compound numbers like "twenty five", "forty two", "a hundred"
        if (i + 1 < tokens.length && _numberWords.containsKey(tokens[i + 1])) {
          final nextVal = _numberWords[tokens[i + 1]]!;
          if (const [20, 30, 40, 50, 60, 70, 80, 90].contains(val) && nextVal < 10) {
            val += nextVal;
            i++;
          }
        }
        result.add(val.toString());
      } else if (tok == 'a' && i + 1 < tokens.length && tokens[i + 1] == 'hundred') {
        result.add('100');
        i++;
      } else {
        result.add(tok);
      }
      i++;
    }

    return result.join(' ');
  }

  static String _stripFillers(String text) {
    String res = text;
    for (final filler in _fillers) {
      res = res.replaceAll(RegExp(r'\b' + RegExp.escape(filler) + r'\b'), ' ');
    }
    return res;
  }
}
