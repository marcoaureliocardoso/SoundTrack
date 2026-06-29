import 'event_audio_settings.dart';
import 'event_moment.dart';

class SoundTrackEvent {
  factory SoundTrackEvent({
    required String id,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    required EventAudioSettings audioSettings,
    required List<EventMoment> moments,
  }) {
    final normalizedMoments = <EventMoment>[];
    final momentIds = <String>{};
    for (final moment in moments) {
      if (!momentIds.add(moment.id)) {
        throw ArgumentError('Duplicate moment id: ${moment.id}.');
      }
      normalizedMoments.add(
        moment.copyWith(position: normalizedMoments.length),
      );
    }

    return SoundTrackEvent._(
      List.unmodifiable(normalizedMoments),
      id: id,
      name: name,
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
      audioSettings: audioSettings,
    );
  }

  const SoundTrackEvent._(
    this._moments, {
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.audioSettings,
  });

  factory SoundTrackEvent.create({required String id, required String name}) {
    final now = DateTime.now().toUtc();
    return SoundTrackEvent(
      id: id,
      name: name,
      createdAt: now,
      updatedAt: now,
      audioSettings: const EventAudioSettings.defaults(),
      moments: const [],
    );
  }

  factory SoundTrackEvent.fromJson(
    Map<String, Object?> json, {
    bool imported = false,
    String? replacementId,
  }) {
    final momentJson = json['moments'] as List<Object?>;
    return SoundTrackEvent(
      id: replacementId ?? json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      audioSettings: EventAudioSettings.fromJson(
        Map<String, Object?>.from(json['audioSettings'] as Map),
      ),
      moments: momentJson
          .map(
            (item) => EventMoment.fromJson(
              Map<String, Object?>.from(item! as Map),
              imported: imported,
            ),
          )
          .toList(),
    );
  }

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final EventAudioSettings audioSettings;
  final List<EventMoment> _moments;

  List<EventMoment> get moments => List.unmodifiable(_moments);

  SoundTrackEvent addMoment(EventMoment moment) {
    return copyWith(
      updatedAt: DateTime.now().toUtc(),
      moments: [
        ..._moments,
        moment.copyWith(position: _moments.length),
      ],
    );
  }

  SoundTrackEvent updateMoment(EventMoment moment) {
    final index = _moments.indexWhere((candidate) => candidate.id == moment.id);
    if (index == -1) {
      throw StateError('Moment ${moment.id} does not belong to event $id.');
    }

    final updatedMoments = [..._moments];
    updatedMoments[index] = moment.copyWith(position: index);
    return copyWith(updatedAt: DateTime.now().toUtc(), moments: updatedMoments);
  }

  SoundTrackEvent removeMoment(String momentId) {
    final index = _moments.indexWhere((moment) => moment.id == momentId);
    if (index == -1) {
      throw StateError('Moment $momentId does not belong to event $id.');
    }

    final remaining = [..._moments]..removeAt(index);
    return copyWith(updatedAt: DateTime.now().toUtc(), moments: remaining);
  }

  SoundTrackEvent reorderMoment({
    required int oldIndex,
    required int newIndex,
  }) {
    final reordered = [..._moments];
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final moment = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moment);
    return copyWith(updatedAt: DateTime.now().toUtc(), moments: reordered);
  }

  SoundTrackEvent copyWith({
    String? id,
    String? name,
    DateTime? updatedAt,
    EventAudioSettings? audioSettings,
    List<EventMoment>? moments,
  }) {
    return SoundTrackEvent(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      audioSettings: audioSettings ?? this.audioSettings,
      moments: moments ?? _moments,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'audioSettings': audioSettings.toJson(),
      'moments': _moments.map((moment) => moment.toJson()).toList(),
    };
  }
}
