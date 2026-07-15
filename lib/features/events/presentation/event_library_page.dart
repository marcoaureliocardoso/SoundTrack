import 'package:flutter/material.dart';

import '../../../app/theme/soundtrack_theme.dart';
import '../application/event_library_controller.dart';
import '../application/event_transfer_controller.dart';
import '../data/event_export_codec.dart';
import '../domain/audio_reference.dart';
import '../domain/soundtrack_event.dart';
import '../../../platform/documents/document_gateway.dart';
import 'audio_relink_page.dart';
import 'event_flow_callbacks.dart';
import 'event_overview_page.dart';
import 'event_sort_order.dart';
import 'widgets/event_list_row.dart';

const addEventKey = Key('add-event');
const eventSortKey = Key('event-sort');
const libraryMenuKey = Key('library-menu');
const eventNameFieldKey = Key('event-name-field');

const openAudioEngineLabKey = Key('open-audio-engine-lab');

Key librarySkeletonRowKey(int index) => ValueKey('library-skeleton-$index');

enum _LibraryMenuAction { importEvent, audioEngineLab }

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
  EventSortOrder _sortOrder = EventSortOrder.newest;

  List<SoundTrackEvent> get _visibleEvents =>
      sortEvents(widget.controller.events, _sortOrder);

  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventos'),
        actions: [
          TextButton(
            key: addEventKey,
            onPressed: _documentBusy ? null : _create,
            style: TextButton.styleFrom(
              minimumSize: const Size(
                SoundTrackTokens.targetMinSize,
                SoundTrackTokens.targetMinSize,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Novo'),
          ),
          PopupMenuButton<_LibraryMenuAction>(
            key: libraryMenuKey,
            tooltip: 'Mais opções da biblioteca',
            enabled: !_documentBusy,
            icon: _documentBusy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.more_vert),
            onSelected: _handleLibraryMenuAction,
            itemBuilder: (context) => [
              if (widget.onImport != null)
                const PopupMenuItem(
                  value: _LibraryMenuAction.importEvent,
                  child: Text('Importar evento'),
                ),
              if (widget.audioEngineLabRoute != null)
                const PopupMenuItem(
                  key: openAudioEngineLabKey,
                  value: _LibraryMenuAction.audioEngineLab,
                  child: Text('Audio Engine Lab'),
                ),
            ],
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _documentBusy,
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            if (widget.controller.loading && widget.controller.events.isEmpty) {
              return const _LibrarySkeleton();
            }
            if (widget.controller.error != null &&
                widget.controller.events.isEmpty) {
              return _ErrorView(onRetry: widget.controller.load);
            }
            final events = _visibleEvents;
            final momentCount = events.fold<int>(
              0,
              (total, event) => total + event.moments.length,
            );
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  SoundTrackTokens.pagePadding,
                  12,
                  SoundTrackTokens.pagePadding,
                  32,
                ),
                children: [
                  Text(
                    '${events.length} '
                    '${events.length == 1 ? 'evento' : 'eventos'} · '
                    '$momentCount '
                    '${momentCount == 1 ? 'momento' : 'momentos'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: SoundTrackTokens.secondaryText,
                    ),
                  ),
                  const SizedBox(height: SoundTrackTokens.sectionGap),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Seus eventos',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      PopupMenuButton<EventSortOrder>(
                        key: eventSortKey,
                        tooltip: 'Ordenar eventos',
                        initialValue: _sortOrder,
                        onSelected: (value) {
                          setState(() => _sortOrder = value);
                        },
                        itemBuilder: (context) => EventSortOrder.values
                            .map(
                              (order) => PopupMenuItem(
                                value: order,
                                child: Text(_sortOrderLabel(order)),
                              ),
                            )
                            .toList(),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: SoundTrackTokens.targetMinSize,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                const Icon(Icons.sort, size: 20),
                                Text(_sortOrderLabel(_sortOrder)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (events.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 56),
                      child: Column(
                        children: [
                          Text(
                            'Nenhum evento ainda',
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Use Novo no cabeçalho para criar o primeiro.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    for (var index = 0; index < events.length; index++) ...[
                      EventListRow(
                        key: ValueKey(events[index].id),
                        event: events[index],
                        number: index + 1,
                        status: _preflightStatusLabel(
                          widget.controller.preflightStatusFor(events[index]),
                        ),
                        onTap: _documentBusy
                            ? null
                            : () => _open(events[index]),
                      ),
                      if (index < events.length - 1) const Divider(height: 1),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleLibraryMenuAction(_LibraryMenuAction action) {
    switch (action) {
      case _LibraryMenuAction.importEvent:
        _import();
      case _LibraryMenuAction.audioEngineLab:
        Navigator.of(context).pushNamed(widget.audioEngineLabRoute!);
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
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => EventOverviewPage(
          eventId: event.id,
          libraryController: widget.controller,
          createEditorController: widget.createEditorController,
          onSelectAudio: widget.onSelectAudio,
          onExport: widget.onExport,
          buildLiveEntryPage: widget.buildLiveEntryPage,
        ),
      ),
    );
    if (mounted) {
      await widget.controller.load();
    }
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

String _sortOrderLabel(EventSortOrder order) {
  return switch (order) {
    EventSortOrder.newest => 'Mais recentes',
    EventSortOrder.oldest => 'Mais antigos',
    EventSortOrder.nameAscending => 'Nome: A–Z',
    EventSortOrder.nameDescending => 'Nome: Z–A',
  };
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
    return Padding(
      padding: const EdgeInsets.all(SoundTrackTokens.pagePadding),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Não foi possível carregar os eventos',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Verifique o acesso ao armazenamento e tente novamente.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibrarySkeleton extends StatelessWidget {
  const _LibrarySkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(alpha: .1);
    return ExcludeSemantics(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          SoundTrackTokens.pagePadding,
          28,
          SoundTrackTokens.pagePadding,
          32,
        ),
        children: [
          for (var index = 0; index < 3; index++)
            Padding(
              key: librarySkeletonRowKey(index),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FractionallySizedBox(
                          widthFactor: .62,
                          child: Container(height: 16, color: color),
                        ),
                        const SizedBox(height: 10),
                        FractionallySizedBox(
                          widthFactor: .38,
                          child: Container(height: 12, color: color),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
