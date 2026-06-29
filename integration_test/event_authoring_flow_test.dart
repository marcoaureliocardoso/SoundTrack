import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/application/event_editor_controller.dart';
import 'package:soundtrack/features/events/application/event_library_controller.dart';
import 'package:soundtrack/features/events/application/event_transfer_controller.dart';
import 'package:soundtrack/features/events/data/event_export_codec.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/platform/documents/document_gateway.dart';

import '../test/support/in_memory_event_repository.dart';

void main() {
  test(
    'create moments, export, import and relink with fake documents',
    () async {
      final repository = InMemoryEventRepository();
      var eventSequence = 0;
      final library = EventLibraryController(
        repository: repository,
        newId: () => 'event-${++eventSequence}',
      );
      final created = await library.create('Casamento');
      var momentSequence = 0;
      final editor = EventEditorController(
        repository: repository,
        initial: created,
        newId: () => 'moment-${++momentSequence}',
      );
      editor.addMoment('Entrada');
      editor.updateMoment(
        editor.draft.moments.single.copyWith(
          audio: const AudioReference(
            uri: 'content://original',
            displayName: 'entrada.mp3',
            pending: false,
            artist: 'Band',
            duration: Duration(minutes: 3),
          ),
        ),
      );
      editor.addMoment('Sem arquivo');
      await editor.save();

      final gateway = _FlowGateway();
      final transfer = EventTransferController(
        gateway: gateway,
        codec: const EventExportCodec(),
        repository: repository,
        newId: () => 'event-${++eventSequence}',
        clock: () => DateTime.utc(2026, 6, 29),
      );
      expect(await transfer.exportEvent(editor.draft), isTrue);

      gateway.openedContents = gateway.exportedContents;
      final imported = await transfer.importEvent();
      expect(imported!.id, 'event-2');
      expect(imported.moments[0].audio!.pending, isTrue);
      expect(imported.moments[1].audioPending, isTrue);
      expect(imported.moments[1].audio, isNull);

      gateway.picked = const PickedDocument(
        uri: 'content://replacement',
        displayName: 'entrada-local.mp3',
      );
      gateway.probe = const AudioProbeResult(
        playable: true,
        artist: 'Local Band',
        duration: Duration(minutes: 4),
      );
      final relinked = await transfer.relinkMoment(imported, 'moment-1');
      final relinkedWithoutReference = await transfer.relinkMoment(
        relinked,
        'moment-2',
      );
      expect(relinkedWithoutReference.moments[0].audio!.pending, isFalse);
      expect(relinkedWithoutReference.moments[0].audio!.artist, 'Local Band');
      expect(
        relinkedWithoutReference.moments[1].audio!.uri,
        'content://replacement',
      );
    },
  );
}

class _FlowGateway implements DocumentGateway {
  String? exportedContents;
  String? openedContents;
  PickedDocument? picked;
  AudioProbeResult probe = const AudioProbeResult(playable: false);

  @override
  Future<bool> createEventJson({
    required String suggestedName,
    required String contents,
  }) async {
    exportedContents = contents;
    return true;
  }

  @override
  Future<String?> openEventJson() async => openedContents;

  @override
  Future<bool> canRead(String uri) async => false;

  @override
  Future<PickedDocument?> pickAudio() async => picked;

  @override
  Future<AudioProbeResult> probeAudio(String uri) async => probe;
}
