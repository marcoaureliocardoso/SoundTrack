import 'audio_reference.dart';

enum EndBehavior { loop, stop }

class EventMoment {
  const EventMoment({
    required this.id,
    required this.position,
    required this.name,
    required this.audio,
    required this.endBehavior,
    required this.narrationEnabled,
    required this.gainDb,
    required this.fadeIn,
    required this.fadeOut,
  });

  factory EventMoment.create({
    required String id,
    required int position,
    required String name,
  }) {
    return EventMoment(
      id: id,
      position: position,
      name: name,
      audio: null,
      endBehavior: EndBehavior.loop,
      narrationEnabled: false,
      gainDb: 0,
      fadeIn: null,
      fadeOut: null,
    );
  }

  factory EventMoment.fromJson(
    Map<String, Object?> json, {
    bool imported = false,
  }) {
    final audioJson = json['audio'];
    final fadeInMs = json['fadeInMs'] as int?;
    final fadeOutMs = json['fadeOutMs'] as int?;

    return EventMoment(
      id: json['id'] as String,
      position: json['position'] as int,
      name: json['name'] as String,
      audio: audioJson == null
          ? null
          : AudioReference.fromJson(
              Map<String, Object?>.from(audioJson as Map),
              imported: imported,
            ),
      endBehavior: EndBehavior.values.byName(json['endBehavior'] as String),
      narrationEnabled: json['narrationEnabled'] as bool,
      gainDb: (json['gainDb'] as num).toDouble().clamp(-12.0, 6.0),
      fadeIn: fadeInMs == null ? null : Duration(milliseconds: fadeInMs),
      fadeOut: fadeOutMs == null ? null : Duration(milliseconds: fadeOutMs),
    );
  }

  final String id;
  final int position;
  final String name;
  final AudioReference? audio;
  final EndBehavior endBehavior;
  final bool narrationEnabled;
  final double gainDb;
  final Duration? fadeIn;
  final Duration? fadeOut;

  bool get audioPending => audio == null || audio!.pending;

  EventMoment copyWith({
    String? id,
    int? position,
    String? name,
    AudioReference? audio,
    bool clearAudio = false,
    EndBehavior? endBehavior,
    bool? narrationEnabled,
    double? gainDb,
    Duration? fadeIn,
    Duration? fadeOut,
  }) {
    return EventMoment(
      id: id ?? this.id,
      position: position ?? this.position,
      name: name ?? this.name,
      audio: clearAudio ? null : audio ?? this.audio,
      endBehavior: endBehavior ?? this.endBehavior,
      narrationEnabled: narrationEnabled ?? this.narrationEnabled,
      gainDb: (gainDb ?? this.gainDb).clamp(-12.0, 6.0),
      fadeIn: fadeIn ?? this.fadeIn,
      fadeOut: fadeOut ?? this.fadeOut,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'position': position,
      'name': name,
      'audio': audio?.toJson(),
      'endBehavior': endBehavior.name,
      'narrationEnabled': narrationEnabled,
      'gainDb': gainDb,
      'fadeInMs': fadeIn?.inMilliseconds,
      'fadeOutMs': fadeOut?.inMilliseconds,
    };
  }
}
