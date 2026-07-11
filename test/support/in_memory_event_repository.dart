import 'package:soundtrack/features/events/data/event_repository.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';

class InMemoryEventRepository implements EventRepository {
  InMemoryEventRepository([Iterable<SoundTrackEvent> initialEvents = const []])
    : _events = {for (final event in initialEvents) event.id: event};

  final Map<String, SoundTrackEvent> _events;

  Object? findAllError;
  Object? findByIdError;
  Object? saveError;
  Object? deleteError;

  @override
  Future<void> delete(String id) async {
    final error = deleteError;
    if (error != null) {
      throw error;
    }
    _events.remove(id);
  }

  @override
  Future<List<SoundTrackEvent>> findAll() async {
    final error = findAllError;
    if (error != null) {
      throw error;
    }
    return List.unmodifiable(_events.values);
  }

  @override
  Future<SoundTrackEvent?> findById(String id) async {
    final error = findByIdError;
    if (error != null) {
      throw error;
    }
    return _events[id];
  }

  @override
  Future<void> save(SoundTrackEvent event) async {
    final error = saveError;
    if (error != null) {
      throw error;
    }
    _events[event.id] = event;
  }
}
