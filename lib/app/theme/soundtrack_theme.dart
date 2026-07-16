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
  static const destructiveContainer = Color(0xFF3A2328);

  static const pagePadding = 16.0;
  static const sectionGap = 20.0;
  static const rowMinHeight = 64.0;
  static const targetMinSize = 48.0;
}

ThemeData buildSoundTrackTheme() {
  const scheme = ColorScheme.dark(
    primary: SoundTrackTokens.accent,
    onPrimary: SoundTrackTokens.onAccent,
    primaryContainer: SoundTrackTokens.elevatedSurface,
    onPrimaryContainer: SoundTrackTokens.primaryText,
    secondary: SoundTrackTokens.accent,
    onSecondary: SoundTrackTokens.onAccent,
    secondaryContainer: SoundTrackTokens.elevatedSurface,
    onSecondaryContainer: SoundTrackTokens.primaryText,
    surface: SoundTrackTokens.surface,
    onSurface: SoundTrackTokens.primaryText,
    surfaceDim: SoundTrackTokens.background,
    surfaceBright: SoundTrackTokens.elevatedSurface,
    surfaceContainerLowest: SoundTrackTokens.background,
    surfaceContainerLow: SoundTrackTokens.surface,
    surfaceContainer: SoundTrackTokens.surface,
    surfaceContainerHigh: SoundTrackTokens.elevatedSurface,
    surfaceContainerHighest: SoundTrackTokens.border,
    onSurfaceVariant: SoundTrackTokens.secondaryText,
    outline: SoundTrackTokens.secondaryText,
    outlineVariant: SoundTrackTokens.border,
    error: SoundTrackTokens.destructive,
    onError: SoundTrackTokens.background,
    errorContainer: SoundTrackTokens.destructiveContainer,
    onErrorContainer: SoundTrackTokens.primaryText,
    surfaceTint: SoundTrackTokens.accent,
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
