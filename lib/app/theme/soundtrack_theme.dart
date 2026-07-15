import 'package:flutter/material.dart';

abstract final class SoundTrackTokens {
  static const background = Color(0xFF091315);
  static const surface = Color(0xFF111F21);
  static const elevatedSurface = Color(0xFF182B2C);
  static const border = Color(0xFF263638);
  static const primaryText = Color(0xFFEDF7F5);
  static const secondaryText = Color(0xFF8FA19F);
  static const accent = Color(0xFF73D2C7);
  static const onAccent = Color(0xFF092426);
  static const warning = Color(0xFFD0B66F);
  static const destructive = Color(0xFFCC9DA4);

  static const pagePadding = 16.0;
  static const sectionGap = 20.0;
  static const rowMinHeight = 64.0;
  static const targetMinSize = 48.0;
}

ThemeData buildSoundTrackTheme() {
  const scheme = ColorScheme.dark(
    primary: SoundTrackTokens.accent,
    onPrimary: SoundTrackTokens.onAccent,
    surface: SoundTrackTokens.surface,
    onSurface: SoundTrackTokens.primaryText,
    error: SoundTrackTokens.destructive,
    onError: SoundTrackTokens.background,
  );
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: SoundTrackTokens.background,
    colorScheme: scheme,
    dividerColor: SoundTrackTokens.border,
    cardTheme: const CardThemeData(
      color: SoundTrackTokens.surface,
      margin: EdgeInsets.zero,
    ),
    textTheme: ThemeData.dark().textTheme.apply(
      bodyColor: SoundTrackTokens.primaryText,
      displayColor: SoundTrackTokens.primaryText,
    ),
  );
}
