import 'package:flutter/material.dart';

import '../../../../app/theme/soundtrack_theme.dart';
import '../live_dashboard_keys.dart';

class EmergencyVolumeToggleBar extends StatelessWidget {
  const EmergencyVolumeToggleBar({
    required this.expanded,
    required this.onToggle,
    this.compact = false,
    super.key,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: expanded,
      label: 'Volumes de emergência',
      excludeSemantics: true,
      child: Material(
        color: SoundTrackTokens.surface,
        child: InkWell(
          key: volumesToggleKey,
          onTap: onToggle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: SoundTrackTokens.targetMinSize,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(compact ? 'Volumes' : 'Volumes de emergência'),
                  ),
                  Icon(expanded ? Icons.expand_more : Icons.expand_less),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
