import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/application/event_audio_availability_service.dart';
import 'package:soundtrack/features/events/application/event_library_controller.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_audio_settings.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/features/live/application/preflight_record_repository.dart';

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

    test(
      'load exposes but does not persist an event changed by revalidation',
      () async {
        final event = SoundTrackEvent.create(id: 'event', name: 'Evento')
            .copyWith(
              moments: [
                EventMoment.create(
                  id: 'moment',
                  position: 0,
                  name: 'Entrada',
                ).copyWith(
                  audio: const AudioReference(
                    uri: 'content://audio/entry',
                    displayName: 'entrada.ogg',
                    pending: false,
                    artist: null,
                    duration: null,
                  ),
                ),
              ],
            );
        final repository = _CountingSaveRepository([event]);
        final controller = EventLibraryController(
          repository: repository,
          newId: () => 'new',
          revalidateAudio: (events) async => [
            events.single.copyWith(
              moments: [
                events.single.moments.single.copyWith(
                  audio: events.single.moments.single.audio!.markPending(),
                ),
              ],
            ),
          ],
        );

        await controller.load();

        expect(controller.events.single.moments.single.audio!.pending, isTrue);
        expect(
          (await repository.findById('event'))!.moments.single.audio!.pending,
          isFalse,
        );
        expect(repository.saveCalls, 0);
      },
    );

    test('load does not save events unchanged by revalidation', () async {
      final event = SoundTrackEvent.create(id: 'event', name: 'Evento');
      final repository = _CountingSaveRepository([event]);
      final controller = EventLibraryController(
        repository: repository,
        newId: () => 'new',
        revalidateAudio: (events) async => events,
      );

      await controller.load();

      expect(controller.events.single, same(event));
      expect(repository.saveCalls, 0);
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

    test(
      'rename retains pending audio when the next readability check throws',
      () async {
        final event = _eventWithAudio();
        final repository = InMemoryEventRepository([event]);
        var canReadCalls = 0;
        final availability = EventAudioAvailabilityService(
          canRead: (_) async {
            canReadCalls++;
            if (canReadCalls == 1) {
              return false;
            }
            throw StateError('transient read failure');
          },
          probeAudio: (_) async => throw StateError('must not probe'),
        );
        final controller = EventLibraryController(
          repository: repository,
          newId: () => 'unused',
          revalidateAudio: availability.revalidate,
        );

        await controller.load();
        await controller.rename('event', 'Depois');

        expect(controller.events.single.name, 'Depois');
        expect(controller.events.single.moments.single.audio!.pending, isTrue);
        final persisted = await repository.findById('event');
        expect(persisted!.name, 'Depois');
        expect(persisted.moments.single.audio!.pending, isFalse);
        expect(canReadCalls, 2);
      },
    );

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

    test(
      'serializes operations, keeps loading, and continues after an error',
      () async {
        final error = StateError('first failed');
        final repository = _SequencedSaveRepository();
        var nextId = 0;
        final controller = EventLibraryController(
          repository: repository,
          newId: () => 'event-${++nextId}',
        );

        final first = controller.create('Primeiro');
        final second = controller.create('Segundo');
        await repository.firstSaveStarted.future;

        expect(repository.saveCalls, 1);
        expect(controller.loading, isTrue);

        repository.firstSaveGate.completeError(error);
        await expectLater(first, throwsA(same(error)));
        await repository.secondSaveStarted.future;

        expect(controller.loading, isTrue);
        repository.secondSaveGate.complete();
        final secondEvent = await second;

        expect(secondEvent.name, 'Segundo');
        expect(controller.events.map((event) => event.name), ['Segundo']);
        expect(controller.error, isNull);
        expect(controller.loading, isFalse);
      },
    );

    test('successful write does not depend on a subsequent refresh', () async {
      final repository = InMemoryEventRepository();
      final controller = EventLibraryController(
        repository: repository,
        newId: () => 'event',
      );
      await controller.load();
      repository.findAllError = StateError('refresh failed');

      final created = await controller.create('Evento');

      expect(created.id, 'event');
      expect(controller.events, [same(created)]);
      expect(controller.error, isNull);
    });

    test('dispose during load prevents post-await state changes', () async {
      final completer = Completer<List<SoundTrackEvent>>();
      final repository = _DelayedFindAllRepository(completer.future);
      final controller = EventLibraryController(
        repository: repository,
        newId: () => 'new',
      );

      final load = controller.load();
      controller.dispose();
      completer.complete([SoundTrackEvent.create(id: 'late', name: 'Late')]);
      await load;

      expect(controller.events, isEmpty);
    });

    test(
      'rename preserves repository changes newer than visible cache',
      () async {
        final original = SoundTrackEvent.create(id: 'event', name: 'Original')
            .addMoment(
              EventMoment.create(id: 'first', position: 0, name: 'Primeiro'),
            );
        final repository = InMemoryEventRepository([original]);
        final controller = EventLibraryController(
          repository: repository,
          newId: () => 'unused',
        );
        await controller.load();
        final externallyUpdated = original.copyWith(
          audioSettings: original.audioSettings.copyWith(masterVolume: 0.35),
          moments: [
            ...original.moments,
            EventMoment.create(id: 'second', position: 1, name: 'Segundo'),
          ],
        );
        await repository.save(externallyUpdated);

        await controller.rename('event', 'Renomeado');

        final persisted = await repository.findById('event');
        expect(persisted!.name, 'Renomeado');
        expect(persisted.audioSettings.masterVolume, 0.35);
        expect(persisted.moments.map((moment) => moment.id), [
          'first',
          'second',
        ]);
      },
    );

    test(
      'duplicate copies repository changes newer than visible cache',
      () async {
        final original = SoundTrackEvent.create(id: 'event', name: 'Original')
            .addMoment(
              EventMoment.create(id: 'first', position: 0, name: 'Primeiro'),
            );
        final repository = InMemoryEventRepository([original]);
        final controller = EventLibraryController(
          repository: repository,
          newId: () => 'copy',
        );
        await controller.load();
        final externallyUpdated = original.copyWith(
          audioSettings: original.audioSettings.copyWith(masterVolume: 0.35),
          moments: [
            ...original.moments,
            EventMoment.create(id: 'second', position: 1, name: 'Segundo'),
          ],
        );
        await repository.save(externallyUpdated);

        final duplicate = await controller.duplicate('event');

        expect(duplicate.audioSettings.masterVolume, 0.35);
        expect(duplicate.moments.map((moment) => moment.id), [
          'first',
          'second',
        ]);
      },
    );

    test(
      'duplicate retains pending audio when the next probe throws',
      () async {
        final original = _eventWithAudio();
        final repository = InMemoryEventRepository([original]);
        var canReadCalls = 0;
        var probeCalls = 0;
        final availability = EventAudioAvailabilityService(
          canRead: (_) async {
            canReadCalls++;
            return canReadCalls > 1;
          },
          probeAudio: (_) async {
            probeCalls++;
            throw StateError('transient probe failure');
          },
        );
        final controller = EventLibraryController(
          repository: repository,
          newId: () => 'copy',
          revalidateAudio: availability.revalidate,
        );

        await controller.load();
        final duplicate = await controller.duplicate('event');

        expect(duplicate.moments.single.audio!.pending, isTrue);
        expect(
          controller.events.every(
            (event) => event.moments.single.audio!.pending,
          ),
          isTrue,
        );
        expect(
          (await repository.findById('event'))!.moments.single.audio!.pending,
          isFalse,
        );
        expect(
          (await repository.findById('copy'))!.moments.single.audio!.pending,
          isFalse,
        );
        expect(canReadCalls, 2);
        expect(probeCalls, 1);
      },
    );

    test('loads current records and marks edited records unchecked', () async {
      final current = SoundTrackEvent.create(id: 'current', name: 'Current');
      final edited = SoundTrackEvent.create(id: 'edited', name: 'Edited');
      final records = _MemoryPreflightRecords([
        PreflightRecord(
          eventId: current.id,
          checkedAt: DateTime.utc(2026, 7, 1),
          eventUpdatedAt: current.updatedAt,
          sourceSignature: preflightSourceSignature(current),
          errorCount: 0,
          warningCount: 2,
        ),
        PreflightRecord(
          eventId: edited.id,
          checkedAt: DateTime.utc(2026, 7, 1),
          eventUpdatedAt: edited.updatedAt.subtract(const Duration(seconds: 1)),
          errorCount: 1,
          warningCount: 0,
        ),
      ]);
      final controller = EventLibraryController(
        repository: InMemoryEventRepository([current, edited]),
        newId: () => 'unused',
        preflightRecords: records,
      );

      await controller.load();

      expect(
        controller.preflightStatusFor(current),
        EventPreflightStatus.warnings,
      );
      expect(
        controller.preflightStatusFor(edited),
        EventPreflightStatus.unchecked,
      );
    });

    test('marks a record stale when revalidation changes availability', () async {
      final event = _eventWithAudio();
      final records = _MemoryPreflightRecords([
        PreflightRecord(
          eventId: event.id,
          checkedAt: DateTime.utc(2026, 7, 1),
          eventUpdatedAt: event.updatedAt,
          sourceSignature: preflightSourceSignature(event),
          errorCount: 0,
          warningCount: 0,
        ),
      ]);
      final controller = EventLibraryController(
        repository: InMemoryEventRepository([event]),
        newId: () => 'unused',
        preflightRecords: records,
        revalidateAudio: (events) async => [
          events.single.copyWith(
            moments: [
              events.single.moments.single.copyWith(
                audio: events.single.moments.single.audio!.markPending(),
              ),
            ],
          ),
        ],
      );

      await controller.load();

      expect(controller.events.single.moments.single.audio!.pending, isTrue);
      expect(
        controller.preflightStatusFor(controller.events.single),
        EventPreflightStatus.unchecked,
      );
    });

    test('deleting an event also deletes its preflight record', () async {
      final event = SoundTrackEvent.create(id: 'event', name: 'Event');
      final records = _MemoryPreflightRecords([
        PreflightRecord(
          eventId: event.id,
          checkedAt: DateTime.utc(2026, 7, 1),
          eventUpdatedAt: event.updatedAt,
          errorCount: 0,
          warningCount: 0,
        ),
      ]);
      final controller = EventLibraryController(
        repository: InMemoryEventRepository([event]),
        newId: () => 'unused',
        preflightRecords: records,
      );

      await controller.delete(event.id);

      expect(await records.findByEventId(event.id), isNull);
    });

    test('preflight load failure leaves events visible and unchecked', () async {
      final event = SoundTrackEvent.create(id: 'event', name: 'Event');
      final records = _MemoryPreflightRecords()
        ..findAllError = StateError('corrupt preflight records');
      final controller = EventLibraryController(
        repository: InMemoryEventRepository([event]),
        newId: () => 'unused',
        preflightRecords: records,
      );

      await controller.load();

      expect(controller.events, [same(event)]);
      expect(controller.error, isNull);
      expect(
        controller.preflightStatusFor(event),
        EventPreflightStatus.unchecked,
      );
    });

    test('event delete failure preserves its preflight record', () async {
      final event = SoundTrackEvent.create(id: 'event', name: 'Event');
      final repository = InMemoryEventRepository([event])
        ..deleteError = StateError('event delete failed');
      final records = _MemoryPreflightRecords([
        PreflightRecord(
          eventId: event.id,
          checkedAt: DateTime.utc(2026, 7, 1),
          eventUpdatedAt: event.updatedAt,
          errorCount: 0,
          warningCount: 0,
        ),
      ]);
      final controller = EventLibraryController(
        repository: repository,
        newId: () => 'unused',
        preflightRecords: records,
      );

      await expectLater(controller.delete(event.id), throwsStateError);

      expect(await records.findByEventId(event.id), isNotNull);
      expect(await repository.findById(event.id), same(event));
    });

    test('record delete failure does not resurrect a deleted event', () async {
      final event = SoundTrackEvent.create(id: 'event', name: 'Event');
      final repository = InMemoryEventRepository([event]);
      final records = _MemoryPreflightRecords([
        PreflightRecord(
          eventId: event.id,
          checkedAt: DateTime.utc(2026, 7, 1),
          eventUpdatedAt: event.updatedAt,
          errorCount: 0,
          warningCount: 0,
        ),
      ])..deleteError = StateError('record delete failed');
      final controller = EventLibraryController(
        repository: repository,
        newId: () => 'unused',
        preflightRecords: records,
      );
      await controller.load();

      await controller.delete(event.id);

      expect(controller.events, isEmpty);
      expect(await repository.findById(event.id), isNull);
      expect(controller.error, isNull);
    });
  });
}

SoundTrackEvent _eventWithAudio() {
  return SoundTrackEvent.create(id: 'event', name: 'Antes').copyWith(
    moments: [
      EventMoment.create(id: 'moment', position: 0, name: 'Entrada').copyWith(
        audio: const AudioReference(
          uri: 'content://audio/entry',
          displayName: 'entrada.ogg',
          pending: false,
          artist: null,
          duration: null,
        ),
      ),
    ],
  );
}

class _DelayedFindAllRepository extends InMemoryEventRepository {
  _DelayedFindAllRepository(this.result);

  final Future<List<SoundTrackEvent>> result;

  @override
  Future<List<SoundTrackEvent>> findAll() => result;
}

class _SequencedSaveRepository extends InMemoryEventRepository {
  final firstSaveStarted = Completer<void>();
  final secondSaveStarted = Completer<void>();
  final firstSaveGate = Completer<void>();
  final secondSaveGate = Completer<void>();
  int saveCalls = 0;

  @override
  Future<void> save(SoundTrackEvent event) async {
    saveCalls++;
    if (saveCalls == 1) {
      firstSaveStarted.complete();
      await firstSaveGate.future;
    } else {
      secondSaveStarted.complete();
      await secondSaveGate.future;
    }
    await super.save(event);
  }
}

class _CountingSaveRepository extends InMemoryEventRepository {
  _CountingSaveRepository(super.initialEvents);

  int saveCalls = 0;

  @override
  Future<void> save(SoundTrackEvent event) async {
    saveCalls++;
    await super.save(event);
  }
}

class _MemoryPreflightRecords implements PreflightRecordRepository {
  _MemoryPreflightRecords([Iterable<PreflightRecord> initial = const []])
    : _records = {for (final record in initial) record.eventId: record};

  final Map<String, PreflightRecord> _records;
  Object? findAllError;
  Object? deleteError;

  @override
  Future<void> delete(String eventId) async {
    if (deleteError case final error?) throw error;
    _records.remove(eventId);
  }

  @override
  Future<List<PreflightRecord>> findAll() async {
    if (findAllError case final error?) throw error;
    return List.unmodifiable(_records.values);
  }

  @override
  Future<PreflightRecord?> findByEventId(String eventId) async =>
      _records[eventId];

  @override
  Future<void> save(PreflightRecord record) async {
    _records[record.eventId] = record;
  }
}
