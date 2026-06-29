import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/application/event_editor_controller.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_audio_settings.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/event_validation.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';

import '../../../support/in_memory_event_repository.dart';

void main() {
  group('EventEditorController', () {
    test('renames, adds a moment, and saves the edited aggregate', () async {
      final initial = SoundTrackEvent.create(id: 'e1', name: 'Antes');
      final repository = InMemoryEventRepository([initial]);
      final controller = EventEditorController(
        repository: repository,
        initial: initial,
        newId: () => 'moment-1',
      );

      controller.rename('Depois');
      controller.addMoment('Entrada');
      await controller.save();

      final persisted = await repository.findById('e1');
      expect(persisted!.name, 'Depois');
      expect(persisted.moments.single.name, 'Entrada');
      expect(controller.dirty, isFalse);
    });

    test('mutations replace draft, mark dirty, and notify', () {
      final initial = SoundTrackEvent.create(id: 'e1', name: 'Evento');
      final controller = EventEditorController(
        repository: InMemoryEventRepository(),
        initial: initial,
        newId: () => 'moment-1',
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.rename('Novo nome');

      expect(controller.draft, isNot(same(initial)));
      expect(controller.draft.name, 'Novo nome');
      expect(controller.dirty, isTrue);
      expect(notifications, 1);
    });

    test('recomputes validation after every relevant mutation', () {
      final initial = SoundTrackEvent.create(id: 'e1', name: '');
      final controller = EventEditorController(
        repository: InMemoryEventRepository(),
        initial: initial,
        newId: () => 'moment-1',
      );
      expect(controller.issues.map((issue) => issue.code), [
        EventIssueCode.emptyName,
        EventIssueCode.noMoments,
      ]);

      controller.rename('Evento');
      expect(controller.issues.map((issue) => issue.code), [
        EventIssueCode.noMoments,
      ]);

      controller.addMoment('Entrada');
      expect(controller.issues.map((issue) => issue.code), [
        EventIssueCode.missingAudio,
      ]);

      controller.updateMoment(
        controller.draft.moments.single.copyWith(
          audio: const AudioReference(
            uri: 'content://song',
            displayName: 'Song',
            pending: false,
            artist: null,
            duration: null,
          ),
        ),
      );
      expect(controller.issues, isEmpty);
    });

    test('updates settings and moments, removes, and reorders moments', () {
      var nextId = 0;
      final controller = EventEditorController(
        repository: InMemoryEventRepository(),
        initial: SoundTrackEvent.create(id: 'e1', name: 'Evento'),
        newId: () => 'moment-${++nextId}',
      );
      final settings = const EventAudioSettings.defaults().copyWith(
        masterVolume: 0.5,
      );

      controller.updateSettings(settings);
      controller.addMoment('Primeiro');
      controller.addMoment('Segundo');
      controller.updateMoment(
        controller.draft.moments.first.copyWith(name: 'Atualizado'),
      );
      controller.reorderMoment(0, 2);
      controller.removeMoment('moment-2');

      expect(controller.draft.audioSettings, settings);
      expect(controller.draft.moments.single.id, 'moment-1');
      expect(controller.draft.moments.single.name, 'Atualizado');
      expect(controller.draft.moments.single.position, 0);
    });

    test('save failure keeps dirty and propagates the error', () async {
      final error = StateError('save failed');
      final repository = InMemoryEventRepository()..saveError = error;
      final controller = EventEditorController(
        repository: repository,
        initial: SoundTrackEvent.create(id: 'e1', name: 'Evento'),
        newId: () => 'moment',
      );
      controller.rename('Editado');

      await expectLater(controller.save(), throwsA(same(error)));

      expect(controller.dirty, isTrue);
    });

    test('save notifies when dirty becomes false', () async {
      final controller = EventEditorController(
        repository: InMemoryEventRepository(),
        initial: SoundTrackEvent.create(id: 'e1', name: 'Evento'),
        newId: () => 'moment',
      );
      controller.rename('Editado');
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.save();

      expect(controller.dirty, isFalse);
      expect(notifications, 1);
    });

    test('issues cannot be mutated externally', () {
      final controller = EventEditorController(
        repository: InMemoryEventRepository(),
        initial: SoundTrackEvent.create(id: 'e1', name: 'Evento'),
        newId: () => 'moment',
      );

      expect(
        () => controller.issues.add(
          const EventIssue(code: EventIssueCode.emptyName, message: 'external'),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => controller.draft.moments.add(
          EventMoment.create(id: 'external', position: 0, name: 'External'),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
