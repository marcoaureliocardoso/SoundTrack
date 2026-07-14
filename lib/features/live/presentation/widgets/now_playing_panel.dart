import 'package:flutter/material.dart';

import '../../application/live_event_state.dart';
import '../../../playback/domain/playback_snapshot.dart';
import '../live_dashboard_keys.dart';
import 'track_name_ticker.dart';

class NowPlayingPanel extends StatelessWidget {
  const NowPlayingPanel({required this.state, this.compact = false, super.key});

  final LiveEventState state;
  final bool compact;

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
    void showTrackDetails() {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: nowPlayingDetailsKey,
          title: const Text('Faixa atual'),
          content: SelectableText(track),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    }

    return Semantics(
      container: true,
      label: 'Agora: $moment. Faixa: $track. $status. Tempo $time.',
      button: compact,
      onTap: compact ? showTrackDetails : null,
      excludeSemantics: true,
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: InkWell(
          onTap: compact ? showTrackDetails : null,
          child: Padding(
            padding: EdgeInsets.all(compact ? 8 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!compact) ...[
                  Text('AGORA', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                ],
                Text(
                  moment,
                  style: compact
                      ? Theme.of(context).textTheme.titleMedium
                      : Theme.of(context).textTheme.headlineSmall,
                  maxLines: compact ? 1 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                ),
                if (!compact) ...[
                  const SizedBox(height: 4),
                  TrackNameTicker(
                    key: nowPlayingTrackKey,
                    text: track,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (state.currentAudioArtist case final artist?)
                    Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                SizedBox(height: compact ? 2 : 12),
                if (compact)
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    children: [Text(status), Text(time)],
                  )
                else
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [Text(status), Text(time)],
                  ),
              ],
            ),
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
