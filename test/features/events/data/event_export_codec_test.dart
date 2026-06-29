import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/data/event_export_codec.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_audio_settings.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/platform/documents/document_gateway.dart';

void main() {
  final event = SoundTrackEvent(
    id: 'old',
    name: 'Cerimônia',
    createdAt: DateTime.utc(2025),
    updatedAt: DateTime.utc(2025, 2),
    audioSettings: const EventAudioSettings.defaults(),
    moments: [
      EventMoment(
        id: 'm1',
        position: 0,
        name: 'Entrada',
        audio: const AudioReference(
          uri: 'content://song',
          displayName: 'song.mp3',
          pending: false,
          artist: 'Old',
          duration: Duration(seconds: 1),
        ),
        endBehavior: EndBehavior.loop,
        narrationEnabled: false,
        gainDb: 0,
        fadeIn: null,
        fadeOut: null,
      ),
    ],
  );
  const codec = EventExportCodec();

  test('encode writes format, schema 1 and UTC exportedAt', () {
    final json =
        jsonDecode(
              codec.encode(event, DateTime.parse('2026-06-29T12:00:00-03:00')),
            )
            as Map<String, Object?>;
    expect(json['format'], 'soundtrack-event');
    expect(json['schemaVersion'], 1);
    expect(json['exportedAt'], '2026-06-29T15:00:00.000Z');
  });

  test('invalid JSON has typed invalidJson error', () async {
    await expectLater(
      codec.decode(
        '{',
        replacementId: 'new',
        canRead: (_) async => true,
        probeAudio: (_) async => const AudioProbeResult(playable: true),
      ),
      throwsA(EventImportException.invalidJson),
    );
  });

  test('wrong format is unsupportedFormat', () async {
    await expectLater(
      _decode(codec, event, replacementId: 'new', format: 'other'),
      throwsA(EventImportException.unsupportedFormat),
    );
  });

  test('missing or non-string format is invalidJson', () async {
    for (final format in <Object?>[null, 42]) {
      final value =
          jsonDecode(codec.encode(event, DateTime.utc(2026)))
              as Map<String, Object?>;
      if (format == null) {
        value.remove('format');
      } else {
        value['format'] = format;
      }
      await expectLater(
        codec.decode(
          jsonEncode(value),
          replacementId: 'new',
          canRead: (_) async => true,
          probeAudio: (_) async => const AudioProbeResult(playable: true),
        ),
        throwsA(EventImportException.invalidJson),
      );
    }
  });

  test('schema 2 is unsupportedVersion', () async {
    await expectLater(
      _decode(codec, event, replacementId: 'new', version: 2),
      throwsA(EventImportException.unsupportedVersion),
    );
  });

  test('validates required envelope fields before probing', () async {
    final value =
        jsonDecode(codec.encode(event, DateTime.utc(2026)))
            as Map<String, Object?>;
    value.remove('audioSources');
    var probes = 0;
    await expectLater(
      codec.decode(
        jsonEncode(value),
        replacementId: 'new',
        canRead: (_) async {
          probes++;
          return true;
        },
        probeAudio: (_) async => const AudioProbeResult(playable: true),
      ),
      throwsA(EventImportException.invalidJson),
    );
    expect(probes, 0);
  });

  test('rejects malformed audioSources before probing', () async {
    final invalidSources = <Object?>[
      'not-a-map',
      <String, Object?>{
        'uri': '',
        'displayName': 'song.mp3',
        'portable': false,
        'artist': null,
        'durationMs': null,
      },
      <String, Object?>{
        'uri': 'content://song',
        'displayName': '',
        'portable': false,
        'artist': null,
        'durationMs': null,
      },
      <String, Object?>{
        'uri': 'content://song',
        'displayName': 'song.mp3',
        'portable': true,
        'artist': null,
        'durationMs': null,
      },
      <String, Object?>{
        'uri': 'content://song',
        'displayName': 'song.mp3',
        'portable': false,
        'artist': 7,
        'durationMs': null,
      },
      <String, Object?>{
        'uri': 'content://song',
        'displayName': 'song.mp3',
        'portable': false,
        'artist': null,
        'durationMs': -1,
      },
    ];
    for (final source in invalidSources) {
      final value =
          jsonDecode(codec.encode(event, DateTime.utc(2026)))
              as Map<String, Object?>;
      value['audioSources'] = [source];
      var probes = 0;
      await expectLater(
        codec.decode(
          jsonEncode(value),
          replacementId: 'new',
          canRead: (_) async {
            probes++;
            return true;
          },
          probeAudio: (_) async {
            probes++;
            return const AudioProbeResult(playable: true);
          },
        ),
        throwsA(EventImportException.invalidJson),
      );
      expect(probes, 0);
    }
  });

  test(
    'schema 1 imports with replacement id and reuses playable source',
    () async {
      final imported = await codec.decode(
        codec.encode(event, DateTime.utc(2026)),
        replacementId: 'new',
        canRead: (_) async => true,
        probeAudio: (_) async => const AudioProbeResult(
          playable: true,
          artist: 'Fresh',
          duration: Duration(seconds: 9),
        ),
      );
      expect(imported.id, 'new');
      expect(imported.moments.single.audio!.pending, isFalse);
      expect(imported.moments.single.audio!.artist, 'Fresh');
      expect(
        imported.moments.single.audio!.duration,
        const Duration(seconds: 9),
      );
    },
  );

  test('inaccessible or unplayable sources remain pending', () async {
    final inaccessible = await codec.decode(
      codec.encode(event, DateTime.utc(2026)),
      replacementId: 'a',
      canRead: (_) async => false,
      probeAudio: (_) async => throw StateError('must not probe'),
    );
    final unplayable = await codec.decode(
      codec.encode(event, DateTime.utc(2026)),
      replacementId: 'b',
      canRead: (_) async => true,
      probeAudio: (_) async => const AudioProbeResult(playable: false),
    );
    expect(inaccessible.moments.single.audio!.pending, isTrue);
    expect(unplayable.moments.single.audio!.pending, isTrue);
  });
}

Future<SoundTrackEvent> _decode(
  EventExportCodec codec,
  SoundTrackEvent event, {
  required String replacementId,
  String format = 'soundtrack-event',
  int version = 1,
}) {
  final value = jsonDecode(codec.encode(event, DateTime.utc(2026))) as Map;
  value['format'] = format;
  value['schemaVersion'] = version;
  return codec.decode(
    jsonEncode(value),
    replacementId: replacementId,
    canRead: (_) async => true,
    probeAudio: (_) async => const AudioProbeResult(playable: true),
  );
}
