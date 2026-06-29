import 'package:flutter/material.dart';

import '../../domain/soundtrack_event.dart';

enum EventCardAction { open, duplicate, rename, export, delete }

class EventCard extends StatelessWidget {
  const EventCard({
    required this.event,
    required this.onAction,
    this.exportEnabled = false,
    super.key,
  });

  final SoundTrackEvent event;
  final ValueChanged<EventCardAction> onAction;
  final bool exportEnabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: () => onAction(EventCardAction.open),
        leading: const Icon(Icons.event_note),
        title: Text(event.name),
        subtitle: Text(
          '${event.moments.length} '
          '${event.moments.length == 1 ? 'momento' : 'momentos'}',
        ),
        trailing: PopupMenuButton<EventCardAction>(
          tooltip: 'Ações de ${event.name}',
          onSelected: onAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: EventCardAction.open,
              child: Text('Abrir'),
            ),
            const PopupMenuItem(
              value: EventCardAction.duplicate,
              child: Text('Duplicar'),
            ),
            const PopupMenuItem(
              value: EventCardAction.rename,
              child: Text('Renomear'),
            ),
            PopupMenuItem(
              value: EventCardAction.export,
              enabled: exportEnabled,
              child: const Text('Exportar'),
            ),
            const PopupMenuItem(
              value: EventCardAction.delete,
              child: Text('Excluir'),
            ),
          ],
        ),
      ),
    );
  }
}
