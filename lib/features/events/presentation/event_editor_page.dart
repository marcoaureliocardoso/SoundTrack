import 'package:flutter/material.dart';

import '../../../app/theme/soundtrack_theme.dart';
import '../../../app/widgets/editorial_components.dart';
import '../application/event_editor_controller.dart';
import '../domain/audio_reference.dart';
import '../domain/event_moment.dart';
import '../domain/soundtrack_event.dart';
import 'moment_editor_sheet.dart';
import 'widgets/event_audio_settings_editor.dart';
import 'widgets/moment_list_row.dart';

enum EventEditorInitialSection { top, audio }

const addMomentKey = Key('add-moment');
const eventAudioSectionKey = Key('event-audio-section');
const momentNameFieldKey = Key('moment-name-field');
Key momentTileKey(String id) => Key('moment-$id');

class EventEditorPage extends StatefulWidget {
  const EventEditorPage({
    required this.controller,
    this.onSelectAudio,
    this.initialSection = EventEditorInitialSection.top,
    super.key,
  });

  final EventEditorController controller;
  final Future<AudioReference?> Function()? onSelectAudio;
  final EventEditorInitialSection initialSection;

  @override
  State<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends State<EventEditorPage> {
  final _audioTargetKey = GlobalKey();
  late final TextEditingController _nameController;
  bool _saving = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.controller.draft.name);
    if (widget.initialSection == EventEditorInitialSection.audio) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targetContext = _audioTargetKey.currentContext;
        if (mounted && targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: 0.05,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final event = widget.controller.draft;
        final saveBlockMessage = event.name.trim().isEmpty
            ? 'Informe o nome do evento.'
            : null;
        final canSave =
            !_saving && widget.controller.dirty && saveBlockMessage == null;
        return PopScope<void>(
          canPop: _allowPop || !widget.controller.dirty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmDiscard();
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Editar estrutura'),
              actions: [
                Tooltip(
                  message: saveBlockMessage ?? 'Salvar',
                  child: TextButton(
                    onPressed: canSave ? _save : null,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Salvar'),
                  ),
                ),
              ],
            ),
            body: AbsorbPointer(
              absorbing: _saving,
              child: _buildEditor(event, saveBlockMessage),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditor(SoundTrackEvent event, String? validationMessage) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(
        SoundTrackTokens.pagePadding,
        8,
        SoundTrackTokens.pagePadding,
        32,
      ),
      buildDefaultDragHandles: false,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Nome do evento'),
            onChanged: widget.controller.rename,
          ),
          if (validationMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              validationMessage,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: SoundTrackTokens.sectionGap),
          EditorialSectionHeader(
            title: 'Momentos',
            actionLabel: 'Adicionar',
            actionKey: addMomentKey,
            onAction: _saving ? null : _addMoment,
          ),
          if (event.moments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Adicione o primeiro momento')),
            ),
        ],
      ),
      footer: Container(
        key: _audioTargetKey,
        child: KeyedSubtree(
          key: eventAudioSectionKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: SoundTrackTokens.sectionGap),
              const Divider(),
              const SizedBox(height: SoundTrackTokens.sectionGap),
              const EditorialSectionHeader(title: 'Áudio do evento'),
              const SizedBox(height: 8),
              EventAudioSettingsEditor(
                settings: event.audioSettings,
                onChanged: widget.controller.updateSettings,
              ),
            ],
          ),
        ),
      ),
      itemCount: event.moments.length,
      onReorderItem: (oldIndex, newIndex) {
        widget.controller.reorderMoment(
          oldIndex,
          newIndex > oldIndex ? newIndex + 1 : newIndex,
        );
      },
      itemBuilder: (context, index) {
        final moment = event.moments[index];
        return MomentListRow(
          key: momentTileKey(moment.id),
          moment: moment,
          number: index + 1,
          index: index,
          onTap: () => _editMoment(moment),
        );
      },
    );
  }

  Future<void> _addMoment() async {
    var draftName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Novo momento'),
        content: TextFormField(
          key: momentNameFieldKey,
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
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      widget.controller.addMoment(name.trim());
    }
  }

  Future<void> _editMoment(EventMoment moment) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => MomentEditorSheet(
        moment: moment,
        onSelectAudio: widget.onSelectAudio,
        onSave: widget.controller.updateMoment,
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.controller.save();
      if (mounted) {
        final message = widget.controller.dirty
            ? 'O evento mudou durante o salvamento'
            : 'Evento salvo';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar o evento')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDiscard() async {
    if (_saving) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text('As alterações não salvas serão perdidas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }
}
