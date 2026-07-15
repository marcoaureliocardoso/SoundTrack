import 'package:flutter/material.dart';

import '../../../../app/theme/soundtrack_theme.dart';
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
    final duration = state.currentAudioDuration;
    final progress = duration == null || duration.inMilliseconds <= 0
        ? null
        : (playback.position.inMilliseconds / duration.inMilliseconds).clamp(
            0.0,
            1.0,
          );
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
      child: DecoratedBox(
        key: nowPlayingAccentKey,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          border: const Border(
            left: BorderSide(color: SoundTrackTokens.accent, width: 4),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: compact ? showTrackDetails : null,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 10 : 16,
                compact ? 8 : 16,
                compact ? 10 : 16,
                compact ? 8 : 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!compact) ...[
                    Text(
                      'AGORA',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: SoundTrackTokens.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    moment,
                    style: compact
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
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
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SoundTrackTokens.secondaryText,
                        ),
                      ),
                  ],
                  SizedBox(height: compact ? 2 : 12),
                  if (compact)
                    Text(
                      '$status · $time',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [Text(status), Text(time)],
                    ),
                  if (!compact) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progress ?? 0,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                ],
              ),
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
