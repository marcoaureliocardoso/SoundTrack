import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/event_audio_settings.dart';
import 'package:soundtrack/features/playback/application/fade_driver.dart';
import 'package:soundtrack/features/playback/application/live_playback_port.dart';
import 'package:soundtrack/features/playback/application/playback_coordinator.dart';
import 'package:soundtrack/features/playback/domain/playback_alert.dart';

import '../../../support/fake_player_port.dart';

void main() {
  group('playback interruption policy', () {
    test('pause interruption resumes once after focus is granted', () async {
      final fixture = _Fixture();
      await fixture.start();
      final focus = _FocusProbe();

      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionStarted(AudioInterruptionType.pause),
      );
      await fixture.coordinator.handleAudioSessionEvent(
        _end(AudioInterruptionType.pause, focus),
      );

      expect(focus.calls, 1);
      expect(_playCalls(fixture), 2);
      await fixture.dispose();
    });

    test('unknown never requests focus or resumes', () async {
      final fixture = _Fixture();
      await fixture.start();
      final focus = _FocusProbe();

      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionStarted(AudioInterruptionType.unknown),
      );
      await fixture.coordinator.handleAudioSessionEvent(
        _end(AudioInterruptionType.unknown, focus),
      );

      expect(focus.calls, 0);
      expect(_playCalls(fixture), 1);
      await fixture.dispose();
    });

    test(
      'pause interruption that begins while paused never requests focus',
      () async {
        final fixture = _Fixture();
        await fixture.start();
        await fixture.coordinator.pause();
        final focus = _FocusProbe();

        await fixture.coordinator.handleAudioSessionEvent(
          const PlaybackInterruptionStarted(AudioInterruptionType.pause),
        );
        await fixture.coordinator.handleAudioSessionEvent(
          _end(AudioInterruptionType.pause, focus),
        );

        expect(focus.calls, 0);
        expect(_playCalls(fixture), 1);
        await fixture.dispose();
      },
    );

    test('duck alerts without focus, player, or volume changes', () async {
      final fixture = _Fixture();
      await fixture.start();
      final focus = _FocusProbe();
      final volumes = List<double>.of(fixture.playerA.volumes);
      final alerts = <PlaybackAlert>[];
      fixture.coordinator.alerts.listen(alerts.add);

      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionStarted(AudioInterruptionType.duck),
      );
      await fixture.coordinator.handleAudioSessionEvent(
        _end(AudioInterruptionType.duck, focus),
      );
      await _flush();

      expect(focus.calls, 0);
      expect(_playCalls(fixture), 1);
      expect(fixture.playerA.volumes, volumes);
      expect(alerts.map((alert) => alert.code), [
        PlaybackAlertCode.interruptionStarted,
        PlaybackAlertCode.interruptionEnded,
      ]);
      await fixture.dispose();
    });

    for (final action in ['pause', 'stop']) {
      test(
        'queued begin followed by user $action never auto-resumes',
        () async {
          final fixture = _Fixture();
          await fixture.start();
          final focus = _FocusProbe();

          final begin = fixture.coordinator.handleAudioSessionEvent(
            const PlaybackInterruptionStarted(AudioInterruptionType.pause),
          );
          final override = action == 'pause'
              ? fixture.coordinator.pause()
              : fixture.coordinator.stop();
          await begin;
          await override;
          await fixture.coordinator.handleAudioSessionEvent(
            _end(AudioInterruptionType.pause, focus),
          );

          expect(focus.calls, 0);
          expect(_playCalls(fixture), 1);
          await fixture.dispose();
        },
      );
    }

    test(
      'explicit resume after queued begin prevents later auto-resume',
      () async {
        final fixture = _Fixture();
        await fixture.start();
        final focus = _FocusProbe();

        final begin = fixture.coordinator.handleAudioSessionEvent(
          const PlaybackInterruptionStarted(AudioInterruptionType.pause),
        );
        final resume = fixture.coordinator.resume();
        await Future.wait([begin, resume]);
        await fixture.coordinator.handleAudioSessionEvent(
          _end(AudioInterruptionType.pause, focus),
        );

        expect(focus.calls, 0);
        expect(_playCalls(fixture), 2);
        await fixture.dispose();
      },
    );

    test('pause and duck overlap resumes only after pause end', () async {
      final fixture = _Fixture();
      await fixture.start();
      final focus = _FocusProbe();

      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionStarted(AudioInterruptionType.pause),
      );
      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionStarted(AudioInterruptionType.duck),
      );
      await fixture.coordinator.handleAudioSessionEvent(
        _end(AudioInterruptionType.duck, focus),
      );
      expect(_playCalls(fixture), 1);
      await fixture.coordinator.handleAudioSessionEvent(
        _end(AudioInterruptionType.pause, focus),
      );

      expect(focus.calls, 1);
      expect(_playCalls(fixture), 2);
      await fixture.dispose();
    });

    test('nested pauses do not resume between end events', () async {
      final fixture = _Fixture();
      await fixture.start();
      final focus = _FocusProbe();
      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionStarted(AudioInterruptionType.pause),
      );
      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionStarted(AudioInterruptionType.pause),
      );

      await fixture.coordinator.handleAudioSessionEvent(
        _end(AudioInterruptionType.pause, focus),
      );
      expect(focus.calls, 0);
      expect(_playCalls(fixture), 1);
      await fixture.coordinator.handleAudioSessionEvent(
        _end(AudioInterruptionType.pause, focus),
      );

      expect(focus.calls, 1);
      expect(_playCalls(fixture), 2);
      await fixture.dispose();
    });

    test('overlapping unknown permanently cancels pause auto-resume', () async {
      final fixture = _Fixture();
      await fixture.start();
      final focus = _FocusProbe();
      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionStarted(AudioInterruptionType.pause),
      );
      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionStarted(AudioInterruptionType.unknown),
      );
      await fixture.coordinator.handleAudioSessionEvent(
        _end(AudioInterruptionType.unknown, focus),
      );
      await fixture.coordinator.handleAudioSessionEvent(
        _end(AudioInterruptionType.pause, focus),
      );

      expect(focus.calls, 0);
      expect(_playCalls(fixture), 1);
      await fixture.dispose();
    });

    test('orphan and repeated ends do nothing', () async {
      final fixture = _Fixture();
      await fixture.start();
      final focus = _FocusProbe();
      final alerts = <PlaybackAlert>[];
      fixture.coordinator.alerts.listen(alerts.add);

      await fixture.coordinator.handleAudioSessionEvent(
        _end(AudioInterruptionType.pause, focus),
      );
      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionStarted(AudioInterruptionType.pause),
      );
      await fixture.coordinator.handleAudioSessionEvent(
        _end(AudioInterruptionType.pause, focus),
      );
      await fixture.coordinator.handleAudioSessionEvent(
        _end(AudioInterruptionType.pause, focus),
      );
      await _flush();

      expect(focus.calls, 1);
      expect(_playCalls(fixture), 2);
      expect(
        alerts.where(
          (alert) => alert.code == PlaybackAlertCode.interruptionEnded,
        ),
        hasLength(1),
      );
      await fixture.dispose();
    });

    test('focus false and throw alert without resuming', () async {
      for (final focus in [
        _FocusProbe(result: false),
        _FocusProbe(error: StateError('focus')),
      ]) {
        final fixture = _Fixture();
        await fixture.start();
        final alerts = <PlaybackAlert>[];
        fixture.coordinator.alerts.listen(alerts.add);
        await fixture.coordinator.handleAudioSessionEvent(
          const PlaybackInterruptionStarted(AudioInterruptionType.pause),
        );

        await fixture.coordinator.handleAudioSessionEvent(
          _end(AudioInterruptionType.pause, focus),
        );
        await _flush();

        expect(focus.calls, 1);
        expect(_playCalls(fixture), 1);
        expect(alerts.last.code, PlaybackAlertCode.interruptionEnded);
        await fixture.dispose();
      }
    });

    test('route changes alert and never pause or stop', () async {
      final fixture = _Fixture();
      await fixture.start();
      final alerts = <PlaybackAlert>[];
      fixture.coordinator.alerts.listen(alerts.add);
      final operations = List<String>.of(fixture.playerA.operations);

      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackRouteChanged(),
      );
      await _flush();

      expect(fixture.playerA.operations, operations);
      expect(alerts.single.code, PlaybackAlertCode.routeChanged);
      await fixture.dispose();
    });
  });
}

PlaybackInterruptionEnded _end(AudioInterruptionType type, _FocusProbe focus) =>
    PlaybackInterruptionEnded(type, requestFocus: focus.call);

int _playCalls(_Fixture fixture) =>
    fixture.playerA.operations.where((operation) => operation == 'play').length;

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final class _FocusProbe {
  _FocusProbe({this.result = true, this.error});

  final bool result;
  final Object? error;
  var calls = 0;

  Future<bool> call() async {
    calls++;
    if (error case final error?) {
      throw error;
    }
    return result;
  }
}

final class _Fixture {
  _Fixture() {
    coordinator = PlaybackCoordinator(
      playerA: playerA,
      playerB: playerB,
      outgoingFade: FadeDriver(scheduler: const _ImmediateFadeScheduler()),
      incomingFade: FadeDriver(scheduler: const _ImmediateFadeScheduler()),
      presetVolumes: const EventAudioSettings.defaults(),
    );
  }

  final playerA = FakePlayerPort();
  final playerB = FakePlayerPort();
  late final PlaybackCoordinator coordinator;

  Future<void> start() {
    return coordinator.startMoment(
      MomentPlaybackRequest(
        momentId: 'one',
        momentName: 'One',
        uri: Uri.parse('file:///one.mp3'),
        audioDisplayName: 'one.mp3',
        loop: false,
        narrationEnabled: false,
        gainDb: 0,
        fadeIn: Duration.zero,
        fadeOut: Duration.zero,
      ),
    );
  }

  Future<void> dispose() => coordinator.dispose();
}

final class _ImmediateFadeScheduler implements FadeScheduler {
  const _ImmediateFadeScheduler();

  @override
  Stream<double> fractions(Duration duration) => Stream<double>.value(1);
}
