import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/features/events/presentation/event_sort_order.dart';

void main() {
  test('sorts by all four modes with deterministic tie breakers', () {
    final first = SoundTrackEvent.create(
      id: 'b',
      name: 'Álbum',
    ).copyWith(updatedAt: DateTime.utc(2026, 7, 14));
    final second = SoundTrackEvent.create(
      id: 'a',
      name: 'álbum',
    ).copyWith(updatedAt: DateTime.utc(2026, 7, 15));
    final third = SoundTrackEvent.create(
      id: 'c',
      name: 'Baile',
    ).copyWith(updatedAt: DateTime.utc(2026, 7, 13));

    expect(sortEvents([first, second, third], EventSortOrder.newest), [
      second,
      first,
      third,
    ]);
    expect(sortEvents([first, second, third], EventSortOrder.oldest), [
      third,
      first,
      second,
    ]);
    expect(sortEvents([first, second, third], EventSortOrder.nameAscending), [
      third,
      second,
      first,
    ]);
    expect(sortEvents([first, second, third], EventSortOrder.nameDescending), [
      second,
      first,
      third,
    ]);
  });

  test('does not mutate repository order and resolves equal dates by id', () {
    final first = SoundTrackEvent.create(
      id: 'b',
      name: 'Segundo',
    ).copyWith(updatedAt: DateTime.utc(2026, 7, 15));
    final second = SoundTrackEvent.create(
      id: 'a',
      name: 'Primeiro',
    ).copyWith(updatedAt: DateTime.utc(2026, 7, 15));
    final source = [first, second];

    expect(sortEvents(source, EventSortOrder.newest), [second, first]);
    expect(sortEvents(source, EventSortOrder.oldest), [second, first]);
    expect(source, [first, second]);
  });
}
