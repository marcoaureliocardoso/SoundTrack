import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_export.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';

void main() {
  test('export envelope excludes session state', () {
    final event = SoundTrackEvent.create(id: 'e1', name: 'Reunião');
    final exported = EventExport.create(
      event: event,
      exportedAt: DateTime.utc(2026, 6, 29),
    ).toJson();
    expect(exported['format'], 'soundtrack-event');
    expect(exported['schemaVersion'], 1);
    expect(exported['audioSources'], isA<List<Object?>>());
    expect(exported.containsKey('sessionState'), isFalse);
  });

  test('export converts timestamp to UTC and deduplicates audio by URI', () {
    const sharedAudio = AudioReference(
      uri: 'content://shared',
      displayName: 'Shared',
      pending: false,
      artist: null,
      duration: null,
    );
    const noUriAudio = AudioReference(
      uri: null,
      displayName: 'Pending',
      pending: true,
      artist: null,
      duration: null,
    );
    final event = SoundTrackEvent.create(id: 'e1', name: 'Reunião')
        .addMoment(
          EventMoment.create(
            id: 'a',
            position: 0,
            name: 'A',
          ).copyWith(audio: sharedAudio),
        )
        .addMoment(
          EventMoment.create(
            id: 'b',
            position: 1,
            name: 'B',
          ).copyWith(audio: sharedAudio),
        )
        .addMoment(
          EventMoment.create(
            id: 'c',
            position: 2,
            name: 'C',
          ).copyWith(audio: noUriAudio),
        );

    final exported = EventExport.create(
      event: event,
      exportedAt: DateTime(2026, 6, 29, 12),
    ).toJson();

    expect(exported['format'], EventExport.format);
    expect(exported['schemaVersion'], EventExport.currentSchemaVersion);
    expect(
      exported['exportedAt'],
      DateTime(2026, 6, 29, 12).toUtc().toIso8601String(),
    );
    expect(exported['event'], event.toJson());
    expect(exported['audioSources'], [sharedAudio.toJson()]);
  });
}
