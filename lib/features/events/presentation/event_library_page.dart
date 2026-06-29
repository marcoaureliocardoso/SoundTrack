import 'package:flutter/material.dart';

import '../application/event_editor_controller.dart';
import '../application/event_library_controller.dart';
import '../domain/soundtrack_event.dart';
import 'event_editor_page.dart';
import 'widgets/event_card.dart';

const addEventKey = Key('add-event');
const eventNameFieldKey = Key('event-name-field');

typedef EventEditorControllerFactory =
    EventEditorController Function(SoundTrackEvent event);
typedef EventExportCallback = Future<void> Function(SoundTrackEvent event);

class EventLibraryPage extends StatefulWidget {
  const EventLibraryPage({
    required this.controller,
    required this.createEditorController,
    this.onExport,
    super.key,
  });

  final EventLibraryController controller;
  final EventEditorControllerFactory createEditorController;
  final EventExportCallback? onExport;

  @override
  State<EventLibraryPage> createState() => _EventLibraryPageState();
}

class _EventLibraryPageState extends State<EventLibraryPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus Eventos')),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          if (widget.controller.loading && widget.controller.events.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (widget.controller.error != null &&
              widget.controller.events.isEmpty) {
            return _ErrorView(onRetry: widget.controller.load);
          }
          if (widget.controller.events.isEmpty) {
            return const Center(
              child: Text('Nenhum evento. Crie o primeiro para começar.'),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: widget.controller.events.length,
              itemBuilder: (context, index) {
                final event = widget.controller.events[index];
                return EventCard(
                  key: ValueKey(event.id),
                  event: event,
                  exportEnabled: widget.onExport != null,
                  onAction: (action) => _handleAction(event, action),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: addEventKey,
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Evento'),
      ),
    );
  }

  Future<void> _handleAction(
    SoundTrackEvent event,
    EventCardAction action,
  ) async {
    switch (action) {
      case EventCardAction.open:
        await _open(event);
      case EventCardAction.duplicate:
        await _run(() => widget.controller.duplicate(event.id));
      case EventCardAction.rename:
        final name = await _requestName(
          title: 'Renomear evento',
          actionLabel: 'Renomear',
          initialValue: event.name,
        );
        if (name != null) {
          await _run(() => widget.controller.rename(event.id, name));
        }
      case EventCardAction.export:
        final export = widget.onExport;
        if (export != null) {
          await _run(() => export(event));
        }
      case EventCardAction.delete:
        await _confirmDelete(event);
    }
  }

  Future<void> _create() async {
    final name = await _requestName(title: 'Novo evento', actionLabel: 'Criar');
    if (name == null) {
      return;
    }
    await _run(() => widget.controller.create(name));
  }

  Future<void> _refresh() async {
    await widget.controller.load();
    if (mounted && widget.controller.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar os eventos')),
      );
    }
  }

  Future<void> _open(SoundTrackEvent event) async {
    final editorController = widget.createEditorController(event);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => EventEditorPage(controller: editorController),
      ),
    );
    editorController.dispose();
    if (mounted) {
      await widget.controller.load();
    }
  }

  Future<String?> _requestName({
    required String title,
    required String actionLabel,
    String initialValue = '',
  }) async {
    var draftName = initialValue;
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          key: eventNameFieldKey,
          initialValue: initialValue,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome'),
          onChanged: (value) => draftName = value,
          onFieldSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, draftName),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  Future<void> _confirmDelete(SoundTrackEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir evento?'),
        content: Text(
          'Excluir “${event.name}”? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(() => widget.controller.delete(event.id));
    }
  }

  Future<void> _run(Future<Object?> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível concluir a ação')),
        );
      }
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Não foi possível carregar seus eventos'),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
