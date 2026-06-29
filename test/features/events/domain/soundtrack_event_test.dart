import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/event_validation.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';

void main() {
  group('EventMoment', () {
    test('create applies defaults and reports absent audio as pending', () {
      final moment = EventMoment.create(id: 'a', position: 0, name: 'Entrada');

      expect(moment.endBehavior, EndBehavior.loop);
      expect(moment.narrationEnabled, isFalse);
      expect(moment.gainDb, 0);
      expect(moment.audioPending, isTrue);
    });

    test('copyWith updates fields, clamps gain, and can clear audio', () {
      const audio = AudioReference(
        uri: 'content://song',
        displayName: 'Song',
        pending: false,
        artist: 'Artist',
        duration: Duration(minutes: 3),
      );
      final moment = EventMoment.create(id: 'a', position: 0, name: 'Entrada')
          .copyWith(
            id: 'b',
            position: 2,
            name: 'Saída',
            audio: audio,
            endBehavior: EndBehavior.stop,
            narrationEnabled: true,
            gainDb: 20,
            fadeIn: const Duration(seconds: 1),
            fadeOut: const Duration(seconds: 4),
          );

      expect(moment.id, 'b');
      expect(moment.position, 2);
      expect(moment.name, 'Saída');
      expect(moment.audio, audio);
      expect(moment.endBehavior, EndBehavior.stop);
      expect(moment.narrationEnabled, isTrue);
      expect(moment.gainDb, 6);
      expect(moment.fadeIn, const Duration(seconds: 1));
      expect(moment.fadeOut, const Duration(seconds: 4));
      expect(moment.copyWith(gainDb: -20, clearAudio: true).gainDb, -12);
      expect(moment.copyWith(clearAudio: true).audio, isNull);
    });

    test('JSON round trip restores fields and imported audio is pending', () {
      const moment = EventMoment(
        id: 'a',
        position: 3,
        name: 'Entrada',
        audio: AudioReference(
          uri: 'content://song',
          displayName: 'Song',
          pending: false,
          artist: 'Artist',
          duration: Duration(seconds: 90),
        ),
        endBehavior: EndBehavior.stop,
        narrationEnabled: true,
        gainDb: -3,
        fadeIn: Duration(milliseconds: 500),
        fadeOut: Duration(milliseconds: 750),
      );

      final json = moment.toJson();
      final restored = EventMoment.fromJson(json, imported: true);

      expect(json, {
        'id': 'a',
        'position': 3,
        'name': 'Entrada',
        'audio': moment.audio!.toJson(),
        'endBehavior': 'stop',
        'narrationEnabled': true,
        'gainDb': -3.0,
        'fadeInMs': 500,
        'fadeOutMs': 750,
      });
      expect(restored.audio!.pending, isTrue);
      expect(restored.endBehavior, EndBehavior.stop);
      expect(restored.fadeIn, const Duration(milliseconds: 500));
      expect(restored.fadeOut, const Duration(milliseconds: 750));
      expect(restored.audioPending, isTrue);
    });
  });

  group('SoundTrackEvent', () {
    test('create uses defaults, UTC timestamps, and an immutable list', () {
      final event = SoundTrackEvent.create(id: 'event-1', name: 'Formatura');

      expect(event.id, 'event-1');
      expect(event.name, 'Formatura');
      expect(event.createdAt.isUtc, isTrue);
      expect(event.updatedAt.isUtc, isTrue);
      expect(event.moments, isEmpty);
      expect(
        () => event.moments.add(
          EventMoment.create(id: 'a', position: 0, name: 'Entrada'),
        ),
        throwsUnsupportedError,
      );
    });

    test('add, update, and remove maintain aggregate invariants', () {
      final event = SoundTrackEvent.create(id: 'event-1', name: 'Formatura')
          .addMoment(EventMoment.create(id: 'a', position: 9, name: 'Recepção'))
          .addMoment(EventMoment.create(id: 'b', position: 9, name: 'Entrada'));

      expect(event.moments.map((moment) => moment.position), [0, 1]);

      final updated = event.updateMoment(
        event.moments.first.copyWith(name: 'Boas-vindas'),
      );
      expect(updated.moments.first.name, 'Boas-vindas');
      expect(updated.updatedAt.isBefore(event.updatedAt), isFalse);
      expect(
        () => event.updateMoment(
          EventMoment.create(id: 'missing', position: 0, name: 'Ausente'),
        ),
        throwsStateError,
      );

      final removed = updated.removeMoment('a');
      expect(removed.moments.map((moment) => moment.id), ['b']);
      expect(removed.moments.single.position, 0);
      expect(removed.updatedAt.isBefore(updated.updatedAt), isFalse);
    });

    test('reorder rewrites contiguous positions', () {
      final event = SoundTrackEvent.create(id: 'event-1', name: 'Formatura')
          .addMoment(EventMoment.create(id: 'a', position: 0, name: 'Recepção'))
          .addMoment(EventMoment.create(id: 'b', position: 1, name: 'Entrada'));
      final reordered = event.reorderMoment(oldIndex: 0, newIndex: 2);
      expect(reordered.moments.map((m) => m.id), ['b', 'a']);
      expect(reordered.moments.map((m) => m.position), [0, 1]);
    });

    test('JSON restores UTC dates, settings, moments, and replacement id', () {
      final source = SoundTrackEvent.create(id: 'old', name: 'Formatura')
          .addMoment(
            const EventMoment(
              id: 'a',
              position: 0,
              name: 'Entrada',
              audio: AudioReference(
                uri: 'content://song',
                displayName: 'Song',
                pending: false,
                artist: null,
                duration: null,
              ),
              endBehavior: EndBehavior.stop,
              narrationEnabled: true,
              gainDb: 1,
              fadeIn: null,
              fadeOut: null,
            ),
          );

      final restored = SoundTrackEvent.fromJson(
        source.toJson(),
        imported: true,
        replacementId: 'new',
      );

      expect(restored.id, 'new');
      expect(restored.name, source.name);
      expect(restored.createdAt.isUtc, isTrue);
      expect(restored.updatedAt.isUtc, isTrue);
      expect(restored.settings, source.settings);
      expect(restored.moments.single.audio!.pending, isTrue);
    });

    test('copyWith preserves createdAt and replaces supported fields', () {
      final source = SoundTrackEvent.create(id: 'old', name: 'Formatura');
      final updatedAt = DateTime.utc(2026, 6, 29);
      final copy = source.copyWith(
        id: 'new',
        name: 'Casamento',
        updatedAt: updatedAt,
        settings: source.settings.copyWith(masterVolume: 0.5),
        moments: [EventMoment.create(id: 'a', position: 0, name: 'Entrada')],
      );

      expect(copy.id, 'new');
      expect(copy.name, 'Casamento');
      expect(copy.createdAt, source.createdAt);
      expect(copy.updatedAt, updatedAt);
      expect(copy.settings.masterVolume, 0.5);
      expect(copy.moments.single.id, 'a');
    });
  });

  group('validateEvent', () {
    test('reports event and moment issues with prescribed messages', () {
      final empty = SoundTrackEvent.create(id: 'e1', name: '  ');
      expect(validateEvent(empty).map((issue) => (issue.code, issue.message)), [
        (EventIssueCode.emptyName, 'Informe o nome do evento.'),
        (EventIssueCode.noMoments, 'Adicione pelo menos um momento.'),
      ]);

      final withAudioIssues = SoundTrackEvent.create(id: 'e2', name: 'Evento')
          .addMoment(
            EventMoment.create(id: 'missing', position: 0, name: 'Entrada'),
          )
          .addMoment(
            EventMoment.create(
              id: 'pending',
              position: 1,
              name: 'Saída',
            ).copyWith(
              audio: const AudioReference(
                uri: null,
                displayName: 'Song',
                pending: true,
                artist: null,
                duration: null,
              ),
            ),
          );

      final issues = validateEvent(withAudioIssues);
      expect(issues.map((issue) => issue.code), [
        EventIssueCode.missingAudio,
        EventIssueCode.pendingAudio,
      ]);
      expect(issues.map((issue) => issue.message), [
        'Entrada: escolha uma música.',
        'Saída: religue o áudio pendente.',
      ]);
      expect(issues.map((issue) => issue.momentId), ['missing', 'pending']);
    });
  });
}
