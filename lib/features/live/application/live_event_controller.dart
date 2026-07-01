import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../events/domain/event_moment.dart';
import '../../events/domain/soundtrack_event.dart';
import '../../playback/application/live_playback_port.dart';
import '../../playback/domain/playback_alert.dart';
import 'live_event_state.dart';

class LiveEventController {
  LiveEventController({
    required SoundTrackEvent event,
    required LivePlaybackPort playback,
  }) : _playback = playback,
       state = ValueNotifier<LiveEventState>(
         LiveEventState(
           event: event,
           playback: playback.snapshot.value,
           visibleAlert: null,
           controlsExpanded: false,
         ),
       ) {
    _playback.snapshot.addListener(_onSnapshot);
    _alertSubscription = _playback.alerts.listen(
      _onAlert,
      onError: _onAlertError,
    );
  }

  final LivePlaybackPort _playback;
  final ValueNotifier<LiveEventState> state;

  late final StreamSubscription<PlaybackAlert> _alertSubscription;
  Future<void> _commandTail = Future<void>.value();
  Future<void>? _disposeFuture;
  bool _disposed = false;

  Future<void> startMoment(String momentId) {
    return _enqueue(() async {
      final current = state.value;
      if (current.playback.activeMomentId == momentId) {
        return;
      }

      final moment = _momentById(momentId);
      final uri = _validatedUri(moment?.audio?.uri);
      if (moment == null || moment.audioPending || uri == null) {
        _publishSourceUnavailable(
          momentId,
          moment == null
              ? 'Momento não encontrado.'
              : 'Áudio indisponível para este momento.',
        );
        return;
      }

      final activeMoment = current.activeMoment;
      if (current.playback.narrationActive && activeMoment?.id != moment.id) {
        await _playback.setNarration(false);
        if (_disposed) {
          return;
        }
      }

      final request = MomentPlaybackRequest(
        momentId: moment.id,
        momentName: moment.name,
        uri: uri,
        audioDisplayName: moment.audio!.displayName,
        loop: moment.endBehavior == EndBehavior.loop,
        narrationEnabled: moment.narrationEnabled,
        gainDb: moment.gainDb,
        fadeIn: moment.fadeIn ?? current.event.audioSettings.fadeIn,
        fadeOut: activeMoment?.fadeOut ?? current.event.audioSettings.fadeOut,
      );

      try {
        await _playback.startMoment(request);
      } catch (_) {
        _publish(
          PlaybackAlert(
            PlaybackAlertCode.sourceFailed,
            'Não foi possível iniciar o áudio deste momento.',
            momentId: moment.id,
          ),
        );
      }
    });
  }

  Future<void> pause() => _enqueue(_playback.pause);

  Future<void> resume() => _enqueue(_playback.resume);

  Future<void> stop({required bool confirmed}) {
    if (!confirmed) {
      return Future<void>.value();
    }
    return _enqueue(_playback.stop);
  }

  Future<void> confirmStop() => stop(confirmed: true);

  Future<void> setNarration(bool active) {
    return _enqueue(() async {
      final moment = state.value.activeMoment;
      if (moment == null || !moment.narrationEnabled) {
        _publishSourceUnavailable(
          moment?.id,
          moment == null
              ? 'Inicie um momento com Narração habilitada.'
              : 'Narração não está habilitada para este momento.',
        );
        return;
      }
      await _playback.setNarration(active);
    });
  }

  Future<void> setSessionVolumes({
    required double masterVolume,
    required double musicVolume,
    required double narrationVolume,
  }) {
    return _enqueue(
      () => _playback.setSessionVolumes(
        masterVolume: masterVolume,
        musicVolume: musicVolume,
        narrationVolume: narrationVolume,
      ),
    );
  }

  Future<void> restorePresetVolumes() =>
      _enqueue(_playback.restorePresetVolumes);

  void dismissAlert() {
    _publishState(state.value.copyWith(clearVisibleAlert: true));
  }

  void toggleControlsExpanded() {
    _publishState(
      state.value.copyWith(controlsExpanded: !state.value.controlsExpanded),
    );
  }

  void refreshFromPlaybackSnapshot() {
    _publishState(state.value.copyWith(playback: _playback.snapshot.value));
  }

  Future<void> dispose() {
    final existing = _disposeFuture;
    if (existing != null) {
      return existing;
    }
    _disposed = true;
    _playback.snapshot.removeListener(_onSnapshot);
    state.dispose();
    final result = _alertSubscription.cancel();
    _disposeFuture = result;
    return result;
  }

  Future<void> _enqueue(Future<void> Function() command) {
    final result = _commandTail.then((_) async {
      if (_disposed) {
        return;
      }
      await command();
    });
    _commandTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  EventMoment? _momentById(String id) {
    for (final moment in state.value.event.moments) {
      if (moment.id == id) {
        return moment;
      }
    }
    return null;
  }

  Uri? _validatedUri(String? source) {
    if (source == null || source.trim() != source || source.contains(' ')) {
      return null;
    }
    final uri = Uri.tryParse(source);
    if (uri == null || !uri.hasScheme) {
      return null;
    }
    return uri;
  }

  void _onSnapshot() {
    _publishState(state.value.copyWith(playback: _playback.snapshot.value));
  }

  void _onAlert(PlaybackAlert alert) {
    _publish(alert);
  }

  void _onAlertError(Object _, StackTrace _) {
    _publish(
      const PlaybackAlert(
        PlaybackAlertCode.sourceFailed,
        'Falha ao acompanhar alertas de reprodução.',
      ),
    );
  }

  void _publishSourceUnavailable(String? momentId, String message) {
    _publish(
      PlaybackAlert(
        PlaybackAlertCode.sourceUnavailable,
        message,
        momentId: momentId,
      ),
    );
  }

  void _publish(PlaybackAlert alert) {
    _publishState(state.value.copyWith(visibleAlert: alert));
  }

  void _publishState(LiveEventState next) {
    if (!_disposed) {
      state.value = next;
    }
  }
}
