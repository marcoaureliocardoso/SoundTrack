import 'dart:convert';
import 'dart:io';

import '../domain/soundtrack_event.dart';
import 'event_repository.dart';

class JsonFileEventRepository implements EventRepository {
  JsonFileEventRepository(this.directory);

  final Directory directory;

  File get _file =>
      File('${directory.path}${Platform.pathSeparator}events.json');

  File get _temporaryFile =>
      File('${directory.path}${Platform.pathSeparator}events.json.tmp');

  @override
  Future<List<SoundTrackEvent>> findAll() async {
    final events = (await _read()).values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return events;
  }

  @override
  Future<SoundTrackEvent?> findById(String id) async {
    return (await _read())[id];
  }

  @override
  Future<void> save(SoundTrackEvent event) async {
    final events = await _read();
    events[event.id] = event;
    await _write(events);
  }

  @override
  Future<void> delete(String id) async {
    final events = await _read();
    events.remove(id);
    await _write(events);
  }

  Future<Map<String, SoundTrackEvent>> _read() async {
    if (!await _file.exists()) {
      return {};
    }

    final envelope = Map<String, Object?>.from(
      jsonDecode(await _file.readAsString()) as Map,
    );
    final eventJson = envelope['events'] as List<Object?>;
    final events = <String, SoundTrackEvent>{};
    for (final item in eventJson) {
      final event = SoundTrackEvent.fromJson(
        Map<String, Object?>.from(item! as Map),
      );
      events[event.id] = event;
    }
    return events;
  }

  Future<void> _write(Map<String, SoundTrackEvent> events) async {
    await directory.create(recursive: true);
    final json = jsonEncode({
      'schemaVersion': 1,
      'events': events.values.map((event) => event.toJson()).toList(),
    });
    await _temporaryFile.writeAsString(json, flush: true);

    if (await _file.exists()) {
      await _file.delete();
    }
    await _temporaryFile.rename(_file.path);
  }
}
