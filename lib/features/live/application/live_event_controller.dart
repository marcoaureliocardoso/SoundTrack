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
  Future<void>? _disposeFuture;
  bool _disposed = false;

  Future<void> startMoment(String momentId) {
    if (_disposed) {
      return Future<void>.value();
    }
    final current = state.value;
    if (current.playback.activeMomentId == momentId) {
      return Future<void>.value();
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
      return Future<void>.value();
    }

    final activeMoment = current.activeMoment;
    final pending = <Future<void>>[];
    if (current.playback.narrationActive && activeMoment?.id != moment.id) {
      pending.add(Future<void>.sync(() => _playback.setNarration(false)));
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
    pending.add(_startAndReportFailure(request));
    return _waitForAll(pending);
  }

  Future<void> pause() => _invoke(_playback.pause);

  Future<void> resume() => _invoke(_playback.resume);

  Future<void> stop({required bool confirmed}) {
    if (!confirmed) {
      return Future<void>.value();
    }
    return _invoke(_playback.stop);
  }

  Future<void> confirmStop() => stop(confirmed: true);

  Future<void> setNarration(bool active) {
    return _invoke(() {
      final moment = state.value.activeMoment;
      if (moment == null || !moment.narrationEnabled) {
        _publishSourceUnavailable(
          moment?.id,
          moment == null
              ? 'Inicie um momento com Narração habilitada.'
              : 'Narração não está habilitada para este momento.',
        );
        return Future<void>.value();
      }
      return _playback.setNarration(active);
    });
  }

  Future<void> setSessionVolumes({
    required double masterVolume,
    required double musicVolume,
    required double narrationVolume,
  }) {
    return _invoke(
      () => _playback.setSessionVolumes(
        masterVolume: masterVolume,
        musicVolume: musicVolume,
        narrationVolume: narrationVolume,
      ),
    );
  }

  Future<void> restorePresetVolumes() =>
      _invoke(_playback.restorePresetVolumes);

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

  Future<void> _invoke(Future<void> Function() command) {
    if (_disposed) {
      return Future<void>.value();
    }
    return Future<void>.sync(command);
  }

  Future<void> _startAndReportFailure(MomentPlaybackRequest request) async {
    try {
      await _playback.startMoment(request);
    } catch (error, stackTrace) {
      _publish(
        PlaybackAlert(
          PlaybackAlertCode.sourceFailed,
          'Não foi possível iniciar o áudio deste momento.',
          momentId: request.momentId,
        ),
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _waitForAll(List<Future<void>> pending) async {
    await Future.wait(pending);
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
    final current = state.value;
    final snapshot = _playback.snapshot.value;
    final alert = current.visibleAlert;
    final recoveredFromSourceFailure =
        snapshot.playing &&
        snapshot.activeMomentId != null &&
        alert?.code == PlaybackAlertCode.sourceFailed &&
        alert?.momentId == snapshot.activeMomentId;
    _publishState(
      current.copyWith(
        playback: snapshot,
        clearVisibleAlert: recoveredFromSourceFailure,
      ),
    );
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
