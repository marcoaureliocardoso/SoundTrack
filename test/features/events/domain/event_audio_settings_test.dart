import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/event_audio_settings.dart';

void main() {
  test('uses approved defaults', () {
    const settings = EventAudioSettings.defaults();
    expect(settings.masterVolume, 0.80);
    expect(settings.musicVolume, 1.0);
    expect(settings.narrationVolume, 0.25);
    expect(settings.fadeIn, const Duration(seconds: 2));
    expect(settings.fadeOut, const Duration(seconds: 2));
  });

  test('round trips through json', () {
    const original = EventAudioSettings(
      masterVolume: 0.7,
      musicVolume: 0.9,
      narrationVolume: 0.2,
      fadeIn: Duration(milliseconds: 1200),
      fadeOut: Duration(milliseconds: 1700),
    );
    expect(EventAudioSettings.fromJson(original.toJson()), original);
  });

  test('copyWith clamps volume values', () {
    const settings = EventAudioSettings.defaults();

    final updated = settings.copyWith(
      masterVolume: -0.1,
      musicVolume: 1.2,
      narrationVolume: 0.4,
      fadeIn: const Duration(milliseconds: 500),
      fadeOut: const Duration(milliseconds: 750),
    );

    expect(updated.masterVolume, 0.0);
    expect(updated.musicVolume, 1.0);
    expect(updated.narrationVolume, 0.4);
    expect(updated.fadeIn, const Duration(milliseconds: 500));
    expect(updated.fadeOut, const Duration(milliseconds: 750));
  });

  test('clamps persisted volume values when reading json', () {
    final settings = EventAudioSettings.fromJson({
      'masterVolume': -0.2,
      'musicVolume': 1.4,
      'narrationVolume': 0.5,
      'fadeInMs': 1000,
      'fadeOutMs': 1500,
    });

    expect(settings.masterVolume, 0.0);
    expect(settings.musicVolume, 1.0);
    expect(settings.narrationVolume, 0.5);
  });

  test('rejects out-of-range volumes in the direct constructor', () {
    expect(
      () => EventAudioSettings(
        masterVolume: -0.1,
        musicVolume: 1.0,
        narrationVolume: 0.25,
        fadeIn: const Duration(seconds: 2),
        fadeOut: const Duration(seconds: 2),
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('implements value equality and coherent hashCode', () {
    const first = EventAudioSettings.defaults();
    const equal = EventAudioSettings.defaults();
    const different = EventAudioSettings(
      masterVolume: 0.7,
      musicVolume: 1.0,
      narrationVolume: 0.25,
      fadeIn: Duration(seconds: 2),
      fadeOut: Duration(seconds: 2),
    );

    expect(first, equal);
    expect(first.hashCode, equal.hashCode);
    expect(first, isNot(different));
  });
}
