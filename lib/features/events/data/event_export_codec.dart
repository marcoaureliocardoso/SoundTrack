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

    final format = root['format'];
    if (format is! String) {
      throw EventImportException.invalidJson;
    }
    if (format != EventExport.format) {
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
    final Map<String, _CanonicalAudioSource> sources;
    try {
      final audioSources = root['audioSources'];
      if (root['exportedAt'] is! String ||
          DateTime.tryParse(root['exportedAt']! as String) == null ||
          root['event'] is! Map ||
          audioSources is! List ||
          audioSources.any((source) => !_validAudioSource(source))) {
        throw const FormatException();
      }
      sources = {};
      for (final value in audioSources) {
        final source = _CanonicalAudioSource.fromJson(
          Map<String, Object?>.from(value as Map),
        );
        if (sources.containsKey(source.uri)) throw const FormatException();
        sources[source.uri] = source;
      }
      imported = SoundTrackEvent.fromJson(
        Map<String, Object?>.from(root['event']! as Map),
        imported: true,
        replacementId: replacementId,
      );
      final referencedUris = <String>{};
      for (final moment in imported.moments) {
        final audio = moment.audio;
        final uri = audio?.uri;
        if (audio == null || uri == null || uri.isEmpty) continue;
        referencedUris.add(uri);
        final source = sources[uri];
        if (source == null || !source.matches(audio)) {
          throw const FormatException();
        }
      }
      if (referencedUris.length != sources.length) {
        throw const FormatException();
      }
    } catch (_) {
      throw EventImportException.invalidJson;
    }

    final resolved = <String, AudioReference?>{};
    for (final entry in sources.entries) {
      final source = entry.value;
      if (!await canRead(entry.key)) {
        resolved[entry.key] = null;
        continue;
      }
      final probe = await probeAudio(entry.key);
      resolved[entry.key] = probe.playable
          ? AudioReference(
              uri: entry.key,
              displayName: source.displayName,
              pending: false,
              artist: probe.artist ?? source.artist,
              duration: probe.duration ?? source.duration,
            )
          : null;
    }
    final moments = <EventMoment>[];
    for (final moment in imported.moments) {
      final audio = moment.audio;
      if (audio?.uri == null || audio!.uri!.isEmpty) {
        moments.add(moment);
        continue;
      }
      final canonical = resolved[audio.uri!];
      moments.add(
        canonical == null ? moment : moment.copyWith(audio: canonical),
      );
    }
    return imported.copyWith(moments: moments);
  }

  bool _validAudioSource(Object? value) {
    if (value is! Map) return false;
    try {
      final source = Map<String, Object?>.from(value);
      final uri = source['uri'];
      final displayName = source['displayName'];
      final artist = source['artist'];
      final durationMs = source['durationMs'];
      return uri is String &&
          uri.isNotEmpty &&
          displayName is String &&
          displayName.isNotEmpty &&
          source['portable'] == false &&
          (artist == null || artist is String) &&
          (durationMs == null || (durationMs is int && durationMs >= 0));
    } catch (_) {
      return false;
    }
  }
}

class _CanonicalAudioSource {
  const _CanonicalAudioSource({
    required this.uri,
    required this.displayName,
    required this.artist,
    required this.duration,
  });

  factory _CanonicalAudioSource.fromJson(Map<String, Object?> json) {
    return _CanonicalAudioSource(
      uri: json['uri']! as String,
      displayName: json['displayName']! as String,
      artist: json['artist'] as String?,
      duration: json['durationMs'] == null
          ? null
          : Duration(milliseconds: json['durationMs']! as int),
    );
  }

  final String uri;
  final String displayName;
  final String? artist;
  final Duration? duration;

  bool matches(AudioReference audio) {
    return audio.uri == uri &&
        audio.displayName == displayName &&
        audio.artist == artist &&
        audio.duration == duration;
  }
}
