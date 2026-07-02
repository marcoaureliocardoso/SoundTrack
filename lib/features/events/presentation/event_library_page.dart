import 'package:flutter/material.dart';

import '../application/event_editor_controller.dart';
import '../application/event_library_controller.dart';
import '../application/event_transfer_controller.dart';
import '../data/event_export_codec.dart';
import '../domain/audio_reference.dart';
import '../domain/soundtrack_event.dart';
import '../../../platform/documents/document_gateway.dart';
import 'audio_relink_page.dart';
import 'event_editor_page.dart';
import 'widgets/event_card.dart';

const addEventKey = Key('add-event');
const eventNameFieldKey = Key('event-name-field');

typedef EventEditorControllerFactory =
    EventEditorController Function(SoundTrackEvent event);
typedef EventExportCallback = Future<bool> Function(SoundTrackEvent event);
typedef EventImportCallback = Future<SoundTrackEvent?> Function();
typedef EventLiveEntryPageBuilder = Widget Function(SoundTrackEvent event);
const openAudioEngineLabKey = Key('open-audio-engine-lab');

class EventLibraryPage extends StatefulWidget {
  const EventLibraryPage({
    required this.controller,
    required this.createEditorController,
    this.onExport,
    this.onImport,
    this.transferController,
    this.onSelectAudio,
    this.buildLiveEntryPage,
    this.audioEngineLabRoute,
    super.key,
  });

  final EventLibraryController controller;
  final EventEditorControllerFactory createEditorController;
  final EventExportCallback? onExport;
  final EventImportCallback? onImport;
  final EventTransferController? transferController;
  final Future<AudioReference?> Function()? onSelectAudio;
  final EventLiveEntryPageBuilder? buildLiveEntryPage;
  final String? audioEngineLabRoute;

  @override
  State<EventLibraryPage> createState() => _EventLibraryPageState();
}

class _EventLibraryPageState extends State<EventLibraryPage> {
  bool _documentBusy = false;

  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Eventos'),
        actions: [
          if (widget.audioEngineLabRoute != null)
            IconButton(
              key: openAudioEngineLabKey,
              tooltip: 'Audio Engine Lab',
              onPressed: () =>
                  Navigator.of(context).pushNamed(widget.audioEngineLabRoute!),
              icon: const Icon(Icons.science),
            ),
          if (_documentBusy)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (widget.onImport != null)
            TextButton.icon(
              onPressed: _documentBusy ? null : _import,
              icon: const Icon(Icons.file_open),
              label: const Text('Importar'),
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _documentBusy,
        child: ListenableBuilder(
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
                    preflightStatusLabel: _preflightStatusLabel(
                      widget.controller.preflightStatusFor(event),
                    ),
                    exportEnabled: widget.onExport != null && !_documentBusy,
                    onAction: (action) => _handleAction(event, action),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: addEventKey,
        onPressed: _documentBusy ? null : _create,
        icon: const Icon(Icons.add),
        label: const Text('Evento'),
      ),
    );
  }

  Future<void> _handleAction(
    SoundTrackEvent event,
    EventCardAction action,
  ) async {
    if (_documentBusy) return;
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
        if (_documentBusy) return;
        final export = widget.onExport;
        if (export != null) {
          setState(() => _documentBusy = true);
          try {
            final exported = await export(event);
            if (mounted) {
              _message(exported ? 'Evento exportado' : 'Exportação cancelada');
            }
          } catch (error) {
            if (mounted) _message(eventDocumentErrorMessage(error));
          } finally {
            if (mounted) setState(() => _documentBusy = false);
          }
        }
      case EventCardAction.delete:
        await _confirmDelete(event);
    }
  }

  Future<void> _create() async {
    if (_documentBusy) return;
    final name = await _requestName(title: 'Novo evento', actionLabel: 'Criar');
    if (name == null) {
      return;
    }
    await _run(() => widget.controller.create(name));
  }

  Future<void> _refresh() async {
    if (_documentBusy) return;
    await widget.controller.load();
    if (mounted && widget.controller.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar os eventos')),
      );
    }
  }

  Future<void> _open(
    SoundTrackEvent event, {
    bool allowWhileDocumentBusy = false,
  }) async {
    if (_documentBusy && !allowWhileDocumentBusy) return;
    final editorController = widget.createEditorController(event);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => EventEditorPage(
          controller: editorController,
          onSelectAudio: widget.onSelectAudio,
          onStartLive: widget.buildLiveEntryPage == null ? null : _openLive,
        ),
      ),
    );
    editorController.dispose();
    if (mounted) {
      await widget.controller.load();
    }
  }

  void _openLive(SoundTrackEvent snapshot) {
    final builder = widget.buildLiveEntryPage;
    if (builder == null) return;
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => builder(snapshot)));
  }

  Future<void> _import() async {
    if (_documentBusy) return;
    setState(() => _documentBusy = true);
    try {
      final imported = await widget.onImport?.call();
      if (!mounted) return;
      if (imported == null) {
        _message('Importação cancelada');
        return;
      }
      await widget.controller.load();
      if (!mounted) return;
      final hasPending = imported.moments.any((moment) => moment.audioPending);
      if (hasPending && widget.transferController != null) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => AudioRelinkPage(
              event: imported,
              controller: widget.transferController!,
            ),
          ),
        );
        if (mounted) await widget.controller.load();
      } else {
        _message('Evento importado');
        await _open(imported, allowWhileDocumentBusy: true);
      }
    } catch (error) {
      if (mounted) _message(eventDocumentErrorMessage(error));
    } finally {
      if (mounted) setState(() => _documentBusy = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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

String _preflightStatusLabel(EventPreflightStatus status) {
  return switch (status) {
    EventPreflightStatus.unchecked => 'Não verificado',
    EventPreflightStatus.ready => 'Pronto',
    EventPreflightStatus.warnings => 'Avisos',
    EventPreflightStatus.errors => 'Erros',
  };
}

String eventDocumentErrorMessage(Object error) {
  if (error == EventImportException.invalidJson) {
    return 'Arquivo inválido. Escolha uma exportação do SoundTrack.';
  }
  if (error == EventImportException.unsupportedFormat) {
    return 'Formato não reconhecido. Escolha um arquivo .soundtrack.json.';
  }
  if (error == EventImportException.unsupportedVersion) {
    return 'Versão do arquivo não suportada. Atualize o SoundTrack.';
  }
  if (error is DocumentGatewayException) {
    if (error.code == 'picker_busy') {
      return 'Já existe um seletor de arquivos aberto.';
    }
    return 'Não foi possível acessar o arquivo. Verifique o armazenamento e tente novamente.';
  }
  return 'Não foi possível concluir a operação com o arquivo.';
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
