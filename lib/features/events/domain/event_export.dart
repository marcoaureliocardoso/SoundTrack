import 'audio_reference.dart';
import 'soundtrack_event.dart';

class EventExport {
  const EventExport._({required this.event, required this.exportedAt});

  static const format = 'soundtrack-event';
  static const currentSchemaVersion = 1;

  final SoundTrackEvent event;
  final DateTime exportedAt;

  factory EventExport.create({
    required SoundTrackEvent event,
    required DateTime exportedAt,
  }) {
    return EventExport._(event: event, exportedAt: exportedAt.toUtc());
  }

  Map<String, Object?> toJson() {
    return {
      'format': format,
      'schemaVersion': currentSchemaVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'event': event.toJson(),
      'audioSources': _audioSources().map((audio) => audio.toJson()).toList(),
    };
  }

  Iterable<AudioReference> _audioSources() sync* {
    final seenUris = <String>{};
    for (final moment in event.moments) {
      final audio = moment.audio;
      final uri = audio?.uri;
      if (audio != null && uri != null && uri.isNotEmpty && seenUris.add(uri)) {
        yield audio;
      }
    }
  }
}
