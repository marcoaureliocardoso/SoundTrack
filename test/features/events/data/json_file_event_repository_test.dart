import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

  test('replaces an event by id and writes the versioned envelope', () async {
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
