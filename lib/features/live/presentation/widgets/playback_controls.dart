import 'package:flutter/material.dart';

import '../../../playback/domain/playback_snapshot.dart';
import '../live_dashboard_keys.dart';

class PlaybackControls extends StatefulWidget {
  const PlaybackControls({
    required this.playback,
    required this.narrationAvailable,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onNarrationChanged,
    this.compact = false,
    super.key,
  });

  final PlaybackSnapshot playback;
  final bool narrationAvailable;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;
  final Future<void> Function() onStop;
  final Future<void> Function(bool active) onNarrationChanged;
  final bool compact;

  @override
  State<PlaybackControls> createState() => _PlaybackControlsState();
}

class _PlaybackControlsState extends State<PlaybackControls> {
  var _transportBusy = false;
  var _narrationBusy = false;
  var _stopBusy = false;

  @override
  Widget build(BuildContext context) {
    final playback = widget.playback;
    final hasCurrent = playback.activeMomentId != null;
    final paused = playback.phase == PlaybackPhase.paused;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 2 : 12),
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
              compact: widget.compact,
              onPressed: hasCurrent && !_transportBusy
                  ? () =>
                        _runTransport(paused ? widget.onResume : widget.onPause)
                  : null,
            ),
            _Control(
              key: stopPlaybackKey,
              icon: Icons.stop,
              label: 'Parar',
              compact: widget.compact,
              onPressed: hasCurrent && !_stopBusy ? _runStop : null,
            ),
            Semantics(
              label: playback.narrationActive
                  ? 'Narração ativa'
                  : 'Narração inativa',
              enabled: widget.narrationAvailable && !_narrationBusy,
              child: FilterChip(
                key: narrationKey,
                avatar: const Icon(Icons.mic, size: 20),
                label: Text(
                  playback.narrationActive
                      ? 'Narração ativa'
                      : 'Narração inativa',
                ),
                selected: playback.narrationActive,
                visualDensity: widget.compact
                    ? VisualDensity.compact
                    : VisualDensity.standard,
                onSelected: widget.narrationAvailable && !_narrationBusy
                    ? _runNarration
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runTransport(Future<void> Function() command) async {
    if (_transportBusy) return;
    setState(() => _transportBusy = true);
    try {
      await command();
    } catch (_) {
      // The controller publishes the operator-facing alert.
    } finally {
      if (mounted) {
        setState(() => _transportBusy = false);
      }
    }
  }

  Future<void> _runNarration(bool active) async {
    if (_narrationBusy) return;
    setState(() => _narrationBusy = true);
    try {
      await widget.onNarrationChanged(active);
    } catch (_) {
      // The controller publishes the operator-facing alert.
    } finally {
      if (mounted) {
        setState(() => _narrationBusy = false);
      }
    }
  }

  Future<void> _runStop() async {
    if (_stopBusy) return;
    setState(() => _stopBusy = true);
    try {
      await widget.onStop();
    } catch (_) {
      // The controller publishes the operator-facing alert.
    } finally {
      if (mounted) {
        setState(() => _stopBusy = false);
      }
    }
  }
}

class _Control extends StatelessWidget {
  const _Control({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.compact,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool compact;

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
        if (!compact) Text(label),
      ],
    );
  }
}
