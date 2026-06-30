import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/application/event_audio_availability_service.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/platform/documents/document_gateway.dart';

void main() {
  group('EventAudioAvailabilityService', () {
    test('marks a non-pending unreadable reference as pending', () async {
      final event = _eventWithAudio(_audio());
      final service = EventAudioAvailabilityService(
        canRead: (_) async => false,
        probeAudio: (_) async => throw StateError('must not probe'),
      );

      final result = await service.revalidate([event]);

      final audio = result.single.moments.single.audio!;
      expect(audio.pending, isTrue);
      expect(audio.uri, 'content://audio/entry');
      expect(audio.displayName, 'entrada.ogg');
      expect(audio.artist, 'Artista');
      expect(audio.duration, const Duration(seconds: 12));
    });

    test('probes the same URI only once across moments', () async {
      var canReadCalls = 0;
      var probeCalls = 0;
      final event = SoundTrackEvent.create(id: 'event', name: 'Evento')
          .copyWith(
            moments: [
              _moment(id: 'first', position: 0, audio: _audio()),
              _moment(id: 'second', position: 1, audio: _audio()),
            ],
          );
      final service = EventAudioAvailabilityService(
        canRead: (_) async {
          canReadCalls++;
          return true;
        },
        probeAudio: (_) async {
          probeCalls++;
          return const AudioProbeResult(playable: true);
        },
      );

      await service.revalidate([event]);

      expect(canReadCalls, 1);
      expect(probeCalls, 1);
    });

    test(
      'returns the identical event when a playable probe changes nothing',
      () async {
        final event = _eventWithAudio(_audio());
        final service = EventAudioAvailabilityService(
          canRead: (_) async => true,
          probeAudio: (_) async => const AudioProbeResult(
            playable: true,
            artist: 'Artista',
            duration: Duration(seconds: 12),
          ),
        );

        final result = await service.revalidate([event]);

        expect(result.single, same(event));
      },
    );

    test('marks the reference pending when probing throws', () async {
      final event = _eventWithAudio(_audio());
      final service = EventAudioAvailabilityService(
        canRead: (_) async => true,
        probeAudio: (_) async => throw StateError('probe failed'),
      );

      final result = await service.revalidate([event]);

      expect(result.single.moments.single.audio!.pending, isTrue);
    });

    test('marks an unplayable readable reference as pending', () async {
      final event = _eventWithAudio(_audio());
      final service = EventAudioAvailabilityService(
        canRead: (_) async => true,
        probeAudio: (_) async => const AudioProbeResult(playable: false),
      );

      final result = await service.revalidate([event]);

      expect(result.single.moments.single.audio!.pending, isTrue);
    });

    test(
      'clears pending and applies metadata supplied by a playable probe',
      () async {
        final event = _eventWithAudio(_audio().markPending());
        final service = EventAudioAvailabilityService(
          canRead: (_) async => true,
          probeAudio: (_) async => const AudioProbeResult(
            playable: true,
            artist: 'Novo artista',
            duration: Duration(seconds: 30),
          ),
        );

        final result = await service.revalidate([event]);

        final audio = result.single.moments.single.audio!;
        expect(audio.pending, isFalse);
        expect(audio.artist, 'Novo artista');
        expect(audio.duration, const Duration(seconds: 30));
      },
    );

    test('does not probe or change a moment without audio', () async {
      final event = SoundTrackEvent.create(id: 'event', name: 'Evento')
          .copyWith(
            moments: [
              EventMoment.create(id: 'moment', position: 0, name: 'Entrada'),
            ],
          );
      final service = EventAudioAvailabilityService(
        canRead: (_) async => throw StateError('must not read'),
        probeAudio: (_) async => throw StateError('must not probe'),
      );

      final result = await service.revalidate([event]);

      expect(result.single, same(event));
      expect(result.single.moments.single.audio, isNull);
      expect(result.single.moments.single.audioPending, isTrue);
    });
  });
}

AudioReference _audio() {
  return const AudioReference(
    uri: 'content://audio/entry',
    displayName: 'entrada.ogg',
    pending: false,
    artist: 'Artista',
    duration: Duration(seconds: 12),
  );
}

SoundTrackEvent _eventWithAudio(AudioReference audio) {
  return SoundTrackEvent.create(id: 'event', name: 'Evento').copyWith(
    moments: [_moment(id: 'moment', position: 0, audio: audio)],
  );
}

EventMoment _moment({
  required String id,
  required int position,
  required AudioReference audio,
}) {
  return EventMoment.create(
    id: id,
    position: position,
    name: id,
  ).copyWith(audio: audio);
}
