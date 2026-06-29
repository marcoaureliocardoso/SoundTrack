import 'dart:convert';

import '../../events/domain/audio_reference.dart';
import '../../events/domain/event_export.dart';
import '../../events/domain/event_moment.dart';
import '../../events/domain/soundtrack_event.dart';
import '../../../platform/documents/document_gateway.dart';

enum EventImportException implements Exception {
  invalidJson,
  unsupportedFormat,
  unsupportedVersion,
}

class EventExportCodec {
  const EventExportCodec();

  String encode(SoundTrackEvent event, DateTime exportedAt) {
    return jsonEncode(
      EventExport.create(event: event, exportedAt: exportedAt).toJson(),
    );
  }

  Future<SoundTrackEvent> decode(
    String contents, {
    required String replacementId,
    required Future<bool> Function(String) canRead,
    required Future<AudioProbeResult> Function(String) probeAudio,
  }) async {
    final Map<String, Object?> root;
    try {
      final decoded = jsonDecode(contents);
      if (decoded is! Map) {
        throw const FormatException();
      }
      root = Map<String, Object?>.from(decoded);
    } catch (_) {
      throw EventImportException.invalidJson;
    }

    if (root['format'] != EventExport.format) {
      throw EventImportException.unsupportedFormat;
    }
    final schemaVersion = root['schemaVersion'];
    if (schemaVersion is! int) {
      throw EventImportException.invalidJson;
    }
    if (schemaVersion != EventExport.currentSchemaVersion) {
      throw EventImportException.unsupportedVersion;
    }

    final SoundTrackEvent imported;
    try {
      final audioSources = root['audioSources'];
      if (root['exportedAt'] is! String ||
          DateTime.tryParse(root['exportedAt']! as String) == null ||
          root['event'] is! Map ||
          audioSources is! List ||
          audioSources.any((source) => source is! Map)) {
        throw const FormatException();
      }
      imported = SoundTrackEvent.fromJson(
        Map<String, Object?>.from(root['event']! as Map),
        imported: true,
        replacementId: replacementId,
      );
    } catch (_) {
      throw EventImportException.invalidJson;
    }

    final moments = <EventMoment>[];
    for (final moment in imported.moments) {
      final audio = moment.audio;
      if (audio?.uri == null || audio!.uri!.isEmpty) {
        moments.add(moment);
        continue;
      }
      final uri = audio.uri!;
      if (!await canRead(uri)) {
        moments.add(moment);
        continue;
      }
      final probe = await probeAudio(uri);
      moments.add(
        probe.playable
            ? moment.copyWith(
                audio: AudioReference(
                  uri: uri,
                  displayName: audio.displayName,
                  pending: false,
                  artist: probe.artist ?? audio.artist,
                  duration: probe.duration ?? audio.duration,
                ),
              )
            : moment,
      );
    }
    return imported.copyWith(moments: moments);
  }
}
