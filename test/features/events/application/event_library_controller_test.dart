import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/application/event_library_controller.dart';
import 'package:soundtrack/features/events/domain/event_audio_settings.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';

import '../../../support/in_memory_event_repository.dart';

void main() {
  group('EventLibraryController', () {
    test('loads, creates, duplicates, and deletes visible events', () async {
      final repository = InMemoryEventRepository();
      var nextId = 0;
      final controller = EventLibraryController(
        repository: repository,
        newId: () => 'event-${++nextId}',
      );

      await controller.load();
      final original = await controller.create('Casamento');
      await controller.duplicate(original.id);
      await controller.delete(original.id);

      expect(controller.events, hasLength(1));
      expect(controller.events.single.id, 'event-2');
      expect(controller.events.single.name, 'Casamento (cópia)');
      expect((await repository.findAll()).map((event) => event.id), [
        'event-2',
      ]);
    });

    test('load reports loading, notifies, and clears an old error', () async {
      final completer = Completer<List<SoundTrackEvent>>();
      final repository = _DelayedFindAllRepository(completer.future);
      final controller = EventLibraryController(
        repository: repository,
        newId: () => 'new',
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      final load = controller.load();

      expect(controller.loading, isTrue);
      expect(notifications, 1);
      completer.complete([]);
      await load;
      expect(controller.loading, isFalse);
      expect(controller.error, isNull);
      expect(notifications, 2);
    });

    test('load exposes repository errors without remaining loading', () async {
      final error = StateError('read failed');
      final repository = InMemoryEventRepository()..findAllError = error;
      final controller = EventLibraryController(
        repository: repository,
        newId: () => 'new',
      );

      await controller.load();

      expect(controller.loading, isFalse);
      expect(controller.error, same(error));
      expect(controller.events, isEmpty);
    });

    test('CRUD errors are exposed, notified, and rethrown', () async {
      final error = StateError('write failed');
      final repository = InMemoryEventRepository()..saveError = error;
      final controller = EventLibraryController(
        repository: repository,
        newId: () => 'new',
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      await expectLater(controller.create('Evento'), throwsA(same(error)));

      expect(controller.error, same(error));
      expect(controller.loading, isFalse);
      expect(notifications, greaterThan(0));
    });

    test(
      'duplicate copies settings and moments into a new aggregate',
      () async {
        final original = SoundTrackEvent.create(id: 'original', name: 'Festa')
            .copyWith(
              audioSettings: const EventAudioSettings.defaults().copyWith(
                masterVolume: 0.4,
              ),
              moments: [
                EventMoment.create(id: 'moment', position: 0, name: 'Entrada'),
              ],
            );
        final repository = InMemoryEventRepository([original]);
        final controller = EventLibraryController(
          repository: repository,
          newId: () => 'copy',
        );
        await controller.load();

        final duplicate = await controller.duplicate('original');

        expect(duplicate.id, 'copy');
        expect(duplicate.name, 'Festa (cópia)');
        expect(duplicate.audioSettings, original.audioSettings);
        expect(duplicate.moments.map((moment) => moment.id), ['moment']);
        expect(duplicate.moments, isNot(same(original.moments)));
        expect(duplicate.createdAt.isUtc, isTrue);
        expect(duplicate.updatedAt, duplicate.createdAt);
      },
    );

    test('duplicate fails explicitly when the event does not exist', () async {
      final controller = EventLibraryController(
        repository: InMemoryEventRepository(),
        newId: () => 'copy',
      );

      await expectLater(
        controller.duplicate('missing'),
        throwsA(isA<StateError>()),
      );
      expect(controller.error, isA<StateError>());
    });

    test('rename persists and refreshes the visible event', () async {
      final event = SoundTrackEvent.create(id: 'event', name: 'Antes');
      final repository = InMemoryEventRepository([event]);
      final controller = EventLibraryController(
        repository: repository,
        newId: () => 'unused',
      );
      await controller.load();

      await controller.rename('event', 'Depois');

      expect(controller.events.single.name, 'Depois');
      expect((await repository.findById('event'))!.name, 'Depois');
    });

    test('events cannot be mutated externally', () async {
      final controller = EventLibraryController(
        repository: InMemoryEventRepository(),
        newId: () => 'unused',
      );
      await controller.load();

      expect(
        () => controller.events.add(
          SoundTrackEvent.create(id: 'external', name: 'External'),
        ),
        throwsUnsupportedError,
      );
    });
  });
}

class _DelayedFindAllRepository extends InMemoryEventRepository {
  _DelayedFindAllRepository(this.result);

  final Future<List<SoundTrackEvent>> result;

  @override
  Future<List<SoundTrackEvent>> findAll() => result;
}
