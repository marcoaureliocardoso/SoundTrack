import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../features/events/application/event_editor_controller.dart';
import '../features/events/application/event_library_controller.dart';
import '../features/events/application/event_transfer_controller.dart';
import '../features/events/data/event_export_codec.dart';
import '../features/events/data/event_repository.dart';
import '../features/events/data/json_file_event_repository.dart';
import '../features/events/domain/soundtrack_event.dart';
import '../platform/documents/document_gateway.dart';
import '../platform/documents/method_channel_document_gateway.dart';

class AppDependencies {
  const AppDependencies({
    required this.eventRepository,
    required this.newEventId,
    required this.newMomentId,
    this.documentGateway = const MethodChannelDocumentGateway(),
    this.exportCodec = const EventExportCodec(),
    this.clock = DateTime.now,
  });

  final EventRepository eventRepository;
  final String Function() newEventId;
  final String Function() newMomentId;
  final DocumentGateway documentGateway;
  final EventExportCodec exportCodec;
  final DateTime Function() clock;

  static Future<AppDependencies> create() async {
    final documents = await getApplicationDocumentsDirectory();
    final repository = JsonFileEventRepository(
      Directory('${documents.path}${Platform.pathSeparator}soundtrack'),
    );
    const uuid = Uuid();
    return AppDependencies(
      eventRepository: repository,
      newEventId: uuid.v4,
      newMomentId: uuid.v4,
    );
  }

  EventLibraryController createLibraryController() {
    return EventLibraryController(
      repository: eventRepository,
      newId: newEventId,
    );
  }

  EventEditorController createEditorController(SoundTrackEvent event) {
    return EventEditorController(
      repository: eventRepository,
      initial: event,
      newId: newMomentId,
    );
  }

  EventTransferController createTransferController() {
    return EventTransferController(
      gateway: documentGateway,
      codec: exportCodec,
      repository: eventRepository,
      newId: newEventId,
      clock: clock,
    );
  }
}
