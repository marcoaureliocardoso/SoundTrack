import 'package:flutter/material.dart';

import '../../../playback/domain/playback_alert.dart';
import '../live_dashboard_keys.dart';

class LiveAlertBanner extends StatelessWidget {
  const LiveAlertBanner({
    required this.alert,
    required this.onDismiss,
    this.compact = false,
    super.key,
  });

  final PlaybackAlert alert;
  final VoidCallback onDismiss;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    void showDetails() {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: liveAlertDetailsKey,
          title: const Text('Aviso de reprodução'),
          content: SelectableText(alert.message),
          actions: [
            TextButton(
              onPressed: () {
                onDismiss();
                Navigator.pop(dialogContext);
              },
              child: const Text('Dispensar aviso'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    }

    final message = compact
        ? Semantics(
            label: 'Ver detalhes do aviso: ${alert.message}',
            button: true,
            excludeSemantics: true,
            child: InkWell(
              key: liveAlertBannerKey,
              onTap: showDetails,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  alert.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
            ),
          )
        : Text(
            alert.message,
            key: liveAlertBannerKey,
            style: TextStyle(color: colors.onErrorContainer),
          );
    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(child: message),
            IconButton(
              tooltip: 'Dispensar aviso',
              onPressed: onDismiss,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              icon: const Icon(Icons.close),
              color: colors.onErrorContainer,
            ),
          ],
        ),
      ),
    );
  }
}
