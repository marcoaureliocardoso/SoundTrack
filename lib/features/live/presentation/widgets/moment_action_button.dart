import 'package:flutter/material.dart';

import '../../../events/domain/event_moment.dart';
import '../../application/live_event_state.dart';

class MomentActionButton extends StatelessWidget {
  const MomentActionButton({
    required this.number,
    required this.moment,
    required this.status,
    required this.onPressed,
    this.commandEnabled = true,
    super.key,
  });

  final int number;
  final EventMoment moment;
  final MomentStatus status;
  final VoidCallback onPressed;
  final bool commandEnabled;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (status) {
      MomentStatus.current => 'ATUAL',
      MomentStatus.pending => 'ÁUDIO PENDENTE',
      MomentStatus.error => 'ERRO NO ÁUDIO',
      MomentStatus.ready => 'TOQUE PARA INICIAR',
    };
    final enabled = status == MomentStatus.ready && commandEnabled;
    final track = moment.audio?.displayName ?? 'Sem faixa vinculada';
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$number. ${moment.name}. $track. $statusText',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: FilledButton(
          style: FilledButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            backgroundColor: status == MomentStatus.current
                ? colors.primaryContainer
                : null,
            foregroundColor: status == MomentStatus.current
                ? colors.onPrimaryContainer
                : null,
            disabledBackgroundColor: status == MomentStatus.current
                ? colors.primaryContainer
                : colors.surfaceContainerHighest,
            disabledForegroundColor: status == MomentStatus.current
                ? colors.onPrimaryContainer
                : colors.onSurfaceVariant,
          ),
          onPressed: enabled ? onPressed : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 36),
                child: Text(
                  '$number',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moment.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(track, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
