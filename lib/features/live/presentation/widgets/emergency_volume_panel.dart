import 'dart:async';

import 'package:flutter/material.dart';

import '../../../playback/domain/playback_snapshot.dart';
import '../live_dashboard_keys.dart';

typedef SessionVolumesChanged =
    Future<void> Function({
      required double masterVolume,
      required double musicVolume,
      required double narrationVolume,
    });

class EmergencyVolumePanel extends StatelessWidget {
  const EmergencyVolumePanel({
    required this.expanded,
    required this.playback,
    required this.onToggle,
    required this.onVolumesChanged,
    required this.onRestore,
    super.key,
  });

  final bool expanded;
  final PlaybackSnapshot playback;
  final VoidCallback onToggle;
  final SessionVolumesChanged onVolumesChanged;
  final Future<void> Function() onRestore;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        key: emergencyVolumesKey,
        initiallyExpanded: expanded,
        onExpansionChanged: (_) => onToggle(),
        title: const Text('Volumes de emergência'),
        subtitle: const Text('Ajustes temporários desta sessão'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _VolumeSlider(
            label: 'Master',
            value: playback.masterVolume * 100,
            onChanged: (value) => unawaited(
              onVolumesChanged(
                masterVolume: value / 100,
                musicVolume: playback.musicVolume,
                narrationVolume: playback.narrationVolume,
              ),
            ),
          ),
          _VolumeSlider(
            label: 'Música',
            value: playback.musicVolume * 100,
            onChanged: (value) => unawaited(
              onVolumesChanged(
                masterVolume: playback.masterVolume,
                musicVolume: value / 100,
                narrationVolume: playback.narrationVolume,
              ),
            ),
          ),
          _VolumeSlider(
            label: 'Narração',
            value: playback.narrationVolume * 100,
            onChanged: (value) => unawaited(
              onVolumesChanged(
                masterVolume: playback.masterVolume,
                musicVolume: playback.musicVolume,
                narrationVolume: value / 100,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => unawaited(onRestore()),
              icon: const Icon(Icons.restore),
              label: const Text('Restaurar predefinições'),
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final rounded = value.round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label — $rounded%'),
        Slider(
          value: value.clamp(0, 100),
          min: 0,
          max: 100,
          divisions: 100,
          label: '$rounded%',
          semanticFormatterCallback: (sliderValue) =>
              '$label ${sliderValue.round()} por cento',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
