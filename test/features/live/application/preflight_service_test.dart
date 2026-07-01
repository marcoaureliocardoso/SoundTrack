import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_audio_settings.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/features/live/application/preflight_record_repository.dart';
import 'package:soundtrack/features/live/application/preflight_service.dart';
import 'package:soundtrack/features/live/domain/preflight_result.dart';
import 'package:soundtrack/platform/system/system_status_gateway.dart';

void main() {
  group('PreflightService', () {
    test(
      'returns preparable moments and system route for a ready event',
      () async {
        final records = _MemoryRecords();
        final event = _event([
          _moment('one', 'content://one'),
          _moment('two', 'content://two'),
        ]);
        final service = PreflightService(
          canRead: (_) async => true,
          canPrepare: (_) async => true,
          systemStatus: _SystemStatus(),
          records: records,
          clock: () => DateTime.utc(2026, 7, 1, 12),
        );

        final result = await service.check(event);

        expect(result.hasErrors, isFalse);
        expect(result.hasWarnings, isFalse);
        expect(result.readyMomentIds, {'one', 'two'});
        expect(
          result.items,
          contains(
            isA<PreflightItem>()
                .having((item) => item.code, 'code', PreflightCode.outputRoute)
                .having(
                  (item) => item.severity,
                  'severity',
                  PreflightSeverity.info,
                )
                .having(
                  (item) => item.message,
                  'message',
                  contains('Bluetooth'),
                ),
          ),
        );
        expect(records.saved.single.eventId, event.id);
        expect(records.saved.single.errorCount, 0);
        expect(records.saved.single.warningCount, 0);
        expect(records.saved.single.eventUpdatedAt, event.updatedAt);
      },
    );

    test('uses strict volume and battery warning thresholds', () async {
      Future<PreflightResult> check({
        required double volume,
        required int battery,
        required bool charging,
      }) {
        return PreflightService(
          canRead: (_) async => true,
          canPrepare: (_) async => true,
          systemStatus: _SystemStatus(
            volume: volume,
            battery: battery,
            isCharging: charging,
          ),
          records: _MemoryRecords(),
        ).check(_event([_moment('one', 'content://one')]));
      }

      final below = await check(volume: .299, battery: 19, charging: false);
      final boundary = await check(volume: .30, battery: 20, charging: false);
      final charging = await check(volume: 1, battery: 1, charging: true);

      expect(
        below.items.map((item) => item.code),
        containsAll([PreflightCode.lowSystemVolume, PreflightCode.lowBattery]),
      );
      expect(boundary.hasWarnings, isFalse);
      expect(charging.hasWarnings, isFalse);
    });

    test('warns for DND false and unknown but not true', () async {
      Future<PreflightResult> check(bool? dnd) => PreflightService(
        canRead: (_) async => true,
        canPrepare: (_) async => true,
        systemStatus: _SystemStatus(dnd: dnd),
        records: _MemoryRecords(),
      ).check(_event([_moment('one', 'content://one')]));

      expect(
        (await check(false)).items.map((item) => item.code),
        contains(PreflightCode.doNotDisturb),
      );
      expect(
        (await check(null)).items.map((item) => item.code),
        contains(PreflightCode.doNotDisturb),
      );
      expect(
        (await check(true)).items.map((item) => item.code),
        isNot(contains(PreflightCode.doNotDisturb)),
      );
    });

    test('reports every pending, unreadable and unpreparable moment', () async {
      final service = PreflightService(
        canRead: (uri) async => uri != 'content://unreadable',
        canPrepare: (uri) async => uri != 'content://broken',
        systemStatus: _SystemStatus(),
        records: _MemoryRecords(),
      );
      final event = _event([
        EventMoment.create(id: 'missing', position: 0, name: 'Missing'),
        _moment('pending', 'content://pending', pending: true),
        _moment('unreadable', 'content://unreadable'),
        _moment('broken', 'content://broken'),
        _moment('ready', 'content://ready'),
      ]);

      final result = await service.check(event);

      expect(
        result.items.where((item) => item.severity == PreflightSeverity.error),
        hasLength(4),
      );
      expect(
        result.items.map((item) => item.code),
        containsAll([
          PreflightCode.audioPending,
          PreflightCode.audioUnreadable,
          PreflightCode.audioUnpreparable,
        ]),
      );
      expect(result.readyMomentIds, {'ready'});
    });

    test(
      'attempts prepare after read failure and records both source errors',
      () async {
        final records = _MemoryRecords();
        var prepareCalls = 0;
        final service = PreflightService(
          canRead: (_) async => false,
          canPrepare: (_) async {
            prepareCalls++;
            throw StateError('prepare failed');
          },
          systemStatus: _SystemStatus(),
          records: records,
        );

        final result = await service.check(
          _event([_moment('broken', 'content://broken')]),
        );

        expect(prepareCalls, 1);
        expect(
          result.items
              .where((item) => item.momentId == 'broken')
              .map((item) => item.code),
          [PreflightCode.audioUnreadable, PreflightCode.audioUnpreparable],
        );
        expect(result.readyMomentIds, isNot(contains('broken')));
        expect(records.saved.single.errorCount, 2);
      },
    );

    test(
      'turns probe and gateway failures into items and continues checks',
      () async {
        final service = PreflightService(
          canRead: (uri) async {
            if (uri.endsWith('read-failure')) throw StateError('read failed');
            return true;
          },
          canPrepare: (uri) async {
            if (uri.endsWith('prepare-failure')) {
              throw StateError('prepare failed');
            }
            return true;
          },
          systemStatus: _ThrowingSystemStatus(),
          records: _MemoryRecords(),
        );

        final result = await service.check(
          _event([
            _moment('read-failure', 'content://read-failure'),
            _moment('prepare-failure', 'content://prepare-failure'),
            _moment('ready', 'content://ready'),
          ]),
        );

        expect(result.readyMomentIds, {'ready'});
        expect(
          result.items.where(
            (item) => item.severity == PreflightSeverity.error,
          ),
          hasLength(2),
        );
        expect(
          result.items.where(
            (item) => item.severity == PreflightSeverity.warning,
          ),
          hasLength(4),
        );
      },
    );

    test('does not mutate or save the event', () async {
      final records = _MemoryRecords();
      final event = _event([_moment('one', 'content://one')]);
      final before = event.toJson().toString();
      final service = PreflightService(
        canRead: (_) async => false,
        canPrepare: (_) async => false,
        systemStatus: _SystemStatus(),
        records: records,
      );

      await service.check(event);

      expect(event.toJson().toString(), before);
      expect(records.saved, hasLength(1));
    });

    test(
      'does not save a partial record when record persistence fails',
      () async {
        final records = _MemoryRecords()..saveError = StateError('disk full');
        final service = PreflightService(
          canRead: (_) async => true,
          canPrepare: (_) async => true,
          systemStatus: _SystemStatus(),
          records: records,
        );

        await expectLater(
          service.check(_event([_moment('one', 'content://one')])),
          throwsStateError,
        );
      },
    );
  });
}

SoundTrackEvent _event(List<EventMoment> moments) {
  return SoundTrackEvent(
    id: 'event',
    name: 'Evento',
    createdAt: DateTime.utc(2026, 6, 1),
    updatedAt: DateTime.utc(2026, 6, 30, 23),
    audioSettings: const EventAudioSettings.defaults(),
    moments: moments,
  );
}

EventMoment _moment(String id, String uri, {bool pending = false}) {
  return EventMoment.create(id: id, position: 0, name: id).copyWith(
    audio: AudioReference(
      uri: uri,
      displayName: '$id.mp3',
      pending: pending,
      artist: null,
      duration: null,
    ),
  );
}

class _MemoryRecords implements PreflightRecordRepository {
  final saved = <PreflightRecord>[];
  Object? saveError;

  @override
  Future<void> delete(String eventId) async {}

  @override
  Future<List<PreflightRecord>> findAll() async => List.unmodifiable(saved);

  @override
  Future<PreflightRecord?> findByEventId(String eventId) async {
    for (final record in saved.reversed) {
      if (record.eventId == eventId) return record;
    }
    return null;
  }

  @override
  Future<void> save(PreflightRecord record) async {
    if (saveError case final error?) throw error;
    saved.add(record);
  }
}

class _SystemStatus implements SystemStatusGateway {
  _SystemStatus({
    this.volume = 1,
    this.battery = 100,
    this.isCharging = true,
    this.dnd = true,
  });

  final double volume;
  final int battery;
  final bool isCharging;
  final bool? dnd;

  @override
  Future<int> batteryPercent() async => battery;

  @override
  Future<bool> charging() async => isCharging;

  @override
  Future<bool?> doNotDisturbEnabled() async => dnd;

  @override
  Future<double> mediaVolume() async => volume;

  @override
  Future<String> outputRouteLabel() async => 'Bluetooth';

  @override
  Future<void> setKeepScreenOn(bool enabled) async {}
}

class _ThrowingSystemStatus implements SystemStatusGateway {
  @override
  Future<int> batteryPercent() async => throw StateError('battery');

  @override
  Future<bool> charging() async => false;

  @override
  Future<bool?> doNotDisturbEnabled() async => throw StateError('dnd');

  @override
  Future<double> mediaVolume() async => throw StateError('volume');

  @override
  Future<String> outputRouteLabel() async => throw StateError('route');

  @override
  Future<void> setKeepScreenOn(bool enabled) async {}
}
