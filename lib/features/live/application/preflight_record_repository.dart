import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../events/data/event_storage_exception.dart';

class PreflightRecord {
  PreflightRecord({
    required this.eventId,
    required DateTime checkedAt,
    DateTime? eventUpdatedAt,
    required this.errorCount,
    required this.warningCount,
  }) : checkedAt = checkedAt.toUtc(),
       eventUpdatedAt = (eventUpdatedAt ?? checkedAt).toUtc() {
    if (eventId.isEmpty) {
      throw ArgumentError.value(eventId, 'eventId', 'must not be empty');
    }
    if (errorCount < 0 || warningCount < 0) {
      throw ArgumentError('Preflight counts must not be negative.');
    }
  }

  factory PreflightRecord.fromJson(Map<String, Object?> json) {
    return PreflightRecord(
      eventId: json['eventId'] as String,
      checkedAt: DateTime.parse(json['checkedAt'] as String),
      eventUpdatedAt: DateTime.parse(json['eventUpdatedAt'] as String),
      errorCount: json['errorCount'] as int,
      warningCount: json['warningCount'] as int,
    );
  }

  final String eventId;
  final DateTime checkedAt;
  final DateTime eventUpdatedAt;
  final int errorCount;
  final int warningCount;

  bool isStaleFor(DateTime updatedAt) => eventUpdatedAt != updatedAt.toUtc();

  Map<String, Object?> toJson() => {
    'eventId': eventId,
    'checkedAt': checkedAt.toIso8601String(),
    'eventUpdatedAt': eventUpdatedAt.toIso8601String(),
    'errorCount': errorCount,
    'warningCount': warningCount,
  };
}

abstract interface class PreflightRecordRepository {
  Future<List<PreflightRecord>> findAll();

  Future<PreflightRecord?> findByEventId(String eventId);

  Future<void> save(PreflightRecord record);

  Future<void> delete(String eventId);
}

class JsonFilePreflightRecordRepository implements PreflightRecordRepository {
  JsonFilePreflightRecordRepository(
    this.directory, {
    Future<File> Function(File temporaryFile, String destinationPath)? promote,
  }) : _promote = promote ?? _rename;

  final Directory directory;
  final Future<File> Function(File temporaryFile, String destinationPath)
  _promote;

  static final Map<String, Future<void>> _operationTails = {};

  File get _file =>
      File('${directory.path}${Platform.pathSeparator}preflight-records.json');

  File get _temporaryFile => File(
    '${directory.path}${Platform.pathSeparator}preflight-records.json.tmp',
  );

  @override
  Future<List<PreflightRecord>> findAll() {
    return _synchronized(() async {
      final records = (await _read()).values.toList()
        ..sort((a, b) => b.checkedAt.compareTo(a.checkedAt));
      return List.unmodifiable(records);
    });
  }

  @override
  Future<PreflightRecord?> findByEventId(String eventId) {
    return _synchronized(() async => (await _read())[eventId]);
  }

  @override
  Future<void> save(PreflightRecord record) {
    return _synchronized(() async {
      final records = await _read();
      records[record.eventId] = record;
      await _write(records);
    });
  }

  @override
  Future<void> delete(String eventId) {
    return _synchronized(() async {
      final records = await _read();
      if (records.remove(eventId) == null) return;
      await _write(records);
    });
  }

  Future<T> _synchronized<T>(Future<T> Function() operation) {
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

  Future<Map<String, PreflightRecord>> _read() async {
    if (await _file.exists()) return _readFile(_file);
    if (!await _temporaryFile.exists()) return {};

    final recovered = await _readFile(_temporaryFile);
    await _promoteTemporary();
    return recovered;
  }

  Future<Map<String, PreflightRecord>> _readFile(File source) async {
    try {
      final decoded = jsonDecode(await source.readAsString());
      if (decoded is! Map) {
        throw _corrupted(source, 'The preflight store root must be an object.');
      }
      final envelope = Map<String, Object?>.from(decoded);
      final version = envelope['schemaVersion'];
      if (version is! int) {
        throw _corrupted(
          source,
          'The preflight store schemaVersion must be an integer.',
        );
      }
      if (version != 1) {
        throw EventStorageException(
          code: EventStorageErrorCode.incompatibleSchema,
          path: source.absolute.path,
          cause: version,
        );
      }
      final recordJson = envelope['records'];
      if (recordJson is! List) {
        throw _corrupted(source, 'The preflight store records must be a list.');
      }

      final records = <String, PreflightRecord>{};
      for (final item in recordJson) {
        if (item is! Map) {
          throw _corrupted(source, 'Each preflight record must be an object.');
        }
        final record = PreflightRecord.fromJson(
          Map<String, Object?>.from(item),
        );
        if (records.containsKey(record.eventId)) {
          throw _corrupted(
            source,
            'Duplicate preflight event id: ${record.eventId}.',
          );
        }
        records[record.eventId] = record;
      }
      return records;
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

  Future<void> _write(Map<String, PreflightRecord> records) async {
    await directory.create(recursive: true);
    await _temporaryFile.writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'records': records.values.map((record) => record.toJson()).toList(),
      }),
      flush: true,
    );
    try {
      await _promoteTemporary();
    } catch (error, stackTrace) {
      await _discardTemporary(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _discardTemporary(
    Object promotionError,
    StackTrace promotionStackTrace,
  ) async {
    try {
      if (await _temporaryFile.exists()) await _temporaryFile.delete();
    } catch (_) {
      throw EventStorageException(
        code: EventStorageErrorCode.storageFailure,
        path: _temporaryFile.absolute.path,
        cause: promotionError,
        stackTrace: promotionStackTrace,
      );
    }
  }

  Future<void> _promoteTemporary() => _promote(_temporaryFile, _file.path);

  static Future<File> _rename(File temporaryFile, String destinationPath) =>
      temporaryFile.rename(destinationPath);
}
