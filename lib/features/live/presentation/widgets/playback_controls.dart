import 'package:flutter/material.dart';

import '../../../../app/theme/soundtrack_theme.dart';
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
    final narrationLabel = playback.narrationActive
        ? 'Narração ativa'
        : 'Narração inativa';
    final narrationEnabled = widget.narrationAvailable && !_narrationBusy;

    return Material(
      key: playbackFooterKey,
      color: SoundTrackTokens.surface,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 100,
              child: _DockControl(
                controlKey: pausePlaybackKey,
                icon: paused ? Icons.play_arrow : Icons.pause,
                label: paused ? 'Retomar' : 'Pausar',
                showLabel: !widget.compact,
                foreground: hasCurrent ? colors.onSurface : inactiveForeground,
                background: colors.surfaceContainerHigh,
                onPressed: hasCurrent && !_transportBusy
                    ? () => _runTransport(
                        paused ? widget.onResume : widget.onPause,
                      )
                    : null,
              ),
            ),
            Expanded(
              flex: 100,
              child: _DockControl(
                controlKey: stopPlaybackKey,
                icon: Icons.stop,
                label: 'Parar',
                showLabel: !widget.compact,
                foreground: hasCurrent
                    ? SoundTrackTokens.destructive
                    : inactiveForeground,
                borderColor: hasCurrent
                    ? SoundTrackTokens.destructive
                    : SoundTrackTokens.border,
                onPressed: hasCurrent && !_stopBusy ? _runStop : null,
              ),
            ),
            Expanded(
              flex: 135,
              child: _DockControl(
                controlKey: narrationKey,
                icon: Icons.mic,
                label: narrationLabel,
                showLabel: !widget.compact,
                toggled: playback.narrationActive,
                foreground: narrationEnabled || playback.narrationActive
                    ? colors.primary
                    : inactiveForeground,
                background: playback.narrationActive
                    ? colors.primary.withValues(alpha: .12)
                    : Colors.transparent,
                onPressed: narrationEnabled
                    ? () => _runNarration(!playback.narrationActive)
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

class _DockControl extends StatelessWidget {
  const _DockControl({
    required this.controlKey,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.foreground,
    required this.showLabel,
    this.background = Colors.transparent,
    this.borderColor,
    this.toggled,
  });

  final Key controlKey;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color foreground;
  final bool showLabel;
  final Color background;
  final Color? borderColor;
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      label: label,
      button: true,
      enabled: enabled,
      toggled: toggled,
      excludeSemantics: true,
      child: Material(
        color: background,
        child: InkWell(
          key: controlKey,
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(
              minWidth: SoundTrackTokens.targetMinSize,
              minHeight: 64,
            ),
            decoration: borderColor == null
                ? null
                : BoxDecoration(border: Border.all(color: borderColor!)),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: label,
                  child: Icon(icon, color: foreground),
                ),
                if (showLabel) ...[
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: foreground),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
