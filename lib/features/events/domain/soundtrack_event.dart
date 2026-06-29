import 'event_audio_settings.dart';
import 'event_moment.dart';

class SoundTrackEvent {
  factory SoundTrackEvent({
    required String id,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    required EventAudioSettings settings,
    required List<EventMoment> moments,
  }) {
    return SoundTrackEvent._(
      List.unmodifiable(moments),
      id: id,
      name: name,
      createdAt: createdAt,
      updatedAt: updatedAt,
      settings: settings,
    );
  }

  const SoundTrackEvent._(
    this._moments, {
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.settings,
  });

  factory SoundTrackEvent.create({required String id, required String name}) {
    final now = DateTime.now().toUtc();
    return SoundTrackEvent(
      id: id,
      name: name,
      createdAt: now,
      updatedAt: now,
      settings: const EventAudioSettings.defaults(),
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
      settings: EventAudioSettings.fromJson(
        Map<String, Object?>.from(json['settings'] as Map),
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
  final EventAudioSettings settings;
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
    final remaining = _moments
        .where((moment) => moment.id != momentId)
        .toList();
    return copyWith(
      updatedAt: DateTime.now().toUtc(),
      moments: _withContiguousPositions(remaining),
    );
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
    return copyWith(
      updatedAt: DateTime.now().toUtc(),
      moments: _withContiguousPositions(reordered),
    );
  }

  SoundTrackEvent copyWith({
    String? id,
    String? name,
    DateTime? updatedAt,
    EventAudioSettings? settings,
    List<EventMoment>? moments,
  }) {
    return SoundTrackEvent(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      settings: settings ?? this.settings,
      moments: moments ?? _moments,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'settings': settings.toJson(),
      'moments': _moments.map((moment) => moment.toJson()).toList(),
    };
  }

  static List<EventMoment> _withContiguousPositions(List<EventMoment> moments) {
    return [
      for (var index = 0; index < moments.length; index++)
        moments[index].copyWith(position: index),
    ];
  }
}
