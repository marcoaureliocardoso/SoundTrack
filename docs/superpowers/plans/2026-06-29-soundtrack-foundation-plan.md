# SoundTrack Foundation, Event Editing, Import and Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Criar o aplicativo Flutter Android com catálogo, editor, persistência local, seleção de músicas, exportação JSON, importação e religamento de áudios pendentes.

**Architecture:** Entidades imutáveis vivem em `lib/features/events/domain`; persistência e documentos são acessados por portas; controladores `ChangeNotifier` coordenam casos de uso; telas dependem apenas desses contratos. O repositório salva um único envelope JSON por escrita atômica e nunca persiste estado transitório do Modo Evento.

**Tech Stack:** Flutter 3.44.2, Dart 3.12.2, Kotlin, `path_provider`, `uuid`, Flutter Test e Integration Test.

---

## File map

### Application shell

- `lib/main.dart`: inicialização e montagem das dependências.
- `lib/app/soundtrack_app.dart`: `MaterialApp`, tema e rotas.
- `lib/app/app_dependencies.dart`: composição explícita das implementações.

### Event domain

- `lib/features/events/domain/audio_reference.dart`: URI local, metadados e estado pendente.
- `lib/features/events/domain/event_audio_settings.dart`: volumes e fades globais.
- `lib/features/events/domain/event_moment.dart`: configuração de um momento.
- `lib/features/events/domain/soundtrack_event.dart`: agregado do evento.
- `lib/features/events/domain/event_export.dart`: envelope versionado `.soundtrack.json`.
- `lib/features/events/domain/event_validation.dart`: problemas de preparação sem dependências de UI.

### Data and platform

- `lib/features/events/data/event_repository.dart`: contrato do repositório.
- `lib/features/events/data/json_file_event_repository.dart`: persistência atômica.
- `lib/features/events/data/event_export_codec.dart`: serialização, validação e migração de importação.
- `lib/platform/documents/document_gateway.dart`: contrato para escolher/criar documentos.
- `lib/platform/documents/method_channel_document_gateway.dart`: cliente Dart do canal Android.
- `android/app/src/main/kotlin/com/soundtrack/soundtrack/MainActivity.kt`: registro do canal.
- `android/app/src/main/kotlin/com/soundtrack/soundtrack/DocumentChannel.kt`: SAF e metadados.

### Presentation

- `lib/features/events/application/event_library_controller.dart`: catálogo e CRUD.
- `lib/features/events/application/event_editor_controller.dart`: rascunho, reordenação e validação.
- `lib/features/events/application/event_transfer_controller.dart`: exportação, importação e religamento.
- `lib/features/events/presentation/event_library_page.dart`: Meus Eventos.
- `lib/features/events/presentation/event_editor_page.dart`: preparação.
- `lib/features/events/presentation/moment_editor_sheet.dart`: edição focal de um momento.
- `lib/features/events/presentation/audio_relink_page.dart`: áudios pendentes.
- `lib/features/events/presentation/widgets/event_card.dart`: resumo e menu.
- `lib/features/events/presentation/widgets/moment_tile.dart`: momento reordenável.

### Tests

- `test/features/events/domain/`: modelos e regras puras.
- `test/features/events/data/`: repositório e codec.
- `test/features/events/application/`: controladores com fakes.
- `test/features/events/presentation/`: widgets.
- `integration_test/event_authoring_flow_test.dart`: fluxo completo sem reprodução.

### Task 1: Scaffold Flutter and application shell

**Files:**
- Create through Flutter: `pubspec.yaml`, `android/`, `lib/main.dart`, `test/widget_test.dart`
- Create: `lib/app/soundtrack_app.dart`
- Create: `lib/app/app_dependencies.dart`
- Modify: `lib/main.dart`
- Test: `test/app/soundtrack_app_test.dart`

- [ ] **Step 1: Create the Flutter project and add foundation dependencies**

Run:

```powershell
flutter create --platforms=android --org com.soundtrack --project-name soundtrack .
flutter pub add path_provider uuid
```

Expected: Flutter reports project creation, `pubspec.yaml` contains `path_provider` and `uuid`, and the existing `docs/` directory remains intact.

- [ ] **Step 2: Replace the generated smoke test with a failing app-shell test**

Create `test/app/soundtrack_app_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/app/soundtrack_app.dart';

void main() {
  testWidgets('opens the event library', (tester) async {
    await tester.pumpWidget(const SoundTrackApp());

    expect(find.text('SoundTrack'), findsOneWidget);
    expect(find.text('Meus Eventos'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
```

Delete `test/widget_test.dart`.

- [ ] **Step 3: Run the test to verify it fails**

Run:

```powershell
flutter test test/app/soundtrack_app_test.dart
```

Expected: FAIL because `SoundTrackApp` does not exist.

- [ ] **Step 4: Add the minimal app shell**

Create `lib/app/soundtrack_app.dart`:

```dart
import 'package:flutter/material.dart';

class SoundTrackApp extends StatelessWidget {
  const SoundTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoundTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('SoundTrack')),
        body: const Center(child: Text('Meus Eventos')),
        floatingActionButton: FloatingActionButton(
          onPressed: null,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
```

Replace `lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:soundtrack/app/soundtrack_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SoundTrackApp());
}
```

Create `lib/app/app_dependencies.dart`:

```dart
class AppDependencies {
  const AppDependencies();
}
```

- [ ] **Step 5: Verify and commit**

Run:

```powershell
dart format lib test
flutter analyze
flutter test
```

Expected: analyzer exits with no issues and the app-shell test passes.

Commit:

```powershell
git add pubspec.yaml pubspec.lock android lib test
git commit -m "chore: scaffold SoundTrack Flutter app"
```

### Task 2: Define audio settings and audio references

**Files:**
- Create: `lib/features/events/domain/event_audio_settings.dart`
- Create: `lib/features/events/domain/audio_reference.dart`
- Test: `test/features/events/domain/event_audio_settings_test.dart`
- Test: `test/features/events/domain/audio_reference_test.dart`

- [ ] **Step 1: Write failing serialization and clamping tests**

Create `test/features/events/domain/event_audio_settings_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/event_audio_settings.dart';

void main() {
  test('uses approved defaults', () {
    const settings = EventAudioSettings.defaults();
    expect(settings.masterVolume, 0.80);
    expect(settings.musicVolume, 1.0);
    expect(settings.narrationVolume, 0.25);
    expect(settings.fadeIn, const Duration(seconds: 2));
    expect(settings.fadeOut, const Duration(seconds: 2));
  });

  test('round trips through json', () {
    const original = EventAudioSettings(
      masterVolume: 0.7,
      musicVolume: 0.9,
      narrationVolume: 0.2,
      fadeIn: Duration(milliseconds: 1200),
      fadeOut: Duration(milliseconds: 1700),
    );
    expect(EventAudioSettings.fromJson(original.toJson()), original);
  });
}
```

Create `test/features/events/domain/audio_reference_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';

void main() {
  test('imports a non-portable source as pending', () {
    final source = AudioReference.fromJson({
      'uri': 'content://provider/audio/1',
      'displayName': 'entrada.mp3',
      'artist': 'Artista',
      'durationMs': 120000,
      'portable': false,
    }, imported: true);

    expect(source.pending, isTrue);
    expect(source.displayName, 'entrada.mp3');
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```powershell
flutter test test/features/events/domain
```

Expected: FAIL because both domain classes are missing.

- [ ] **Step 3: Implement immutable value objects**

Create `lib/features/events/domain/event_audio_settings.dart`:

```dart
class EventAudioSettings {
  const EventAudioSettings({
    required this.masterVolume,
    required this.musicVolume,
    required this.narrationVolume,
    required this.fadeIn,
    required this.fadeOut,
  });

  const EventAudioSettings.defaults()
      : masterVolume = 0.80,
        musicVolume = 1.0,
        narrationVolume = 0.25,
        fadeIn = const Duration(seconds: 2),
        fadeOut = const Duration(seconds: 2);

  final double masterVolume;
  final double musicVolume;
  final double narrationVolume;
  final Duration fadeIn;
  final Duration fadeOut;

  Map<String, Object> toJson() => {
        'masterVolume': masterVolume,
        'musicVolume': musicVolume,
        'narrationVolume': narrationVolume,
        'fadeInMs': fadeIn.inMilliseconds,
        'fadeOutMs': fadeOut.inMilliseconds,
      };

  factory EventAudioSettings.fromJson(Map<String, Object?> json) {
    return EventAudioSettings(
      masterVolume: (json['masterVolume'] as num).toDouble(),
      musicVolume: (json['musicVolume'] as num).toDouble(),
      narrationVolume: (json['narrationVolume'] as num).toDouble(),
      fadeIn: Duration(milliseconds: json['fadeInMs'] as int),
      fadeOut: Duration(milliseconds: json['fadeOutMs'] as int),
    );
  }

  EventAudioSettings copyWith({
    double? masterVolume,
    double? musicVolume,
    double? narrationVolume,
    Duration? fadeIn,
    Duration? fadeOut,
  }) {
    return EventAudioSettings(
      masterVolume:
          (masterVolume ?? this.masterVolume).clamp(0.0, 1.0).toDouble(),
      musicVolume:
          (musicVolume ?? this.musicVolume).clamp(0.0, 1.0).toDouble(),
      narrationVolume:
          (narrationVolume ?? this.narrationVolume)
              .clamp(0.0, 1.0)
              .toDouble(),
      fadeIn: fadeIn ?? this.fadeIn,
      fadeOut: fadeOut ?? this.fadeOut,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EventAudioSettings &&
      other.masterVolume == masterVolume &&
      other.musicVolume == musicVolume &&
      other.narrationVolume == narrationVolume &&
      other.fadeIn == fadeIn &&
      other.fadeOut == fadeOut;

  @override
  int get hashCode =>
      Object.hash(masterVolume, musicVolume, narrationVolume, fadeIn, fadeOut);
}
```

Create `lib/features/events/domain/audio_reference.dart`:

```dart
class AudioReference {
  const AudioReference({
    required this.uri,
    required this.displayName,
    required this.pending,
    this.artist,
    this.duration,
  });

  final String? uri;
  final String displayName;
  final bool pending;
  final String? artist;
  final Duration? duration;

  Map<String, Object?> toJson() => {
        'uri': uri,
        'displayName': displayName,
        'artist': artist,
        'durationMs': duration?.inMilliseconds,
        'portable': false,
      };

  factory AudioReference.fromJson(
    Map<String, Object?> json, {
    bool imported = false,
  }) {
    return AudioReference(
      uri: json['uri'] as String?,
      displayName: json['displayName'] as String,
      artist: json['artist'] as String?,
      duration: json['durationMs'] == null
          ? null
          : Duration(milliseconds: json['durationMs'] as int),
      pending: imported || json['uri'] == null,
    );
  }

  AudioReference relink({
    required String uri,
    required String displayName,
    String? artist,
    Duration? duration,
  }) {
    return AudioReference(
      uri: uri,
      displayName: displayName,
      pending: false,
      artist: artist,
      duration: duration,
    );
  }
}
```

- [ ] **Step 4: Verify and commit**

Run:

```powershell
dart format lib/features/events/domain test/features/events/domain
flutter test test/features/events/domain
flutter analyze
```

Expected: all domain tests pass and analyzer reports no issues.

Commit:

```powershell
git add lib/features/events/domain test/features/events/domain
git commit -m "feat: add event audio value objects"
```

### Task 3: Define moments, events, validation and export envelope

**Files:**
- Create: `lib/features/events/domain/event_moment.dart`
- Create: `lib/features/events/domain/soundtrack_event.dart`
- Create: `lib/features/events/domain/event_export.dart`
- Create: `lib/features/events/domain/event_validation.dart`
- Test: `test/features/events/domain/soundtrack_event_test.dart`
- Test: `test/features/events/domain/event_export_test.dart`

- [ ] **Step 1: Write failing aggregate tests**

Create `test/features/events/domain/soundtrack_event_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';

void main() {
  test('reorder rewrites contiguous positions', () {
    final event = SoundTrackEvent.create(id: 'event-1', name: 'Formatura')
        .addMoment(EventMoment.create(id: 'a', position: 0, name: 'Recepção'))
        .addMoment(EventMoment.create(id: 'b', position: 1, name: 'Entrada'));

    final reordered = event.reorderMoment(oldIndex: 0, newIndex: 2);

    expect(reordered.moments.map((m) => m.id), ['b', 'a']);
    expect(reordered.moments.map((m) => m.position), [0, 1]);
  });
}
```

Create `test/features/events/domain/event_export_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/event_export.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';

void main() {
  test('export envelope excludes session state', () {
    final event = SoundTrackEvent.create(id: 'e1', name: 'Reunião');
    final exported = EventExport.create(
      event: event,
      exportedAt: DateTime.utc(2026, 6, 29),
    ).toJson();

    expect(exported['format'], 'soundtrack-event');
    expect(exported['schemaVersion'], 1);
    expect(exported['audioSources'], isA<List<Object?>>());
    expect(exported.containsKey('sessionState'), isFalse);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```powershell
flutter test test/features/events/domain/soundtrack_event_test.dart test/features/events/domain/event_export_test.dart
```

Expected: FAIL because aggregate classes are missing.

- [ ] **Step 3: Implement moment behavior**

Create `lib/features/events/domain/event_moment.dart` with:

```dart
import 'audio_reference.dart';

enum EndBehavior { loop, stop }

class EventMoment {
  const EventMoment({
    required this.id,
    required this.position,
    required this.name,
    required this.endBehavior,
    required this.narrationEnabled,
    required this.gainDb,
    this.audio,
    this.fadeIn,
    this.fadeOut,
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
      endBehavior: EndBehavior.loop,
      narrationEnabled: false,
      gainDb: 0,
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
      id: id,
      position: position ?? this.position,
      name: name ?? this.name,
      audio: clearAudio ? null : audio ?? this.audio,
      endBehavior: endBehavior ?? this.endBehavior,
      narrationEnabled: narrationEnabled ?? this.narrationEnabled,
      gainDb: (gainDb ?? this.gainDb).clamp(-12.0, 6.0).toDouble(),
      fadeIn: fadeIn ?? this.fadeIn,
      fadeOut: fadeOut ?? this.fadeOut,
    );
  }

  Map<String, Object?> toJson() => {
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

  factory EventMoment.fromJson(
    Map<String, Object?> json, {
    bool imported = false,
  }) {
    return EventMoment(
      id: json['id'] as String,
      position: json['position'] as int,
      name: json['name'] as String,
      audio: json['audio'] == null
          ? null
          : AudioReference.fromJson(
              Map<String, Object?>.from(json['audio'] as Map),
              imported: imported,
            ),
      endBehavior: EndBehavior.values.byName(json['endBehavior'] as String),
      narrationEnabled: json['narrationEnabled'] as bool,
      gainDb: (json['gainDb'] as num).toDouble(),
      fadeIn: json['fadeInMs'] == null
          ? null
          : Duration(milliseconds: json['fadeInMs'] as int),
      fadeOut: json['fadeOutMs'] == null
          ? null
          : Duration(milliseconds: json['fadeOutMs'] as int),
    );
  }
}
```

- [ ] **Step 4: Implement event, export and validation**

Create `soundtrack_event.dart`:

```dart
import 'event_audio_settings.dart';
import 'event_moment.dart';

class SoundTrackEvent {
  const SoundTrackEvent({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.audioSettings,
    required this.moments,
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
    return SoundTrackEvent(
      id: replacementId ?? json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      audioSettings: EventAudioSettings.fromJson(
        Map<String, Object?>.from(json['audioSettings'] as Map),
      ),
      moments: (json['moments'] as List<Object?>)
          .map(
            (item) => EventMoment.fromJson(
              Map<String, Object?>.from(item as Map),
              imported: imported,
            ),
          )
          .toList(growable: false),
    );
  }

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final EventAudioSettings audioSettings;
  final List<EventMoment> moments;

  SoundTrackEvent addMoment(EventMoment moment) =>
      copyWith(moments: [...moments, moment], updatedAt: DateTime.now().toUtc());

  SoundTrackEvent updateMoment(EventMoment moment) {
    if (!moments.any((item) => item.id == moment.id)) {
      throw StateError('Moment ${moment.id} does not belong to event $id');
    }
    return copyWith(
      moments: [
        for (final item in moments)
          if (item.id == moment.id) moment else item,
      ],
      updatedAt: DateTime.now().toUtc(),
    );
  }

  SoundTrackEvent removeMoment(String momentId) {
    final remaining = moments.where((item) => item.id != momentId).toList();
    return copyWith(
      moments: [
        for (var index = 0; index < remaining.length; index++)
          remaining[index].copyWith(position: index),
      ],
      updatedAt: DateTime.now().toUtc(),
    );
  }

  SoundTrackEvent reorderMoment({
    required int oldIndex,
    required int newIndex,
  }) {
    final reordered = [...moments];
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    return copyWith(
      moments: [
        for (var index = 0; index < reordered.length; index++)
          reordered[index].copyWith(position: index),
      ],
      updatedAt: DateTime.now().toUtc(),
    );
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
      moments: moments ?? this.moments,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'audioSettings': audioSettings.toJson(),
        'moments': moments.map((moment) => moment.toJson()).toList(),
      };
}
```

Create `event_export.dart`:

```dart
import 'audio_reference.dart';
import 'soundtrack_event.dart';

class EventExport {
  static const format = 'soundtrack-event';
  static const currentSchemaVersion = 1;

  const EventExport({
    required this.schemaVersion,
    required this.exportedAt,
    required this.event,
  });

  factory EventExport.create({
    required SoundTrackEvent event,
    required DateTime exportedAt,
  }) {
    return EventExport(
      schemaVersion: currentSchemaVersion,
      exportedAt: exportedAt.toUtc(),
      event: event,
    );
  }

  final int schemaVersion;
  final DateTime exportedAt;
  final SoundTrackEvent event;

  Map<String, Object?> toJson() {
    final byUri = <String, AudioReference>{};
    for (final moment in event.moments) {
      final audio = moment.audio;
      if (audio?.uri != null) byUri[audio!.uri!] = audio;
    }
    return {
      'format': format,
      'schemaVersion': schemaVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'event': event.toJson(),
      'audioSources': byUri.values.map((audio) => audio.toJson()).toList(),
    };
  }
}
```

Create `event_validation.dart`:

```dart
import 'soundtrack_event.dart';

enum EventIssueCode { emptyName, noMoments, missingAudio, pendingAudio }

class EventIssue {
  const EventIssue(this.code, this.message, {this.momentId});
  final EventIssueCode code;
  final String message;
  final String? momentId;
}

List<EventIssue> validateEvent(SoundTrackEvent event) {
  final issues = <EventIssue>[];
  if (event.name.trim().isEmpty) {
    issues.add(const EventIssue(
      EventIssueCode.emptyName,
      'Informe o nome do evento.',
    ));
  }
  if (event.moments.isEmpty) {
    issues.add(const EventIssue(
      EventIssueCode.noMoments,
      'Adicione pelo menos um momento.',
    ));
  }
  for (final moment in event.moments) {
    if (moment.audio == null) {
      issues.add(EventIssue(
        EventIssueCode.missingAudio,
        '${moment.name}: escolha uma música.',
        momentId: moment.id,
      ));
    } else if (moment.audio!.pending) {
      issues.add(EventIssue(
        EventIssueCode.pendingAudio,
        '${moment.name}: religue o áudio pendente.',
        momentId: moment.id,
      ));
    }
  }
  return issues;
}
```

Keep every method as a pure transformation. The only clock reads above update aggregate timestamps.

- [ ] **Step 5: Verify and commit**

Run:

```powershell
dart format lib/features/events/domain test/features/events/domain
flutter test test/features/events/domain
flutter analyze
```

Expected: aggregate, serialization and ordering tests pass.

Commit:

```powershell
git add lib/features/events/domain test/features/events/domain
git commit -m "feat: model SoundTrack events and moments"
```

### Task 4: Add atomic local persistence

**Files:**
- Create: `lib/features/events/data/event_repository.dart`
- Create: `lib/features/events/data/json_file_event_repository.dart`
- Test: `test/features/events/data/json_file_event_repository_test.dart`

- [ ] **Step 1: Write failing repository tests**

Create `test/features/events/data/json_file_event_repository_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/data/json_file_event_repository.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';

void main() {
  late Directory directory;
  late JsonFileEventRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('soundtrack_repo_');
    repository = JsonFileEventRepository(directory);
  });

  tearDown(() => directory.delete(recursive: true));

  test('persists events across repository instances', () async {
    final event = SoundTrackEvent.create(id: 'e1', name: 'Solenidade');
    await repository.save(event);

    final reopened = JsonFileEventRepository(directory);
    expect((await reopened.findAll()).single.name, 'Solenidade');
  });

  test('deleting an event does not affect others', () async {
    await repository.save(SoundTrackEvent.create(id: 'a', name: 'A'));
    await repository.save(SoundTrackEvent.create(id: 'b', name: 'B'));
    await repository.delete('a');

    expect((await repository.findAll()).map((e) => e.id), ['b']);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```powershell
flutter test test/features/events/data/json_file_event_repository_test.dart
```

Expected: FAIL because the repository is missing.

- [ ] **Step 3: Implement the repository contract and atomic file store**

Create `lib/features/events/data/event_repository.dart`:

```dart
import '../domain/soundtrack_event.dart';

abstract interface class EventRepository {
  Future<List<SoundTrackEvent>> findAll();
  Future<SoundTrackEvent?> findById(String id);
  Future<void> save(SoundTrackEvent event);
  Future<void> delete(String id);
}
```

Create `lib/features/events/data/json_file_event_repository.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import '../domain/soundtrack_event.dart';
import 'event_repository.dart';

class JsonFileEventRepository implements EventRepository {
  JsonFileEventRepository(this.directory);

  final Directory directory;
  File get _file => File('${directory.path}${Platform.pathSeparator}events.json');

  Future<Map<String, SoundTrackEvent>> _read() async {
    if (!await _file.exists()) return {};
    final decoded = jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
    final items = decoded['events'] as List<dynamic>? ?? const [];
    return {
      for (final item in items)
        (item as Map<String, dynamic>)['id'] as String:
            SoundTrackEvent.fromJson(Map<String, Object?>.from(item)),
    };
  }

  Future<void> _write(Iterable<SoundTrackEvent> events) async {
    await directory.create(recursive: true);
    final temporary = File('${_file.path}.tmp');
    final payload = jsonEncode({
      'schemaVersion': 1,
      'events': events.map((event) => event.toJson()).toList(),
    });
    await temporary.writeAsString(payload, flush: true);
    if (await _file.exists()) await _file.delete();
    await temporary.rename(_file.path);
  }

  @override
  Future<List<SoundTrackEvent>> findAll() async {
    final events = (await _read()).values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return events;
  }

  @override
  Future<SoundTrackEvent?> findById(String id) async => (await _read())[id];

  @override
  Future<void> save(SoundTrackEvent event) async {
    final events = await _read();
    events[event.id] = event;
    await _write(events.values);
  }

  @override
  Future<void> delete(String id) async {
    final events = await _read();
    events.remove(id);
    await _write(events.values);
  }
}
```

- [ ] **Step 4: Verify and commit**

Run:

```powershell
dart format lib/features/events/data test/features/events/data
flutter test test/features/events/data
flutter analyze
```

Expected: repository tests pass, including reopen and selective delete.

Commit:

```powershell
git add lib/features/events/data test/features/events/data
git commit -m "feat: persist events atomically"
```

### Task 5: Add event library and editor controllers

**Files:**
- Create: `lib/features/events/application/event_library_controller.dart`
- Create: `lib/features/events/application/event_editor_controller.dart`
- Test: `test/features/events/application/event_library_controller_test.dart`
- Test: `test/features/events/application/event_editor_controller_test.dart`

- [ ] **Step 1: Write failing controller tests with an in-memory fake**

Create `test/support/in_memory_event_repository.dart` implementing `EventRepository` with a `Map<String, SoundTrackEvent>`.

Create `test/features/events/application/event_library_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/application/event_library_controller.dart';
import '../../../support/in_memory_event_repository.dart';

void main() {
  test('create, duplicate and delete refresh the visible list', () async {
    final controller = EventLibraryController(
      repository: InMemoryEventRepository(),
      newId: () => 'generated-${DateTime.now().microsecondsSinceEpoch}',
    );

    await controller.load();
    final created = await controller.create('Casamento');
    final copy = await controller.duplicate(created.id);
    await controller.delete(created.id);

    expect(controller.events, hasLength(1));
    expect(controller.events.single.id, copy.id);
    expect(controller.events.single.name, 'Casamento (cópia)');
  });
}
```

Create `test/features/events/application/event_editor_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/application/event_editor_controller.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import '../../../support/in_memory_event_repository.dart';

void main() {
  test('save persists current draft', () async {
    final repository = InMemoryEventRepository();
    final controller = EventEditorController(
      repository: repository,
      initial: SoundTrackEvent.create(id: 'e1', name: 'Evento'),
      newId: () => 'moment-1',
    );

    controller.rename('Evento editado');
    controller.addMoment('Recepção');
    await controller.save();

    final saved = await repository.findById('e1');
    expect(saved!.name, 'Evento editado');
    expect(saved.moments.single.name, 'Recepção');
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```powershell
flutter test test/features/events/application
```

Expected: FAIL because the controllers are missing.

- [ ] **Step 3: Implement controller public APIs**

`EventLibraryController` must expose:

```dart
class EventLibraryController extends ChangeNotifier {
  EventLibraryController({
    required EventRepository repository,
    required String Function() newId,
  });

  List<SoundTrackEvent> get events;
  bool get loading;
  Object? get error;
  Future<void> load();
  Future<SoundTrackEvent> create(String name);
  Future<SoundTrackEvent> duplicate(String id);
  Future<void> rename(String id, String name);
  Future<void> delete(String id);
}
```

`EventEditorController` must expose:

```dart
class EventEditorController extends ChangeNotifier {
  EventEditorController({
    required EventRepository repository,
    required SoundTrackEvent initial,
    required String Function() newId,
  });

  SoundTrackEvent get draft;
  bool get dirty;
  List<EventIssue> get issues;
  void rename(String name);
  void updateSettings(EventAudioSettings settings);
  void addMoment(String name);
  void updateMoment(EventMoment moment);
  void removeMoment(String id);
  void reorderMoment(int oldIndex, int newIndex);
  Future<void> save();
}
```

Every mutation replaces the immutable aggregate, sets `dirty`, recomputes `issues`, and calls `notifyListeners()`. `save()` persists one aggregate and clears `dirty` only after success.

- [ ] **Step 4: Verify and commit**

Run:

```powershell
dart format lib/features/events/application test/features/events/application test/support
flutter test test/features/events/application
flutter analyze
```

Expected: all controller tests pass.

Commit:

```powershell
git add lib/features/events/application test/features/events/application test/support
git commit -m "feat: add event authoring controllers"
```

### Task 6: Build event library and editor UI

**Files:**
- Create: `lib/features/events/presentation/event_library_page.dart`
- Create: `lib/features/events/presentation/event_editor_page.dart`
- Create: `lib/features/events/presentation/moment_editor_sheet.dart`
- Create: `lib/features/events/presentation/widgets/event_card.dart`
- Create: `lib/features/events/presentation/widgets/moment_tile.dart`
- Modify: `lib/app/soundtrack_app.dart`
- Modify: `lib/app/app_dependencies.dart`
- Modify: `lib/main.dart`
- Test: `test/features/events/presentation/event_library_page_test.dart`
- Test: `test/features/events/presentation/event_editor_page_test.dart`

- [ ] **Step 1: Write failing widget tests**

`event_library_page_test.dart` must inject an `EventLibraryController`, tap the add button, enter `Formatura`, confirm, and expect one `EventCard`.

`event_editor_page_test.dart` must inject an `EventEditorController`, add two moments, drag the second above the first, and verify the controller order.

Use stable keys:

```dart
const addEventKey = Key('add-event');
const eventNameFieldKey = Key('event-name-field');
const addMomentKey = Key('add-moment');
Key momentTileKey(String id) => Key('moment-$id');
```

- [ ] **Step 2: Run widget tests to verify they fail**

Run:

```powershell
flutter test test/features/events/presentation
```

Expected: FAIL because pages and keys do not exist.

- [ ] **Step 3: Implement the library page**

Use `ListenableBuilder(listenable: controller, builder: ...)`. The page must:

- call `load()` once in `initState`;
- show loading, empty, error and populated states;
- expose create, open, duplicate, rename, export and delete;
- confirm delete with event name;
- navigate to `EventEditorPage` and reload on return.

The `EventCard` menu values must be a typed enum:

```dart
enum EventCardAction { open, duplicate, rename, export, delete }
```

- [ ] **Step 4: Implement the editor page**

Use `ReorderableListView.builder` bound to `controller.reorderMoment`. The screen must contain:

- event name field;
- global Master, Música, Narração, fade-in and fade-out controls;
- list of `MomentTile`;
- add-moment button;
- save action;
- disabled Modo Evento button labeled `Disponível após instalar o motor de áudio`.

`MomentEditorSheet` edits name, end behavior, Narração, gain from -12 dB to +6 dB, inherited/custom fades and audio selection callback. Do not access platform APIs directly from widgets.

- [ ] **Step 5: Compose dependencies and verify**

`AppDependencies.create()` obtains `getApplicationDocumentsDirectory()`, builds `JsonFileEventRepository`, and supplies UUID v4 factories. `main()` awaits dependencies before `runApp`.

Run:

```powershell
dart format lib test
flutter analyze
flutter test
```

Expected: all unit and widget tests pass.

Commit:

```powershell
git add lib test
git commit -m "feat: build event library and editor"
```

### Task 7: Implement Android Storage Access Framework gateway

**Files:**
- Create: `lib/platform/documents/document_gateway.dart`
- Create: `lib/platform/documents/method_channel_document_gateway.dart`
- Create: `android/app/src/main/kotlin/com/soundtrack/soundtrack/DocumentChannel.kt`
- Modify: `android/app/src/main/kotlin/com/soundtrack/soundtrack/MainActivity.kt`
- Test: `test/platform/documents/method_channel_document_gateway_test.dart`
- Test: `android/app/src/test/kotlin/com/soundtrack/soundtrack/DocumentMetadataTest.kt`

- [ ] **Step 1: Write failing Dart channel contract tests**

Use `TestDefaultBinaryMessengerBinding` to mock channel `com.soundtrack/documents`. Verify:

- `pickAudio` maps URI, display name and size;
- `openEventJson` returns UTF-8 content;
- `createEventJson` sends name and JSON;
- platform cancellation maps to `null`, not an error.

Define the contract:

```dart
class PickedDocument {
  const PickedDocument({
    required this.uri,
    required this.displayName,
    this.mimeType,
    this.size,
  });
  final String uri;
  final String displayName;
  final String? mimeType;
  final int? size;
}

abstract interface class DocumentGateway {
  Future<PickedDocument?> pickAudio();
  Future<String?> openEventJson();
  Future<bool> createEventJson({
    required String suggestedName,
    required String contents,
  });
  Future<bool> canRead(String uri);
  Future<AudioProbeResult> probeAudio(String uri);
}

class AudioProbeResult {
  const AudioProbeResult({
    required this.playable,
    this.artist,
    this.duration,
  });
  final bool playable;
  final String? artist;
  final Duration? duration;
}
```

- [ ] **Step 2: Run the Dart test to verify it fails**

Run:

```powershell
flutter test test/platform/documents/method_channel_document_gateway_test.dart
```

Expected: FAIL because gateway files do not exist.

- [ ] **Step 3: Implement the Dart channel adapter**

Use:

```dart
static const _channel = MethodChannel('com.soundtrack/documents');
```

Methods and arguments:

- `pickAudio`, no args;
- `openEventJson`, no args;
- `createEventJson`, `{suggestedName, contents}`;
- `canRead`, `{uri}`;
- `probeAudio`, `{uri}` returning `playable`, `artist` and `durationMs`.

Catch `PlatformException` only to wrap it in a typed `DocumentGatewayException(code, message)`; preserve cancellation as `null`.

- [ ] **Step 4: Implement Kotlin SAF handling**

`DocumentChannel` must use `ActivityResultContracts.OpenDocument` with `arrayOf("audio/*")` for music and `arrayOf("application/json", "text/plain", "application/octet-stream")` for `.soundtrack.json`. Use `ActivityResultContracts.CreateDocument("application/json")` for export. For audio:

```kotlin
contentResolver.takePersistableUriPermission(
    uri,
    Intent.FLAG_GRANT_READ_URI_PERMISSION
)
```

Return a map containing `uri`, `displayName`, `mimeType`, and `size`. Read/write JSON with `contentResolver.openInputStream` and `openOutputStream`. Implement `probeAudio` with `MediaMetadataRetriever.setDataSource(context, uri)` and extract artist/duration; return `playable: false` on an unsupported or unreadable source without consuming the URI permission. Reject a second concurrent picker request with error code `picker_busy`.

Register from `MainActivity.configureFlutterEngine`:

```kotlin
DocumentChannel(
    activity = this,
    messenger = flutterEngine.dartExecutor.binaryMessenger,
).register()
```

- [ ] **Step 5: Verify Dart and Android tests**

Run:

```powershell
flutter test test/platform/documents
flutter analyze
Set-Location android
.\gradlew.bat testDebugUnitTest
Set-Location ..
```

Expected: Dart channel tests and Android unit tests pass.

Commit:

```powershell
git add lib/platform android/app/src test/platform
git commit -m "feat: add Android document gateway"
```

### Task 8: Implement export, import and audio relinking

**Files:**
- Create: `lib/features/events/data/event_export_codec.dart`
- Create: `lib/features/events/application/event_transfer_controller.dart`
- Create: `lib/features/events/presentation/audio_relink_page.dart`
- Modify: `lib/features/events/presentation/event_library_page.dart`
- Modify: `lib/features/events/presentation/moment_editor_sheet.dart`
- Test: `test/features/events/data/event_export_codec_test.dart`
- Test: `test/features/events/application/event_transfer_controller_test.dart`
- Test: `test/features/events/presentation/audio_relink_page_test.dart`

- [ ] **Step 1: Write failing codec tests**

Cover:

- export has format, schema and ISO timestamp;
- invalid JSON throws `EventImportException.invalidJson`;
- wrong format throws `unsupportedFormat`;
- schema `2` throws `unsupportedVersion`;
- schema `1` imports with replacement event ID;
- inaccessible sources become pending;
- accessible but unplayable sources remain pending;
- accessible and playable sources are reused;
- no partial save occurs after parse failure.

Use injected probes:

```dart
Future<bool> Function(String uri) canRead;
Future<AudioProbeResult> Function(String uri) probeAudio;
```

so tests do not call Android.

- [ ] **Step 2: Run tests to verify they fail**

Run:

```powershell
flutter test test/features/events/data/event_export_codec_test.dart test/features/events/application/event_transfer_controller_test.dart
```

Expected: FAIL because codec and controller are missing.

- [ ] **Step 3: Implement the versioned codec**

Public API:

```dart
class EventExportCodec {
  const EventExportCodec();

  String encode(SoundTrackEvent event, DateTime exportedAt);

  Future<SoundTrackEvent> decode(
    String contents, {
    required String replacementId,
    required Future<bool> Function(String uri) canRead,
    required Future<AudioProbeResult> Function(String uri) probeAudio,
  });
}
```

Decode into memory, validate every required field, migrate supported older versions, then evaluate both `canRead` and `probeAudio`. A source leaves pending only when both checks succeed. Return one complete aggregate and never call a repository inside the codec.

- [ ] **Step 4: Implement transfer controller and UI**

`EventTransferController` coordinates `DocumentGateway`, codec and repository:

```dart
Future<bool> exportEvent(SoundTrackEvent event);
Future<SoundTrackEvent?> importEvent();
Future<void> relinkMoment({
  required SoundTrackEvent event,
  required String momentId,
});
```

`importEvent()` passes `DocumentGateway.canRead` and `DocumentGateway.probeAudio` to the codec and saves only after successful decode. On success, navigate to `AudioRelinkPage` when `moments.any((m) => m.audioPending)`.

`AudioRelinkPage` lists expected filename, artist and duration; each item has `Escolher música` and `Resolver depois`. After selection, call `DocumentGateway.probeAudio(uri)`; clear pending only when `playable` is true, and store returned artist/duration when available.

- [ ] **Step 5: Run the complete foundation suite**

Run:

```powershell
dart format lib test integration_test
flutter analyze
flutter test
flutter test integration_test/event_authoring_flow_test.dart
git diff --check
```

Expected: analyzer clean, all tests pass, and integration flow covers create → add moments → export → import → relink.

Commit:

```powershell
git add lib test integration_test
git commit -m "feat: import export and relink events"
```

### Task 9: Foundation acceptance checkpoint

**Files:**
- Create: `docs/qa/foundation-checklist.md`
- Modify: `README.md`

- [ ] **Step 1: Document manual acceptance**

`docs/qa/foundation-checklist.md` must contain checkboxes for:

- fresh install creates an event;
- event survives process restart;
- moments reorder correctly;
- moved/deleted audio shows pending;
- export opens Android create-document picker;
- exported JSON is readable as UTF-8;
- import creates a new ID;
- invalid import creates no event;
- relinking requires explicit file choice.

- [ ] **Step 2: Run acceptance on an Android emulator**

Run:

```powershell
flutter devices
flutter run
```

Exercise every checklist item that does not require a second physical device. Record emulator model and Android API in the checklist.

- [ ] **Step 3: Run final verification**

Run:

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
git diff --check
git status --short
```

Expected: format, analyzer and tests pass; only the intended README/checklist edits are uncommitted.

- [ ] **Step 4: Commit the checkpoint**

```powershell
git add README.md docs/qa/foundation-checklist.md
git commit -m "docs: record foundation acceptance"
```
