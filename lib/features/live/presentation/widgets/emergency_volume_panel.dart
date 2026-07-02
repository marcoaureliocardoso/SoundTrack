import 'package:flutter/material.dart';

import '../../../playback/domain/playback_snapshot.dart';
import '../live_dashboard_keys.dart';

typedef SessionVolumesChanged =
    Future<void> Function({
      required double masterVolume,
      required double musicVolume,
      required double narrationVolume,
    });

typedef _Volumes = ({double master, double music, double narration});

class EmergencyVolumePanel extends StatefulWidget {
  const EmergencyVolumePanel({
    required this.expanded,
    required this.playback,
    required this.onToggle,
    required this.onVolumesChanged,
    required this.onRestore,
    super.key,
  });

  final bool expanded;
  final PlaybackSnapshot playback;
  final VoidCallback onToggle;
  final SessionVolumesChanged onVolumesChanged;
  final Future<void> Function() onRestore;

  @override
  State<EmergencyVolumePanel> createState() => _EmergencyVolumePanelState();
}

class _EmergencyVolumePanelState extends State<EmergencyVolumePanel> {
  late _Volumes _local;
  _Volumes? _queued;
  _Volumes? _awaitingAck;
  var _sending = false;
  var _dragging = false;
  var _restoreBusy = false;

  @override
  void initState() {
    super.initState();
    _local = _snapshotVolumes(widget.playback);
  }

  @override
  void didUpdateWidget(EmergencyVolumePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final confirmed = _snapshotVolumes(widget.playback);
    if (_awaitingAck == confirmed) {
      _awaitingAck = null;
      if (_queued == null && !_dragging) {
        _local = confirmed;
      }
    } else if (_awaitingAck == null &&
        _queued == null &&
        !_sending &&
        !_dragging) {
      _local = confirmed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        key: emergencyVolumesKey,
        initiallyExpanded: widget.expanded,
        onExpansionChanged: (_) => widget.onToggle(),
        title: const Text('Volumes de emergência'),
        subtitle: const Text('Ajustes temporários desta sessão'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _VolumeSlider(
            label: 'Master',
            value: _local.master * 100,
            onChangeStart: _beginDrag,
            onChangeEnd: _endDrag,
            onChanged: (value) => _changeVolumes(master: value / 100),
          ),
          _VolumeSlider(
            label: 'Música',
            value: _local.music * 100,
            onChangeStart: _beginDrag,
            onChangeEnd: _endDrag,
            onChanged: (value) => _changeVolumes(music: value / 100),
          ),
          _VolumeSlider(
            label: 'Narração',
            value: _local.narration * 100,
            onChangeStart: _beginDrag,
            onChangeEnd: _endDrag,
            onChanged: (value) => _changeVolumes(narration: value / 100),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _restoreBusy ? null : _restore,
              icon: const Icon(Icons.restore),
              label: const Text('Restaurar predefinições'),
            ),
          ),
        ],
      ),
    );
  }

  void _changeVolumes({double? master, double? music, double? narration}) {
    setState(() {
      _local = (
        master: master ?? _local.master,
        music: music ?? _local.music,
        narration: narration ?? _local.narration,
      );
      _queued = _local;
      _awaitingAck = _local;
    });
    if (!_sending) {
      _drainVolumeChanges();
    }
  }

  Future<void> _drainVolumeChanges() async {
    if (_sending) return;
    _sending = true;
    try {
      while (_queued != null) {
        final volumes = _queued!;
        _queued = null;
        try {
          await widget.onVolumesChanged(
            masterVolume: volumes.master,
            musicVolume: volumes.music,
            narrationVolume: volumes.narration,
          );
        } catch (_) {
          _queued = null;
          _awaitingAck = null;
          break;
        }
      }
    } finally {
      _sending = false;
    }
  }

  Future<void> _restore() async {
    if (_restoreBusy) return;
    setState(() => _restoreBusy = true);
    try {
      await widget.onRestore();
    } catch (_) {
      // The controller publishes the operator-facing alert.
    } finally {
      if (mounted) {
        setState(() => _restoreBusy = false);
      }
    }
  }

  void _beginDrag(double _) {
    _dragging = true;
  }

  void _endDrag(double _) {
    _dragging = false;
    final confirmed = _snapshotVolumes(widget.playback);
    if (_awaitingAck == null && _queued == null && !_sending && mounted) {
      setState(() => _local = confirmed);
    }
  }

  _Volumes _snapshotVolumes(PlaybackSnapshot playback) => (
    master: playback.masterVolume,
    music: playback.musicVolume,
    narration: playback.narrationVolume,
  );
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onChangeStart,
    required this.onChangeEnd,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final rounded = value.round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label — $rounded%'),
        Slider(
          value: value.clamp(0, 100),
          min: 0,
          max: 100,
          divisions: 100,
          label: '$rounded%',
          semanticFormatterCallback: (sliderValue) =>
              '$label ${sliderValue.round()} por cento',
          onChangeStart: onChangeStart,
          onChangeEnd: onChangeEnd,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
