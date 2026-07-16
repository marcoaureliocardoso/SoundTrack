import 'package:flutter/material.dart';

import '../../../../app/widgets/editorial_components.dart';
import '../../domain/event_audio_settings.dart';

class EventAudioSettingsEditor extends StatelessWidget {
  const EventAudioSettingsEditor({
    required this.settings,
    required this.onChanged,
    super.key,
  });

  final EventAudioSettings settings;
  final ValueChanged<EventAudioSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LabeledVolumeControl(
          label: 'Master',
          description: 'Limite geral da saída do aplicativo',
          value: settings.masterVolume,
          onChanged: (value) =>
              onChanged(settings.copyWith(masterVolume: value)),
        ),
        const SizedBox(height: 12),
        LabeledVolumeControl(
          label: 'Música',
          description: 'Nível normal da trilha sonora',
          value: settings.musicVolume,
          onChanged: (value) =>
              onChanged(settings.copyWith(musicVolume: value)),
        ),
        const SizedBox(height: 12),
        LabeledVolumeControl(
          label: 'Música durante a narração',
          description: 'Nível usado enquanto Narração estiver ativa',
          value: settings.narrationVolume,
          onChanged: (value) =>
              onChanged(settings.copyWith(narrationVolume: value)),
        ),
        const SizedBox(height: 16),
        _AdaptiveFadeFields(settings: settings, onChanged: onChanged),
      ],
    );
  }
}

class _AdaptiveFadeFields extends StatelessWidget {
  const _AdaptiveFadeFields({required this.settings, required this.onChanged});

  final EventAudioSettings settings;
  final ValueChanged<EventAudioSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final vertical = constraints.maxWidth < 360 || textScale > 1.4;
        final fadeIn = _FadeField(
          label: 'Fade-in',
          value: settings.fadeIn,
          onChanged: (value) => onChanged(settings.copyWith(fadeIn: value)),
        );
        final fadeOut = _FadeField(
          label: 'Fade-out',
          value: settings.fadeOut,
          onChanged: (value) => onChanged(settings.copyWith(fadeOut: value)),
        );
        if (vertical) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [fadeIn, const SizedBox(height: 12), fadeOut],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: fadeIn),
            const SizedBox(width: 12),
            Expanded(child: fadeOut),
          ],
        );
      },
    );
  }
}

class _FadeField extends StatelessWidget {
  const _FadeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Duration value;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value.inMilliseconds,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: const [0, 1000, 2000, 3000, 5000]
          .map(
            (milliseconds) => DropdownMenuItem(
              value: milliseconds,
              child: Text('${milliseconds ~/ 1000} s'),
            ),
          )
          .toList(),
      onChanged: (milliseconds) {
        if (milliseconds != null) {
          onChanged(Duration(milliseconds: milliseconds));
        }
      },
    );
  }
}
