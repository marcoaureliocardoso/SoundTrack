import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';

void main() {
  test('imports a non-portable source as pending', () {
    final source = AudioReference.fromJson({
      'uri': 'content://provider/audio/1',
      'displayName': 'entrada.mp3',
      'artist': 'Artista',
      'durationMs': 120000,
      'portable': false,
    }, imported: true);

    expect(source.pending, isTrue);
    expect(source.displayName, 'entrada.mp3');
  });

  test('marks a source without uri as pending', () {
    final source = AudioReference.fromJson({
      'displayName': 'ausente.mp3',
      'artist': null,
      'durationMs': null,
      'portable': false,
    });

    expect(source.pending, isTrue);
  });

  test('marks a source with an empty uri as pending', () {
    final source = AudioReference.fromJson({
      'uri': '',
      'displayName': 'ausente.mp3',
      'artist': null,
      'durationMs': null,
      'portable': false,
    });

    expect(source.pending, isTrue);
  });

  test('rejects a non-pending source without a uri', () {
    expect(
      () => AudioReference(
        uri: null,
        displayName: 'invalida.mp3',
        pending: false,
        artist: null,
        duration: null,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('relinks a pending source and serializes metadata', () {
    const source = AudioReference(
      uri: null,
      displayName: 'ausente.mp3',
      pending: true,
      artist: null,
      duration: null,
    );

    final relinked = source.relink(
      uri: 'content://provider/audio/2',
      displayName: 'reencontrada.mp3',
      artist: 'Artista',
      duration: const Duration(seconds: 42),
    );

    expect(relinked.pending, isFalse);
    expect(relinked.toJson(), {
      'uri': 'content://provider/audio/2',
      'displayName': 'reencontrada.mp3',
      'artist': 'Artista',
      'durationMs': 42000,
      'portable': false,
    });
  });

  test('rejects relinking with an empty uri', () {
    const source = AudioReference(
      uri: null,
      displayName: 'ausente.mp3',
      pending: true,
      artist: null,
      duration: null,
    );

    expect(
      () => source.relink(uri: '', displayName: 'ausente.mp3'),
      throwsArgumentError,
    );
  });

  test('marks a reference pending without changing its metadata', () {
    const source = AudioReference(
      uri: 'content://provider/audio/3',
      displayName: 'entrada.mp3',
      pending: false,
      artist: 'Artista',
      duration: Duration(seconds: 90),
    );

    final pending = source.markPending();

    expect(pending, isNot(same(source)));
    expect(pending.pending, isTrue);
    expect(pending.uri, source.uri);
    expect(pending.displayName, source.displayName);
    expect(pending.artist, source.artist);
    expect(pending.duration, source.duration);
    expect(source.pending, isFalse);
  });

  test('round trips uri, artist, and duration through json', () {
    const original = AudioReference(
      uri: 'content://provider/audio/3',
      displayName: 'entrada.mp3',
      pending: false,
      artist: 'Artista',
      duration: Duration(seconds: 90),
    );

    final restored = AudioReference.fromJson(original.toJson());

    expect(restored.uri, original.uri);
    expect(restored.artist, original.artist);
    expect(restored.duration, original.duration);
    expect(restored.pending, isFalse);
  });
}
