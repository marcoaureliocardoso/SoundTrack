import '../../events/domain/event_moment.dart';
import '../../events/domain/soundtrack_event.dart';
import '../../playback/domain/playback_alert.dart';
import '../../playback/domain/playback_snapshot.dart';

enum MomentStatus { ready, current, pending, error }

class LiveEventState {
  const LiveEventState({
    required this.event,
    required this.playback,
    required this.visibleAlert,
    required this.controlsExpanded,
  });

  final SoundTrackEvent event;
  final PlaybackSnapshot playback;
  final PlaybackAlert? visibleAlert;
  final bool controlsExpanded;

  EventMoment? get activeMoment => _momentById(playback.activeMomentId);

  bool get narrationAvailable => activeMoment?.narrationEnabled ?? false;

  String? get currentMomentName => activeMoment?.name;

  String? get currentAudioDisplayName => activeMoment?.audio?.displayName;

  String? get currentAudioArtist => activeMoment?.audio?.artist;

  Duration? get currentAudioDuration =>
      playback.duration ?? activeMoment?.audio?.duration;

  MomentStatus momentStatus(String momentId) {
    final moment = _momentById(momentId);
    if (moment == null) {
      return MomentStatus.error;
    }
    if (playback.activeMomentId == momentId) {
      return MomentStatus.current;
    }
    if (_isSourceFailureFor(momentId)) {
      return MomentStatus.error;
    }
    if (moment.audioPending) {
      return MomentStatus.pending;
    }
    return MomentStatus.ready;
  }

  LiveEventState copyWith({
    PlaybackSnapshot? playback,
    PlaybackAlert? visibleAlert,
    bool clearVisibleAlert = false,
    bool? controlsExpanded,
  }) {
    return LiveEventState(
      event: event,
      playback: playback ?? this.playback,
      visibleAlert: clearVisibleAlert
          ? null
          : visibleAlert ?? this.visibleAlert,
      controlsExpanded: controlsExpanded ?? this.controlsExpanded,
    );
  }

  EventMoment? _momentById(String? momentId) {
    if (momentId == null) {
      return null;
    }
    for (final moment in event.moments) {
      if (moment.id == momentId) {
        return moment;
      }
    }
    return null;
  }

  bool _isSourceFailureFor(String momentId) {
    final alert = visibleAlert;
    return alert?.momentId == momentId &&
        (alert?.code == PlaybackAlertCode.sourceUnavailable ||
            alert?.code == PlaybackAlertCode.sourceFailed);
  }
}
