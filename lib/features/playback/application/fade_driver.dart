import 'dart:async';
import 'dart:math';

abstract interface class FadeScheduler {
  Stream<double> fractions(Duration duration);
}

final class TimerFadeScheduler implements FadeScheduler {
  const TimerFadeScheduler();

  @override
  Stream<double> fractions(Duration duration) {
    if (duration == Duration.zero) {
      return Stream<double>.value(1);
    }

    final steps = max(1, duration.inMilliseconds ~/ 50);
    final delay = duration ~/ steps;
    Timer? timer;
    var step = 0;
    late final StreamController<double> controller;
    controller = StreamController<double>(
      onListen: () {
        timer = Timer.periodic(delay, (timer) {
          step++;
          controller.add(step / steps);
          if (step == steps) {
            timer.cancel();
            unawaited(controller.close());
          }
        });
      },
      onCancel: () {
        timer?.cancel();
      },
    );
    return controller.stream;
  }
}

final class FadeDriver {
  FadeDriver({required FadeScheduler scheduler}) : this._(scheduler);

  FadeDriver._(this._scheduler);

  final FadeScheduler _scheduler;
  var _generation = 0;
  Future<void> _applyTail = Future<void>.value();
  _FadeRun? _activeRun;

  Future<void> run({
    required double from,
    required double to,
    required Duration duration,
    required Future<void> Function(double value) apply,
  }) async {
    final generation = ++_generation;
    _activeRun?.cancel();
    final fadeRun = _FadeRun();
    _activeRun = fadeRun;
    late final StreamSubscription<double> subscription;
    subscription = _scheduler
        .fractions(duration)
        .listen(
          (fraction) {
            subscription.pause();
            unawaited(
              _enqueueApply(
                generation: generation,
                value: from + ((to - from) * fraction),
                apply: apply,
              ).then(
                (_) {
                  if (!fadeRun.isComplete && generation == _generation) {
                    subscription.resume();
                  }
                },
                onError: (Object error, StackTrace stackTrace) {
                  if (!fadeRun.isComplete) {
                    fadeRun.completeError(error, stackTrace);
                    unawaited(subscription.cancel());
                  }
                },
              ),
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            fadeRun.completeError(error, stackTrace);
          },
          onDone: fadeRun.complete,
          cancelOnError: true,
        );
    fadeRun.attach(subscription);

    try {
      await fadeRun.done;
    } finally {
      if (identical(_activeRun, fadeRun)) {
        _activeRun = null;
      }
    }
  }

  void cancel() {
    _generation++;
    final activeRun = _activeRun;
    _activeRun = null;
    activeRun?.cancel();
  }

  Future<void> _enqueueApply({
    required int generation,
    required double value,
    required Future<void> Function(double value) apply,
  }) {
    final result = Completer<void>();
    _applyTail = _applyTail.then((_) async {
      if (generation != _generation) {
        result.complete();
        return;
      }
      try {
        await apply(value);
        result.complete();
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }
}

final class _FadeRun {
  final _completion = Completer<void>();
  StreamSubscription<double>? _subscription;

  Future<void> get done => _completion.future;

  bool get isComplete => _completion.isCompleted;

  void attach(StreamSubscription<double> subscription) {
    _subscription = subscription;
    if (isComplete) {
      unawaited(subscription.cancel());
    }
  }

  void complete() {
    if (!isComplete) {
      _completion.complete();
    }
  }

  void completeError(Object error, StackTrace stackTrace) {
    if (!isComplete) {
      _completion.completeError(error, stackTrace);
    }
  }

  void cancel() {
    complete();
    final subscription = _subscription;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }
}
