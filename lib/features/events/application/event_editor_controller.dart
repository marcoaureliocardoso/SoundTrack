import 'package:flutter/foundation.dart';

import '../data/event_repository.dart';
import '../domain/event_audio_settings.dart';
import '../domain/event_moment.dart';
import '../domain/event_validation.dart';
import '../domain/soundtrack_event.dart';

class EventEditorController extends ChangeNotifier {
  factory EventEditorController({
    required EventRepository repository,
    required SoundTrackEvent initial,
    required String Function() newId,
  }) {
    return EventEditorController._(
      repository,
      initial,
      newId,
      List.unmodifiable(validateEvent(initial)),
    );
  }

  EventEditorController._(
    this._repository,
    this._draft,
    this._newId,
    this._issues,
  );

  final EventRepository _repository;
  final String Function() _newId;

  SoundTrackEvent _draft;
  bool _dirty = false;
  List<EventIssue> _issues;
  int _revision = 0;
  bool _disposed = false;

  SoundTrackEvent get draft => _draft;
  bool get dirty => _dirty;
  List<EventIssue> get issues => List.unmodifiable(_issues);

  void rename(String name) {
    _replaceDraft(
      _draft.copyWith(name: name, updatedAt: DateTime.now().toUtc()),
    );
  }

  void updateSettings(EventAudioSettings audioSettings) {
    _replaceDraft(
      _draft.copyWith(
        audioSettings: audioSettings,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  void addMoment(String name) {
    _replaceDraft(
      _draft.addMoment(
        EventMoment.create(
          id: _newId(),
          position: _draft.moments.length,
          name: name,
        ),
      ),
    );
  }

  void updateMoment(EventMoment moment) {
    _replaceDraft(_draft.updateMoment(moment));
  }

  void removeMoment(String id) {
    _replaceDraft(_draft.removeMoment(id));
  }

  void reorderMoment(int oldIndex, int newIndex) {
    _replaceDraft(_draft.reorderMoment(oldIndex: oldIndex, newIndex: newIndex));
  }

  Future<void> save() async {
    final snapshot = _draft;
    final savedRevision = _revision;
    await _repository.save(snapshot);
    if (_disposed || savedRevision != _revision || !_dirty) {
      return;
    }
    _dirty = false;
    notifyListeners();
  }

  void _replaceDraft(SoundTrackEvent draft) {
    _draft = draft;
    _dirty = true;
    _revision++;
    _issues = List.unmodifiable(validateEvent(draft));
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
