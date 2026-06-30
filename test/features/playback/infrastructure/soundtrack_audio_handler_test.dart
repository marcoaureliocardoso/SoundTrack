import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/playback/application/live_playback_port.dart';
import 'package:soundtrack/features/playback/application/player_port.dart';
import 'package:soundtrack/features/playback/domain/playback_alert.dart';
import 'package:soundtrack/features/playback/domain/playback_snapshot.dart';
import 'package:soundtrack/features/playback/infrastructure/audio_engine_factory.dart';
import 'package:soundtrack/features/playback/infrastructure/audio_session_observer.dart';
import 'package:soundtrack/features/playback/infrastructure/soundtrack_audio_handler.dart';
import 'package:soundtrack/main.dart' as app;

import '../../../support/fake_player_port.dart';

void main() {
  test('audio service config retains foreground playback while paused', () {
    expect(
      app.soundTrackAudioServiceConfig.androidNotificationOngoing,
      isFalse,
    );
    expect(
      app.soundTrackAudioServiceConfig.androidStopForegroundOnPause,
      isFalse,
    );
  });

  test(
    'AudioEngineFactory prepares a configured observer before handler',
    () async {
      final backend = _FactoryAudioSessionBackend();
      final factory = AudioEngineFactory(loadAudioSession: () async => backend);

      final handler = await factory.prepareHandler();

      expect(backend.configurations, hasLength(1));
      expect(backend.configurations.single.androidWillPauseWhenDucked, isFalse);
      await handler.dispose();
      expect(backend.cancelCount, 3);
    },
  );

  test(
    'AudioEngineFactory cleans the first player if the second throws',
    () async {
      final first = FakePlayerPort();
      final original = StateError('second player');
      var calls = 0;
      final factory = AudioEngineFactory(
        createPlayer: () {
          calls++;
          if (calls == 2) {
            throw original;
          }
          return first;
        },
      );

      await expectLater(factory.prepareHandler(), throwsA(same(original)));

      expect(first.disposeCalls, 1);
    },
  );

  test(
    'AudioEngineFactory cleans coordinator if handler creation throws',
    () async {
      final first = FakePlayerPort();
      final second = FakePlayerPort();
      final players = <PlayerPort>[first, second];
      final original = StateError('handler');
      final factory = AudioEngineFactory(
        createPlayer: () => players.removeAt(0),
        loadAudioSession: () async => _FactoryAudioSessionBackend(),
        createHandler: (_) => throw original,
      );

      await expectLater(factory.prepareHandler(), throwsA(same(original)));

      expect(first.disposeCalls, 1);
      expect(second.disposeCalls, 1);
    },
  );

  group('SoundTrackAudioHandler', () {
    late _FakePlaybackCoordinator coordinator;
    late SoundTrackAudioHandler handler;

    setUp(() {
      coordinator = _FakePlaybackCoordinator();
      handler = SoundTrackAudioHandler(coordinator: coordinator);
    });

    tearDown(() => handler.dispose());

    test(
      'playMediaItem decodes every moment field and publishes metadata',
      () async {
        await handler.playMediaItem(_mediaItem());

        final request = coordinator.started.single;
        expect(request.momentId, 'moment-1');
        expect(request.momentName, 'Entrada');
        expect(request.uri, Uri.parse('file:///music/entrada.mp3'));
        expect(request.audioDisplayName, 'entrada.mp3');
        expect(request.loop, isTrue);
        expect(request.narrationEnabled, isFalse);
        expect(request.gainDb, -3.5);
        expect(request.fadeIn, const Duration(milliseconds: 1200));
        expect(request.fadeOut, const Duration(milliseconds: 2300));
        expect(handler.mediaItem.value?.title, 'Entrada');
        expect(handler.mediaItem.value?.artist, 'entrada.mp3');
      },
    );

    test(
      'first media item is published only after coordinator confirmation',
      () async {
        final confirmation = Completer<void>();
        coordinator.onStart = (request) async {
          await confirmation.future;
          coordinator.publish(
            _snapshot(
              phase: PlaybackPhase.playing,
              playing: true,
              activeMomentId: request.momentId,
            ),
          );
        };

        final start = handler.startMoment(_request());
        await Future<void>.delayed(Duration.zero);
        expect(handler.mediaItem.valueOrNull, isNull);

        confirmation.complete();
        await start;
        expect(handler.mediaItem.value?.artist, 'entrada.mp3');
      },
    );

    test('failed replacement keeps confirmed media item', () async {
      await handler.startMoment(_request());
      final published = <String?>[];
      final subscription = handler.mediaItem.listen(
        (item) => published.add(item?.artist),
      );
      coordinator.onStart = (_) async {
        coordinator.publish(
          _snapshot(
            phase: PlaybackPhase.loading,
            playing: true,
            activeMomentId: 'moment-1',
          ),
        );
        coordinator.publish(
          _snapshot(
            phase: PlaybackPhase.playing,
            playing: true,
            activeMomentId: 'moment-1',
          ),
        );
      };

      await handler.startMoment(
        _request(
          momentId: 'moment-2',
          momentName: 'Saída',
          audioDisplayName: 'saida.mp3',
        ),
      );

      expect(handler.mediaItem.value?.id, 'moment-1');
      expect(handler.mediaItem.value?.artist, 'entrada.mp3');
      expect(published, isNot(contains('saida.mp3')));
      await subscription.cancel();
    });

    test(
      'same active moment does not replace metadata for skipped audio',
      () async {
        await handler.startMoment(_request());
        coordinator.onStart = (_) async {};

        await handler.startMoment(
          _request(
            momentName: 'Entrada alternativa',
            audioDisplayName: 'alternativa.mp3',
          ),
        );

        expect(handler.mediaItem.value?.title, 'Entrada');
        expect(handler.mediaItem.value?.artist, 'entrada.mp3');
      },
    );

    test(
      'concurrent same-id starts publish metadata for latest confirmation',
      () async {
        final firstReleased = Completer<void>();
        final secondReleased = Completer<void>();
        coordinator.onStart = (request) async {
          if (request.audioDisplayName == 'first.mp3') {
            await firstReleased.future;
            return;
          }
          await secondReleased.future;
          coordinator.publish(
            _snapshot(
              phase: PlaybackPhase.playing,
              playing: true,
              activeMomentId: request.momentId,
            ),
          );
        };

        final first = handler.startMoment(
          _request(audioDisplayName: 'first.mp3'),
        );
        final second = handler.startMoment(
          _request(audioDisplayName: 'second.mp3'),
        );
        await Future<void>.delayed(Duration.zero);
        expect(handler.mediaItem.valueOrNull, isNull);

        firstReleased.complete();
        secondReleased.complete();
        await Future.wait([first, second]);
        expect(handler.mediaItem.value?.artist, 'second.mp3');
      },
    );

    test('play, pause and stop delegate to the coordinator', () async {
      await handler.play();
      await handler.pause();
      await handler.stop();

      expect(coordinator.resumeCalls, 1);
      expect(coordinator.pauseCalls, 1);
      expect(coordinator.stopCalls, 1);
    });

    test('playbackState mirrors snapshot with one pause or resume control', () {
      coordinator.publish(
        _snapshot(
          phase: PlaybackPhase.loading,
          playing: true,
          position: const Duration(seconds: 4),
        ),
      );

      var state = handler.playbackState.value;
      expect(state.processingState, AudioProcessingState.loading);
      expect(state.playing, isTrue);
      expect(state.updatePosition, const Duration(seconds: 4));
      expect(state.controls.map((control) => control.action), [
        MediaAction.pause,
      ]);
      expect(state.androidCompactActionIndices, [0]);
      expect(state.controls, isNot(contains(MediaControl.skipToNext)));
      expect(state.controls, isNot(contains(MediaControl.skipToPrevious)));

      coordinator.publish(
        _snapshot(phase: PlaybackPhase.paused, playing: false),
      );
      state = handler.playbackState.value;
      expect(state.processingState, AudioProcessingState.ready);
      expect(state.controls.single.action, MediaAction.play);

      coordinator.publish(
        _snapshot(phase: PlaybackPhase.transitioning, playing: true),
      );
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.loading,
      );

      coordinator.publish(_snapshot(phase: PlaybackPhase.stopped));
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.idle,
      );
    });

    test('active media item retains moment and audio display names', () async {
      await handler.startMoment(_request());
      coordinator.publish(
        _snapshot(
          phase: PlaybackPhase.playing,
          playing: true,
          activeMomentId: 'moment-1',
        ),
      );

      expect(handler.mediaItem.value?.id, 'moment-1');
      expect(handler.mediaItem.value?.title, 'Entrada');
      expect(handler.mediaItem.value?.artist, 'entrada.mp3');
    });

    test('custom actions validate then delegate', () async {
      await handler.customAction('startMoment', _mediaItem().extras);
      await handler.customAction('setNarration', {'active': true});
      await handler.customAction('setSessionVolumes', {
        'masterVolume': 0.8,
        'musicVolume': 0.7,
        'narrationVolume': 0.3,
      });
      await handler.customAction('restorePresetVolumes');

      expect(coordinator.started.single.momentName, 'Entrada');
      expect(coordinator.narration, [true]);
      expect(coordinator.volumes, [(master: 0.8, music: 0.7, narration: 0.3)]);
      expect(coordinator.restoreCalls, 1);
    });

    test(
      'invalid custom action payload is typed and does not mutate',
      () async {
        await expectLater(
          handler.customAction('setSessionVolumes', {
            'masterVolume': 'loud',
            'musicVolume': 0.7,
            'narrationVolume': 0.3,
          }),
          throwsA(isA<AudioHandlerPayloadException>()),
        );
        await expectLater(
          handler.customAction('startMoment', {'momentId': 'incomplete'}),
          throwsA(isA<AudioHandlerPayloadException>()),
        );

        expect(coordinator.volumes, isEmpty);
        expect(coordinator.started, isEmpty);
      },
    );

    test('dispose is idempotent and suppresses late publications', () async {
      final states = <PlaybackState>[];
      final subscription = handler.playbackState.listen(states.add);
      await handler.dispose();
      await handler.dispose();
      final beforeLatePublish = states.length;

      coordinator.publish(
        _snapshot(phase: PlaybackPhase.playing, playing: true),
      );
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.disposeCalls, 1);
      expect(states.length, beforeLatePublish);
      await subscription.cancel();
    });
  });
}

final class _FactoryAudioSessionBackend implements AudioSessionBackend {
  final configurations = <AudioSessionConfiguration>[];
  final _interruptions = StreamController<AudioInterruptionEvent>.broadcast();
  final _noisy = StreamController<void>.broadcast();
  final _devices = StreamController<AudioDevicesChangedEvent>.broadcast();
  var cancelCount = 0;

  @override
  Stream<AudioInterruptionEvent> get interruptionEventStream =>
      _countCancellation(_interruptions.stream);

  @override
  Stream<void> get becomingNoisyEventStream =>
      _countCancellation(_noisy.stream);

  @override
  Stream<AudioDevicesChangedEvent> get devicesChangedEventStream =>
      _countCancellation(_devices.stream);

  Stream<T> _countCancellation<T>(Stream<T> stream) =>
      stream.asBroadcastStream(onCancel: (_) => cancelCount++);

  @override
  Future<void> configure(AudioSessionConfiguration configuration) async {
    configurations.add(configuration);
  }

  @override
  Future<bool> setActive(bool active) async => true;
}

MediaItem _mediaItem() => MediaItem(
  id: 'moment-1',
  title: 'Entrada',
  extras: {
    'momentId': 'moment-1',
    'momentName': 'Entrada',
    'uri': 'file:///music/entrada.mp3',
    'audioDisplayName': 'entrada.mp3',
    'loop': true,
    'narrationEnabled': false,
    'gainDb': -3.5,
    'fadeInMs': 1200,
    'fadeOutMs': 2300,
  },
);

MomentPlaybackRequest _request({
  String momentId = 'moment-1',
  String momentName = 'Entrada',
  String audioDisplayName = 'entrada.mp3',
}) => MomentPlaybackRequest(
  momentId: momentId,
  momentName: momentName,
  uri: Uri.parse('file:///music/entrada.mp3'),
  audioDisplayName: audioDisplayName,
  loop: true,
  narrationEnabled: false,
  gainDb: -3.5,
  fadeIn: const Duration(milliseconds: 1200),
  fadeOut: const Duration(milliseconds: 2300),
);

PlaybackSnapshot _snapshot({
  required PlaybackPhase phase,
  bool playing = false,
  Duration position = Duration.zero,
  String? activeMomentId,
}) {
  return PlaybackSnapshot(
    phase: phase,
    playing: playing,
    position: position,
    duration: const Duration(minutes: 2),
    narrationActive: false,
    masterVolume: 0.8,
    musicVolume: 1,
    narrationVolume: 0.25,
    activeMomentId: activeMomentId,
  );
}

final class _FakePlaybackCoordinator implements LivePlaybackPort {
  final notifier = ValueNotifier<PlaybackSnapshot>(
    const PlaybackSnapshot.idle(),
  );
  final alertsController = StreamController<PlaybackAlert>.broadcast();
  final started = <MomentPlaybackRequest>[];
  final narration = <bool>[];
  final volumes = <({double master, double music, double narration})>[];
  var pauseCalls = 0;
  var resumeCalls = 0;
  var stopCalls = 0;
  var restoreCalls = 0;
  var disposeCalls = 0;
  Future<void> Function(MomentPlaybackRequest request)? onStart;

  @override
  ValueListenable<PlaybackSnapshot> get snapshot => notifier;

  @override
  Stream<PlaybackAlert> get alerts => alertsController.stream;

  void publish(PlaybackSnapshot snapshot) => notifier.value = snapshot;

  @override
  Future<void> startMoment(MomentPlaybackRequest request) async {
    started.add(request);
    final callback = onStart;
    if (callback != null) {
      await callback(request);
      return;
    }
    publish(
      _snapshot(
        phase: PlaybackPhase.playing,
        playing: true,
        activeMomentId: request.momentId,
      ),
    );
  }

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> resume() async => resumeCalls++;

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> setNarration(bool active) async => narration.add(active);

  @override
  Future<void> setSessionVolumes({
    required double masterVolume,
    required double musicVolume,
    required double narrationVolume,
  }) async {
    volumes.add((
      master: masterVolume,
      music: musicVolume,
      narration: narrationVolume,
    ));
  }

  @override
  Future<void> restorePresetVolumes() async => restoreCalls++;

  @override
  Future<void> dispose() async => disposeCalls++;
}
