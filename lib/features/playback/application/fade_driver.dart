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
    final previousRun = _activeRun;
    if (previousRun != null) {
      unawaited(previousRun.cancel());
    }
    final fadeRun = _FadeRun(
      applyValue: (value) =>
          _enqueueApply(generation: generation, value: value, apply: apply),
    );
    _activeRun = fadeRun;
    final subscription = _scheduler
        .fractions(duration)
        .listen(
          (fraction) {
            fadeRun.add(from + ((to - from) * fraction));
          },
          onError: fadeRun.addError,
          onDone: fadeRun.closeInput,
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
    if (activeRun != null) {
      unawaited(activeRun.cancel());
    }
  }

  Future<void> _enqueueApply({
    required int generation,
    required double value,
    required Future<void> Function(double value) apply,
  }) {
    final result = Completer<void>();
    // An apply callback must not await another run on this same serial driver.
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
  _FadeRun({required Future<void> Function(double value) applyValue})
    : this._(applyValue);

  _FadeRun._(this._applyValue);

  final Future<void> Function(double value) _applyValue;
  final _completion = Completer<void>();
  StreamSubscription<double>? _subscription;
  double? _latestPending;
  Object? _error;
  StackTrace? _errorStackTrace;
  var _draining = false;
  var _inputDone = false;
  var _stopRequested = false;
  var _cancellationStarted = false;

  Future<void> get done => _completion.future;

  void attach(StreamSubscription<double> subscription) {
    _subscription = subscription;
    if (_stopRequested && !_inputDone) {
      _startSubscriptionCancellation(subscription);
    }
  }

  void add(double value) {
    if (_stopRequested || _completion.isCompleted) {
      return;
    }
    _latestPending = value;
    if (!_draining) {
      _draining = true;
      unawaited(_drain());
    }
  }

  void addError(Object error, StackTrace stackTrace) {
    _recordError(error, stackTrace);
    _requestStop();
  }

  void closeInput() {
    if (_cancellationStarted) {
      return;
    }
    _inputDone = true;
    _maybeComplete();
  }

  Future<void> cancel() {
    _requestStop();
    return done;
  }

  Future<void> _drain() async {
    try {
      while (!_stopRequested) {
        final value = _latestPending;
        if (value == null) {
          break;
        }
        _latestPending = null;
        try {
          await _applyValue(value);
        } on Object catch (error, stackTrace) {
          _recordError(error, stackTrace);
          _requestStop();
        }
      }
    } finally {
      _draining = false;
      _maybeComplete();
    }
  }

  void _requestStop() {
    _stopRequested = true;
    _latestPending = null;
    if (_inputDone) {
      _maybeComplete();
      return;
    }
    final subscription = _subscription;
    if (subscription != null) {
      _startSubscriptionCancellation(subscription);
    }
  }

  void _startSubscriptionCancellation(StreamSubscription<double> subscription) {
    if (_cancellationStarted) {
      return;
    }
    _cancellationStarted = true;
    Future<void>.sync(subscription.cancel).then(
      (_) {
        _inputDone = true;
        _maybeComplete();
      },
      onError: (Object error, StackTrace stackTrace) {
        _recordError(error, stackTrace);
        _inputDone = true;
        _maybeComplete();
      },
    );
  }

  void _recordError(Object error, StackTrace stackTrace) {
    _error ??= error;
    _errorStackTrace ??= stackTrace;
  }

  void _maybeComplete() {
    if (!_inputDone || _draining || _completion.isCompleted) {
      return;
    }
    final error = _error;
    if (error == null) {
      _completion.complete();
    } else {
      _completion.completeError(error, _errorStackTrace);
    }
  }
}
