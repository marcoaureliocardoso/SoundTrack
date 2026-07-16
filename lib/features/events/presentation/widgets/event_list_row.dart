import 'package:flutter/material.dart';

import '../../../../app/theme/soundtrack_theme.dart';
import '../../../../app/widgets/editorial_components.dart';
import '../../domain/soundtrack_event.dart';

class EventListRow extends StatelessWidget {
  const EventListRow({
    required this.event,
    required this.number,
    required this.status,
    required this.onTap,
    super.key,
  });

  final SoundTrackEvent event;
  final int number;
  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final momentCount = event.moments.length;
    final momentLabel =
        '$momentCount '
        '${momentCount == 1 ? 'momento' : 'momentos'}';
    final updatedLabel = 'Atualizado ${_shortDate(event.updatedAt)}';
    return Semantics(
      button: true,
      enabled: onTap != null,
      label:
          'Evento $number. ${event.name}. $momentLabel. '
          '$updatedLabel. $status',
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
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        event.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          Text(
                            momentLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: SoundTrackTokens.secondaryText,
                            ),
                          ),
                          Text(
                            updatedLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: SoundTrackTokens.secondaryText,
                            ),
                          ),
                          StatusIndicator(
                            label: status,
                            severity: _severityFor(status),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: theme.colorScheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

StatusSeverity _severityFor(String status) {
  return switch (status) {
    'Pronto' => StatusSeverity.success,
    'Avisos' => StatusSeverity.warning,
    'Erros' => StatusSeverity.error,
    _ => StatusSeverity.neutral,
  };
}

String _shortDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
