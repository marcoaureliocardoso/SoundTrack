import 'package:flutter/foundation.dart';

import '../data/event_repository.dart';
import '../domain/soundtrack_event.dart';

class EventLibraryController extends ChangeNotifier {
  factory EventLibraryController({
    required EventRepository repository,
    required String Function() newId,
  }) {
    return EventLibraryController._(repository, newId);
  }

  EventLibraryController._(this._repository, this._newId);

  final EventRepository _repository;
  final String Function() _newId;

  List<SoundTrackEvent> _events = const [];
  bool _loading = false;
  Object? _error;

  List<SoundTrackEvent> get events => List.unmodifiable(_events);
  bool get loading => _loading;
  Object? get error => _error;

  Future<void> load() async {
    _beginOperation();
    try {
      _events = List.unmodifiable(await _repository.findAll());
      _error = null;
    } catch (error) {
      _error = error;
    } finally {
      _endOperation();
    }
  }

  Future<SoundTrackEvent> create(String name) {
    return _mutate(() async {
      final event = SoundTrackEvent.create(id: _newId(), name: name);
      await _repository.save(event);
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
      return duplicate;
    });
  }

  Future<void> rename(String id, String name) {
    return _mutate(() async {
      final event = await _repository.findById(id);
      if (event == null) {
        throw StateError('Event $id does not exist.');
      }
      await _repository.save(
        event.copyWith(name: name, updatedAt: DateTime.now().toUtc()),
      );
    });
  }

  Future<void> delete(String id) {
    return _mutate(() => _repository.delete(id));
  }

  Future<T> _mutate<T>(Future<T> Function() operation) async {
    _beginOperation();
    try {
      final result = await operation();
      _events = List.unmodifiable(await _repository.findAll());
      _error = null;
      return result;
    } catch (error) {
      _error = error;
      rethrow;
    } finally {
      _endOperation();
    }
  }

  void _beginOperation() {
    _loading = true;
    _error = null;
    notifyListeners();
  }

  void _endOperation() {
    _loading = false;
    notifyListeners();
  }
}
