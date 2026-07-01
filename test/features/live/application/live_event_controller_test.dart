import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_audio_settings.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/features/live/application/live_event_controller.dart';
import 'package:soundtrack/features/live/application/live_event_state.dart';
import 'package:soundtrack/features/playback/domain/playback_alert.dart';
import 'package:soundtrack/features/playback/domain/playback_snapshot.dart';

import '../../../support/fake_live_playback_port.dart';

void main() {
  group('LiveEventController state', () {
    test('starts from the immutable event and current playback snapshot', () {
      final playback = FakeLivePlaybackPort();
      playback.snapshotNotifier.value = const PlaybackSnapshot.idle().copyWith(
        phase: PlaybackPhase.playing,
        playing: true,
        activeMomentId: 'first',
      );
      final event = _event();
      final controller = LiveEventController(event: event, playback: playback);

      expect(controller.state.value.event, same(event));
      expect(controller.state.value.playback, same(playback.snapshot.value));
      expect(controller.state.value.activeMoment?.id, 'first');
      expect(controller.state.value.narrationAvailable, isTrue);
      expect(controller.state.value.currentMomentName, 'First');
      expect(controller.state.value.currentAudioDisplayName, 'first.mp3');
      expect(
        controller.state.value.momentStatus('first'),
        MomentStatus.current,
      );
      expect(controller.state.value.momentStatus('second'), MomentStatus.ready);
      expect(
        controller.state.value.momentStatus('pending'),
        MomentStatus.pending,
      );

      controller.dispose();
    });

    test(
      'publishes snapshots, alerts, dismissal and controls expansion',
      () async {
        final playback = FakeLivePlaybackPort();
        final controller = LiveEventController(
          event: _event(),
          playback: playback,
        );
        final observed = <LiveEventState>[];
        controller.state.addListener(
          () => observed.add(controller.state.value),
        );

        playback.snapshotNotifier.value = const PlaybackSnapshot.idle()
            .copyWith(activeMomentId: 'second');
        playback.alertController.add(
          const PlaybackAlert(
            PlaybackAlertCode.sourceFailed,
            'Falhou',
            momentId: 'second',
          ),
        );
        await _flush();

        expect(controller.state.value.activeMoment?.id, 'second');
        expect(controller.state.value.visibleAlert?.message, 'Falhou');
        expect(
          controller.state.value.momentStatus('second'),
          MomentStatus.error,
        );

        controller.dismissAlert();
        controller.toggleControlsExpanded();

        expect(controller.state.value.visibleAlert, isNull);
        expect(controller.state.value.controlsExpanded, isTrue);
        expect(observed, hasLength(greaterThanOrEqualTo(4)));
        await controller.dispose();
      },
    );
  });

  group('LiveEventController commands', () {
    test('maps a valid moment to an exact playback request', () async {
      final playback = FakeLivePlaybackPort();
      final controller = LiveEventController(
        event: _event(),
        playback: playback,
      );

      await controller.startMoment('second');

      final request = playback.requests.single;
      expect(request.momentId, 'second');
      expect(request.momentName, 'Second');
      expect(request.uri, Uri.parse('content://second'));
      expect(request.audioDisplayName, 'second.mp3');
      expect(request.loop, isFalse);
      expect(request.narrationEnabled, isFalse);
      expect(request.gainDb, -3);
      expect(request.fadeIn, const Duration(milliseconds: 250));
      expect(request.fadeOut, const Duration(seconds: 4));
      await controller.dispose();
    });

    test(
      'uses the active moment fade-out and disables narration first',
      () async {
        final playback = FakeLivePlaybackPort();
        playback.snapshotNotifier.value = const PlaybackSnapshot.idle()
            .copyWith(narrationActive: true, activeMomentId: 'first');
        final controller = LiveEventController(
          event: _event(),
          playback: playback,
        );

        await controller.startMoment('second');

        expect(playback.commands, ['narration:false', 'start:second']);
        expect(
          playback.requests.single.fadeOut,
          const Duration(milliseconds: 750),
        );
        await controller.dispose();
      },
    );

    test('does not disable inactive narration when changing moments', () async {
      final playback = FakeLivePlaybackPort();
      playback.snapshotNotifier.value = const PlaybackSnapshot.idle().copyWith(
        activeMomentId: 'first',
      );
      final controller = LiveEventController(
        event: _event(),
        playback: playback,
      );

      await controller.startMoment('second');

      expect(playback.commands, ['start:second']);
      await controller.dispose();
    });

    test('does nothing when the selected moment is already active', () async {
      final playback = FakeLivePlaybackPort();
      playback.snapshotNotifier.value = const PlaybackSnapshot.idle().copyWith(
        narrationActive: true,
        activeMomentId: 'first',
      );
      final controller = LiveEventController(
        event: _event(),
        playback: playback,
      );

      await controller.startMoment('first');

      expect(playback.commands, isEmpty);
      await controller.dispose();
    });

    for (final id in ['missing', 'pending', 'invalid']) {
      test('rejects $id moment with a typed visible alert', () async {
        final playback = FakeLivePlaybackPort();
        final controller = LiveEventController(
          event: _event(),
          playback: playback,
        );

        await controller.startMoment(id);

        expect(playback.requests, isEmpty);
        expect(
          controller.state.value.visibleAlert?.code,
          PlaybackAlertCode.sourceUnavailable,
        );
        expect(controller.state.value.visibleAlert?.momentId, id);
        await controller.dispose();
      });
    }

    test('allows narration only for an enabled active moment', () async {
      final playback = FakeLivePlaybackPort();
      final controller = LiveEventController(
        event: _event(),
        playback: playback,
      );

      await controller.setNarration(true);
      expect(playback.commands, isEmpty);
      expect(
        controller.state.value.visibleAlert?.code,
        PlaybackAlertCode.sourceUnavailable,
      );

      playback.snapshotNotifier.value = const PlaybackSnapshot.idle().copyWith(
        activeMomentId: 'second',
      );
      await controller.setNarration(true);
      expect(playback.commands, isEmpty);

      playback.snapshotNotifier.value = const PlaybackSnapshot.idle().copyWith(
        activeMomentId: 'first',
      );
      await controller.setNarration(true);
      expect(playback.commands, ['narration:true']);
      await controller.dispose();
    });

    test('delegates transport, protected stop and temporary volumes', () async {
      final playback = FakeLivePlaybackPort();
      final event = _event();
      final before = event.toJson().toString();
      final controller = LiveEventController(event: event, playback: playback);

      await controller.pause();
      await controller.resume();
      await controller.stop(confirmed: false);
      await controller.stop(confirmed: true);
      await controller.setSessionVolumes(
        masterVolume: .1,
        musicVolume: .2,
        narrationVolume: .3,
      );
      await controller.restorePresetVolumes();

      expect(playback.pauseCalls, 1);
      expect(playback.resumeCalls, 1);
      expect(playback.stopCalls, 1);
      expect(playback.sessionVolumes.single, (
        master: .1,
        music: .2,
        narration: .3,
      ));
      expect(playback.restoreCalls, 1);
      expect(event.toJson().toString(), before);
      await controller.dispose();
    });

    test(
      'serializes concurrent starts and evaluates the latest snapshot',
      () async {
        final playback = FakeLivePlaybackPort();
        final firstStarted = Completer<void>();
        final releaseFirst = Completer<void>();
        playback.onStartMoment = (request) async {
          if (request.momentId == 'first') {
            firstStarted.complete();
            await releaseFirst.future;
            playback.snapshotNotifier.value = const PlaybackSnapshot.idle()
                .copyWith(activeMomentId: 'second');
          }
        };
        final controller = LiveEventController(
          event: _event(),
          playback: playback,
        );

        final first = controller.startMoment('first');
        await firstStarted.future;
        final second = controller.startMoment('second');
        releaseFirst.complete();
        await Future.wait([first, second]);

        expect(playback.requests.map((request) => request.momentId), ['first']);
        await controller.dispose();
      },
    );
  });

  group('LiveEventController lifecycle', () {
    test('turns alert stream errors into a visible source failure', () async {
      final playback = FakeLivePlaybackPort();
      final controller = LiveEventController(
        event: _event(),
        playback: playback,
      );

      playback.alertController.addError(StateError('stream failed'));
      await _flush();

      expect(
        controller.state.value.visibleAlert?.code,
        PlaybackAlertCode.sourceFailed,
      );
      await controller.dispose();
    });

    test('dispose is idempotent, detaches and never owns playback', () async {
      final playback = FakeLivePlaybackPort();
      final controller = LiveEventController(
        event: _event(),
        playback: playback,
      );
      final before = controller.state.value;

      await controller.dispose();
      await controller.dispose();
      playback.snapshotNotifier.value = const PlaybackSnapshot.idle().copyWith(
        activeMomentId: 'first',
      );
      playback.alertController.add(
        const PlaybackAlert(PlaybackAlertCode.routeChanged, 'changed'),
      );
      await _flush();

      expect(controller.state.value, same(before));
      expect(playback.stopCalls, 0);
      expect(playback.disposeCalls, 0);
    });
  });
}

SoundTrackEvent _event() {
  return SoundTrackEvent(
    id: 'event',
    name: 'Event',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026, 7),
    audioSettings: const EventAudioSettings(
      masterVolume: .8,
      musicVolume: 1,
      narrationVolume: .25,
      fadeIn: Duration(seconds: 3),
      fadeOut: Duration(seconds: 4),
    ),
    moments: [
      _moment(
        'first',
        narrationEnabled: true,
        fadeOut: const Duration(milliseconds: 750),
      ),
      _moment(
        'second',
        endBehavior: EndBehavior.stop,
        gainDb: -3,
        fadeIn: const Duration(milliseconds: 250),
      ),
      EventMoment.create(id: 'pending', position: 2, name: 'Pending'),
      _moment('invalid', uri: 'not a uri'),
    ],
  );
}

EventMoment _moment(
  String id, {
  String? uri,
  EndBehavior endBehavior = EndBehavior.loop,
  bool narrationEnabled = false,
  double gainDb = 0,
  Duration? fadeIn,
  Duration? fadeOut,
}) {
  return EventMoment(
    id: id,
    position: 0,
    name: '${id[0].toUpperCase()}${id.substring(1)}',
    audio: AudioReference(
      uri: uri ?? 'content://$id',
      displayName: '$id.mp3',
      pending: false,
      artist: null,
      duration: null,
    ),
    endBehavior: endBehavior,
    narrationEnabled: narrationEnabled,
    gainDb: gainDb,
    fadeIn: fadeIn,
    fadeOut: fadeOut,
  );
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);
