import 'package:flutter/material.dart';
import 'tokens.dart';

/// Builds [ThemeData] for dark and light modes using [MelodiaTokens].
///
/// Font family uses an Apple-system-style fallback stack.
/// No external font downloads are required.
abstract final class AppTheme {
  static const List<String> _fontFamilyFallback = [
    '-apple-system',
    'BlinkMacSystemFont',
    'Inter',
    'Roboto',
    'Segoe UI',
  ];

  static ThemeData _base({
    required Brightness brightness,
    required MelodiaTokens tokens,
    required ColorScheme colorScheme,
  }) {
    final textTheme = TextTheme(
      displayLarge:  MelodiaTokens.largeTitle.copyWith(color: tokens.text, fontFamilyFallback: _fontFamilyFallback),
      displayMedium: MelodiaTokens.title1.copyWith(color: tokens.text,     fontFamilyFallback: _fontFamilyFallback),
      displaySmall:  MelodiaTokens.title2.copyWith(color: tokens.text,     fontFamilyFallback: _fontFamilyFallback),
      headlineMedium:MelodiaTokens.title3.copyWith(color: tokens.text,     fontFamilyFallback: _fontFamilyFallback),
      headlineSmall: MelodiaTokens.headline.copyWith(color: tokens.text,   fontFamilyFallback: _fontFamilyFallback),
      bodyLarge:     MelodiaTokens.body.copyWith(color: tokens.text,       fontFamilyFallback: _fontFamilyFallback),
      bodyMedium:    MelodiaTokens.callout.copyWith(color: tokens.textSecondary, fontFamilyFallback: _fontFamilyFallback),
      bodySmall:     MelodiaTokens.footnote.copyWith(color: tokens.textSecondary, fontFamilyFallback: _fontFamilyFallback),
      labelLarge:    MelodiaTokens.subhead.copyWith(color: tokens.text,    fontFamilyFallback: _fontFamilyFallback),
      labelSmall:    MelodiaTokens.caption.copyWith(color: tokens.textTertiary, fontFamilyFallback: _fontFamilyFallback),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.background,
      extensions: <ThemeExtension<dynamic>>[tokens],
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.background,
        foregroundColor: tokens.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: MelodiaTokens.headline.copyWith(
          color: tokens.text,
          fontFamilyFallback: _fontFamilyFallback,
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.separator,
        thickness: 0.5,
      ),
      iconTheme: IconThemeData(color: tokens.text),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: tokens.surface,
        selectedItemColor: tokens.accent,
        unselectedItemColor: tokens.textSecondary,
      ),
    );
  }

  static ThemeData get dark {
    const tokens = MelodiaTokens.dark;
    final cs = ColorScheme.dark(
      primary: tokens.accent,
      onPrimary: Colors.white,
      surface: tokens.surface,
      onSurface: tokens.text,
      error: tokens.destructive,
    );
    return _base(brightness: Brightness.dark, tokens: tokens, colorScheme: cs);
  }

  static ThemeData get light {
    const tokens = MelodiaTokens.light;
    final cs = ColorScheme.light(
      primary: tokens.accent,
      onPrimary: Colors.white,
      surface: tokens.surface,
      onSurface: tokens.text,
      error: tokens.destructive,
    );
    return _base(brightness: Brightness.light, tokens: tokens, colorScheme: cs);
  }
}
