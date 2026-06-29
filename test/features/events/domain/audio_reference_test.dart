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
      'uri': null,
      'displayName': 'ausente.mp3',
      'artist': null,
      'durationMs': null,
      'portable': false,
    });

    expect(source.pending, isTrue);
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
}
