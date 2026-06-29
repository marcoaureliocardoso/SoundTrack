import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../features/events/application/event_editor_controller.dart';
import '../features/events/application/event_library_controller.dart';
import '../features/events/data/event_repository.dart';
import '../features/events/data/json_file_event_repository.dart';
import '../features/events/domain/soundtrack_event.dart';

class AppDependencies {
  const AppDependencies({
    required this.eventRepository,
    required this.newEventId,
    required this.newMomentId,
  });

  final EventRepository eventRepository;
  final String Function() newEventId;
  final String Function() newMomentId;

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
}
