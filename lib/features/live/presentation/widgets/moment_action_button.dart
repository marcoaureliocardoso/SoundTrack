import 'package:flutter/material.dart';

import '../../../../app/theme/soundtrack_theme.dart';
import '../../../events/domain/event_moment.dart';
import '../../application/live_event_state.dart';

Key momentStatusStripeKey(String momentId) =>
    ValueKey('moment-status-stripe-$momentId');

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
    final backgroundColor = switch (status) {
      MomentStatus.current => colors.surfaceContainerHigh,
      _ => Colors.transparent,
    };
    final statusColor = switch (status) {
      MomentStatus.current => colors.primary,
      MomentStatus.pending => SoundTrackTokens.warning,
      MomentStatus.error => SoundTrackTokens.destructive,
      MomentStatus.ready => colors.onSurfaceVariant,
    };

    return Semantics(
      button: true,
      enabled: enabled,
      selected: status == MomentStatus.current,
      label: '$number. ${moment.name}. $track. $statusText',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: backgroundColor,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: SoundTrackTokens.rowMinHeight,
                ),
                child: DecoratedBox(
                  key: momentStatusStripeKey(moment.id),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: status == MomentStatus.current
                            ? colors.primary
                            : Colors.transparent,
                        width: status == MomentStatus.current ? 4 : 0,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 36),
                          child: Text(
                            '$number',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: status == MomentStatus.current
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                moment.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: colors.onSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                track,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: colors.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                statusText,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: statusColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
