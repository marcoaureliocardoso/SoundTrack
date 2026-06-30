import 'dart:async';
import 'dart:math';

abstract interface class FadeScheduler {
  Stream<double> fractions(Duration duration);
}

final class TimerFadeScheduler implements FadeScheduler {
  const TimerFadeScheduler();

  @override
  Stream<double> fractions(Duration duration) async* {
    if (duration == Duration.zero) {
      yield 1;
      return;
    }

    final steps = max(1, duration.inMilliseconds ~/ 50);
    final delay = duration ~/ steps;
    for (var step = 1; step <= steps; step++) {
      await Future<void>.delayed(delay);
      yield step / steps;
    }
  }
}

final class FadeDriver {
  FadeDriver({required FadeScheduler scheduler}) : this._(scheduler);

  FadeDriver._(this._scheduler);

  final FadeScheduler _scheduler;
  var _generation = 0;

  Future<void> run({
    required double from,
    required double to,
    required Duration duration,
    required Future<void> Function(double value) apply,
  }) async {
    final generation = ++_generation;
    await for (final fraction in _scheduler.fractions(duration)) {
      if (generation != _generation) {
        return;
      }
      await apply(from + ((to - from) * fraction));
    }
  }

  void cancel() {
    _generation++;
  }
}
