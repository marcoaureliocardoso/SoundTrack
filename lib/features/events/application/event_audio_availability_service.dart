import '../../../platform/documents/document_gateway.dart';
import '../domain/audio_reference.dart';
import '../domain/event_moment.dart';
import '../domain/soundtrack_event.dart';

typedef CanReadAudio = Future<bool> Function(String uri);
typedef ProbeAudio = Future<AudioProbeResult> Function(String uri);

class EventAudioAvailabilityService {
  const EventAudioAvailabilityService({
    required this.canRead,
    required this.probeAudio,
  });

  final CanReadAudio canRead;
  final ProbeAudio probeAudio;

  Future<List<SoundTrackEvent>> revalidate(
    Iterable<SoundTrackEvent> events,
  ) async {
    final availabilityByUri = <String, Future<_AudioAvailability>>{};
    final revalidated = <SoundTrackEvent>[];

    for (final event in events) {
      revalidated.add(
        await _revalidateEvent(event, availabilityByUri: availabilityByUri),
      );
    }

    return List.unmodifiable(revalidated);
  }

  Future<SoundTrackEvent> _revalidateEvent(
    SoundTrackEvent event, {
    required Map<String, Future<_AudioAvailability>> availabilityByUri,
  }) async {
    var changed = false;
    final moments = <EventMoment>[];

    for (final moment in event.moments) {
      final audio = moment.audio;
      final uri = audio?.uri;
      if (audio == null || uri == null || uri.isEmpty) {
        moments.add(moment);
        continue;
      }

      final availability = await availabilityByUri.putIfAbsent(
        uri,
        () => _check(uri),
      );
      final revalidatedAudio = _apply(audio, availability);
      if (identical(revalidatedAudio, audio)) {
        moments.add(moment);
      } else {
        changed = true;
        moments.add(moment.copyWith(audio: revalidatedAudio));
      }
    }

    return changed ? event.copyWith(moments: moments) : event;
  }

  Future<_AudioAvailability> _check(String uri) async {
    try {
      if (!await canRead(uri)) {
        return const _AudioAvailability.unavailable();
      }
      final probe = await probeAudio(uri);
      return _AudioAvailability.available(probe);
    } catch (_) {
      return const _AudioAvailability.unknown();
    }
  }

  AudioReference _apply(AudioReference audio, _AudioAvailability availability) {
    if (!availability.known) {
      return audio;
    }
    final probe = availability.probe;
    if (probe == null || !probe.playable) {
      return audio.markPending();
    }

    final artist = probe.artist ?? audio.artist;
    final duration = probe.duration ?? audio.duration;
    if (!audio.pending &&
        artist == audio.artist &&
        duration == audio.duration) {
      return audio;
    }

    return audio.relink(
      uri: audio.uri!,
      displayName: audio.displayName,
      artist: artist,
      duration: duration,
    );
  }
}

class _AudioAvailability {
  const _AudioAvailability.available(this.probe) : known = true;

  const _AudioAvailability.unavailable() : known = true, probe = null;

  const _AudioAvailability.unknown() : known = false, probe = null;

  final bool known;
  final AudioProbeResult? probe;
}
