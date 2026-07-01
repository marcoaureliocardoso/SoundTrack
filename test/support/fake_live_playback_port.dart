import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soundtrack/features/playback/application/live_playback_port.dart';
import 'package:soundtrack/features/playback/domain/playback_alert.dart';
import 'package:soundtrack/features/playback/domain/playback_snapshot.dart';

final class FakeLivePlaybackPort implements LivePlaybackPort {
  final snapshotNotifier = ValueNotifier<PlaybackSnapshot>(
    const PlaybackSnapshot.idle(),
  );
  final alertController = StreamController<PlaybackAlert>.broadcast();
  final requests = <MomentPlaybackRequest>[];
  final commands = <String>[];
  final sessionVolumes = <({double master, double music, double narration})>[];
  Future<void> Function(MomentPlaybackRequest request)? onStartMoment;
  Future<void> Function(bool active)? onSetNarration;
  var disposeCalls = 0;
  var pauseCalls = 0;
  var resumeCalls = 0;
  var stopCalls = 0;
  var restoreCalls = 0;

  @override
  ValueListenable<PlaybackSnapshot> get snapshot => snapshotNotifier;

  @override
  Stream<PlaybackAlert> get alerts => alertController.stream;

  @override
  Future<void> startMoment(MomentPlaybackRequest request) async {
    requests.add(request);
    commands.add('start:${request.momentId}');
    await onStartMoment?.call(request);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    commands.add('pause');
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    commands.add('resume');
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    commands.add('stop');
  }

  @override
  Future<void> setNarration(bool active) async {
    commands.add('narration:$active');
    await onSetNarration?.call(active);
  }

  @override
  Future<void> setSessionVolumes({
    required double masterVolume,
    required double musicVolume,
    required double narrationVolume,
  }) async {
    sessionVolumes.add((
      master: masterVolume,
      music: musicVolume,
      narration: narrationVolume,
    ));
    commands.add('volumes');
  }

  @override
  Future<void> restorePresetVolumes() async {
    restoreCalls++;
    commands.add('restore');
  }

  @override
  Future<void> dispose() async => disposeCalls++;
}
