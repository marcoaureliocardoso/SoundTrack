import '../domain/soundtrack_event.dart';

enum EventSortOrder { newest, oldest, nameAscending, nameDescending }

List<SoundTrackEvent> sortEvents(
  Iterable<SoundTrackEvent> source,
  EventSortOrder order,
) {
  int compareIds(SoundTrackEvent left, SoundTrackEvent right) =>
      left.id.compareTo(right.id);

  int compareNewest(SoundTrackEvent left, SoundTrackEvent right) {
    final updated = right.updatedAt.compareTo(left.updatedAt);
    return updated != 0 ? updated : compareIds(left, right);
  }

  int compareOldest(SoundTrackEvent left, SoundTrackEvent right) {
    final updated = left.updatedAt.compareTo(right.updatedAt);
    return updated != 0 ? updated : compareIds(left, right);
  }

  int compareName(
    SoundTrackEvent left,
    SoundTrackEvent right, {
    required bool descending,
  }) {
    final leftName = left.name.trim().toLowerCase();
    final rightName = right.name.trim().toLowerCase();
    final name = descending
        ? rightName.compareTo(leftName)
        : leftName.compareTo(rightName);
    return name != 0 ? name : compareNewest(left, right);
  }

  final events = source.toList()
    ..sort(switch (order) {
      EventSortOrder.newest => compareNewest,
      EventSortOrder.oldest => compareOldest,
      EventSortOrder.nameAscending => (left, right) => compareName(
        left,
        right,
        descending: false,
      ),
      EventSortOrder.nameDescending => (left, right) => compareName(
        left,
        right,
        descending: true,
      ),
    });
  return List.unmodifiable(events);
}
