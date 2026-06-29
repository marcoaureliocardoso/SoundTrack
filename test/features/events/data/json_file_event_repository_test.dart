import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/data/event_storage_exception.dart';
import 'package:soundtrack/features/events/data/json_file_event_repository.dart';
import 'package:soundtrack/features/events/domain/event_audio_settings.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';

void main() {
  late Directory directory;
  late JsonFileEventRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('soundtrack_repo_');
    repository = JsonFileEventRepository(directory);
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('persists an event for a new repository instance', () async {
    await repository.save(_event(id: 'a', name: 'Formatura'));

    final reopened = JsonFileEventRepository(directory);
    final restored = await reopened.findById('a');

    expect(restored?.name, 'Formatura');
  });

  test('deletes only the event with the requested id', () async {
    await repository.save(_event(id: 'a', name: 'Formatura'));
    await repository.save(_event(id: 'b', name: 'Casamento'));

    await repository.delete('a');

    final events = await repository.findAll();
    expect(events.map((event) => event.id), ['b']);
  });

  test(
    'updates an existing events.json and writes the versioned envelope',
    () async {
      await repository.save(_event(id: 'a', name: 'Original'));
      await repository.save(_event(id: 'a', name: 'Atualizado'));

      final envelope =
          jsonDecode(
                await File(
                  '${directory.path}${Platform.pathSeparator}events.json',
                ).readAsString(),
              )
              as Map<String, Object?>;
      final events = envelope['events'] as List<Object?>;

      expect(envelope['schemaVersion'], 1);
      expect(events, hasLength(1));
      expect((events.single as Map<String, Object?>)['name'], 'Atualizado');
      expect(
        File(
          '${directory.path}${Platform.pathSeparator}events.json.tmp',
        ).existsSync(),
        isFalse,
      );
    },
  );

  test('preserves the existing events.json when promotion fails', () async {
    await repository.save(_event(id: 'a', name: 'Original'));
    final failingRepository = JsonFileEventRepository(
      directory,
      promote: (temporaryFile, destinationPath) async {
        throw FileSystemException('Promotion failed.', temporaryFile.path);
      },
    );

    await expectLater(
      failingRepository.save(_event(id: 'a', name: 'Atualizado')),
      throwsA(isA<FileSystemException>()),
    );

    final restored = await JsonFileEventRepository(directory).findById('a');
    final temporaryFile = File(
      '${directory.path}${Platform.pathSeparator}events.json.tmp',
    );

    expect(restored?.name, 'Original');
    expect(temporaryFile.existsSync(), isFalse);
  });

  test('does not recover a save whose live promotion failed', () async {
    final failingRepository = JsonFileEventRepository(
      directory,
      promote: (temporaryFile, destinationPath) async {
        throw FileSystemException('Promotion failed.', temporaryFile.path);
      },
    );

    await expectLater(
      failingRepository.save(_event(id: 'a', name: 'Rejeitado')),
      throwsA(isA<FileSystemException>()),
    );

    final reopened = JsonFileEventRepository(directory);
    expect(await reopened.findAll(), isEmpty);
    expect(
      File(
        '${directory.path}${Platform.pathSeparator}events.json',
      ).existsSync(),
      isFalse,
    );
  });

  test('findAll orders events by updatedAt descending', () async {
    await repository.save(
      _event(id: 'older', name: 'Antigo', updatedAt: DateTime.utc(2026, 6, 28)),
    );
    await repository.save(
      _event(id: 'newer', name: 'Novo', updatedAt: DateTime.utc(2026, 6, 29)),
    );

    final events = await repository.findAll();

    expect(events.map((event) => event.id), ['newer', 'older']);
  });

  test('serializes overlapping saves from different instances', () async {
    final promotions = _ControlledPromotions();
    final firstRepository = JsonFileEventRepository(
      directory,
      promote: promotions.promoteFirst,
    );
    final secondRepository = JsonFileEventRepository(
      directory,
      promote: promotions.promoteSecond,
    );

    final firstSave = firstRepository.save(_event(id: 'a', name: 'A'));
    await promotions.firstEntered.future;
    final secondSave = secondRepository.save(_event(id: 'b', name: 'B'));
    final secondEnteredBeforeRelease = await Future.any([
      promotions.secondEntered.future.then((_) => true),
      Future<bool>.delayed(const Duration(milliseconds: 50), () => false),
    ]);

    promotions.releaseFirst.complete();
    Object? saveError;
    try {
      await Future.wait([firstSave, secondSave]);
    } catch (error) {
      saveError = error;
    }

    expect(secondEnteredBeforeRelease, isFalse);
    expect(saveError, isNull);
    expect(
      (await JsonFileEventRepository(
        directory,
      ).findAll()).map((event) => event.id).toSet(),
      {'a', 'b'},
    );
  });

  test('serializes reads behind an in-progress save', () async {
    await repository.save(_event(id: 'a', name: 'Original'));
    final promotionEntered = Completer<void>();
    final allowPromotion = Completer<void>();
    final updatingRepository = JsonFileEventRepository(
      directory,
      promote: (temporaryFile, destinationPath) async {
        promotionEntered.complete();
        await allowPromotion.future;
        return temporaryFile.rename(destinationPath);
      },
    );

    final save = updatingRepository.save(_event(id: 'a', name: 'Atualizado'));
    await promotionEntered.future;
    final read = JsonFileEventRepository(directory).findById('a');
    allowPromotion.complete();
    await save;

    expect((await read)?.name, 'Atualizado');
  });

  test('continues the path queue after an operation fails', () async {
    await repository.save(_event(id: 'a', name: 'Original'));
    final failingRepository = JsonFileEventRepository(
      directory,
      promote: (temporaryFile, destinationPath) async {
        throw FileSystemException('Promotion failed.', temporaryFile.path);
      },
    );

    await expectLater(
      failingRepository.save(_event(id: 'a', name: 'Falha')),
      throwsA(isA<FileSystemException>()),
    );
    await JsonFileEventRepository(
      directory,
    ).save(_event(id: 'b', name: 'Seguinte'));

    expect((await repository.findAll()).map((event) => event.id).toSet(), {
      'a',
      'b',
    });
  });

  test('does not rewrite storage when deleting a missing id', () async {
    final failingRepository = JsonFileEventRepository(
      directory,
      promote: (temporaryFile, destinationPath) async {
        throw FileSystemException('Promotion should not run.');
      },
    );

    await failingRepository.delete('missing');

    expect(
      File(
        '${directory.path}${Platform.pathSeparator}events.json',
      ).existsSync(),
      isFalse,
    );
  });

  test('rejects a future schema with a typed storage error', () async {
    final file = File('${directory.path}${Platform.pathSeparator}events.json');
    await file.writeAsString(
      jsonEncode({'schemaVersion': 2, 'events': <Object?>[]}),
    );

    await expectLater(
      repository.findAll(),
      throwsA(
        isA<EventStorageException>()
            .having(
              (error) => error.code,
              'code',
              EventStorageErrorCode.incompatibleSchema,
            )
            .having((error) => error.path, 'path', file.absolute.path)
            .having((error) => error.cause, 'cause', 2),
      ),
    );
  });

  test('rejects duplicate event ids as corrupted data', () async {
    final event = _event(id: 'duplicate', name: 'Duplicado');
    final file = File('${directory.path}${Platform.pathSeparator}events.json');
    await file.writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'events': [event.toJson(), event.toJson()],
      }),
    );

    await expectLater(
      repository.findAll(),
      throwsA(
        isA<EventStorageException>()
            .having(
              (error) => error.code,
              'code',
              EventStorageErrorCode.corruptedData,
            )
            .having((error) => error.path, 'path', file.absolute.path),
      ),
    );
  });

  test('recovers a valid temporary store when the final is absent', () async {
    final temporaryFile = File(
      '${directory.path}${Platform.pathSeparator}events.json.tmp',
    );
    await temporaryFile.writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'events': [_event(id: 'recovered', name: 'Recuperado').toJson()],
      }),
    );

    final restored = await repository.findById('recovered');

    expect(restored?.name, 'Recuperado');
    expect(temporaryFile.existsSync(), isFalse);
    expect(
      File(
        '${directory.path}${Platform.pathSeparator}events.json',
      ).existsSync(),
      isTrue,
    );
  });

  test('rejects a truncated temporary store without promoting it', () async {
    final temporaryFile = File(
      '${directory.path}${Platform.pathSeparator}events.json.tmp',
    );
    final finalFile = File(
      '${directory.path}${Platform.pathSeparator}events.json',
    );
    await temporaryFile.writeAsString('{"schemaVersion":1,"events":[');

    await expectLater(
      repository.findAll(),
      throwsA(
        isA<EventStorageException>()
            .having(
              (error) => error.code,
              'code',
              EventStorageErrorCode.corruptedData,
            )
            .having((error) => error.path, 'path', temporaryFile.absolute.path),
      ),
    );
    expect(finalFile.existsSync(), isFalse);
    expect(temporaryFile.existsSync(), isTrue);
  });

  test('uses the final store when a residual temporary file exists', () async {
    await repository.save(_event(id: 'final', name: 'Final'));
    final temporaryFile = File(
      '${directory.path}${Platform.pathSeparator}events.json.tmp',
    );
    await temporaryFile.writeAsString('truncated');

    final events = await repository.findAll();

    expect(events.map((event) => event.id), ['final']);
    expect(temporaryFile.existsSync(), isTrue);
  });
}

SoundTrackEvent _event({
  required String id,
  required String name,
  DateTime? updatedAt,
}) {
  return SoundTrackEvent(
    id: id,
    name: name,
    createdAt: DateTime.utc(2026, 6, 29),
    updatedAt: updatedAt ?? DateTime.utc(2026, 6, 29),
    audioSettings: const EventAudioSettings.defaults(),
    moments: const [],
  );
}

class _ControlledPromotions {
  final firstEntered = Completer<void>();
  final secondEntered = Completer<void>();
  final releaseFirst = Completer<void>();
  final _firstFinished = Completer<void>();

  Future<File> promoteFirst(File temporaryFile, String destinationPath) async {
    firstEntered.complete();
    await releaseFirst.future;
    try {
      return await temporaryFile.rename(destinationPath);
    } finally {
      _firstFinished.complete();
    }
  }

  Future<File> promoteSecond(File temporaryFile, String destinationPath) async {
    secondEntered.complete();
    await _firstFinished.future;
    return temporaryFile.rename(destinationPath);
  }
}
