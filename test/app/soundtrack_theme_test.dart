import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/app/theme/soundtrack_theme.dart';

import '../support/color_contrast.dart';

void main() {
  test('uses the approved dark palette with AA contrast', () {
    final theme = buildSoundTrackTheme();

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF091315));
    expect(theme.colorScheme.primary, const Color(0xFF73D2C7));
    expect(theme.colorScheme.surface, const Color(0xFF111F21));
    expect(theme.dividerColor, const Color(0xFF263638));
    expect(
      contrastRatio(theme.colorScheme.onSurface, theme.scaffoldBackgroundColor),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrastRatio(theme.colorScheme.onPrimary, theme.colorScheme.primary),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('exposes the approved spacing and status tokens', () {
    expect(SoundTrackTokens.pagePadding, 16);
    expect(SoundTrackTokens.sectionGap, 20);
    expect(SoundTrackTokens.rowMinHeight, 64);
    expect(SoundTrackTokens.targetMinSize, 48);
    expect(SoundTrackTokens.warning, const Color(0xFFD0B66F));
    expect(SoundTrackTokens.destructive, const Color(0xFFCC9DA4));
  });
}
