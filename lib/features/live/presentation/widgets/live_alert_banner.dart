import 'package:flutter/material.dart';

import '../../../playback/domain/playback_alert.dart';

class LiveAlertBanner extends StatelessWidget {
  const LiveAlertBanner({
    required this.alert,
    required this.onDismiss,
    super.key,
  });

  final PlaybackAlert alert;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                alert.message,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
            IconButton(
              tooltip: 'Dispensar aviso',
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
              color: colors.onErrorContainer,
            ),
          ],
        ),
      ),
    );
  }
}
