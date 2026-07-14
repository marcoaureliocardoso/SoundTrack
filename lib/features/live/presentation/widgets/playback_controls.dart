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
    final colors = Theme.of(context).colorScheme;
    final inactiveForeground = colors.onSurfaceVariant;
    final hasCurrent = playback.activeMomentId != null;
    final paused = playback.phase == PlaybackPhase.paused;
    final pause = _Control(
      key: pausePlaybackKey,
      icon: paused ? Icons.play_arrow : Icons.pause,
      label: paused ? 'Retomar' : 'Pausar',
      compact: widget.compact,
      disabledForegroundColor: inactiveForeground,
      onPressed: hasCurrent && !_transportBusy
          ? () => _runTransport(paused ? widget.onResume : widget.onPause)
          : null,
    );
    final stop = _Control(
      key: stopPlaybackKey,
      icon: Icons.stop,
      label: 'Parar',
      compact: widget.compact,
      disabledForegroundColor: inactiveForeground,
      onPressed: hasCurrent && !_stopBusy ? _runStop : null,
    );
    final narrationLabel = playback.narrationActive
        ? 'Narração ativa'
        : 'Narração inativa';
    final narrationEnabled = widget.narrationAvailable && !_narrationBusy;
    final compactNarrationForeground = playback.narrationActive
        ? colors.onSecondaryContainer
        : narrationEnabled
        ? colors.onSurface
        : inactiveForeground;
    final compactNarration = Semantics(
      label: narrationLabel,
      button: true,
      toggled: playback.narrationActive,
      enabled: narrationEnabled,
      excludeSemantics: true,
      child: Material(
        color: playback.narrationActive
            ? colors.secondaryContainer
            : Colors.transparent,
        child: InkWell(
          key: narrationKey,
          onTap: narrationEnabled
              ? () => _runNarration(!playback.narrationActive)
              : null,
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                const SizedBox(width: 8),
                Icon(Icons.mic, size: 20, color: compactNarrationForeground),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    narrationLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: compactNarrationForeground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
    final narration = Semantics(
      label: narrationLabel,
      enabled: narrationEnabled,
      child: FilterChip(
        key: narrationKey,
        avatar: Icon(
          Icons.mic,
          size: 20,
          color: narrationEnabled ? null : inactiveForeground,
        ),
        label: Text(
          narrationLabel,
          style: narrationEnabled
              ? null
              : Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: inactiveForeground),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        side: narrationEnabled ? null : BorderSide(color: inactiveForeground),
        selected: playback.narrationActive,
        visualDensity: widget.compact
            ? VisualDensity.compact
            : VisualDensity.standard,
        onSelected: narrationEnabled ? _runNarration : null,
      ),
    );
    if (widget.compact) {
      return SizedBox(
        height: 50,
        child: Card(
          margin: EdgeInsets.zero,
          child: Row(
            children: [
              pause,
              stop,
              const SizedBox(width: 4),
              Expanded(child: compactNarration),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [pause, stop, narration],
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
    required this.disabledForegroundColor,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool compact;
  final Color disabledForegroundColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          style: IconButton.styleFrom(
            disabledForegroundColor: disabledForegroundColor,
          ),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: onPressed,
          tooltip: label,
          icon: Icon(icon),
        ),
        if (!compact)
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: enabled ? null : disabledForegroundColor,
            ),
          ),
      ],
    );
  }
}
