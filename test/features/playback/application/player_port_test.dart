import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/playback/application/player_port.dart';

void main() {
  test('play starts synchronously and errors are typed', () {
    final fake = _FakePlayerPort();
    final PlayerPort port = fake;
    final void Function() play = port.play;
    final Stream<PlayerPortError> errors = port.errors;

    play();

    expect(fake.started, isTrue);
    expect(errors, same(fake.errors));
  });

  test('PlayerPortError exposes a useful description and optional cause', () {
    final cause = StateError('decoder failed');
    final error = PlayerPortError('Unable to play source', cause: cause);
    const errorWithoutCause = PlayerPortError('Playback interrupted');

    expect(error.message, 'Unable to play source');
    expect(error.cause, same(cause));
    expect(error.toString(), contains('Unable to play source'));
    expect(error.toString(), contains('Bad state: decoder failed'));
    expect(errorWithoutCause.cause, isNull);
    expect(
      errorWithoutCause.toString(),
      'PlayerPortError: Playback interrupted',
    );
  });
}

final class _FakePlayerPort implements PlayerPort {
  bool started = false;

  @override
  final Stream<Duration> position = const Stream.empty();

  @override
  final Stream<Duration?> duration = const Stream.empty();

  @override
  final Stream<void> completed = const Stream.empty();

  @override
  final Stream<PlayerPortError> errors = const Stream.empty();

  @override
  Future<void> load(Uri source) async {}

  @override
  void play() {
    started = true;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setLooping(bool looping) async {}

  @override
  Future<void> dispose() async {}
}
