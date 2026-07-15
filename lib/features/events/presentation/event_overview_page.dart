import 'package:flutter/material.dart';

import '../../../app/theme/soundtrack_theme.dart';
import '../../../app/widgets/editorial_components.dart';
import '../application/event_library_controller.dart';
import '../domain/audio_reference.dart';
import '../domain/event_moment.dart';
import '../domain/soundtrack_event.dart';
import 'event_editor_page.dart';
import 'event_flow_callbacks.dart';

const eventOverviewMenuKey = Key('event-overview-menu');
const eventOverviewNameFieldKey = Key('event-overview-name-field');
const editEventStructureKey = Key('edit-event-structure');
const prepareLiveEventKey = Key('prepare-live-event');
const adjustEventAudioKey = Key('adjust-event-audio');

enum _EventAction { export, duplicate, rename, delete }

class EventOverviewPage extends StatefulWidget {
  const EventOverviewPage({
    required this.eventId,
    required this.libraryController,
    required this.createEditorController,
    this.onSelectAudio,
    this.onExport,
    this.buildLiveEntryPage,
    super.key,
  });

  final String eventId;
  final EventLibraryController libraryController;
  final EventEditorControllerFactory createEditorController;
  final Future<AudioReference?> Function()? onSelectAudio;
  final EventExportCallback? onExport;
  final EventLiveEntryPageBuilder? buildLiveEntryPage;

  @override
  State<EventOverviewPage> createState() => _EventOverviewPageState();
}

class _EventOverviewPageState extends State<EventOverviewPage> {
  bool _busy = false;
  bool _openingLive = false;

  SoundTrackEvent? get _event {
    for (final event in widget.libraryController.events) {
      if (event.id == widget.eventId) return event;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.libraryController,
      builder: (context, _) {
        final event = _event;
        return Scaffold(
          appBar: AppBar(
            actions: [
              if (_busy)
                const SizedBox(
                  width: SoundTrackTokens.targetMinSize,
                  height: SoundTrackTokens.targetMinSize,
                  child: Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                PopupMenuButton<_EventAction>(
                  key: eventOverviewMenuKey,
                  tooltip: 'Mais opções do evento',
                  onSelected: _handleAction,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _EventAction.export,
                      enabled: widget.onExport != null,
                      child: const Text('Exportar'),
                    ),
                    const PopupMenuItem(
                      value: _EventAction.duplicate,
                      child: Text('Duplicar'),
                    ),
                    const PopupMenuItem(
                      value: _EventAction.rename,
                      child: Text('Renomear'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: _EventAction.delete,
                      child: Text('Excluir'),
                    ),
                  ],
                ),
            ],
          ),
          body: event == null
              ? const Center(child: Text('Evento não encontrado'))
              : AbsorbPointer(
                  absorbing: _busy,
                  child: _buildOverview(context, event),
                ),
        );
      },
    );
  }

  Widget _buildOverview(BuildContext context, SoundTrackEvent event) {
    final theme = Theme.of(context);
    final settings = event.audioSettings;
    final status = _statusFor(event);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SoundTrackTokens.pagePadding,
        8,
        SoundTrackTokens.pagePadding,
        32,
      ),
      children: [
        Text(
          event.name,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _momentCountLabel(event.moments.length),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: SoundTrackTokens.secondaryText,
              ),
            ),
            Text(
              'Atualizado ${_shortDate(event.updatedAt)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: SoundTrackTokens.secondaryText,
              ),
            ),
            StatusIndicator(label: status.label, severity: status.severity),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: editEventStructureKey,
            onPressed: () => _edit(event),
            child: const Text('Editar estrutura'),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: SoundTrackTokens.sectionGap),
        const EditorialSectionHeader(title: 'Operação'),
        OperationalActionRow(
          key: prepareLiveEventKey,
          icon: Icons.fact_check_outlined,
          title: 'Preparar Modo Evento',
          description: 'Verificar músicas e ajustes antes de entrar ao vivo',
          onTap: widget.buildLiveEntryPage == null
              ? null
              : () => _prepare(event),
        ),
        const SizedBox(height: SoundTrackTokens.sectionGap),
        const EditorialSectionHeader(title: 'Momentos'),
        if (event.moments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Nenhum momento adicionado',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: SoundTrackTokens.secondaryText,
              ),
            ),
          )
        else
          for (var index = 0; index < event.moments.length; index++) ...[
            _MomentSummaryRow(number: index + 1, moment: event.moments[index]),
            if (index < event.moments.length - 1) const Divider(height: 1),
          ],
        const SizedBox(height: SoundTrackTokens.sectionGap),
        EditorialSectionHeader(
          title: 'Áudio do evento',
          actionLabel: 'Ajustar',
          onAction: () => _edit(event),
        ),
        KeyedSubtree(
          key: adjustEventAudioKey,
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _AudioMetric(
                label: 'Master',
                value: _percentage(settings.masterVolume),
              ),
              _AudioMetric(
                label: 'Música',
                value: _percentage(settings.musicVolume),
              ),
              _AudioMetric(
                label: 'Música durante a narração',
                value: _percentage(settings.narrationVolume),
              ),
              _AudioMetric(label: 'Fade-in', value: _seconds(settings.fadeIn)),
              _AudioMetric(
                label: 'Fade-out',
                value: _seconds(settings.fadeOut),
              ),
            ],
          ),
        ),
      ],
    );
  }

  ({String label, StatusSeverity severity}) _statusFor(SoundTrackEvent event) {
    return switch (widget.libraryController.preflightStatusFor(event)) {
      EventPreflightStatus.unchecked => (
        label: 'Não verificado',
        severity: StatusSeverity.neutral,
      ),
      EventPreflightStatus.ready => (
        label: 'Pronto para iniciar',
        severity: StatusSeverity.success,
      ),
      EventPreflightStatus.warnings => (
        label: 'Requer atenção',
        severity: StatusSeverity.warning,
      ),
      EventPreflightStatus.errors => (
        label: 'Correções necessárias',
        severity: StatusSeverity.error,
      ),
    };
  }

  Future<void> _edit(SoundTrackEvent event) async {
    final controller = widget.createEditorController(event);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EventEditorPage(
          controller: controller,
          onSelectAudio: widget.onSelectAudio,
        ),
      ),
    );
    controller.dispose();
    if (mounted) await widget.libraryController.load();
  }

  Future<void> _prepare(SoundTrackEvent event) async {
    final builder = widget.buildLiveEntryPage;
    if (builder == null || _openingLive) return;
    _openingLive = true;
    try {
      await Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => builder(event)));
    } finally {
      _openingLive = false;
    }
  }

  Future<void> _handleAction(_EventAction action) async {
    final event = _event;
    if (event == null || _busy) return;
    switch (action) {
      case _EventAction.export:
        await _export(event);
      case _EventAction.duplicate:
        await _run(
          () => widget.libraryController.duplicate(event.id),
          successMessage: 'Evento duplicado',
        );
      case _EventAction.rename:
        await _rename(event);
      case _EventAction.delete:
        await _delete(event);
    }
  }

  Future<void> _export(SoundTrackEvent event) async {
    final export = widget.onExport;
    if (export == null) return;
    await _run(() async {
      final exported = await export(event);
      if (mounted) {
        _message(exported ? 'Evento exportado' : 'Exportação cancelada');
      }
      return null;
    });
  }

  Future<void> _rename(SoundTrackEvent event) async {
    var draftName = event.name;
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Renomear evento'),
        content: TextFormField(
          key: eventOverviewNameFieldKey,
          initialValue: event.name,
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
            child: const Text('Renomear'),
          ),
        ],
      ),
    );
    final name = value?.trim();
    if (name == null || name.isEmpty || name == event.name) return;
    await _run(() => widget.libraryController.rename(event.id, name));
  }

  Future<void> _delete(SoundTrackEvent event) async {
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
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await widget.libraryController.delete(event.id);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _message('Não foi possível excluir o evento');
      }
    }
  }

  Future<void> _run(
    Future<Object?> Function() operation, {
    String? successMessage,
  }) async {
    setState(() => _busy = true);
    try {
      await operation();
      if (mounted && successMessage != null) _message(successMessage);
    } catch (_) {
      if (mounted) _message('Não foi possível concluir a ação');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _MomentSummaryRow extends StatelessWidget {
  const _MomentSummaryRow({required this.number, required this.moment});

  final int number;
  final EventMoment moment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: SoundTrackTokens.rowMinHeight,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              child: Text(
                number.toString().padLeft(2, '0'),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: SoundTrackTokens.secondaryText,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    moment.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    moment.audio?.displayName ?? 'Sem música selecionada',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: SoundTrackTokens.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioMetric extends StatelessWidget {
  const _AudioMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: '$label  ',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: SoundTrackTokens.secondaryText),
        children: [
          TextSpan(
            text: value,
            style: const TextStyle(
              color: SoundTrackTokens.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _momentCountLabel(int count) =>
    '$count ${count == 1 ? 'momento' : 'momentos'}';

String _percentage(double value) => '${(value * 100).round()}%';

String _seconds(Duration value) =>
    '${value.inSeconds} ${value.inSeconds == 1 ? 'segundo' : 'segundos'}';

String _shortDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
