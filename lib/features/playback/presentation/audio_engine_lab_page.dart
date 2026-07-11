import 'dart:async';

import 'package:flutter/material.dart';

import '../../../platform/documents/document_gateway.dart';
import '../application/live_playback_port.dart';
import '../domain/playback_alert.dart';
import '../domain/playback_snapshot.dart';

const selectAudioAKey = Key('audio-lab-select-a');
const selectAudioBKey = Key('audio-lab-select-b');
const loadAudioAKey = Key('audio-lab-load-a');
const loadAudioBKey = Key('audio-lab-load-b');
const crossfadeAToBKey = Key('audio-lab-crossfade-a-b');
const crossfadeBToAKey = Key('audio-lab-crossfade-b-a');
const narrationToggleKey = Key('audio-lab-narration');

class AudioEngineLabPage extends StatefulWidget {
  const AudioEngineLabPage({
    required this.playback,
    required this.documents,
    super.key,
  });

  final LivePlaybackPort playback;
  final DocumentGateway documents;

  @override
  State<AudioEngineLabPage> createState() => _AudioEngineLabPageState();
}

class _AudioEngineLabPageState extends State<AudioEngineLabPage> {
  static const _crossfadeDuration = Duration(milliseconds: 600);

  StreamSubscription<PlaybackAlert>? _alertSubscription;
  PickedDocument? _audioA;
  PickedDocument? _audioB;
  PlaybackAlert? _lastAlert;
  String? _localError;
  var _loop = false;
  var _narration = false;
  var _master = 0.8;
  var _music = 1.0;
  var _narrationVolume = 0.25;
  var _gainDb = 0.0;

  @override
  void initState() {
    super.initState();
    final snapshot = widget.playback.snapshot.value;
    _master = snapshot.masterVolume;
    _music = snapshot.musicVolume;
    _narrationVolume = snapshot.narrationVolume;
    _narration = snapshot.narrationActive;
    _alertSubscription = widget.playback.alerts.listen((alert) {
      if (mounted) {
        setState(() => _lastAlert = alert);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_alertSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Engine Lab')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'DEBUG ONLY',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _SourceRow(
            label: 'A',
            document: _audioA,
            selectKey: selectAudioAKey,
            loadKey: loadAudioAKey,
            onSelect: () => _select(isA: true),
            onLoad: _audioA == null
                ? null
                : () => _start(_audioA!, isA: true, crossfade: false),
          ),
          _SourceRow(
            label: 'B',
            document: _audioB,
            selectKey: selectAudioBKey,
            loadKey: loadAudioBKey,
            onSelect: () => _select(isA: false),
            onLoad: _audioB == null
                ? null
                : () => _start(_audioB!, isA: false, crossfade: false),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                key: crossfadeAToBKey,
                onPressed: _audioB == null
                    ? null
                    : () => _start(_audioB!, isA: false, crossfade: true),
                child: const Text('Crossfade A→B'),
              ),
              FilledButton(
                key: crossfadeBToAKey,
                onPressed: _audioA == null
                    ? null
                    : () => _start(_audioA!, isA: true, crossfade: true),
                child: const Text('Crossfade B→A'),
              ),
              OutlinedButton(
                onPressed: widget.playback.stop,
                child: const Text('Stop'),
              ),
            ],
          ),
          SwitchListTile(
            title: const Text('Loop'),
            value: _loop,
            onChanged: (value) => setState(() => _loop = value),
          ),
          SwitchListTile(
            key: narrationToggleKey,
            title: const Text('Narração'),
            value: _narration,
            onChanged: (value) {
              setState(() => _narration = value);
              unawaited(widget.playback.setNarration(value));
            },
          ),
          _VolumeSlider(
            label: 'Master',
            value: _master,
            onChanged: (value) {
              setState(() => _master = value);
              _applyVolumes();
            },
          ),
          _VolumeSlider(
            label: 'Música',
            value: _music,
            onChanged: (value) {
              setState(() => _music = value);
              _applyVolumes();
            },
          ),
          _VolumeSlider(
            label: 'Narração',
            value: _narrationVolume,
            onChanged: (value) {
              setState(() => _narrationVolume = value);
              _applyVolumes();
            },
          ),
          Text('Gain ${_gainDb.toStringAsFixed(1)} dB'),
          Slider(
            value: _gainDb,
            min: -12,
            max: 6,
            divisions: 18,
            onChanged: (value) => setState(() => _gainDb = value),
          ),
          const Divider(),
          ValueListenableBuilder<PlaybackSnapshot>(
            valueListenable: widget.playback.snapshot,
            builder: (context, snapshot, _) => SelectableText(
              'Snapshot: phase=${snapshot.phase.name}, '
              'playing=${snapshot.playing}, '
              'active=${snapshot.activeMomentId ?? '-'}, '
              'position=${snapshot.position.inMilliseconds}ms, '
              'duration=${snapshot.duration?.inMilliseconds ?? '-'}ms, '
              'narration=${snapshot.narrationActive}',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _lastAlert == null
                ? 'Último alerta: -'
                : 'Último alerta: ${_lastAlert!.code.name} — '
                      '${_lastAlert!.message}',
          ),
          if (_localError != null) ...[
            const SizedBox(height: 8),
            Text(
              _localError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _select({required bool isA}) async {
    try {
      final document = await widget.documents.pickAudio();
      if (!mounted || document == null) {
        return;
      }
      if (Uri.tryParse(document.uri)?.scheme != 'content') {
        setState(() {
          _localError = 'Selecione um áudio Android content://.';
        });
        return;
      }
      setState(() {
        if (isA) {
          _audioA = document;
        } else {
          _audioB = document;
        }
        _localError = null;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() => _localError = 'Falha ao selecionar áudio: $error');
      }
    }
  }

  Future<void> _start(
    PickedDocument document, {
    required bool isA,
    required bool crossfade,
  }) async {
    final fade = crossfade ? _crossfadeDuration : Duration.zero;
    await widget.playback.startMoment(
      MomentPlaybackRequest(
        momentId: isA ? 'audio-lab-a' : 'audio-lab-b',
        momentName: isA ? 'Audio Lab A' : 'Audio Lab B',
        uri: Uri.parse(document.uri),
        audioDisplayName: document.displayName,
        loop: _loop,
        narrationEnabled: true,
        gainDb: _gainDb,
        fadeIn: fade,
        fadeOut: fade,
      ),
    );
  }

  void _applyVolumes() {
    unawaited(
      widget.playback.setSessionVolumes(
        masterVolume: _master,
        musicVolume: _music,
        narrationVolume: _narrationVolume,
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.label,
    required this.document,
    required this.selectKey,
    required this.loadKey,
    required this.onSelect,
    required this.onLoad,
  });

  final String label;
  final PickedDocument? document;
  final Key selectKey;
  final Key loadKey;
  final VoidCallback onSelect;
  final VoidCallback? onLoad;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fonte $label: ${document?.displayName ?? 'não selecionada'}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  key: selectKey,
                  onPressed: onSelect,
                  child: Text('Selecionar $label'),
                ),
                FilledButton(
                  key: loadKey,
                  onPressed: onLoad,
                  child: Text('Load $label'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label ${(value * 100).round()}%'),
        Slider(value: value, onChanged: onChanged),
      ],
    );
  }
}
