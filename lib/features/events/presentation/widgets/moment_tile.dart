import 'package:flutter/material.dart';

import '../../domain/event_moment.dart';

class MomentTile extends StatelessWidget {
  const MomentTile({
    required this.moment,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final EventMoment moment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final audioLabel = moment.audio?.displayName ?? 'Áudio não selecionado';
    return Card(
      child: ListTile(
        onTap: onEdit,
        leading: const Icon(Icons.drag_handle),
        title: Text(moment.name),
        subtitle: Text(
          '$audioLabel • ${moment.endBehavior == EndBehavior.loop ? 'Loop' : 'Parar'}'
          '${moment.narrationEnabled ? ' • Narração' : ''}',
        ),
        trailing: IconButton(
          tooltip: 'Excluir ${moment.name}',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }
}
