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
    test('begin preserves playback and records auto-resume intent', () async {
      final fixture = _Fixture();
      await fixture.start();
      final alerts = <PlaybackAlert>[];
      fixture.coordinator.alerts.listen(alerts.add);
      final operations = List<String>.of(fixture.playerA.operations);

      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionStarted(AudioInterruptionType.pause),
      );
      await _flush();

      expect(fixture.playerA.operations, operations);
      expect(fixture.coordinator.snapshot.value.playing, isTrue);
      expect(alerts.single.code, PlaybackAlertCode.interruptionStarted);
      await fixture.dispose();
    });

    test('end resumes once when playback was active', () async {
      final fixture = _Fixture();
      await fixture.start();
      final alerts = <PlaybackAlert>[];
      fixture.coordinator.alerts.listen(alerts.add);
      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionStarted(AudioInterruptionType.pause),
      );

      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionEnded(
          AudioInterruptionType.pause,
          focusGranted: true,
        ),
      );
      await _flush();
      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionEnded(
          AudioInterruptionType.pause,
          focusGranted: true,
        ),
      );
      await _flush();

      expect(
        fixture.playerA.operations.where((operation) => operation == 'play'),
        hasLength(2),
      );
      expect(alerts.map((alert) => alert.code), [
        PlaybackAlertCode.interruptionStarted,
        PlaybackAlertCode.interruptionEnded,
        PlaybackAlertCode.interruptionEnded,
      ]);
      await fixture.dispose();
    });

    test('user pause during interruption cancels auto-resume', () async {
      final fixture = _Fixture();
      await fixture.start();
      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionStarted(AudioInterruptionType.pause),
      );

      await fixture.coordinator.pause();
      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionEnded(
          AudioInterruptionType.pause,
          focusGranted: true,
        ),
      );

      expect(
        fixture.playerA.operations.where((operation) => operation == 'play'),
        hasLength(1),
      );
      expect(fixture.coordinator.snapshot.value.playing, isFalse);
      await fixture.dispose();
    });

    test('user stop during interruption cancels auto-resume', () async {
      final fixture = _Fixture();
      await fixture.start();
      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionStarted(AudioInterruptionType.pause),
      );

      await fixture.coordinator.stop();
      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionEnded(
          AudioInterruptionType.pause,
          focusGranted: true,
        ),
      );

      expect(
        fixture.playerA.operations.where((operation) => operation == 'play'),
        hasLength(1),
      );
      expect(fixture.coordinator.snapshot.value.activeMomentId, isNull);
      await fixture.dispose();
    });

    test('focus denial does not resume and emits interruption alert', () async {
      final fixture = _Fixture();
      await fixture.start();
      final alerts = <PlaybackAlert>[];
      fixture.coordinator.alerts.listen(alerts.add);
      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionStarted(AudioInterruptionType.pause),
      );

      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionEnded(
          AudioInterruptionType.pause,
          focusGranted: false,
        ),
      );
      await _flush();

      expect(
        fixture.playerA.operations.where((operation) => operation == 'play'),
        hasLength(1),
      );
      expect(alerts.last.code, PlaybackAlertCode.interruptionEnded);
      expect(alerts.last.message, contains('foco'));
      await fixture.dispose();
    });

    test('duck alerts but does not change session volumes', () async {
      final fixture = _Fixture();
      await fixture.start();
      final volumes = List<double>.of(fixture.playerA.volumes);
      final snapshot = fixture.coordinator.snapshot.value;
      final alerts = <PlaybackAlert>[];
      fixture.coordinator.alerts.listen(alerts.add);

      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionStarted(AudioInterruptionType.duck),
      );
      await fixture.coordinator.handleAudioSessionEvent(
        const PlaybackInterruptionEnded(
          AudioInterruptionType.duck,
          focusGranted: true,
        ),
      );
      await _flush();

      expect(fixture.playerA.volumes, volumes);
      expect(
        fixture.coordinator.snapshot.value.masterVolume,
        snapshot.masterVolume,
      );
      expect(
        fixture.coordinator.snapshot.value.musicVolume,
        snapshot.musicVolume,
      );
      expect(alerts.map((alert) => alert.code), [
        PlaybackAlertCode.interruptionStarted,
        PlaybackAlertCode.interruptionEnded,
      ]);
      await fixture.dispose();
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

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
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
