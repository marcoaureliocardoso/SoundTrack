import 'package:flutter/material.dart';

import '../../../../app/theme/soundtrack_theme.dart';
import '../../domain/event_moment.dart';

class MomentListRow extends StatelessWidget {
  const MomentListRow({
    required this.moment,
    required this.number,
    required this.index,
    required this.onTap,
    super.key,
  });

  final EventMoment moment;
  final int number;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final audio = moment.audio;
    final audioLabel = audio == null
        ? 'Sem música selecionada'
        : audio.pending
        ? 'Áudio pendente: ${audio.displayName}'
        : audio.displayName;
    final playbackLabel = moment.endBehavior == EndBehavior.loop
        ? 'Repetir em loop'
        : 'Parar ao terminar';
    return Semantics(
      button: true,
      label: 'Momento $number. ${moment.name}. $audioLabel. $playbackLabel',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: SoundTrackTokens.rowMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    number.toString().padLeft(2, '0'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: SoundTrackTokens.secondaryText,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        moment.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        audioLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: SoundTrackTokens.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 10,
                        runSpacing: 2,
                        children: [
                          Text(playbackLabel),
                          if (moment.narrationEnabled)
                            const Text('Narração disponível'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                ReorderableDragStartListener(
                  index: index,
                  child: const SizedBox.square(
                    dimension: SoundTrackTokens.targetMinSize,
                    child: Icon(Icons.drag_handle),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
