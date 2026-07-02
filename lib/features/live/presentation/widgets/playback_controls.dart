import 'dart:async';

import 'package:flutter/material.dart';

import '../../../playback/domain/playback_snapshot.dart';
import '../live_dashboard_keys.dart';

class PlaybackControls extends StatelessWidget {
  const PlaybackControls({
    required this.playback,
    required this.narrationAvailable,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onNarrationChanged,
    super.key,
  });

  final PlaybackSnapshot playback;
  final bool narrationAvailable;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;
  final Future<void> Function() onStop;
  final Future<void> Function(bool active) onNarrationChanged;

  @override
  Widget build(BuildContext context) {
    final hasCurrent = playback.activeMomentId != null;
    final paused = playback.phase == PlaybackPhase.paused;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _Control(
              key: pausePlaybackKey,
              icon: paused ? Icons.play_arrow : Icons.pause,
              label: paused ? 'Retomar' : 'Pausar',
              onPressed: hasCurrent
                  ? () => unawaited(paused ? onResume() : onPause())
                  : null,
            ),
            _Control(
              key: stopPlaybackKey,
              icon: Icons.stop,
              label: 'Parar',
              onPressed: hasCurrent ? () => unawaited(onStop()) : null,
            ),
            Semantics(
              label: playback.narrationActive
                  ? 'Narração ativa'
                  : 'Narração inativa',
              enabled: narrationAvailable,
              child: FilterChip(
                key: narrationKey,
                avatar: const Icon(Icons.mic, size: 20),
                label: Text(
                  playback.narrationActive
                      ? 'Narração ativa'
                      : 'Narração inativa',
                ),
                selected: playback.narrationActive,
                onSelected: narrationAvailable
                    ? (active) => unawaited(onNarrationChanged(active))
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: onPressed,
          tooltip: label,
          icon: Icon(icon),
        ),
        Text(label),
      ],
    );
  }
}
