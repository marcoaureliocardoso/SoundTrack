import 'package:flutter/material.dart';

import '../application/event_editor_controller.dart';
import '../domain/audio_reference.dart';
import '../domain/event_audio_settings.dart';
import '../domain/event_moment.dart';
import '../domain/soundtrack_event.dart';
import 'moment_editor_sheet.dart';
import 'widgets/moment_tile.dart';

const addMomentKey = Key('add-moment');
const momentNameFieldKey = Key('moment-name-field');
Key momentTileKey(String id) => Key('moment-$id');

class EventEditorPage extends StatefulWidget {
  const EventEditorPage({
    required this.controller,
    this.onSelectAudio,
    super.key,
  });

  final EventEditorController controller;
  final Future<AudioReference?> Function()? onSelectAudio;

  @override
  State<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends State<EventEditorPage> {
  late final TextEditingController _nameController;
  bool _saving = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.controller.draft.name);
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
        final issues = widget.controller.issues;
        final validationMessage = issues.isEmpty ? null : issues.first.message;
        return PopScope<void>(
          canPop: _allowPop || !widget.controller.dirty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              _confirmDiscard();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Editar evento'),
              actions: [
                IconButton(
                  tooltip: validationMessage ?? 'Salvar',
                  onPressed:
                      _saving ||
                          !widget.controller.dirty ||
                          validationMessage != null
                      ? null
                      : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                ),
              ],
            ),
            body: AbsorbPointer(
              absorbing: _saving,
              child: _buildEditor(event, validationMessage),
            ),
            floatingActionButton: FloatingActionButton.extended(
              key: addMomentKey,
              onPressed: _saving ? null : _addMoment,
              icon: const Icon(Icons.add),
              label: const Text('Momento'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditor(SoundTrackEvent event, String? validationMessage) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
      buildDefaultDragHandles: false,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Nome do evento'),
              onChanged: widget.controller.rename,
            ),
            const SizedBox(height: 16),
            _GlobalControls(
              settings: event.audioSettings,
              onChanged: widget.controller.updateSettings,
            ),
            if (validationMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                validationMessage,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Tooltip(
              message: 'Disponível após instalar o motor de áudio',
              child: FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Disponível após instalar o motor de áudio'),
              ),
            ),
            const SizedBox(height: 16),
            Text('Momentos', style: Theme.of(context).textTheme.titleLarge),
            if (event.moments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('Adicione o primeiro momento')),
              ),
          ],
        ),
      ),
      itemCount: event.moments.length,
      onReorderItem: (oldIndex, newIndex) {
        // The domain API accepts the pre-removal insertion index.
        widget.controller.reorderMoment(
          oldIndex,
          newIndex > oldIndex ? newIndex + 1 : newIndex,
        );
      },
      itemBuilder: (context, index) {
        final moment = event.moments[index];
        return ReorderableDragStartListener(
          key: momentTileKey(moment.id),
          index: index,
          child: MomentTile(
            moment: moment,
            onEdit: () => _editMoment(moment),
            onDelete: () => widget.controller.removeMoment(moment.id),
          ),
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
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _confirmDiscard() async {
    if (_saving) {
      return;
    }
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
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }
}

class _GlobalControls extends StatelessWidget {
  const _GlobalControls({required this.settings, required this.onChanged});

  final EventAudioSettings settings;
  final ValueChanged<EventAudioSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _VolumeControl(
          label: 'Master',
          value: settings.masterVolume,
          onChanged: (value) =>
              onChanged(settings.copyWith(masterVolume: value)),
        ),
        _VolumeControl(
          label: 'Música',
          value: settings.musicVolume,
          onChanged: (value) =>
              onChanged(settings.copyWith(musicVolume: value)),
        ),
        _VolumeControl(
          label: 'Narração',
          value: settings.narrationVolume,
          onChanged: (value) =>
              onChanged(settings.copyWith(narrationVolume: value)),
        ),
        Row(
          children: [
            Expanded(
              child: _DurationControl(
                label: 'Fade-in',
                value: settings.fadeIn,
                onChanged: (value) =>
                    onChanged(settings.copyWith(fadeIn: value)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DurationControl(
                label: 'Fade-out',
                value: settings.fadeOut,
                onChanged: (value) =>
                    onChanged(settings.copyWith(fadeOut: value)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VolumeControl extends StatelessWidget {
  const _VolumeControl({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            divisions: 20,
            label: '${(value * 100).round()}%',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _DurationControl extends StatelessWidget {
  const _DurationControl({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Duration value;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value.inMilliseconds,
      decoration: InputDecoration(labelText: label),
      items: const [0, 1000, 2000, 3000, 5000]
          .map(
            (milliseconds) => DropdownMenuItem(
              value: milliseconds,
              child: Text('${milliseconds ~/ 1000} s'),
            ),
          )
          .toList(),
      onChanged: (milliseconds) {
        if (milliseconds != null) {
          onChanged(Duration(milliseconds: milliseconds));
        }
      },
    );
  }
}
