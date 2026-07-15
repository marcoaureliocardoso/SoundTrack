import 'package:flutter/material.dart';

import '../theme/soundtrack_theme.dart';

class EditorialSectionHeader extends StatelessWidget {
  const EditorialSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : assert(
         (actionLabel == null && onAction == null) || actionLabel != null,
         'An action label is required when an action is provided.',
       );

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              minimumSize: const Size(
                SoundTrackTokens.targetMinSize,
                SoundTrackTokens.targetMinSize,
              ),
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

enum StatusSeverity { neutral, success, warning, error }

class StatusIndicator extends StatelessWidget {
  const StatusIndicator({
    required this.label,
    this.severity = StatusSeverity.neutral,
    super.key,
  });

  const StatusIndicator.success({required this.label, super.key})
    : severity = StatusSeverity.success;

  const StatusIndicator.warning({required this.label, super.key})
    : severity = StatusSeverity.warning;

  const StatusIndicator.error({required this.label, super.key})
    : severity = StatusSeverity.error;

  final String label;
  final StatusSeverity severity;

  @override
  Widget build(BuildContext context) {
    final (icon, color, semanticsPrefix) = switch (severity) {
      StatusSeverity.neutral => (
        Icons.info_outline,
        SoundTrackTokens.secondaryText,
        'Informação',
      ),
      StatusSeverity.success => (
        Icons.check_circle_outline,
        SoundTrackTokens.accent,
        'Pronto',
      ),
      StatusSeverity.warning => (
        Icons.warning_amber_rounded,
        SoundTrackTokens.warning,
        'Atenção',
      ),
      StatusSeverity.error => (
        Icons.error_outline,
        SoundTrackTokens.destructive,
        'Erro',
      ),
    };

    return Semantics(
      label: '$semanticsPrefix. $label',
      excludeSemantics: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Icon(icon, color: color, size: 20),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class OperationalActionRow extends StatelessWidget {
  const OperationalActionRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive
        ? SoundTrackTokens.destructive
        : theme.colorScheme.primary;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '$title. $description',
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
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: SoundTrackTokens.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LabeledVolumeControl extends StatelessWidget {
  const LabeledVolumeControl({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions = 100,
    super.key,
  }) : assert(min < max),
       assert(value >= min && value <= max);

  final String label;
  final String description;
  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedValue = (value - min) / (max - min);
    final percentage = (normalizedValue * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 2,
          children: [
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '$percentage%',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: SoundTrackTokens.secondaryText,
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: SoundTrackTokens.targetMinSize,
          ),
          child: Slider(
            min: min,
            max: max,
            divisions: divisions,
            value: value,
            label: '$percentage%',
            semanticFormatterCallback: (_) => '$label, $percentage por cento',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
