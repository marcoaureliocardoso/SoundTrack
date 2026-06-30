import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/event_audio_settings.dart';
import 'package:soundtrack/features/playback/application/fade_driver.dart';
import 'package:soundtrack/features/playback/application/live_playback_port.dart';
import 'package:soundtrack/features/playback/application/playback_coordinator.dart';
import 'package:soundtrack/features/playback/application/player_port.dart';
import 'package:soundtrack/features/playback/domain/playback_alert.dart';
import 'package:soundtrack/features/playback/domain/playback_snapshot.dart';

import '../../../support/fake_player_port.dart';

void main() {
  group('PlaybackCoordinator', () {
    test('first moment loads at zero volume and fades in', () async {
      final fixture = _Fixture();
      final request = _request('one');

      final start = fixture.coordinator.startMoment(request);
      await _flush();

      expect(fixture.playerA.operations.take(3), [
        'volume:0.0',
        'load:content://audio/one',
        'loop:false',
      ]);
      expect(fixture.playerA.playing, isTrue);

      fixture.incomingScheduler.emit(1);
      await fixture.incomingScheduler.closeCurrent();
      await start;

      expect(fixture.playerA.volumes, [0, closeTo(0.4, 0.000001)]);
      expect(fixture.coordinator.snapshot.value.phase, PlaybackPhase.playing);
      expect(fixture.coordinator.snapshot.value.activeMomentId, 'one');
      expect(fixture.coordinator.snapshot.value.playing, isTrue);

      await fixture.dispose();
    });

    test('transition preloads standby before either fade starts', () async {
      final fixture = _Fixture();
      await fixture.startFirst();
      fixture.playerB.controlledLoad = Completer<void>();

      final transition = fixture.coordinator.startMoment(_request('two'));
      await _flush();

      expect(fixture.playerB.operations, [
        'volume:0.0',
        'load:content://audio/two',
      ]);
      expect(fixture.outgoingScheduler.runCount, 0);
      expect(fixture.incomingScheduler.runCount, 1);
      expect(fixture.coordinator.snapshot.value.activeMomentId, 'one');

      fixture.playerB.controlledLoad!.complete();
      await _flush();

      expect(fixture.outgoingScheduler.runCount, 1);
      expect(fixture.incomingScheduler.runCount, 2);
      fixture.outgoingScheduler.emit(1);
      fixture.incomingScheduler.emit(1);
      await Future.wait([
        fixture.outgoingScheduler.closeCurrent(),
        fixture.incomingScheduler.closeCurrent(),
      ]);
      await transition;

      expect(fixture.playerA.operations.last, 'stop');
      expect(fixture.coordinator.snapshot.value.activeMomentId, 'two');

      await fixture.dispose();
    });

    test(
      'failed standby load preserves active playback and snapshot',
      () async {
        final fixture = _Fixture();
        await fixture.startFirst();
        fixture.playerA.positionController.add(const Duration(seconds: 12));
        await _flush();
        final before = fixture.coordinator.snapshot.value;
        fixture.playerB.loadError = Exception('missing');
        final alerts = <PlaybackAlert>[];
        final subscription = fixture.coordinator.alerts.listen(alerts.add);

        await fixture.coordinator.startMoment(_request('missing'));
        await _flush();

        final after = fixture.coordinator.snapshot.value;
        expect(fixture.playerA.playing, isTrue);
        expect(fixture.playerA.operations, isNot(contains('stop')));
        expect(fixture.playerB.operations.last, 'stop');
        expect(after.phase, before.phase);
        expect(after.playing, before.playing);
        expect(after.activeMomentId, before.activeMomentId);
        expect(after.position, before.position);
        expect(alerts, hasLength(1));
        expect(alerts.single.code, PlaybackAlertCode.sourceFailed);
        expect(alerts.single.momentId, 'missing');

        await subscription.cancel();
        await fixture.dispose();
      },
    );

    test('requesting the active moment is a no-op', () async {
      final fixture = _Fixture();
      await fixture.startFirst();
      final operations = List<String>.of(fixture.playerA.operations);
      final snapshot = fixture.coordinator.snapshot.value;

      await fixture.coordinator.startMoment(_request('one'));

      expect(fixture.playerA.operations, operations);
      expect(fixture.playerB.operations, isEmpty);
      expect(fixture.coordinator.snapshot.value, same(snapshot));

      await fixture.dispose();
    });

    test('tapping active moment cancels transition and restores it', () async {
      final fixture = _Fixture();
      await fixture.startFirst();
      await fixture.coordinator.setNarration(true);

      final transition = fixture.coordinator.startMoment(_request('two'));
      await _flush();
      expect(
        fixture.coordinator.snapshot.value.phase,
        PlaybackPhase.transitioning,
      );
      expect(fixture.coordinator.snapshot.value.narrationActive, isFalse);

      final cancel = fixture.coordinator.startMoment(_request('one'));
      await Future.wait([transition, cancel]);

      expect(fixture.playerB.operations.last, 'stop');
      expect(fixture.playerB.playing, isFalse);
      expect(fixture.playerA.playing, isTrue);
      expect(fixture.playerA.volumes.last, closeTo(0.2, 0.000001));
      expect(fixture.coordinator.snapshot.value.activeMomentId, 'one');
      expect(fixture.coordinator.snapshot.value.phase, PlaybackPhase.playing);
      expect(fixture.coordinator.snapshot.value.narrationActive, isTrue);

      await fixture.dispose();
    });

    test('a newer request supersedes an active-tap cancellation', () async {
      final fixture = _Fixture();
      await fixture.startFirst();
      final two = fixture.coordinator.startMoment(_request('two'));
      await _flush();
      fixture.playerB.controlledStop = Completer<void>();

      final cancelToOne = fixture.coordinator.startMoment(_request('one'));
      await _flush();
      final three = fixture.coordinator.startMoment(_request('three'));
      await _flush();

      expect(fixture.playerB.loadedSources, [Uri.parse('content://audio/two')]);

      fixture.playerB.controlledStop!.complete();
      await _flush();
      expect(fixture.playerB.loadedSources, [
        Uri.parse('content://audio/two'),
        Uri.parse('content://audio/three'),
      ]);

      fixture.outgoingScheduler.emit(1);
      fixture.incomingScheduler.emit(1);
      await Future.wait([
        fixture.outgoingScheduler.closeCurrent(),
        fixture.incomingScheduler.closeCurrent(),
      ]);
      await Future.wait([two, cancelToOne, three]);

      expect(fixture.coordinator.snapshot.value.activeMomentId, 'three');
      expect(fixture.playerB.playing, isTrue);

      await fixture.dispose();
    });

    test('loop completion is ignored and keeps playing', () async {
      final loopFixture = _Fixture();
      final loopStart = loopFixture.coordinator.startMoment(
        _request('loop', loop: true),
      );
      await _flush();
      loopFixture.incomingScheduler.emit(1);
      await loopFixture.incomingScheduler.closeCurrent();
      await loopStart;

      expect(loopFixture.playerA.looping, isTrue);
      loopFixture.playerA.completedController.add(null);
      await _flush();

      expect(loopFixture.outgoingScheduler.runCount, 0);
      expect(loopFixture.playerA.operations, isNot(contains('stop')));
      expect(
        loopFixture.coordinator.snapshot.value.phase,
        PlaybackPhase.playing,
      );
      expect(loopFixture.coordinator.snapshot.value.activeMomentId, 'loop');
      await loopFixture.dispose();
    });

    test(
      'non-loop completion fades out, stops, and clears active state',
      () async {
        final stopFixture = _Fixture();
        await stopFixture.startFirst();
        await stopFixture.coordinator.setNarration(true);
        stopFixture.playerA.completedController.add(null);
        await _flush();

        expect(stopFixture.outgoingScheduler.runCount, 1);
        stopFixture.outgoingScheduler.emit(0);
        await _flush();
        expect(stopFixture.playerA.volumes.last, closeTo(0.2, 0.000001));
        stopFixture.outgoingScheduler.emit(1);
        await stopFixture.outgoingScheduler.closeCurrent();
        await _flush();

        expect(stopFixture.playerA.volumes.last, 0);
        expect(stopFixture.playerA.operations.last, 'stop');
        expect(
          stopFixture.coordinator.snapshot.value.phase,
          PlaybackPhase.stopped,
        );
        expect(stopFixture.coordinator.snapshot.value.playing, isFalse);
        expect(stopFixture.coordinator.snapshot.value.activeMomentId, isNull);
        expect(stopFixture.coordinator.snapshot.value.narrationActive, isFalse);

        await stopFixture.dispose();
      },
    );

    test('tapping active moment does not cancel its completion fade', () async {
      final fixture = _Fixture();
      await fixture.startFirst();
      fixture.playerA.completedController.add(null);
      await _flush();
      fixture.outgoingScheduler.emit(0.5);
      await _flush();

      await fixture.coordinator.startMoment(_request('one'));

      expect(fixture.coordinator.snapshot.value.activeMomentId, 'one');
      fixture.outgoingScheduler.emit(1);
      await fixture.outgoingScheduler.closeCurrent();
      await _flush();

      expect(fixture.playerA.operations.last, 'stop');
      expect(fixture.coordinator.snapshot.value.phase, PlaybackPhase.stopped);
      expect(fixture.coordinator.snapshot.value.activeMomentId, isNull);

      await fixture.dispose();
    });

    test('completion from outgoing player cannot disrupt transition', () async {
      final fixture = _Fixture();
      await fixture.startFirst();
      final transition = fixture.coordinator.startMoment(_request('two'));
      await _flush();

      fixture.playerA.completedController.add(null);
      await _flush();

      expect(fixture.outgoingScheduler.runCount, 1);
      fixture.outgoingScheduler.emit(1);
      fixture.incomingScheduler.emit(1);
      await Future.wait([
        fixture.outgoingScheduler.closeCurrent(),
        fixture.incomingScheduler.closeCurrent(),
      ]);
      await transition;

      expect(fixture.coordinator.snapshot.value.activeMomentId, 'two');
      expect(fixture.playerB.playing, isTrue);

      await fixture.dispose();
    });

    test(
      'completion stop error emits alert without escaping async handler',
      () async {
        final fixture = _Fixture();
        await fixture.startFirst();
        fixture.playerA.nextStopError = Exception('decoder stop failed');
        final alerts = <PlaybackAlert>[];
        final subscription = fixture.coordinator.alerts.listen(alerts.add);

        fixture.playerA.completedController.add(null);
        await _flush();
        fixture.outgoingScheduler.emit(1);
        await fixture.outgoingScheduler.closeCurrent();
        await _flush();

        expect(alerts, hasLength(1));
        expect(alerts.single.code, PlaybackAlertCode.sourceFailed);
        expect(alerts.single.momentId, 'one');
        expect(fixture.coordinator.snapshot.value.activeMomentId, isNull);

        await subscription.cancel();
        await fixture.dispose();
      },
    );

    test('narration uses ducked volume and resets on transition', () async {
      final fixture = _Fixture();
      await fixture.startFirst();

      await fixture.coordinator.setNarration(true);

      expect(fixture.playerA.volumes.last, closeTo(0.2, 0.000001));
      expect(fixture.coordinator.snapshot.value.narrationActive, isTrue);

      final transition = fixture.coordinator.startMoment(_request('two'));
      await _flush();
      expect(fixture.coordinator.snapshot.value.narrationActive, isFalse);

      fixture.outgoingScheduler.emit(0);
      fixture.incomingScheduler.emit(1);
      await Future.wait([
        fixture.outgoingScheduler.closeCurrent(),
        fixture.incomingScheduler.closeCurrent(),
      ]);
      await transition;

      expect(
        fixture.playerA.volumes.last,
        closeTo(0.2, 0.000001),
        reason: 'fade-out must start from the actual narration volume',
      );
      expect(fixture.playerB.volumes.last, closeTo(0.4, 0.000001));
      expect(fixture.coordinator.snapshot.value.narrationActive, isFalse);

      await fixture.dispose();
    });

    test(
      'pause preserves position and resume continues active player',
      () async {
        final fixture = _Fixture();
        await fixture.startFirst();
        fixture.playerA.positionController.add(const Duration(seconds: 37));
        await _flush();

        await fixture.coordinator.pause();

        expect(fixture.coordinator.snapshot.value.phase, PlaybackPhase.paused);
        expect(
          fixture.coordinator.snapshot.value.position,
          const Duration(seconds: 37),
        );
        expect(fixture.playerA.playing, isFalse);

        await fixture.coordinator.resume();

        expect(fixture.playerA.playing, isTrue);
        expect(fixture.playerA.operations.last, 'play');
        expect(fixture.coordinator.snapshot.value.phase, PlaybackPhase.playing);
        expect(
          fixture.coordinator.snapshot.value.position,
          const Duration(seconds: 37),
        );

        await fixture.dispose();
      },
    );

    test('stop clears the active moment and position', () async {
      final fixture = _Fixture();
      await fixture.startFirst();
      fixture.playerA.positionController.add(const Duration(seconds: 9));
      await _flush();

      await fixture.coordinator.stop();

      expect(fixture.playerA.operations.last, 'stop');
      expect(fixture.coordinator.snapshot.value.phase, PlaybackPhase.stopped);
      expect(fixture.coordinator.snapshot.value.activeMomentId, isNull);
      expect(fixture.coordinator.snapshot.value.position, Duration.zero);
      expect(fixture.coordinator.snapshot.value.playing, isFalse);

      await fixture.dispose();
    });

    test('stop cancels an in-flight standby load', () async {
      final fixture = _Fixture();
      await fixture.startFirst();
      fixture.playerB.holdNextLoad();
      final transition = fixture.coordinator.startMoment(_request('two'));
      await _flush();

      await fixture.coordinator.stop();
      await transition.timeout(const Duration(seconds: 1));

      expect(fixture.playerB.operations.last, 'stop');
      expect(fixture.coordinator.snapshot.value.activeMomentId, isNull);
      expect(fixture.coordinator.snapshot.value.phase, PlaybackPhase.stopped);

      await fixture.dispose();
    });

    test('new start waits for an earlier blocked stop', () async {
      final fixture = _Fixture();
      await fixture.startFirst();
      fixture.playerA.controlledStop = Completer<void>();

      final stop = fixture.coordinator.stop();
      await _flush();
      final start = fixture.coordinator.startMoment(_request('two'));
      await _flush();

      expect(fixture.playerB.loadedSources, isEmpty);

      fixture.playerA.controlledStop!.complete();
      await _flush();
      expect(fixture.playerB.loadedSources, [Uri.parse('content://audio/two')]);
      fixture.incomingScheduler.emit(1);
      await fixture.incomingScheduler.closeCurrent();
      await Future.wait([stop, start]);

      expect(fixture.coordinator.snapshot.value.activeMomentId, 'two');
      expect(fixture.coordinator.snapshot.value.phase, PlaybackPhase.playing);

      await fixture.dispose();
    });

    test('pending pause cannot publish after stop', () async {
      final fixture = _Fixture();
      await fixture.startFirst();
      final releasePause = fixture.playerA.holdNextPause();

      final pause = fixture.coordinator.pause();
      await _flush();
      final stop = fixture.coordinator.stop();
      await _flush();
      releasePause.complete();
      await Future.wait([pause, stop]);

      expect(fixture.coordinator.snapshot.value.phase, PlaybackPhase.stopped);
      expect(fixture.coordinator.snapshot.value.activeMomentId, isNull);

      await fixture.dispose();
    });

    test('pending narration command cannot publish after stop', () async {
      final fixture = _Fixture();
      await fixture.startFirst();
      final releaseVolume = fixture.playerA.holdNextVolume();

      final narration = fixture.coordinator.setNarration(true);
      await _flush();
      final stop = fixture.coordinator.stop();
      await _flush();
      releaseVolume.complete();
      await Future.wait([narration, stop]);

      expect(fixture.coordinator.snapshot.value.phase, PlaybackPhase.stopped);
      expect(fixture.coordinator.snapshot.value.narrationActive, isFalse);

      await fixture.dispose();
    });

    test('concurrent narration commands preserve invocation order', () async {
      final fixture = _Fixture();
      await fixture.startFirst();
      final releaseFirst = fixture.playerA.holdNextVolume();

      final enable = fixture.coordinator.setNarration(true);
      await _flush();
      final disable = fixture.coordinator.setNarration(false);
      await _flush();
      releaseFirst.complete();
      await Future.wait([enable, disable]);

      expect(fixture.playerA.volumes.last, closeTo(0.4, 0.000001));
      expect(fixture.coordinator.snapshot.value.narrationActive, isFalse);

      await fixture.dispose();
    });

    test('session volumes changed during crossfade win at commit', () async {
      final fixture = _Fixture();
      await fixture.startFirst();
      final transition = fixture.coordinator.startMoment(_request('two'));
      await _flush();

      final volumes = fixture.coordinator.setSessionVolumes(
        masterVolume: 0.5,
        musicVolume: 0.2,
        narrationVolume: 0.1,
      );
      await _flush();
      fixture.outgoingScheduler.emit(1);
      fixture.incomingScheduler.emit(1);
      await Future.wait([
        fixture.outgoingScheduler.closeCurrent(),
        fixture.incomingScheduler.closeCurrent(),
      ]);
      await Future.wait([transition, volumes]);

      expect(fixture.playerB.volumes.last, closeTo(0.1, 0.000001));
      expect(fixture.coordinator.snapshot.value.masterVolume, 0.5);
      expect(fixture.coordinator.snapshot.value.musicVolume, 0.2);

      await fixture.dispose();
    });

    test('completion during failed load is processed after rollback', () async {
      final fixture = _Fixture();
      await fixture.startFirst();
      final load = fixture.playerB.holdNextLoad();
      final transition = fixture.coordinator.startMoment(_request('two'));
      await _flush();

      fixture.playerA.completedController.add(null);
      await _flush();
      load.completeError(StateError('load failed'));
      await transition;
      await _flush();

      expect(fixture.outgoingScheduler.runCount, 1);
      fixture.outgoingScheduler.emit(1);
      await fixture.outgoingScheduler.closeCurrent();
      await _flush();
      expect(fixture.coordinator.snapshot.value.activeMomentId, isNull);

      await fixture.dispose();
    });

    test(
      'standby error during fade rolls back instead of committing',
      () async {
        final fixture = _Fixture();
        await fixture.startFirst();
        final alerts = <PlaybackAlert>[];
        final subscription = fixture.coordinator.alerts.listen(alerts.add);
        final transition = fixture.coordinator.startMoment(_request('two'));
        await _flush();

        fixture.playerB.errorController.add(
          const PlayerPortError('decoder failed'),
        );
        await _flush();
        fixture.outgoingScheduler.emit(1);
        fixture.incomingScheduler.emit(1);
        await Future.wait([
          fixture.outgoingScheduler.closeCurrent(),
          fixture.incomingScheduler.closeCurrent(),
        ]);
        await transition;

        expect(fixture.coordinator.snapshot.value.activeMomentId, 'one');
        expect(fixture.playerA.playing, isTrue);
        expect(fixture.playerB.playing, isFalse);
        expect(alerts.single.code, PlaybackAlertCode.sourceFailed);
        expect(alerts.single.momentId, 'two');

        await subscription.cancel();
        await fixture.dispose();
      },
    );

    test('latest tap supersedes an in-flight transition', () async {
      final fixture = _Fixture();
      await fixture.startFirst();
      fixture.playerB.holdNextLoad();

      final two = fixture.coordinator.startMoment(_request('two'));
      await _flush();
      final three = fixture.coordinator.startMoment(_request('three'));
      await _flush();

      expect(fixture.playerB.loadedSources, [
        Uri.parse('content://audio/two'),
        Uri.parse('content://audio/three'),
      ]);
      expect(fixture.playerB.operations, contains('stop'));

      fixture.outgoingScheduler.emit(1);
      fixture.incomingScheduler.emit(1);
      await Future.wait([
        fixture.outgoingScheduler.closeCurrent(),
        fixture.incomingScheduler.closeCurrent(),
      ]);
      await Future.wait([two, three]);

      expect(fixture.coordinator.snapshot.value.activeMomentId, 'three');
      expect(fixture.playerB.playing, isTrue);
      expect(fixture.playerA.operations.last, 'stop');

      await fixture.dispose();
    });

    test(
      'failed crossfade restores active volume and keeps active moment',
      () async {
        final fixture = _Fixture();
        await fixture.startFirst();
        fixture.playerA.nextVolumeError = Exception('output failed');

        final transition = fixture.coordinator.startMoment(_request('two'));
        await _flush();
        fixture.outgoingScheduler.emit(1);
        fixture.incomingScheduler.emit(1);
        await Future.wait([
          fixture.outgoingScheduler.closeCurrent(),
          fixture.incomingScheduler.closeCurrent(),
        ]);
        await transition;

        expect(fixture.playerB.operations.last, 'stop');
        expect(fixture.playerA.playing, isTrue);
        expect(fixture.playerA.volumes.last, closeTo(0.4, 0.000001));
        expect(fixture.coordinator.snapshot.value.activeMomentId, 'one');
        expect(fixture.coordinator.snapshot.value.phase, PlaybackPhase.playing);

        await fixture.dispose();
      },
    );

    test('cleanup errors do not suppress the typed playback alert', () async {
      final fixture = _Fixture();
      await fixture.startFirst();
      fixture.playerB.loadError = Exception('missing');
      fixture.playerB.nextStopError = Exception('stop failed');
      fixture.playerA.nextVolumeError = Exception('restore failed');
      final alerts = <PlaybackAlert>[];
      final subscription = fixture.coordinator.alerts.listen(alerts.add);

      await fixture.coordinator.startMoment(_request('missing'));
      await _flush();

      expect(alerts, hasLength(1));
      expect(alerts.single.code, PlaybackAlertCode.sourceFailed);
      expect(alerts.single.momentId, 'missing');
      expect(fixture.coordinator.snapshot.value.activeMomentId, 'one');

      await subscription.cancel();
      await fixture.dispose();
    });

    test(
      'standby position and duration never leak into active snapshot',
      () async {
        final fixture = _Fixture();
        await fixture.startFirst();

        fixture.playerB.positionController.add(const Duration(seconds: 99));
        fixture.playerB.durationController.add(const Duration(minutes: 9));
        await _flush();

        expect(fixture.coordinator.snapshot.value.position, Duration.zero);
        expect(fixture.coordinator.snapshot.value.duration, isNull);

        fixture.playerA.positionController.add(const Duration(seconds: 8));
        fixture.playerA.durationController.add(const Duration(minutes: 3));
        await _flush();

        expect(
          fixture.coordinator.snapshot.value.position,
          const Duration(seconds: 8),
        );
        expect(
          fixture.coordinator.snapshot.value.duration,
          const Duration(minutes: 3),
        );

        await fixture.dispose();
      },
    );

    test(
      'commits buffered position and duration when standby becomes active',
      () async {
        final fixture = _Fixture();
        await fixture.startFirst();
        fixture.playerA.positionController.add(const Duration(seconds: 8));
        fixture.playerA.durationController.add(const Duration(minutes: 3));
        await _flush();

        final transition = fixture.coordinator.startMoment(_request('two'));
        await _flush();
        fixture.playerB.positionController.add(const Duration(seconds: 1));
        fixture.playerB.durationController.add(const Duration(minutes: 2));
        await _flush();

        expect(
          fixture.coordinator.snapshot.value.position,
          const Duration(seconds: 8),
        );
        expect(
          fixture.coordinator.snapshot.value.duration,
          const Duration(minutes: 3),
        );

        fixture.outgoingScheduler.emit(1);
        fixture.incomingScheduler.emit(1);
        await Future.wait([
          fixture.outgoingScheduler.closeCurrent(),
          fixture.incomingScheduler.closeCurrent(),
        ]);
        await transition;

        expect(
          fixture.coordinator.snapshot.value.position,
          const Duration(seconds: 1),
        );
        expect(
          fixture.coordinator.snapshot.value.duration,
          const Duration(minutes: 2),
        );

        await fixture.dispose();
      },
    );

    test(
      'dispose is idempotent and in-flight load cannot publish afterward',
      () async {
        final fixture = _Fixture();
        fixture.playerA.holdNextLoad();
        final start = fixture.coordinator.startMoment(_request('one'));
        await _flush();
        var publications = 0;
        fixture.coordinator.snapshot.addListener(() => publications++);

        await fixture.coordinator.dispose();
        await fixture.coordinator.dispose();
        final operationsAfterDispose = List<String>.of(
          fixture.playerA.operations,
        );
        final publicationsAfterDispose = publications;

        await start;

        expect(fixture.playerA.disposeCalls, 1);
        expect(fixture.playerB.disposeCalls, 1);
        expect(fixture.playerA.operations, operationsAfterDispose);
        expect(publications, publicationsAfterDispose);
      },
    );

    test('dispose drains queued commands before disposing players', () async {
      final fixture = _Fixture();
      await fixture.startFirst();
      final releasePause = fixture.playerA.holdNextPause();
      final pause = fixture.coordinator.pause();
      await _flush();
      final stop = fixture.coordinator.stop();

      var disposeCompleted = false;
      final firstDispose = fixture.coordinator.dispose()
        ..then((_) => disposeCompleted = true);
      final secondDispose = fixture.coordinator.dispose();
      expect(identical(firstDispose, secondDispose), isTrue);
      await _flush();
      expect(disposeCompleted, isFalse);

      releasePause.complete();
      await Future.wait([pause, stop, firstDispose, secondDispose]);

      final disposeIndex = fixture.playerA.operations.indexOf('dispose');
      expect(disposeIndex, greaterThanOrEqualTo(0));
      expect(
        fixture.playerA.operations.skip(disposeIndex + 1),
        isEmpty,
        reason: 'no queued command may touch a physically disposed player',
      );
      expect(fixture.playerA.disposeCalls, 1);
      expect(fixture.playerB.disposeCalls, 1);
    });
  });
}

MomentPlaybackRequest _request(
  String id, {
  bool loop = false,
  bool narrationEnabled = true,
}) {
  return MomentPlaybackRequest(
    momentId: id,
    momentName: 'Moment $id',
    uri: Uri.parse('content://audio/$id'),
    audioDisplayName: '$id.ogg',
    loop: loop,
    narrationEnabled: narrationEnabled,
    gainDb: 0,
    fadeIn: const Duration(seconds: 1),
    fadeOut: const Duration(seconds: 1),
  );
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
      outgoingFade: FadeDriver(scheduler: outgoingScheduler),
      incomingFade: FadeDriver(scheduler: incomingScheduler),
      presetVolumes: const EventAudioSettings(
        masterVolume: 0.8,
        musicVolume: 0.5,
        narrationVolume: 0.25,
        fadeIn: Duration(seconds: 1),
        fadeOut: Duration(seconds: 1),
      ),
    );
  }

  final playerA = FakePlayerPort();
  final playerB = FakePlayerPort();
  final outgoingScheduler = ManualFadeScheduler();
  final incomingScheduler = ManualFadeScheduler();

  late final PlaybackCoordinator coordinator;

  Future<void> startFirst() async {
    final start = coordinator.startMoment(_request('one'));
    await _flush();
    incomingScheduler.emit(1);
    await incomingScheduler.closeCurrent();
    await start;
  }

  Future<void> dispose() => coordinator.dispose();
}

final class ManualFadeScheduler implements FadeScheduler {
  final _controllers = <StreamController<double>>[];

  StreamController<double> get current => _controllers.last;
  int get runCount => _controllers.length;

  @override
  Stream<double> fractions(Duration duration) {
    final controller = StreamController<double>();
    _controllers.add(controller);
    return controller.stream;
  }

  void emit(double fraction) => current.add(fraction);

  Future<void> closeCurrent() => current.close();
}
