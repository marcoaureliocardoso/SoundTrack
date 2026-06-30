import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/playback/application/fade_driver.dart';

void main() {
  group('TimerFadeScheduler', () {
    test('emits one immediately for a zero duration', () async {
      final fractions = await const TimerFadeScheduler()
          .fractions(Duration.zero)
          .toList();

      expect(fractions, [1]);
    });
  });

  group('FadeDriver', () {
    test('interpolates every scheduled fraction', () async {
      final scheduler = _ManualFadeScheduler();
      final driver = FadeDriver(scheduler: scheduler);
      final applied = <double>[];

      final fade = driver.run(
        from: 0.2,
        to: 0.8,
        duration: const Duration(seconds: 1),
        apply: (value) async => applied.add(value),
      );
      scheduler.emit(0.25);
      scheduler.emit(1);
      await scheduler.close();
      await fade;

      expect(applied, closeToList([0.35, 0.8]));
    });

    test('starting a new fade cancels the previous generation', () async {
      final scheduler = _QueuedFadeScheduler();
      final driver = FadeDriver(scheduler: scheduler);
      final applied = <double>[];
      var current = 0.0;

      final first = driver.run(
        from: current,
        to: 1,
        duration: const Duration(seconds: 1),
        apply: (value) async {
          current = value;
          applied.add(value);
        },
      );
      scheduler.first.emit(0.4);
      await _flushEventQueue();
      expect(current, closeTo(0.4, 0.000001));

      final second = driver.run(
        from: current,
        to: 0,
        duration: const Duration(seconds: 1),
        apply: (value) async {
          current = value;
          applied.add(value);
        },
      );
      scheduler.first.emit(0.8);
      scheduler.second.emit(0.5);
      scheduler.second.emit(1);
      await scheduler.first.close();
      await scheduler.second.close();
      await Future.wait([first, second]);

      expect(applied, closeToList([0.4, 0.2, 0]));
      expect(applied, isNot(contains(closeTo(0.8, 0.000001))));
    });

    test('cancel prevents subsequent fractions from being applied', () async {
      final scheduler = _ManualFadeScheduler();
      final driver = FadeDriver(scheduler: scheduler);
      final applied = <double>[];

      final fade = driver.run(
        from: 0,
        to: 1,
        duration: const Duration(seconds: 1),
        apply: (value) async => applied.add(value),
      );
      scheduler.emit(0.5);
      await _flushEventQueue();

      driver.cancel();
      scheduler.emit(1);
      await scheduler.close();
      await fade;

      expect(applied, [0.5]);
    });
  });
}

Matcher closeToList(List<double> expected) => pairwiseCompare<double, double>(
  expected,
  (actual, expected) => (actual - expected).abs() < 0.000001,
  'approximately equals',
);

Future<void> _flushEventQueue() => Future<void>.delayed(Duration.zero);

class _ManualFadeScheduler implements FadeScheduler {
  final _controller = StreamController<double>();

  @override
  Stream<double> fractions(Duration duration) => _controller.stream;

  void emit(double fraction) => _controller.add(fraction);

  Future<void> close() => _controller.close();
}

class _QueuedFadeScheduler implements FadeScheduler {
  final first = _ManualFadeScheduler();
  final second = _ManualFadeScheduler();
  var _calls = 0;

  @override
  Stream<double> fractions(Duration duration) {
    _calls++;
    return _calls == 1 ? first.fractions(duration) : second.fractions(duration);
  }
}
