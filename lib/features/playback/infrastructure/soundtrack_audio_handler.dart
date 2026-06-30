import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import '../application/live_playback_port.dart';
import '../domain/playback_alert.dart';
import '../domain/playback_snapshot.dart';

final class AudioHandlerPayloadException extends FormatException {
  AudioHandlerPayloadException(this.action, String message)
    : super('Invalid payload for $action: $message');

  final String action;
}

final class SoundTrackAudioHandler extends BaseAudioHandler
    implements LivePlaybackPort {
  factory SoundTrackAudioHandler({required LivePlaybackPort coordinator}) {
    return SoundTrackAudioHandler._(coordinator);
  }

  SoundTrackAudioHandler._(this._coordinator) {
    _coordinator.snapshot.addListener(_publishSnapshot);
    _alertSubscription = _coordinator.alerts.listen(_publishAlert);
    _publishSnapshot();
  }

  final LivePlaybackPort _coordinator;
  final _alerts = StreamController<PlaybackAlert>.broadcast();
  late final StreamSubscription<PlaybackAlert> _alertSubscription;

  MomentPlaybackRequest? _activeRequest;
  Future<void>? _disposeFuture;
  bool _disposed = false;

  @override
  ValueListenable<PlaybackSnapshot> get snapshot => _coordinator.snapshot;

  @override
  Stream<PlaybackAlert> get alerts => _alerts.stream;

  @override
  Future<void> playMediaItem(MediaItem mediaItem) {
    return startMoment(_decodeMoment('playMediaItem', mediaItem.extras));
  }

  @override
  Future<void> startMoment(MomentPlaybackRequest request) async {
    if (_disposed) {
      return;
    }
    _activeRequest = request;
    mediaItem.add(_mediaItemFor(request));
    await _coordinator.startMoment(request);
  }

  @override
  Future<void> play() => resume();

  @override
  Future<void> resume() =>
      _disposed ? Future<void>.value() : _coordinator.resume();

  @override
  Future<void> pause() =>
      _disposed ? Future<void>.value() : _coordinator.pause();

  @override
  Future<void> stop() => _disposed ? Future<void>.value() : _coordinator.stop();

  @override
  Future<void> setNarration(bool active) =>
      _disposed ? Future<void>.value() : _coordinator.setNarration(active);

  @override
  Future<void> setSessionVolumes({
    required double masterVolume,
    required double musicVolume,
    required double narrationVolume,
  }) {
    if (_disposed) {
      return Future<void>.value();
    }
    return _coordinator.setSessionVolumes(
      masterVolume: masterVolume,
      musicVolume: musicVolume,
      narrationVolume: narrationVolume,
    );
  }

  @override
  Future<void> restorePresetVolumes() =>
      _disposed ? Future<void>.value() : _coordinator.restorePresetVolumes();

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    switch (name) {
      case 'startMoment':
        await startMoment(_decodeMoment(name, extras));
        return null;
      case 'setNarration':
        final payload = _payload(name, extras);
        final active = _required<bool>(name, payload, 'active');
        await setNarration(active);
        return null;
      case 'setSessionVolumes':
        final payload = _payload(name, extras);
        final master = _volume(name, payload, 'masterVolume');
        final music = _volume(name, payload, 'musicVolume');
        final narration = _volume(name, payload, 'narrationVolume');
        await setSessionVolumes(
          masterVolume: master,
          musicVolume: music,
          narrationVolume: narration,
        );
        return null;
      case 'restorePresetVolumes':
        if (extras != null && extras.isNotEmpty) {
          throw AudioHandlerPayloadException(name, 'expected no fields');
        }
        await restorePresetVolumes();
        return null;
      default:
        throw AudioHandlerPayloadException(name, 'unsupported action');
    }
  }

  void _publishSnapshot() {
    if (_disposed) {
      return;
    }
    final value = _coordinator.snapshot.value;
    playbackState.add(
      PlaybackState(
        controls: [value.playing ? MediaControl.pause : MediaControl.play],
        androidCompactActionIndices: const [0],
        processingState: switch (value.phase) {
          PlaybackPhase.loading ||
          PlaybackPhase.transitioning => AudioProcessingState.loading,
          PlaybackPhase.idle ||
          PlaybackPhase.stopped => AudioProcessingState.idle,
          PlaybackPhase.playing ||
          PlaybackPhase.paused => AudioProcessingState.ready,
        },
        playing: value.playing,
        updatePosition: value.position,
      ),
    );

    final request = _activeRequest;
    if (value.activeMomentId != null &&
        request != null &&
        value.activeMomentId == request.momentId) {
      mediaItem.add(_mediaItemFor(request, duration: value.duration));
    } else if (value.phase == PlaybackPhase.idle ||
        value.phase == PlaybackPhase.stopped) {
      _activeRequest = null;
      mediaItem.add(null);
    }
  }

  void _publishAlert(PlaybackAlert alert) {
    if (!_disposed) {
      _alerts.add(alert);
    }
  }

  MediaItem _mediaItemFor(MomentPlaybackRequest request, {Duration? duration}) {
    return MediaItem(
      id: request.momentId,
      title: request.momentName,
      artist: request.audioDisplayName,
      duration: duration,
      extras: _encodeMoment(request),
    );
  }

  Map<String, Object> _encodeMoment(MomentPlaybackRequest request) {
    return {
      'momentId': request.momentId,
      'momentName': request.momentName,
      'uri': request.uri.toString(),
      'audioDisplayName': request.audioDisplayName,
      'loop': request.loop,
      'narrationEnabled': request.narrationEnabled,
      'gainDb': request.gainDb,
      'fadeInMs': request.fadeIn.inMilliseconds,
      'fadeOutMs': request.fadeOut.inMilliseconds,
    };
  }

  MomentPlaybackRequest _decodeMoment(
    String action,
    Map<String, dynamic>? extras,
  ) {
    final payload = _payload(action, extras);
    final momentId = _nonEmptyString(action, payload, 'momentId');
    final momentName = _nonEmptyString(action, payload, 'momentName');
    final uriText = _nonEmptyString(action, payload, 'uri');
    final uri = Uri.tryParse(uriText);
    if (uri == null || !uri.hasScheme) {
      throw AudioHandlerPayloadException(action, 'uri must be absolute');
    }
    final audioDisplayName = _nonEmptyString(
      action,
      payload,
      'audioDisplayName',
    );
    final gainDb = _finiteNumber(action, payload, 'gainDb');
    final fadeInMs = _nonNegativeInteger(action, payload, 'fadeInMs');
    final fadeOutMs = _nonNegativeInteger(action, payload, 'fadeOutMs');
    return MomentPlaybackRequest(
      momentId: momentId,
      momentName: momentName,
      uri: uri,
      audioDisplayName: audioDisplayName,
      loop: _required<bool>(action, payload, 'loop'),
      narrationEnabled: _required<bool>(action, payload, 'narrationEnabled'),
      gainDb: gainDb,
      fadeIn: Duration(milliseconds: fadeInMs),
      fadeOut: Duration(milliseconds: fadeOutMs),
    );
  }

  Map<String, dynamic> _payload(String action, Map<String, dynamic>? extras) {
    if (extras == null) {
      throw AudioHandlerPayloadException(action, 'payload is required');
    }
    return extras;
  }

  T _required<T>(String action, Map<String, dynamic> payload, String field) {
    final value = payload[field];
    if (value is! T) {
      throw AudioHandlerPayloadException(action, '$field must be a $T');
    }
    return value;
  }

  String _nonEmptyString(
    String action,
    Map<String, dynamic> payload,
    String field,
  ) {
    final value = _required<String>(action, payload, field);
    if (value.trim().isEmpty) {
      throw AudioHandlerPayloadException(action, '$field must not be empty');
    }
    return value;
  }

  double _finiteNumber(
    String action,
    Map<String, dynamic> payload,
    String field,
  ) {
    final value = payload[field];
    if (value is! num || !value.isFinite) {
      throw AudioHandlerPayloadException(action, '$field must be finite');
    }
    return value.toDouble();
  }

  int _nonNegativeInteger(
    String action,
    Map<String, dynamic> payload,
    String field,
  ) {
    final value = payload[field];
    if (value is! int || value < 0) {
      throw AudioHandlerPayloadException(
        action,
        '$field must be a non-negative integer',
      );
    }
    return value;
  }

  double _volume(String action, Map<String, dynamic> payload, String field) {
    final value = _finiteNumber(action, payload, field);
    if (value < 0 || value > 1) {
      throw AudioHandlerPayloadException(action, '$field must be from 0 to 1');
    }
    return value;
  }

  @override
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _coordinator.snapshot.removeListener(_publishSnapshot);
    await _alertSubscription.cancel();
    await _coordinator.dispose();
    await _alerts.close();
  }
}
