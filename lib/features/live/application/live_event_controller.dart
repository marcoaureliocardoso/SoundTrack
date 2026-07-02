import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../events/domain/event_moment.dart';
import '../../events/domain/soundtrack_event.dart';
import '../../playback/application/live_playback_port.dart';
import '../../playback/domain/playback_alert.dart';
import '../../playback/domain/playback_snapshot.dart';
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
  final Map<String, Future<void>> _pendingStarts = {};
  Future<void>? _transportCommand;
  Future<void>? _narrationCommand;
  Future<void>? _restoreCommand;
  Future<void>? _disposeFuture;
  String? _sourceFailureMomentId;
  bool _sourceRecoveryArmed = false;
  bool _disposed = false;

  Future<void> startMoment(String momentId) {
    if (_disposed) {
      return Future<void>.value();
    }
    final current = state.value;
    if (current.playback.activeMomentId == momentId) {
      return Future<void>.value();
    }
    final pendingStart = _pendingStarts[momentId];
    if (pendingStart != null) {
      return pendingStart;
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
      pending.add(
        _invokeAndReport(
          () => _playback.setNarration(false),
          'Não foi possível desativar a Narração.',
          momentId: activeMoment?.id,
        ),
      );
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
    late final Future<void> command;
    command = _waitForAll(pending).whenComplete(() {
      if (identical(_pendingStarts[momentId], command)) {
        _pendingStarts.remove(momentId);
      }
    });
    _pendingStarts[momentId] = command;
    return command;
  }

  Future<void> pause() =>
      _runTransport(_playback.pause, 'Não foi possível pausar a reprodução.');

  Future<void> resume() =>
      _runTransport(_playback.resume, 'Não foi possível retomar a reprodução.');

  Future<void> stop({required bool confirmed}) {
    if (!confirmed) {
      return Future<void>.value();
    }
    return _invokeAndReport(
      _playback.stop,
      'Não foi possível parar a reprodução.',
    );
  }

  Future<void> confirmStop() => stop(confirmed: true);

  Future<void> setNarration(bool active) {
    if (_disposed) {
      return Future<void>.value();
    }
    final pending = _narrationCommand;
    if (pending != null) {
      return pending;
    }
    final command = Future<void>.sync(() {
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
      return _invokeAndReport(
        () => _playback.setNarration(active),
        'Não foi possível alterar a Narração.',
        momentId: moment.id,
      );
    });
    late final Future<void> tracked;
    tracked = command.whenComplete(() {
      if (identical(_narrationCommand, tracked)) {
        _narrationCommand = null;
      }
    });
    _narrationCommand = tracked;
    return tracked;
  }

  Future<void> setSessionVolumes({
    required double masterVolume,
    required double musicVolume,
    required double narrationVolume,
  }) {
    return _invokeAndReport(
      () => _playback.setSessionVolumes(
        masterVolume: masterVolume,
        musicVolume: musicVolume,
        narrationVolume: narrationVolume,
      ),
      'Não foi possível ajustar os volumes.',
    );
  }

  Future<void> restorePresetVolumes() {
    if (_disposed) {
      return Future<void>.value();
    }
    final pending = _restoreCommand;
    if (pending != null) {
      return pending;
    }
    late final Future<void> command;
    command =
        _invokeAndReport(
          _playback.restorePresetVolumes,
          'Não foi possível restaurar os volumes.',
        ).whenComplete(() {
          if (identical(_restoreCommand, command)) {
            _restoreCommand = null;
          }
        });
    _restoreCommand = command;
    return command;
  }

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

  Future<void> _invokeAndReport(
    Future<void> Function() command,
    String message, {
    String? momentId,
  }) async {
    if (_disposed) {
      return;
    }
    try {
      await Future<void>.sync(command);
    } catch (error, stackTrace) {
      _publish(
        PlaybackAlert(
          PlaybackAlertCode.sourceFailed,
          message,
          momentId: momentId,
        ),
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _runTransport(Future<void> Function() command, String message) {
    if (_disposed) {
      return Future<void>.value();
    }
    final pending = _transportCommand;
    if (pending != null) {
      return pending;
    }
    late final Future<void> tracked;
    tracked = _invokeAndReport(command, message).whenComplete(() {
      if (identical(_transportCommand, tracked)) {
        _transportCommand = null;
      }
    });
    _transportCommand = tracked;
    return tracked;
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
    final matchingTrackedFailure =
        alert?.code == PlaybackAlertCode.sourceFailed &&
        alert?.momentId != null &&
        alert?.momentId == _sourceFailureMomentId &&
        alert?.momentId == snapshot.activeMomentId;
    if (matchingTrackedFailure &&
        (snapshot.phase == PlaybackPhase.loading ||
            snapshot.phase == PlaybackPhase.transitioning)) {
      _sourceRecoveryArmed = true;
    }
    final recoveredFromSourceFailure =
        matchingTrackedFailure &&
        _sourceRecoveryArmed &&
        snapshot.phase == PlaybackPhase.playing &&
        snapshot.playing;
    if (recoveredFromSourceFailure) {
      _sourceFailureMomentId = null;
      _sourceRecoveryArmed = false;
    }
    _publishState(
      current.copyWith(
        playback: snapshot,
        clearVisibleAlert: recoveredFromSourceFailure,
      ),
    );
  }

  void _onAlert(PlaybackAlert alert) {
    if (alert.code == PlaybackAlertCode.sourceFailed &&
        alert.momentId != null) {
      _sourceFailureMomentId = alert.momentId;
      _sourceRecoveryArmed = false;
    }
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
