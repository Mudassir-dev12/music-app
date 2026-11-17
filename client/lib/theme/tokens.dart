import 'package:flutter/material.dart';

/// All design tokens for the Melodia app — colours, type scale, spacing,
/// radii, shadows, and breakpoints — exposed as a [ThemeExtension] so they
/// are always available via `Theme.of(context).extension<MelodiaTokens>()!`.
@immutable
class MelodiaTokens extends ThemeExtension<MelodiaTokens> {
  const MelodiaTokens({
    required this.background,
    required this.surface,
    required this.surface2,
    required this.separator,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.destructive,
    this.statusOnline = const Color(0xFF34C759),
    this.statusWarning = const Color(0xFFFF9F0A),
    this.statusOffline = const Color(0xFFFF453A),
    this.transparent = const Color(0x00000000),
  });

  // ── Colours ──────────────────────────────────────────────────────────────
  final Color background;
  final Color surface;
  final Color surface2;
  final Color separator;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color destructive;
  final Color statusOnline;
  final Color statusWarning;
  final Color statusOffline;
  final Color transparent;

  // ── Type scale ───────────────────────────────────────────────────────────
  static const TextStyle largeTitle = TextStyle(fontSize: 34, fontWeight: FontWeight.w700);
  static const TextStyle title1     = TextStyle(fontSize: 28, fontWeight: FontWeight.w700);
  static const TextStyle title2     = TextStyle(fontSize: 22, fontWeight: FontWeight.w700);
  static const TextStyle title3     = TextStyle(fontSize: 20, fontWeight: FontWeight.w600);
  static const TextStyle headline   = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
  static const TextStyle body       = TextStyle(fontSize: 17, fontWeight: FontWeight.w400);
  static const TextStyle callout    = TextStyle(fontSize: 16, fontWeight: FontWeight.w400);
  static const TextStyle subhead    = TextStyle(fontSize: 15, fontWeight: FontWeight.w400);
  static const TextStyle footnote   = TextStyle(fontSize: 13, fontWeight: FontWeight.w400);
  static const TextStyle caption    = TextStyle(fontSize: 12, fontWeight: FontWeight.w400);

  // ── Spacing ──────────────────────────────────────────────────────────────
  static const double spacingXs   =  4;
  static const double spacingSm   =  8;
  static const double spacingMd   = 12;
  static const double spacingLg   = 16;
  static const double spacingXl   = 20;
  static const double spacingXxl  = 24;
  static const double spacingXxxl = 32;
  static const double spacingPage = 40;

  // ── Radii ────────────────────────────────────────────────────────────────
  static const double radiusArtworkSm =  6;
  static const double radiusCard      = 10;
  static const double radiusHero      = 12;
  static const double radiusSheet     = 14;

  // ── Shadows ──────────────────────────────────────────────────────────────
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x59000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  // ── Breakpoints (logical pixels) ─────────────────────────────────────────
  static const double breakpointPhone   = 768;
  static const double breakpointTablet  = 1024;
  // desktop >= 1024

  // ── Dark palette ─────────────────────────────────────────────────────────
  static const MelodiaTokens dark = MelodiaTokens(
    background:    Color(0xFF000000),
    surface:       Color(0xFF1C1C1E),
    surface2:      Color(0xFF2C2C2E),
    separator:     Color(0xA6545458), // rgba(84,84,88,0.65)
    text:          Color(0xFFFFFFFF),
    textSecondary: Color(0x99EBEBF5), // rgba(235,235,245,0.60)
    textTertiary:  Color(0x4DEBEBF5), // rgba(235,235,245,0.30)
    accent:        Color(0xFFFA233B),
    destructive:   Color(0xFFFF453A),
    statusOnline:  Color(0xFF30D158),
    statusWarning: Color(0xFFFF9F0A),
    statusOffline: Color(0xFFFF453A),
  );

  // ── Light palette ────────────────────────────────────────────────────────
  static const MelodiaTokens light = MelodiaTokens(
    background:    Color(0xFFFFFFFF),
    surface:       Color(0xFFF2F2F7),
    surface2:      Color(0xFFE5E5EA),
    separator:     Color(0x4A3C3C43), // rgba(60,60,67,0.29)
    text:          Color(0xFF000000),
    textSecondary: Color(0x993C3C43), // rgba(60,60,67,0.60)
    textTertiary:  Color(0x4D3C3C43), // rgba(60,60,67,0.30)
    accent:        Color(0xFFFA2D48),
    destructive:   Color(0xFFFF453A),
    statusOnline:  Color(0xFF34C759),
    statusWarning: Color(0xFFFF9500),
    statusOffline: Color(0xFFFF3B30),
  );

  // ── ThemeExtension overrides ─────────────────────────────────────────────
  @override
  MelodiaTokens copyWith({
    Color? background,
    Color? surface,
    Color? surface2,
    Color? separator,
    Color? text,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? destructive,
    Color? statusOnline,
    Color? statusWarning,
    Color? statusOffline,
  }) {
    return MelodiaTokens(
      background:    background    ?? this.background,
      surface:       surface       ?? this.surface,
      surface2:      surface2      ?? this.surface2,
      separator:     separator     ?? this.separator,
      text:          text          ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary:  textTertiary  ?? this.textTertiary,
      accent:        accent        ?? this.accent,
      destructive:   destructive   ?? this.destructive,
      statusOnline:  statusOnline  ?? this.statusOnline,
      statusWarning: statusWarning ?? this.statusWarning,
      statusOffline: statusOffline ?? this.statusOffline,
      transparent:   transparent,
    );
  }

  @override
  MelodiaTokens lerp(MelodiaTokens other, double t) {
    return MelodiaTokens(
      background:    Color.lerp(background,    other.background,    t)!,
      surface:       Color.lerp(surface,       other.surface,       t)!,
      surface2:      Color.lerp(surface2,      other.surface2,      t)!,
      separator:     Color.lerp(separator,     other.separator,     t)!,
      text:          Color.lerp(text,          other.text,          t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary:  Color.lerp(textTertiary,  other.textTertiary,  t)!,
      accent:        Color.lerp(accent,        other.accent,        t)!,
      destructive:   Color.lerp(destructive,   other.destructive,   t)!,
      statusOnline:  Color.lerp(statusOnline,  other.statusOnline,  t)!,
      statusWarning: Color.lerp(statusWarning, other.statusWarning, t)!,
      statusOffline: Color.lerp(statusOffline, other.statusOffline, t)!,
      transparent:   transparent,
    );
  }
}
