import 'package:flutter/widgets.dart';

import '../application/event_editor_controller.dart';
import '../domain/soundtrack_event.dart';

typedef EventEditorControllerFactory =
    EventEditorController Function(SoundTrackEvent event);
typedef EventExportCallback = Future<bool> Function(SoundTrackEvent event);
typedef EventImportCallback = Future<SoundTrackEvent?> Function();
typedef EventLiveEntryPageBuilder = Widget Function(SoundTrackEvent event);
