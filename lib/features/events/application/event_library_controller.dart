import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/event_repository.dart';
import '../domain/event_moment.dart';
import '../domain/soundtrack_event.dart';
import '../../live/application/preflight_record_repository.dart';

typedef RevalidateEventAudio =
    Future<List<SoundTrackEvent>> Function(List<SoundTrackEvent> events);

enum EventPreflightStatus { unchecked, ready, warnings, errors }

class EventLibraryController extends ChangeNotifier {
  factory EventLibraryController({
    required EventRepository repository,
    required String Function() newId,
    RevalidateEventAudio? revalidateAudio,
    PreflightRecordRepository? preflightRecords,
  }) {
    return EventLibraryController._(
      repository,
      newId,
      revalidateAudio ?? _identityRevalidation,
      preflightRecords,
    );
  }

  EventLibraryController._(
    this._repository,
    this._newId,
    this._revalidateAudio,
    this._preflightRecords,
  );

  final EventRepository _repository;
  final String Function() _newId;
  final RevalidateEventAudio _revalidateAudio;
  final PreflightRecordRepository? _preflightRecords;

  List<SoundTrackEvent> _events = const [];
  Map<String, PreflightRecord> _records = const {};
  bool _loading = false;
  Object? _error;
  Future<void> _operationQueue = Future.value();
  int _pendingOperations = 0;
  bool _disposed = false;

  List<SoundTrackEvent> get events => List.unmodifiable(_events);
  bool get loading => _loading;
  Object? get error => _error;

  EventPreflightStatus preflightStatusFor(SoundTrackEvent event) {
    final record = _records[event.id];
    if (record == null || record.isStaleFor(event.updatedAt)) {
      return EventPreflightStatus.unchecked;
    }
    if (record.errorCount > 0) return EventPreflightStatus.errors;
    if (record.warningCount > 0) return EventPreflightStatus.warnings;
    return EventPreflightStatus.ready;
  }

  Future<void> load() {
    return _enqueue(() async {
      try {
        final events = await _repository.findAll();
        final records = await _preflightRecords?.findAll();
        if (_disposed) {
          return;
        }
        final revalidated = await _revalidateAudio(events);
        if (_disposed) {
          return;
        }
        _events = _ordered(revalidated);
        _records = records == null
            ? const {}
            : Map.unmodifiable({
                for (final record in records) record.eventId: record,
              });
        _error = null;
      } catch (error) {
        if (!_disposed) {
          _error = error;
        }
      }
    });
  }

  Future<SoundTrackEvent> create(String name) {
    return _mutate(() async {
      final event = SoundTrackEvent.create(id: _newId(), name: name);
      await _repository.save(event);
      if (!_disposed) {
        _upsert(event);
      }
      return event;
    });
  }

  Future<SoundTrackEvent> duplicate(String id) {
    return _mutate(() async {
      final original = await _repository.findById(id);
      if (original == null) {
        throw StateError('Event $id does not exist.');
      }

      final duplicate =
          SoundTrackEvent.create(
            id: _newId(),
            name: '${original.name} (cópia)',
          ).copyWith(
            audioSettings: original.audioSettings,
            moments: [...original.moments],
          );
      await _repository.save(duplicate);
      final revalidated = await _revalidateOne(
        _overlayKnownAudio(duplicate, sourceEventId: original.id),
      );
      if (!_disposed) {
        _upsert(revalidated);
      }
      return revalidated;
    });
  }

  Future<void> rename(String id, String name) {
    return _mutate(() async {
      final event = await _repository.findById(id);
      if (event == null) {
        throw StateError('Event $id does not exist.');
      }
      final renamed = event.copyWith(
        name: name,
        updatedAt: DateTime.now().toUtc(),
      );
      await _repository.save(renamed);
      final revalidated = await _revalidateOne(
        _overlayKnownAudio(renamed, sourceEventId: event.id),
      );
      if (!_disposed) {
        _upsert(revalidated);
      }
    });
  }

  Future<void> delete(String id) {
    return _mutate(() async {
      await _preflightRecords?.delete(id);
      await _repository.delete(id);
      if (!_disposed) {
        _events = List.unmodifiable(_events.where((event) => event.id != id));
        _records = Map.unmodifiable({..._records}..remove(id));
      }
    });
  }

  Future<T> _mutate<T>(Future<T> Function() operation) {
    return _enqueue(() async {
      try {
        final result = await operation();
        if (!_disposed) {
          _error = null;
        }
        return result;
      } catch (error) {
        if (!_disposed) {
          _error = error;
        }
        rethrow;
      }
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _pendingOperations++;
    if (!_disposed) {
      _loading = true;
      _error = null;
      notifyListeners();
    }

    _operationQueue = _operationQueue.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      } finally {
        if (!_disposed) {
          _pendingOperations--;
          _loading = _pendingOperations > 0;
          notifyListeners();
        }
      }
    });

    return result.future;
  }

  void _upsert(SoundTrackEvent event) {
    _events = _ordered([
      ..._events.where((candidate) => candidate.id != event.id),
      event,
    ]);
  }

  Future<SoundTrackEvent> _revalidateOne(SoundTrackEvent event) async {
    return (await _revalidateAudio([event])).single;
  }

  SoundTrackEvent _overlayKnownAudio(
    SoundTrackEvent candidate, {
    required String sourceEventId,
  }) {
    SoundTrackEvent? source;
    for (final event in _events) {
      if (event.id == sourceEventId) {
        source = event;
        break;
      }
    }
    if (source == null) {
      return candidate;
    }

    var changed = false;
    final moments = <EventMoment>[];
    for (final moment in candidate.moments) {
      final candidateAudio = moment.audio;
      if (candidateAudio == null) {
        moments.add(moment);
        continue;
      }

      EventMoment? sourceMoment;
      for (final projectedMoment in source.moments) {
        if (projectedMoment.id == moment.id &&
            projectedMoment.audio?.uri == candidateAudio.uri) {
          sourceMoment = projectedMoment;
          break;
        }
      }
      final projectedAudio = sourceMoment?.audio;
      if (projectedAudio == null || identical(projectedAudio, candidateAudio)) {
        moments.add(moment);
        continue;
      }

      changed = true;
      moments.add(moment.copyWith(audio: projectedAudio));
    }

    return changed ? candidate.copyWith(moments: moments) : candidate;
  }

  List<SoundTrackEvent> _ordered(Iterable<SoundTrackEvent> events) {
    return List.unmodifiable(
      events.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

Future<List<SoundTrackEvent>> _identityRevalidation(
  List<SoundTrackEvent> events,
) async {
  return events;
}
