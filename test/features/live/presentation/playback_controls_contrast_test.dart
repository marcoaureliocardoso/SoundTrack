import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/live/presentation/live_dashboard_keys.dart';
import 'package:soundtrack/features/live/presentation/widgets/playback_controls.dart';
import 'package:soundtrack/features/playback/domain/playback_snapshot.dart';

import '../../../support/color_contrast.dart';

void main() {
  testWidgets('keeps inactive transport and narration controls legible', (
    tester,
  ) async {
    final theme = _darkTheme();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: PlaybackControls(
            playback: const PlaybackSnapshot.idle(),
            narrationAvailable: false,
            onPause: _noop,
            onResume: _noop,
            onStop: _noop,
            onNarrationChanged: (_) async {},
          ),
        ),
      ),
    );

    final inactive = theme.colorScheme.onSurfaceVariant;
    for (final label in ['Pausar', 'Parar', 'Narração inativa']) {
      expect(tester.widget<Text>(find.text(label)).style?.color, inactive);
    }
    for (final key in [pausePlaybackKey, stopPlaybackKey]) {
      final button = tester.widget<IconButton>(
        find.descendant(of: find.byKey(key), matching: find.byType(IconButton)),
      );
      expect(
        button.style?.foregroundColor?.resolve({WidgetState.disabled}),
        inactive,
      );
    }
    final chip = tester.widget<FilterChip>(find.byKey(narrationKey));
    expect((chip.avatar! as Icon).color, inactive);
    expect(chip.side?.color, inactive);
    expect(
      contrastRatio(inactive, theme.colorScheme.surfaceContainerLow),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('keeps compact inactive narration legible and disabled', (
    tester,
  ) async {
    final theme = _darkTheme();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: PlaybackControls(
            playback: const PlaybackSnapshot.idle(),
            narrationAvailable: false,
            compact: true,
            onPause: _noop,
            onResume: _noop,
            onStop: _noop,
            onNarrationChanged: (_) async {},
          ),
        ),
      ),
    );

    final inactive = theme.colorScheme.onSurfaceVariant;
    final narration = find.byKey(narrationKey);
    expect(
      tester
          .widget<Icon>(
            find.descendant(of: narration, matching: find.byType(Icon)),
          )
          .color,
      inactive,
    );
    expect(
      tester.widget<Text>(find.text('Narração inativa')).style?.color,
      inactive,
    );
    expect(tester.widget<InkWell>(narration).onTap, isNull);
    expect(
      contrastRatio(inactive, theme.colorScheme.surfaceContainerLow),
      greaterThanOrEqualTo(4.5),
    );
  });
}

ThemeData _darkTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );
}

Future<void> _noop() async {}
