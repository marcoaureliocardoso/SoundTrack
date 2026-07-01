import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/data/event_storage_exception.dart';
import 'package:soundtrack/features/live/application/preflight_record_repository.dart';

void main() {
  late Directory directory;
  late JsonFilePreflightRecordRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('preflight-records-');
    repository = JsonFilePreflightRecordRepository(directory);
  });

  tearDown(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  test('saves, replaces, finds, and deletes records', () async {
    await repository.save(_record(errorCount: 1));
    await repository.save(_record(errorCount: 0, warningCount: 2));

    expect((await repository.findAll()), hasLength(1));
    expect((await repository.findByEventId('event'))?.warningCount, 2);

    await repository.delete('event');
    expect(await repository.findByEventId('event'), isNull);
  });

  test('promotes a complete temporary file atomically', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final controlled = JsonFilePreflightRecordRepository(
      directory,
      promote: (temporary, destination) async {
        entered.complete();
        await release.future;
        return temporary.rename(destination);
      },
    );

    final save = controlled.save(_record());
    await entered.future;

    expect(
      File(
        '${directory.path}${Platform.pathSeparator}preflight-records.json.tmp',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '${directory.path}${Platform.pathSeparator}preflight-records.json',
      ).existsSync(),
      isFalse,
    );
    release.complete();
    await save;
    expect(await repository.findByEventId('event'), isNotNull);
  });

  test('rejects corrupt data and future schemas with typed errors', () async {
    final file = File(
      '${directory.path}${Platform.pathSeparator}preflight-records.json',
    );
    await file.writeAsString('not json');
    await expectLater(
      repository.findAll(),
      throwsA(
        isA<EventStorageException>().having(
          (error) => error.code,
          'code',
          EventStorageErrorCode.corruptedData,
        ),
      ),
    );

    await file.writeAsString(jsonEncode({'schemaVersion': 3, 'records': []}));
    await expectLater(
      repository.findAll(),
      throwsA(
        isA<EventStorageException>()
            .having(
              (error) => error.code,
              'code',
              EventStorageErrorCode.incompatibleSchema,
            )
            .having((error) => error.cause, 'cause', 3),
      ),
    );
  });

  test('loads schema 1 records without a signature as legacy data', () async {
    final file = File(
      '${directory.path}${Platform.pathSeparator}preflight-records.json',
    );
    await file.writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'records': [
          {
            'eventId': 'legacy',
            'checkedAt': DateTime.utc(2026, 7, 1).toIso8601String(),
            'eventUpdatedAt': DateTime.utc(2026, 6, 30).toIso8601String(),
            'errorCount': 0,
            'warningCount': 0,
          },
        ],
      }),
    );

    final record = await repository.findByEventId('legacy');

    expect(record, isNotNull);
    expect(record!.sourceSignature, isNull);
  });

  test('serializes overlapping saves across repository instances', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final first = JsonFilePreflightRecordRepository(
      directory,
      promote: (temporary, destination) async {
        entered.complete();
        await release.future;
        return temporary.rename(destination);
      },
    );
    final second = JsonFilePreflightRecordRepository(directory);

    final firstSave = first.save(_record(eventId: 'first'));
    await entered.future;
    final secondSave = second.save(_record(eventId: 'second'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    release.complete();
    await Future.wait([firstSave, secondSave]);

    expect(
      (await repository.findAll()).map((record) => record.eventId).toSet(),
      {'first', 'second'},
    );
  });

  test('detects stale records by exact event update timestamp', () {
    final record = _record(eventUpdatedAt: DateTime.utc(2026, 6, 30, 23));

    expect(record.isStaleFor(DateTime.utc(2026, 6, 30, 23)), isFalse);
    expect(record.isStaleFor(DateTime.utc(2026, 6, 30, 22)), isTrue);
    expect(record.isStaleFor(DateTime.utc(2026, 7, 1)), isTrue);
  });

  test('supports the compact record shape with checkedAt as fallback', () {
    final checkedAt = DateTime.utc(2026, 7, 1);

    final record = PreflightRecord(
      eventId: 'event',
      checkedAt: checkedAt,
      errorCount: 0,
      warningCount: 0,
    );

    expect(record.eventUpdatedAt, checkedAt);
  });
}

PreflightRecord _record({
  String eventId = 'event',
  int errorCount = 0,
  int warningCount = 0,
  DateTime? eventUpdatedAt,
}) {
  return PreflightRecord(
    eventId: eventId,
    checkedAt: DateTime.utc(2026, 7, 1),
    eventUpdatedAt: eventUpdatedAt ?? DateTime.utc(2026, 6, 30, 23),
    sourceSignature: 'signature-$eventId',
    errorCount: errorCount,
    warningCount: warningCount,
  );
}
