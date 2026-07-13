import 'package:flutter/material.dart';

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
      appBar: AppBar(title: const Text('Localizar músicas')),
      body: _pending.isEmpty
          ? const Center(child: Text('Todas as músicas foram localizadas.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Escolha novamente os arquivos que não estão acessíveis.',
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                for (final moment in _pending) _pendingTile(moment),
              ],
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: OutlinedButton(
          onPressed: _busyMomentId == null
              ? () => Navigator.of(context).pop(_event)
              : null,
          child: Text(_pending.isEmpty ? 'Concluir' : 'Resolver depois'),
        ),
      ),
    );
  }

  Widget _pendingTile(EventMoment moment) {
    final audio = moment.audio;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              audio?.displayName ?? 'Nenhuma música selecionada',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(moment.name),
            if (audio?.artist != null) Text(audio!.artist!),
            if (audio?.duration != null) Text(_duration(audio!.duration!)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _busyMomentId == null
                    ? () => _relink(moment.id)
                    : null,
                child: _busyMomentId == moment.id
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Escolher música'),
              ),
            ),
          ],
        ),
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
