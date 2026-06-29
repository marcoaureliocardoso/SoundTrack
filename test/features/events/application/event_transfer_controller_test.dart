import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/application/event_transfer_controller.dart';
import 'package:soundtrack/features/events/data/event_export_codec.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_audio_settings.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/platform/documents/document_gateway.dart';

import '../../../support/in_memory_event_repository.dart';

void main() {
  test(
    'export uses safe soundtrack filename and writes encoded event',
    () async {
      final gateway = _Gateway();
      final controller = _controller(gateway: gateway);
      expect(
        await controller.exportEvent(_event(name: ' Festa / 2026 ')),
        isTrue,
      );
      expect(gateway.suggestedName, 'Festa-2026.soundtrack.json');
      expect(gateway.createdContents, contains('"format":"soundtrack-event"'));
    },
  );

  test('import cancellation does not save', () async {
    final repository = _CountingRepository();
    final result = await _controller(
      gateway: _Gateway(),
      repository: repository,
    ).importEvent();
    expect(result, isNull);
    expect(repository.saveCount, 0);
  });

  test('import parses fully then saves exactly once', () async {
    final source = _event(name: 'Original');
    final gateway = _Gateway()
      ..openedContents = const EventExportCodec().encode(
        source,
        DateTime.utc(2026),
      )
      ..readable = true
      ..probe = const AudioProbeResult(playable: true);
    final repository = _CountingRepository();
    final result = await _controller(
      gateway: gateway,
      repository: repository,
    ).importEvent();
    expect(result!.id, 'new-id');
    expect(repository.saveCount, 1);
  });

  test('probe failure does not partially save import', () async {
    final gateway = _Gateway()
      ..openedContents = const EventExportCodec().encode(
        _event(),
        DateTime.utc(2026),
      )
      ..readable = true
      ..probeError = StateError('probe');
    final repository = _CountingRepository();
    await expectLater(
      _controller(gateway: gateway, repository: repository).importEvent(),
      throwsStateError,
    );
    expect(repository.saveCount, 0);
  });

  test('relink uses authoritative event and playable metadata', () async {
    final authoritative = _event(name: 'Newer');
    final repository = _CountingRepository([authoritative]);
    final gateway = _Gateway()
      ..picked = const PickedDocument(
        uri: 'content://fresh',
        displayName: 'fresh.mp3',
      )
      ..probe = const AudioProbeResult(
        playable: true,
        artist: 'Artist',
        duration: Duration(seconds: 20),
      );
    final stale = authoritative.copyWith(name: 'Stale');
    final result = await _controller(
      gateway: gateway,
      repository: repository,
    ).relinkMoment(stale, 'm1');
    expect(result.name, 'Newer');
    expect(result.moments.single.audio!.displayName, 'fresh.mp3');
    expect(result.moments.single.audio!.artist, 'Artist');
    expect(repository.saveCount, 1);
  });

  test('cancel or unplayable relink never saves', () async {
    final repository = _CountingRepository([_event()]);
    final cancelled = await _controller(
      gateway: _Gateway(),
      repository: repository,
    ).relinkMoment(_event(), 'm1');
    expect(cancelled.moments.single.audio!.pending, isFalse);
    expect(repository.saveCount, 0);

    final gateway = _Gateway()
      ..picked = const PickedDocument(uri: 'bad', displayName: 'bad.mp3')
      ..probe = const AudioProbeResult(playable: false);
    await expectLater(
      _controller(
        gateway: gateway,
        repository: repository,
      ).relinkMoment(_event(), 'm1'),
      throwsA(EventTransferException.unplayableAudio),
    );
    expect(repository.saveCount, 0);
  });

  test('selectAudio returns playable reference without saving', () async {
    final repository = _CountingRepository();
    final gateway = _Gateway()
      ..picked = const PickedDocument(uri: 'fresh', displayName: 'fresh.mp3')
      ..probe = const AudioProbeResult(
        playable: true,
        artist: 'Artist',
        duration: Duration(seconds: 3),
      );
    final audio = await _controller(
      gateway: gateway,
      repository: repository,
    ).selectAudio();
    expect(audio!.displayName, 'fresh.mp3');
    expect(audio.artist, 'Artist');
    expect(repository.saveCount, 0);
  });
}

EventTransferController _controller({
  required _Gateway gateway,
  InMemoryEventRepository? repository,
}) {
  return EventTransferController(
    gateway: gateway,
    codec: const EventExportCodec(),
    repository: repository ?? _CountingRepository(),
    newId: () => 'new-id',
    clock: () => DateTime.utc(2026),
  );
}

SoundTrackEvent _event({String name = 'Event'}) => SoundTrackEvent(
  id: 'event',
  name: name,
  createdAt: DateTime.utc(2025),
  updatedAt: DateTime.utc(2025),
  audioSettings: const EventAudioSettings.defaults(),
  moments: [
    EventMoment(
      id: 'm1',
      position: 0,
      name: 'Moment',
      audio: const AudioReference(
        uri: 'content://old',
        displayName: 'old.mp3',
        pending: false,
        artist: null,
        duration: null,
      ),
      endBehavior: EndBehavior.loop,
      narrationEnabled: false,
      gainDb: 0,
      fadeIn: null,
      fadeOut: null,
    ),
  ],
);

class _CountingRepository extends InMemoryEventRepository {
  _CountingRepository([super.events]);
  int saveCount = 0;
  @override
  Future<void> save(SoundTrackEvent event) {
    saveCount++;
    return super.save(event);
  }
}

class _Gateway implements DocumentGateway {
  String? openedContents;
  PickedDocument? picked;
  bool readable = false;
  AudioProbeResult probe = const AudioProbeResult(playable: false);
  Object? probeError;
  String? suggestedName;
  String? createdContents;

  @override
  Future<bool> canRead(String uri) async => readable;
  @override
  Future<bool> createEventJson({
    required String suggestedName,
    required String contents,
  }) async {
    this.suggestedName = suggestedName;
    createdContents = contents;
    return true;
  }

  @override
  Future<String?> openEventJson() async => openedContents;
  @override
  Future<PickedDocument?> pickAudio() async => picked;
  @override
  Future<AudioProbeResult> probeAudio(String uri) async {
    if (probeError case final error?) throw error;
    return probe;
  }
}
