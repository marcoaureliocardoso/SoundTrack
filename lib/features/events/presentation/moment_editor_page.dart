import 'package:flutter/material.dart';

import '../../../app/theme/soundtrack_theme.dart';
import '../../../app/widgets/editorial_components.dart';
import '../domain/audio_reference.dart';
import '../domain/event_moment.dart';

typedef AudioSelectionCallback = Future<AudioReference?> Function();

const momentEditorNameFieldKey = Key('moment-editor-name-field');
const momentAudioActionKey = Key('moment-audio-action');
const momentGainSliderKey = Key('moment-gain-slider');
const deleteMomentKey = Key('delete-moment');

class MomentEditorPage extends StatefulWidget {
  const MomentEditorPage({
    required this.moment,
    required this.onSave,
    this.onDelete,
    this.onSelectAudio,
    super.key,
  });

  final EventMoment moment;
  final ValueChanged<EventMoment> onSave;
  final VoidCallback? onDelete;
  final AudioSelectionCallback? onSelectAudio;

  @override
  State<MomentEditorPage> createState() => _MomentEditorPageState();
}

class _MomentEditorPageState extends State<MomentEditorPage> {
  late final TextEditingController _nameController;
  late EventMoment _draft;
  bool _selectingAudio = false;
  bool _completed = false;
  String? _audioError;

  @override
  void initState() {
    super.initState();
    _draft = widget.moment;
    _nameController = TextEditingController(text: _draft.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave =
        !_completed &&
        !_selectingAudio &&
        _nameController.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar momento'),
        actions: [
          TextButton(
            onPressed: canSave ? _save : null,
            child: const Text('Salvar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SoundTrackTokens.pagePadding,
          12,
          SoundTrackTokens.pagePadding,
          32,
        ),
        children: [
          TextField(
            key: momentEditorNameFieldKey,
            controller: _nameController,
            autofocus: widget.moment.name.isEmpty,
            decoration: const InputDecoration(labelText: 'Nome do momento'),
            onChanged: (name) {
              setState(() => _draft = _draft.copyWith(name: name));
            },
          ),
          const SizedBox(height: SoundTrackTokens.sectionGap),
          const EditorialSectionHeader(title: 'Música'),
          const SizedBox(height: 4),
          _AudioSelectionRow(
            audio: _draft.audio,
            selecting: _selectingAudio,
            enabled: widget.onSelectAudio != null && !_selectingAudio,
            onPressed: _selectAudio,
          ),
          if (_audioError != null) ...[
            const SizedBox(height: 4),
            Text(
              _audioError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: SoundTrackTokens.sectionGap),
          const EditorialSectionHeader(title: 'Ao terminar a faixa'),
          const SizedBox(height: 8),
          _EndBehaviorControl(
            value: _draft.endBehavior,
            onChanged: (value) {
              setState(() => _draft = _draft.copyWith(endBehavior: value));
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Narração'),
            subtitle: const Text(
              'Permite reduzir a música enquanto houver uma fala',
            ),
            value: _draft.narrationEnabled,
            onChanged: (value) {
              setState(() {
                _draft = _draft.copyWith(narrationEnabled: value);
              });
            },
          ),
          const SizedBox(height: 8),
          _TrackVolumeControl(
            value: _draft.gainDb,
            onChanged: (value) {
              setState(() => _draft = _draft.copyWith(gainDb: value));
            },
          ),
          const SizedBox(height: 12),
          _FadeControl(
            label: 'Fade-in',
            value: _draft.fadeIn,
            onChanged: (value) {
              setState(() {
                _draft = value == null
                    ? _draft.copyWith(clearFadeIn: true)
                    : _draft.copyWith(fadeIn: value);
              });
            },
          ),
          const SizedBox(height: 12),
          _FadeControl(
            label: 'Fade-out',
            value: _draft.fadeOut,
            onChanged: (value) {
              setState(() {
                _draft = value == null
                    ? _draft.copyWith(clearFadeOut: true)
                    : _draft.copyWith(fadeOut: value);
              });
            },
          ),
          if (widget.onDelete != null) ...[
            const SizedBox(height: SoundTrackTokens.sectionGap),
            const Divider(),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: deleteMomentKey,
                onPressed: _completed ? null : _confirmDelete,
                style: TextButton.styleFrom(
                  foregroundColor: SoundTrackTokens.destructive,
                  minimumSize: const Size(
                    SoundTrackTokens.targetMinSize,
                    SoundTrackTokens.targetMinSize,
                  ),
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Excluir este momento'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _save() {
    if (_completed || _selectingAudio) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    _completed = true;
    widget.onSave(_draft.copyWith(name: name));
    Navigator.of(context).pop();
  }

  Future<void> _selectAudio() async {
    final selectAudio = widget.onSelectAudio;
    if (selectAudio == null || _selectingAudio) return;
    setState(() {
      _selectingAudio = true;
      _audioError = null;
    });
    try {
      final audio = await selectAudio();
      if (mounted && audio != null) {
        setState(() => _draft = _draft.copyWith(audio: audio));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _audioError = 'Não foi possível selecionar o áudio';
        });
      }
    } finally {
      if (mounted) setState(() => _selectingAudio = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir este momento?'),
        content: const Text(
          'O momento será removido do evento. '
          'O arquivo no dispositivo não será excluído.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: SoundTrackTokens.destructive,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || _completed) return;
    _completed = true;
    widget.onDelete?.call();
    if (mounted) Navigator.of(context).pop();
  }
}

class _AudioSelectionRow extends StatelessWidget {
  const _AudioSelectionRow({
    required this.audio,
    required this.selecting,
    required this.enabled,
    required this.onPressed,
  });

  final AudioReference? audio;
  final bool selecting;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final filename = audio?.displayName ?? 'Nenhuma música selecionada';
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = textScale > 1.4 || constraints.maxWidth < 300;
        final label = Expanded(
          child: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
        final action = TextButton(
          key: momentAudioActionKey,
          onPressed: enabled ? onPressed : null,
          style: TextButton.styleFrom(
            minimumSize: const Size(
              SoundTrackTokens.targetMinSize,
              SoundTrackTokens.targetMinSize,
            ),
          ),
          child: selecting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Trocar'),
        );
        if (vertical) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.audio_file),
                  const SizedBox(width: 12),
                  label,
                ],
              ),
              Align(alignment: Alignment.centerRight, child: action),
            ],
          );
        }
        return Row(
          children: [
            const Icon(Icons.audio_file),
            const SizedBox(width: 12),
            label,
            const SizedBox(width: 8),
            action,
          ],
        );
      },
    );
  }
}

class _EndBehaviorControl extends StatelessWidget {
  const _EndBehaviorControl({required this.value, required this.onChanged});

  final EndBehavior value;
  final ValueChanged<EndBehavior> onChanged;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) => Semantics(
        label: value == EndBehavior.loop
            ? 'Repetir em loop. Ativo'
            : 'Parar. Ativo',
        child: SegmentedButton<EndBehavior>(
          direction: textScale > 1.4 || constraints.maxWidth < 320
              ? Axis.vertical
              : Axis.horizontal,
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: EndBehavior.loop,
              icon: Icon(Icons.loop),
              label: Text('Repetir em loop'),
            ),
            ButtonSegment(
              value: EndBehavior.stop,
              icon: Icon(Icons.stop),
              label: Text('Parar'),
            ),
          ],
          selected: {value},
          onSelectionChanged: (values) => onChanged(values.single),
        ),
      ),
    );
  }
}

class _TrackVolumeControl extends StatelessWidget {
  const _TrackVolumeControl({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 2,
          children: [
            const Text('Volume da faixa'),
            Text('${value.toStringAsFixed(0)} dB'),
          ],
        ),
        Slider(
          key: momentGainSliderKey,
          min: -12,
          max: 6,
          divisions: 18,
          value: value,
          label: '${value.toStringAsFixed(0)} dB',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _FadeControl extends StatelessWidget {
  const _FadeControl({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Duration? value;
  final ValueChanged<Duration?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int?>(
      initialValue: value?.inMilliseconds,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      onChanged: (milliseconds) => onChanged(
        milliseconds == null ? null : Duration(milliseconds: milliseconds),
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text('Herdado do evento')),
        DropdownMenuItem(value: 0, child: Text('Sem fade')),
        DropdownMenuItem(value: 1000, child: Text('1 s')),
        DropdownMenuItem(value: 2000, child: Text('2 s')),
        DropdownMenuItem(value: 3000, child: Text('3 s')),
        DropdownMenuItem(value: 5000, child: Text('5 s')),
      ],
    );
  }
}
