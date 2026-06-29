import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/application/event_transfer_controller.dart';
import 'package:soundtrack/features/events/data/event_export_codec.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_audio_settings.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/features/events/presentation/audio_relink_page.dart';
import 'package:soundtrack/platform/documents/document_gateway.dart';

import '../../../support/in_memory_event_repository.dart';

void main() {
  testWidgets('lists pending audio and resolves it', (tester) async {
    final event = _event();
    final repository = InMemoryEventRepository([event]);
    final controller = EventTransferController(
      gateway: _Gateway(),
      codec: const EventExportCodec(),
      repository: repository,
      newId: () => 'new',
      clock: DateTime.now,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AudioRelinkPage(event: event, controller: controller),
      ),
    );
    expect(find.text('missing.mp3'), findsOneWidget);
    expect(find.text('Old artist'), findsOneWidget);
    expect(find.text('Escolher música'), findsOneWidget);
    expect(find.text('Resolver depois'), findsOneWidget);

    await tester.tap(find.text('Escolher música'));
    await tester.pumpAndSettle();
    expect(find.text('Todas as músicas foram localizadas.'), findsOneWidget);
    expect(find.text('Concluir'), findsOneWidget);
  });

  testWidgets('lists and relinks a moment with no audio reference', (
    tester,
  ) async {
    final event = _event(withoutAudio: true);
    final repository = InMemoryEventRepository([event]);
    final controller = EventTransferController(
      gateway: _Gateway(),
      codec: const EventExportCodec(),
      repository: repository,
      newId: () => 'new',
      clock: DateTime.now,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AudioRelinkPage(event: event, controller: controller),
      ),
    );
    expect(find.text('Nenhuma música selecionada'), findsOneWidget);
    expect(find.text('Opening'), findsOneWidget);

    await tester.tap(find.text('Escolher música'));
    await tester.pumpAndSettle();
    expect(find.text('Todas as músicas foram localizadas.'), findsOneWidget);
    expect((await repository.findById('e'))!.moments.single.audio!.uri, 'new');
  });

  testWidgets('relink error identifies moment and next action', (tester) async {
    final event = _event();
    final repository = InMemoryEventRepository([event]);
    final gateway = _Gateway()..probe = const AudioProbeResult(playable: false);
    await tester.pumpWidget(
      MaterialApp(
        home: AudioRelinkPage(
          event: event,
          controller: EventTransferController(
            gateway: gateway,
            codec: const EventExportCodec(),
            repository: repository,
            newId: () => 'new',
            clock: DateTime.now,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Escolher música'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Não foi possível religar “Opening”. Escolha outro arquivo de áudio.',
      ),
      findsOneWidget,
    );
  });
}

SoundTrackEvent _event({bool withoutAudio = false}) => SoundTrackEvent(
  id: 'e',
  name: 'Imported',
  createdAt: DateTime.utc(2025),
  updatedAt: DateTime.utc(2025),
  audioSettings: const EventAudioSettings.defaults(),
  moments: [
    EventMoment(
      id: 'm',
      position: 0,
      name: 'Opening',
      audio: withoutAudio
          ? null
          : const AudioReference(
              uri: 'old',
              displayName: 'missing.mp3',
              pending: true,
              artist: 'Old artist',
              duration: Duration(seconds: 10),
            ),
      endBehavior: EndBehavior.loop,
      narrationEnabled: false,
      gainDb: 0,
      fadeIn: null,
      fadeOut: null,
    ),
  ],
);

class _Gateway implements DocumentGateway {
  AudioProbeResult probe = const AudioProbeResult(playable: true);

  @override
  Future<PickedDocument?> pickAudio() async =>
      const PickedDocument(uri: 'new', displayName: 'new.mp3');
  @override
  Future<AudioProbeResult> probeAudio(String uri) async => probe;
  @override
  Future<bool> canRead(String uri) async => true;
  @override
  Future<bool> createEventJson({
    required String suggestedName,
    required String contents,
  }) async => true;
  @override
  Future<String?> openEventJson() async => null;
}
