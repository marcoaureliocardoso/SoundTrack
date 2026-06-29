import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/soundtrack_event.dart';
import 'event_repository.dart';
import 'event_storage_exception.dart';

class JsonFileEventRepository implements EventRepository {
  /// [promote] is an internal test seam. It must not reenter repository
  /// methods targeting the same storage path.
  JsonFileEventRepository(
    this.directory, {
    Future<File> Function(File temporaryFile, String destinationPath)? promote,
  }) : _promote = promote ?? _rename;

  final Directory directory;
  final Future<File> Function(File temporaryFile, String destinationPath)
  _promote;

  static final Map<String, Future<void>> _operationTails = {};

  File get _file =>
      File('${directory.path}${Platform.pathSeparator}events.json');

  File get _temporaryFile =>
      File('${directory.path}${Platform.pathSeparator}events.json.tmp');

  @override
  Future<List<SoundTrackEvent>> findAll() {
    return _synchronized(() async {
      final events = (await _read()).values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return events;
    });
  }

  @override
  Future<SoundTrackEvent?> findById(String id) {
    return _synchronized(() async => (await _read())[id]);
  }

  @override
  Future<void> save(SoundTrackEvent event) {
    return _synchronized(() async {
      final events = await _read();
      events[event.id] = event;
      await _write(events);
    });
  }

  @override
  Future<void> delete(String id) {
    return _synchronized(() async {
      final events = await _read();
      if (!events.containsKey(id)) {
        return;
      }
      events.remove(id);
      await _write(events);
    });
  }

  Future<T> _synchronized<T>(Future<T> Function() operation) {
    // The absolute-path key assumes callers use the canonical app directory
    // supplied by path_provider.
    final storagePath = _file.absolute.path;
    final previous = _operationTails[storagePath] ?? Future<void>.value();
    final result = previous.then((_) => operation());
    late final Future<void> tail;
    tail = result
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() {
          if (identical(_operationTails[storagePath], tail)) {
            _operationTails.remove(storagePath);
          }
        });
    _operationTails[storagePath] = tail;
    return result;
  }

  Future<Map<String, SoundTrackEvent>> _read() async {
    if (await _file.exists()) {
      return _readFile(_file);
    }
    if (!await _temporaryFile.exists()) {
      return {};
    }

    final recovered = await _readFile(_temporaryFile);
    await _promoteTemporary();
    return recovered;
  }

  Future<Map<String, SoundTrackEvent>> _readFile(File source) async {
    try {
      final decoded = jsonDecode(await source.readAsString());
      if (decoded is! Map) {
        throw _corrupted(source, 'The event store root must be an object.');
      }
      final envelope = Map<String, Object?>.from(decoded);
      final schemaVersion = envelope['schemaVersion'];
      if (schemaVersion is! int) {
        throw _corrupted(
          source,
          'The event store schemaVersion must be an integer.',
        );
      }
      if (schemaVersion != 1) {
        throw EventStorageException(
          code: EventStorageErrorCode.incompatibleSchema,
          path: source.absolute.path,
          cause: schemaVersion,
        );
      }

      final eventJson = envelope['events'];
      if (eventJson is! List) {
        throw _corrupted(source, 'The event store events must be a list.');
      }

      final validatedJson = <Map<String, Object?>>[];
      final ids = <String>{};
      for (final item in eventJson) {
        if (item is! Map) {
          throw _corrupted(source, 'Each stored event must be an object.');
        }
        final json = Map<String, Object?>.from(item);
        final id = json['id'];
        if (id is! String) {
          throw _corrupted(source, 'Each stored event must have a string id.');
        }
        if (!ids.add(id)) {
          throw _corrupted(source, 'Duplicate stored event id: $id.');
        }
        validatedJson.add(json);
      }

      return {
        for (final json in validatedJson)
          json['id']! as String: SoundTrackEvent.fromJson(json),
      };
    } on EventStorageException {
      rethrow;
    } catch (error, stackTrace) {
      throw EventStorageException(
        code: EventStorageErrorCode.corruptedData,
        path: source.absolute.path,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  EventStorageException _corrupted(File source, String message) {
    return EventStorageException(
      code: EventStorageErrorCode.corruptedData,
      path: source.absolute.path,
      cause: FormatException(message),
    );
  }

  Future<void> _write(Map<String, SoundTrackEvent> events) async {
    await directory.create(recursive: true);
    final json = jsonEncode({
      'schemaVersion': 1,
      'events': events.values.map((event) => event.toJson()).toList(),
    });
    await _temporaryFile.writeAsString(json, flush: true);
    try {
      await _promoteTemporary();
    } catch (error, stackTrace) {
      await _discardFailedLiveTemporary(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _discardFailedLiveTemporary(
    Object promotionError,
    StackTrace promotionStackTrace,
  ) async {
    try {
      if (await _temporaryFile.exists()) {
        await _temporaryFile.delete();
      }
      return;
    } catch (_) {
      try {
        await _temporaryFile.rename('${_temporaryFile.path}.failed');
        return;
      } catch (_) {
        throw EventStorageException(
          code: EventStorageErrorCode.storageFailure,
          path: _temporaryFile.absolute.path,
          cause: promotionError,
          stackTrace: promotionStackTrace,
        );
      }
    }
  }

  Future<void> _promoteTemporary() async {
    // Final replacement relies on rename semantics from the filesystem backing
    // Android app-private storage; Dart does not expose a directory fsync.
    await _promote(_temporaryFile, _file.path);
  }

  static Future<File> _rename(File temporaryFile, String destinationPath) {
    return temporaryFile.rename(destinationPath);
  }
}
