import 'dart:io';

abstract interface class ActiveLiveSessionStore {
  Future<String?> readEventId();

  Future<void> saveEventId(String eventId);

  Future<void> clear();
}

final class MemoryActiveLiveSessionStore implements ActiveLiveSessionStore {
  String? _eventId;

  @override
  Future<String?> readEventId() async => _eventId;

  @override
  Future<void> saveEventId(String eventId) async {
    _eventId = eventId;
  }

  @override
  Future<void> clear() async {
    _eventId = null;
  }
}

final class FileActiveLiveSessionStore implements ActiveLiveSessionStore {
  FileActiveLiveSessionStore(Directory directory)
    : _file = File(
        '${directory.path}${Platform.pathSeparator}active_live_session',
      );

  final File _file;

  @override
  Future<String?> readEventId() async {
    try {
      final eventId = (await _file.readAsString()).trim();
      return eventId.isEmpty ? null : eventId;
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> saveEventId(String eventId) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(eventId, flush: true);
  }

  @override
  Future<void> clear() async {
    try {
      await _file.delete();
    } on FileSystemException {
      // Clearing an already absent session is idempotent.
    }
  }
}
