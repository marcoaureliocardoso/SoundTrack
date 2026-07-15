import 'package:flutter/material.dart';

import '../../../playback/domain/playback_snapshot.dart';
import '../live_dashboard_keys.dart';

class PlaybackControls extends StatefulWidget {
  const PlaybackControls({
    required this.playback,
    required this.narrationAvailable,
    required this.volumesExpanded,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onNarrationChanged,
    required this.onVolumesToggle,
    this.compact = false,
    super.key,
  });

  final PlaybackSnapshot playback;
  final bool narrationAvailable;
  final bool volumesExpanded;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;
  final Future<void> Function() onStop;
  final Future<void> Function(bool active) onNarrationChanged;
  final VoidCallback onVolumesToggle;
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

    return Card(
      key: playbackFooterKey,
      margin: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showLabels =
              !widget.compact &&
              constraints.maxWidth >= 360 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.4;
          return SizedBox(
            height: showLabels ? 76 : 56,
            child: Row(
              children: [
                Expanded(
                  child: _Control(
                    key: pausePlaybackKey,
                    icon: paused ? Icons.play_arrow : Icons.pause,
                    label: paused ? 'Retomar' : 'Pausar',
                    showLabel: showLabels,
                    disabledForegroundColor: inactiveForeground,
                    onPressed: hasCurrent && !_transportBusy
                        ? () => _runTransport(
                            paused ? widget.onResume : widget.onPause,
                          )
                        : null,
                  ),
                ),
                Expanded(
                  child: _Control(
                    key: stopPlaybackKey,
                    icon: Icons.stop,
                    label: 'Parar',
                    showLabel: showLabels,
                    disabledForegroundColor: inactiveForeground,
                    onPressed: hasCurrent && !_stopBusy ? _runStop : null,
                  ),
                ),
                Expanded(
                  child: _ToggleControl(
                    controlKey: narrationKey,
                    icon: Icons.mic,
                    label: narrationLabel,
                    showLabel: showLabels,
                    selected: playback.narrationActive,
                    enabled: narrationEnabled,
                    selectedColor: colors.secondaryContainer,
                    selectedForeground: colors.onSecondaryContainer,
                    foreground: colors.onSurface,
                    disabledForeground: inactiveForeground,
                    onPressed: narrationEnabled
                        ? () => _runNarration(!playback.narrationActive)
                        : null,
                  ),
                ),
                Expanded(
                  child: _ToggleControl(
                    controlKey: volumesToggleKey,
                    icon: Icons.tune,
                    label: 'Volumes',
                    showLabel: showLabels,
                    selected: widget.volumesExpanded,
                    enabled: true,
                    selectedColor: colors.primaryContainer,
                    selectedForeground: colors.onPrimaryContainer,
                    foreground: colors.onSurface,
                    disabledForeground: inactiveForeground,
                    onPressed: widget.onVolumesToggle,
                  ),
                ),
              ],
            ),
          );
        },
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
    required this.showLabel,
    required this.disabledForegroundColor,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool showLabel;
  final Color disabledForegroundColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      label: label,
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
          if (showLabel)
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: enabled ? null : disabledForegroundColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _ToggleControl extends StatelessWidget {
  const _ToggleControl({
    required this.controlKey,
    required this.icon,
    required this.label,
    required this.showLabel,
    required this.selected,
    required this.enabled,
    required this.selectedColor,
    required this.selectedForeground,
    required this.foreground,
    required this.disabledForeground,
    required this.onPressed,
  });

  final Key controlKey;
  final IconData icon;
  final String label;
  final bool showLabel;
  final bool selected;
  final bool enabled;
  final Color selectedColor;
  final Color selectedForeground;
  final Color foreground;
  final Color disabledForeground;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final effectiveForeground = !enabled
        ? disabledForeground
        : selected
        ? selectedForeground
        : foreground;
    return Semantics(
      label: label,
      button: true,
      toggled: selected,
      enabled: enabled,
      excludeSemantics: true,
      child: Material(
        color: selected ? selectedColor : Colors.transparent,
        child: InkWell(
          key: controlKey,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Tooltip(
                  message: label,
                  child: Icon(icon, size: 24, color: effectiveForeground),
                ),
                if (showLabel)
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: effectiveForeground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
