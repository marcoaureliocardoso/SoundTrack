import 'package:flutter/material.dart';

import '../../application/live_event_state.dart';
import '../../../playback/domain/playback_snapshot.dart';

class NowPlayingPanel extends StatelessWidget {
  const NowPlayingPanel({required this.state, super.key});

  final LiveEventState state;

  @override
  Widget build(BuildContext context) {
    final moment = state.currentMomentName ?? 'Nenhum momento iniciado';
    final track =
        state.currentAudioDisplayName ?? 'Nenhuma faixa em reprodução';
    final playback = state.playback;
    final status = switch (playback.phase) {
      PlaybackPhase.loading => 'Carregando',
      PlaybackPhase.playing => 'Reproduzindo',
      PlaybackPhase.paused => 'Pausado',
      PlaybackPhase.transitioning => 'Em transição',
      PlaybackPhase.stopped => 'Parado',
      PlaybackPhase.idle => 'Aguardando início',
    };
    final time =
        '${_format(playback.position)} / ${_format(state.currentAudioDuration)}';

    return Semantics(
      container: true,
      label: 'Agora: $moment. Faixa: $track. $status. Tempo $time.',
      excludeSemantics: true,
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AGORA', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(moment, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(track, style: Theme.of(context).textTheme.titleMedium),
              if (state.currentAudioArtist case final artist?)
                Text(artist, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [Text(status), Text(time)],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _format(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
