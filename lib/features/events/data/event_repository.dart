import '../domain/soundtrack_event.dart';

abstract interface class EventRepository {
  Future<List<SoundTrackEvent>> findAll();

  Future<SoundTrackEvent?> findById(String id);

  Future<void> save(SoundTrackEvent event);

  Future<void> delete(String id);
}
