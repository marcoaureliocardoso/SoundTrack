import 'package:flutter/material.dart';

import '../domain/audio_reference.dart';
import '../domain/event_moment.dart';

typedef AudioSelectionCallback = Future<AudioReference?> Function();

class MomentEditorSheet extends StatefulWidget {
  const MomentEditorSheet({
    required this.moment,
    required this.onSave,
    this.onSelectAudio,
    super.key,
  });

  final EventMoment moment;
  final ValueChanged<EventMoment> onSave;
  final AudioSelectionCallback? onSelectAudio;

  @override
  State<MomentEditorSheet> createState() => _MomentEditorSheetState();
}

class _MomentEditorSheetState extends State<MomentEditorSheet> {
  late final TextEditingController _nameController;
  late EventMoment _draft;

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
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Editar momento',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
              onChanged: (name) {
                setState(() => _draft = _draft.copyWith(name: name));
              },
            ),
            const SizedBox(height: 16),
            SegmentedButton<EndBehavior>(
              segments: const [
                ButtonSegment(value: EndBehavior.loop, label: Text('Loop')),
                ButtonSegment(value: EndBehavior.stop, label: Text('Parar')),
              ],
              selected: {_draft.endBehavior},
              onSelectionChanged: (value) {
                setState(() {
                  _draft = _draft.copyWith(endBehavior: value.single);
                });
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Narração'),
              value: _draft.narrationEnabled,
              onChanged: (value) {
                setState(() {
                  _draft = _draft.copyWith(narrationEnabled: value);
                });
              },
            ),
            Text('Ganho: ${_draft.gainDb.toStringAsFixed(0)} dB'),
            Slider(
              min: -12,
              max: 6,
              divisions: 18,
              value: _draft.gainDb,
              label: '${_draft.gainDb.toStringAsFixed(0)} dB',
              onChanged: (value) {
                setState(() => _draft = _draft.copyWith(gainDb: value));
              },
            ),
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
            OutlinedButton.icon(
              onPressed: widget.onSelectAudio == null ? null : _selectAudio,
              icon: const Icon(Icons.audio_file),
              label: Text(_draft.audio?.displayName ?? 'Selecionar áudio'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _nameController.text.trim().isEmpty
                  ? null
                  : () {
                      widget.onSave(
                        _draft.copyWith(name: _nameController.text.trim()),
                      );
                      Navigator.pop(context);
                    },
              child: const Text('Concluir'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectAudio() async {
    final audio = await widget.onSelectAudio?.call();
    if (!mounted || audio == null) {
      return;
    }
    setState(() => _draft = _draft.copyWith(audio: audio));
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
    return Row(
      children: [
        Expanded(child: Text(label)),
        DropdownButton<int?>(
          value: value?.inMilliseconds,
          onChanged: (milliseconds) => onChanged(
            milliseconds == null ? null : Duration(milliseconds: milliseconds),
          ),
          items: const [
            DropdownMenuItem(value: null, child: Text('Herdado')),
            DropdownMenuItem(value: 0, child: Text('Sem fade')),
            DropdownMenuItem(value: 1000, child: Text('1 s')),
            DropdownMenuItem(value: 2000, child: Text('2 s')),
            DropdownMenuItem(value: 3000, child: Text('3 s')),
            DropdownMenuItem(value: 5000, child: Text('5 s')),
          ],
        ),
      ],
    );
  }
}
