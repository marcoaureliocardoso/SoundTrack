import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/features/live/application/active_live_session_store.dart';
import 'package:soundtrack/features/live/application/live_event_controller.dart';

import '../../../support/fake_live_playback_port.dart';

void main() {
  test('file store preserves the active event across instances', () async {
    final directory = await Directory.systemTemp.createTemp(
      'soundtrack-live-session-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final first = FileActiveLiveSessionStore(directory);

    await first.saveEventId('event-1');
    final recreated = FileActiveLiveSessionStore(directory);

    expect(await recreated.readEventId(), 'event-1');
    await recreated.clear();
    expect(await first.readEventId(), isNull);
  });

  test('confirmed stop clears session only after playback stops', () async {
    final playback = FakeLivePlaybackPort();
    final store = MemoryActiveLiveSessionStore();
    final controller = LiveEventController(
      event: SoundTrackEvent.create(id: 'event-1', name: 'Evento'),
      playback: playback,
      activeSessionStore: store,
    );

    await controller.activateSession();
    playback.onStop = () async {
      expect(await store.readEventId(), 'event-1');
    };
    await controller.confirmStop();

    expect(playback.stopCalls, 1);
    expect(await store.readEventId(), isNull);
    await controller.dispose();
  });
}
