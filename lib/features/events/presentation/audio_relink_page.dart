import 'package:flutter/material.dart';

import '../../../app/theme/soundtrack_theme.dart';
import '../../../app/widgets/editorial_components.dart';
import '../application/event_transfer_controller.dart';
import '../domain/event_moment.dart';
import '../domain/soundtrack_event.dart';

class AudioRelinkPage extends StatefulWidget {
  const AudioRelinkPage({
    required this.event,
    required this.controller,
    super.key,
  });

  final SoundTrackEvent event;
  final EventTransferController controller;

  @override
  State<AudioRelinkPage> createState() => _AudioRelinkPageState();
}

class _AudioRelinkPageState extends State<AudioRelinkPage> {
  late SoundTrackEvent _event = widget.event;
  String? _busyMomentId;
  String? _error;

  List<EventMoment> get _pending =>
      _event.moments.where((moment) => moment.audioPending).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Áudios pendentes')),
      body: _pending.isEmpty
          ? const Center(child: Text('Todas as músicas foram localizadas.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                SoundTrackTokens.pagePadding,
                12,
                SoundTrackTokens.pagePadding,
                32,
              ),
              children: [
                const Text(
                  'Os arquivos de áudio não acompanham o evento exportado. '
                  'Selecione no dispositivo as músicas de cada momento.',
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: StatusIndicator.error(label: _error!),
                  ),
                const SizedBox(height: SoundTrackTokens.sectionGap),
                for (var index = 0; index < _pending.length; index++) ...[
                  _pendingRow(_pending[index]),
                  if (index < _pending.length - 1) const Divider(height: 1),
                ],
              ],
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextButton(
          onPressed: _busyMomentId == null
              ? () => Navigator.of(context).pop(_event)
              : null,
          child: Text(
            _pending.isEmpty ? 'Voltar ao evento' : 'Resolver depois',
          ),
        ),
      ),
    );
  }

  Widget _pendingRow(EventMoment moment) {
    final audio = moment.audio;
    final metadata = [
      'Momento: ${moment.name}',
      if (audio?.artist != null) audio!.artist!,
      if (audio?.duration != null) _duration(audio!.duration!),
    ].join(' · ');
    return EditorialRow(
      leading: const Icon(
        Icons.warning_amber_rounded,
        color: SoundTrackTokens.warning,
      ),
      title: audio?.displayName ?? 'Nenhum arquivo selecionado',
      subtitle: metadata,
      trailing: TextButton(
        onPressed: _busyMomentId == null ? () => _relink(moment.id) : null,
        child: _busyMomentId == moment.id
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Selecionar'),
      ),
    );
  }

  Future<void> _relink(String momentId) async {
    setState(() {
      _busyMomentId = momentId;
      _error = null;
    });
    try {
      final updated = await widget.controller.relinkMoment(_event, momentId);
      if (mounted) setState(() => _event = updated);
    } catch (_) {
      if (mounted) {
        final moment = _event.moments.firstWhere(
          (candidate) => candidate.id == momentId,
        );
        setState(
          () => _error =
              'Não foi possível religar “${moment.name}”. Escolha outro arquivo de áudio.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyMomentId = null);
    }
  }

  String _duration(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
