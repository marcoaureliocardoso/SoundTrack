# SoundTrack Broad Visual Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved permanent visual system across the SoundTrack main flow while preserving playback behavior, import/export semantics, and accessibility through 200% text scaling.

**Architecture:** Add a small app-level theme and editorial widget vocabulary, then migrate one bounded flow at a time: library, event context, editors, preflight, auxiliary states, and live operation. Existing application controllers remain authoritative; presentation code derives view models without duplicating persistence or playback logic.

**Tech Stack:** Flutter 3 / Dart 3.12, Material 3, `ChangeNotifier`/`ListenableBuilder`, `flutter_test`, `integration_test`, Android emulator QA.

## Global Constraints

- Canonical design: `docs/design/soundtrack-visual-system.md`.
- Theme remains dark throughout the application.
- Reference colors: background `#091315`, surface `#111F21`, elevated surface `#182B2C`, border `#263638`, primary text `#EDF7F5`, secondary text `#8FA19F`, accent `#73D2C7`, warning `#D0B66F`, destructive `#CC9DA4`.
- Normal text contrast must meet WCAG AA; status must never depend on color alone.
- No wide filled CTA in the main flow. Operational navigation uses editorial rows; edit confirmation uses `Salvar` in the app bar.
- Minimum interactive target is 48 dp.
- All main screens must remain usable without clipping, overlap, or unreachable content at text scales 1.0, 1.5, and 2.0 in 320×480 portrait and 480×320 landscape.
- Do not change playback interruption policy, background continuity, audio engine behavior, export payloads, or the debug Audio Engine Lab.
- Entering the Modo Evento must not start a track automatically.
- Do not add a new package dependency; use Flutter and the existing project stack only.
- Preserve the user-owned untracked `.codex-remote-attachments/` directory.

## File Structure

### New files

- `lib/app/theme/soundtrack_theme.dart`: canonical colors, spacing tokens, and `ThemeData`.
- `lib/app/widgets/editorial_components.dart`: reusable section header, status indicator, operational row, and volume control.
- `lib/features/events/presentation/event_sort_order.dart`: deterministic event ordering.
- `lib/features/events/presentation/event_flow_callbacks.dart`: callback typedefs shared by library and event context.
- `lib/features/events/presentation/event_overview_page.dart`: read-oriented event context and menu actions.
- `lib/features/events/presentation/moment_editor_page.dart`: full-screen moment editor.
- `lib/features/events/presentation/widgets/event_list_row.dart`: editorial library row.
- `lib/features/events/presentation/widgets/moment_list_row.dart`: editorial reorderable moment row.
- `lib/features/events/presentation/widgets/event_audio_settings_editor.dart`: event-level volume and fade controls.
- `lib/features/live/presentation/preflight_summary.dart`: pure preflight counts for presentation.
- `lib/features/live/presentation/widgets/emergency_volume_toggle_bar.dart`: persistent curtain toggle above the playback dock.
- `test/app/soundtrack_theme_test.dart`: palette and contrast contract.
- `test/app/editorial_components_test.dart`: shared-component semantics and geometry.
- `test/features/events/presentation/event_sort_order_test.dart`: four ordering modes and tie breakers.
- `test/features/events/presentation/event_overview_page_test.dart`: context navigation and actions.
- `test/features/events/presentation/moment_editor_page_test.dart`: full-screen moment edit behavior.
- `test/features/live/presentation/preflight_summary_test.dart`: summary derivation.

### Renamed or removed files

- Replace `lib/features/events/presentation/widgets/event_card.dart` with `event_list_row.dart`.
- Replace `lib/features/events/presentation/moment_editor_sheet.dart` with `moment_editor_page.dart`.
- Replace `test/features/events/presentation/moment_editor_sheet_test.dart` with `moment_editor_page_test.dart`.

### Modified files

- `lib/app/soundtrack_app.dart`
- `lib/features/events/application/event_editor_controller.dart`
- `lib/features/events/presentation/event_library_page.dart`
- `lib/features/events/presentation/event_editor_page.dart`
- `lib/features/events/presentation/audio_relink_page.dart`
- `lib/features/live/presentation/preflight_page.dart`
- `lib/features/live/presentation/live_dashboard_page.dart`
- `lib/features/live/presentation/widgets/now_playing_panel.dart`
- `lib/features/live/presentation/widgets/moment_action_button.dart`
- `lib/features/live/presentation/widgets/playback_controls.dart`
- `lib/features/live/presentation/widgets/emergency_volume_panel.dart`
- relevant tests under `test/features/events/presentation/` and `test/features/live/presentation/`
- `integration_test/event_authoring_flow_test.dart`
- `integration_test/live_event_flow_test.dart`
- `README.md`
- `CHANGELOG.md`

---

### Task 1: Theme and Editorial Primitives

**Files:**
- Create: `lib/app/theme/soundtrack_theme.dart`
- Create: `lib/app/widgets/editorial_components.dart`
- Create: `test/app/soundtrack_theme_test.dart`
- Create: `test/app/editorial_components_test.dart`
- Modify: `lib/app/soundtrack_app.dart`

**Interfaces:**
- Produces: `ThemeData buildSoundTrackTheme()`.
- Produces: `SoundTrackTokens`, `EditorialSectionHeader`, `StatusIndicator`, `OperationalActionRow`, and `LabeledVolumeControl`.
- Consumes: Material 3 only.

- [ ] **Step 1: Write failing palette and contrast tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/app/theme/soundtrack_theme.dart';

import '../support/color_contrast.dart';

void main() {
  test('uses the approved dark palette with AA contrast', () {
    final theme = buildSoundTrackTheme();
    expect(theme.scaffoldBackgroundColor, const Color(0xFF091315));
    expect(theme.colorScheme.primary, const Color(0xFF73D2C7));
    expect(
      contrastRatio(
        theme.colorScheme.onSurface,
        theme.scaffoldBackgroundColor,
      ),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrastRatio(
        theme.colorScheme.onPrimary,
        theme.colorScheme.primary,
      ),
      greaterThanOrEqualTo(4.5),
    );
  });
}
```

- [ ] **Step 2: Run the new theme test and verify the missing import failure**

Run: `flutter test test/app/soundtrack_theme_test.dart`

Expected: FAIL because `lib/app/theme/soundtrack_theme.dart` does not exist.

- [ ] **Step 3: Implement the canonical theme and tokens**

```dart
import 'package:flutter/material.dart';

abstract final class SoundTrackTokens {
  static const background = Color(0xFF091315);
  static const surface = Color(0xFF111F21);
  static const elevatedSurface = Color(0xFF182B2C);
  static const border = Color(0xFF263638);
  static const primaryText = Color(0xFFEDF7F5);
  static const secondaryText = Color(0xFF8FA19F);
  static const accent = Color(0xFF73D2C7);
  static const onAccent = Color(0xFF092426);
  static const warning = Color(0xFFD0B66F);
  static const destructive = Color(0xFFCC9DA4);

  static const pagePadding = 16.0;
  static const sectionGap = 20.0;
  static const rowMinHeight = 64.0;
  static const targetMinSize = 48.0;
}

ThemeData buildSoundTrackTheme() {
  const scheme = ColorScheme.dark(
    primary: SoundTrackTokens.accent,
    onPrimary: SoundTrackTokens.onAccent,
    surface: SoundTrackTokens.surface,
    onSurface: SoundTrackTokens.primaryText,
    error: SoundTrackTokens.destructive,
    onError: SoundTrackTokens.background,
  );
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: SoundTrackTokens.background,
    colorScheme: scheme,
    dividerColor: SoundTrackTokens.border,
    cardTheme: const CardThemeData(
      color: SoundTrackTokens.surface,
      margin: EdgeInsets.zero,
    ),
    textTheme: ThemeData.dark().textTheme.apply(
      bodyColor: SoundTrackTokens.primaryText,
      displayColor: SoundTrackTokens.primaryText,
    ),
  );
}
```

- [ ] **Step 4: Write shared-component tests before implementing widgets**

```dart
testWidgets('operational row has semantics and a 48 dp target', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildSoundTrackTheme(),
      home: Scaffold(
        body: OperationalActionRow(
          icon: Icons.play_arrow,
          title: 'Preparar Modo Evento',
          description: 'Revisar áudios antes de iniciar',
          onTap: () {},
        ),
      ),
    ),
  );
  expect(tester.getSize(find.byType(OperationalActionRow)).height, greaterThanOrEqualTo(48));
  expect(
    tester.getSemantics(find.byType(OperationalActionRow)).label,
    contains('Preparar Modo Evento'),
  );
});
```

- [ ] **Step 5: Implement the shared components with natural height**

```dart
class OperationalActionRow extends StatelessWidget {
  const OperationalActionRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? SoundTrackTokens.destructive
        : Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '$title. $description',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(title), Text(description)],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

Implement `EditorialSectionHeader`, `StatusIndicator`, and `LabeledVolumeControl` in the same file using `Wrap` or flexible rows, no fixed text height, and `SoundTrackTokens.targetMinSize` for interactive actions.

- [ ] **Step 6: Apply the theme at the app root**

```dart
theme: buildSoundTrackTheme(),
```

Import `soundtrack_theme.dart` and replace only the current `ThemeData` expression assigned to `MaterialApp.theme`. Keep the existing `FutureBuilder`, routes, and active-session restoration body unchanged.

- [ ] **Step 7: Run focused tests and analysis**

Run: `flutter test test/app/soundtrack_theme_test.dart test/app/editorial_components_test.dart test/app/soundtrack_app_test.dart`

Expected: PASS.

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 8: Commit the visual foundation**

```powershell
git add lib/app/theme/soundtrack_theme.dart lib/app/widgets/editorial_components.dart lib/app/soundtrack_app.dart test/app/soundtrack_theme_test.dart test/app/editorial_components_test.dart
git commit -m "feat: add soundtrack visual system foundation"
```

---

### Task 2: Event Ordering and Editorial Library

**Files:**
- Create: `lib/features/events/presentation/event_sort_order.dart`
- Create: `lib/features/events/presentation/widgets/event_list_row.dart`
- Create: `test/features/events/presentation/event_sort_order_test.dart`
- Modify: `lib/features/events/presentation/event_library_page.dart`
- Modify: `test/features/events/presentation/event_library_page_test.dart`
- Delete: `lib/features/events/presentation/widgets/event_card.dart`

**Interfaces:**
- Produces: `enum EventSortOrder { newest, oldest, nameAscending, nameDescending }`.
- Produces: `List<SoundTrackEvent> sortEvents(Iterable<SoundTrackEvent>, EventSortOrder)`.
- Produces: `EventListRow` with `event`, `number`, `status`, and `onTap`.
- Consumes: `EventLibraryController.events` without changing repository order.

- [ ] **Step 1: Write sorting tests with deterministic ties**

```dart
test('sorts by all four modes and deterministic tie breakers', () {
  final first = SoundTrackEvent.create(id: 'b', name: 'Álbum').copyWith(
    updatedAt: DateTime.utc(2026, 7, 14),
  );
  final second = SoundTrackEvent.create(id: 'a', name: 'álbum').copyWith(
    updatedAt: DateTime.utc(2026, 7, 15),
  );
  final third = SoundTrackEvent.create(id: 'c', name: 'Baile').copyWith(
    updatedAt: DateTime.utc(2026, 7, 13),
  );

  expect(sortEvents([first, second, third], EventSortOrder.newest), [second, first, third]);
  expect(sortEvents([first, second, third], EventSortOrder.oldest), [third, first, second]);
  expect(sortEvents([first, second, third], EventSortOrder.nameAscending), [second, first, third]);
  expect(sortEvents([first, second, third], EventSortOrder.nameDescending), [third, second, first]);
});
```

- [ ] **Step 2: Run the sort test and verify failure**

Run: `flutter test test/features/events/presentation/event_sort_order_test.dart`

Expected: FAIL because `EventSortOrder` and `sortEvents` do not exist.

- [ ] **Step 3: Implement sorting exactly as specified**

```dart
enum EventSortOrder { newest, oldest, nameAscending, nameDescending }

List<SoundTrackEvent> sortEvents(
  Iterable<SoundTrackEvent> source,
  EventSortOrder order,
) {
  int tieBreak(SoundTrackEvent a, SoundTrackEvent b) {
    final updated = b.updatedAt.compareTo(a.updatedAt);
    return updated != 0 ? updated : a.id.compareTo(b.id);
  }

  int compareName(SoundTrackEvent a, SoundTrackEvent b, {required bool descending}) {
    final left = a.name.trim().toLowerCase();
    final right = b.name.trim().toLowerCase();
    final name = descending ? right.compareTo(left) : left.compareTo(right);
    return name != 0 ? name : tieBreak(a, b);
  }

  return List.unmodifiable(source.toList()..sort(switch (order) {
    EventSortOrder.newest => (a, b) => b.updatedAt.compareTo(a.updatedAt),
    EventSortOrder.oldest => (a, b) => a.updatedAt.compareTo(b.updatedAt),
    EventSortOrder.nameAscending => (a, b) => compareName(a, b, descending: false),
    EventSortOrder.nameDescending => (a, b) => compareName(a, b, descending: true),
  }));
}
```

- [ ] **Step 4: Write failing library interaction and accessibility tests**

Add tests that assert:

```dart
expect(find.text('Eventos'), findsOneWidget);
expect(find.text('Sua biblioteca SoundTrack'), findsNothing);
expect(find.byKey(addEventKey), findsOneWidget);
expect(find.byKey(eventSortKey), findsOneWidget);
expect(find.byKey(libraryMenuKey), findsOneWidget);
expect(find.text('Importar evento'), findsNothing);

await tester.tap(find.byKey(libraryMenuKey));
await tester.pumpAndSettle();
expect(find.text('Importar evento'), findsOneWidget);

await tester.tap(find.byKey(eventSortKey));
await tester.pumpAndSettle();
await tester.tap(find.text('Nome: A–Z'));
await tester.pumpAndSettle();
expect(_visibleEventNames(tester), ['Alfa', 'Zeta']);
```

Repeat the geometry assertion through `accessibilityTestCases` and require every `EventListRow` to be at least 64 dp tall.

- [ ] **Step 5: Replace the card library with editorial rows**

```dart
const addEventKey = Key('add-event');
const eventSortKey = Key('event-sort');
const libraryMenuKey = Key('library-menu');

enum _LibraryMenuAction { importEvent, audioEngineLab }

class _EventLibraryPageState extends State<EventLibraryPage> {
  EventSortOrder _sortOrder = EventSortOrder.newest;

  List<SoundTrackEvent> get _visibleEvents =>
      sortEvents(widget.controller.events, _sortOrder);
}
```

Build a flexible app bar with `Novo` and `⋮`, place the sorting popup beside `Seus eventos`, render `EventListRow`, and replace the current central empty copy with `Nenhum evento ainda` plus guidance to use `Novo`.

- [ ] **Step 6: Preserve create/import busy-state behavior**

Keep `_documentBusy`, `_import`, `_create`, refresh handling, and document error mapping. Move only the import trigger into `_LibraryMenuAction.importEvent`; do not duplicate it inside the list.

```dart
PopupMenuButton<_LibraryMenuAction>(
  key: libraryMenuKey,
  enabled: !_documentBusy,
  onSelected: (action) {
    if (action == _LibraryMenuAction.importEvent) _import();
  },
  itemBuilder: (_) => const [
    PopupMenuItem(
      value: _LibraryMenuAction.importEvent,
      child: Text('Importar evento'),
    ),
  ],
)
```

- [ ] **Step 7: Run focused library tests**

Run: `flutter test test/features/events/presentation/event_sort_order_test.dart test/features/events/presentation/event_library_page_test.dart`

Expected: PASS.

- [ ] **Step 8: Commit the library migration**

```powershell
git add lib/features/events/presentation/event_sort_order.dart lib/features/events/presentation/event_library_page.dart lib/features/events/presentation/widgets/event_list_row.dart test/features/events/presentation/event_sort_order_test.dart test/features/events/presentation/event_library_page_test.dart
git rm lib/features/events/presentation/widgets/event_card.dart
git commit -m "feat: redesign event library and sorting"
```

---

### Task 3: Event Context and Navigation

**Files:**
- Create: `lib/features/events/presentation/event_flow_callbacks.dart`
- Create: `lib/features/events/presentation/event_overview_page.dart`
- Create: `test/features/events/presentation/event_overview_page_test.dart`
- Modify: `lib/features/events/presentation/event_library_page.dart`
- Modify: `lib/app/soundtrack_app.dart`
- Modify: `test/features/events/presentation/event_library_page_test.dart`
- Modify: `integration_test/event_authoring_flow_test.dart`

**Interfaces:**
- Produces shared typedefs `EventEditorControllerFactory`, `EventExportCallback`, `EventImportCallback`, and `EventLiveEntryPageBuilder`.
- Produces `EventOverviewPage(eventId, libraryController, createEditorController, onSelectAudio, onExport, buildLiveEntryPage)`.
- Consumes `EventLibraryController` as the live source for the current event snapshot.

- [ ] **Step 1: Write failing context navigation tests**

```dart
testWidgets('event row opens context instead of editor', (tester) async {
  await tester.pumpWidget(_libraryWithEvent(name: 'Jaleco'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Jaleco'));
  await tester.pumpAndSettle();

  expect(find.byType(EventOverviewPage), findsOneWidget);
  expect(find.text('Editar estrutura'), findsOneWidget);
  expect(find.text('Preparar Modo Evento'), findsOneWidget);
  expect(find.text('Editar evento'), findsNothing);
});
```

Add tests for export, duplicate, rename, and delete in the `⋮` menu, and assert deletion pops to the library only after confirmation.

- [ ] **Step 2: Run the new context test and verify failure**

Run: `flutter test test/features/events/presentation/event_overview_page_test.dart`

Expected: FAIL because `EventOverviewPage` does not exist.

- [ ] **Step 3: Move flow typedefs out of the library page**

```dart
typedef EventEditorControllerFactory =
    EventEditorController Function(SoundTrackEvent event);
typedef EventExportCallback = Future<bool> Function(SoundTrackEvent event);
typedef EventImportCallback = Future<SoundTrackEvent?> Function();
typedef EventLiveEntryPageBuilder = Widget Function(SoundTrackEvent event);
```

Update imports in `SoundTrackApp`, `EventLibraryPage`, and tests without changing callback behavior.

- [ ] **Step 4: Implement the event context contract**

```dart
class EventOverviewPage extends StatefulWidget {
  const EventOverviewPage({
    required this.eventId,
    required this.libraryController,
    required this.createEditorController,
    this.onSelectAudio,
    this.onExport,
    this.buildLiveEntryPage,
    super.key,
  });

  final String eventId;
  final EventLibraryController libraryController;
  final EventEditorControllerFactory createEditorController;
  final Future<AudioReference?> Function()? onSelectAudio;
  final EventExportCallback? onExport;
  final EventLiveEntryPageBuilder? buildLiveEntryPage;
}
```

Use `ListenableBuilder` over `libraryController`; find the event by `eventId`. Render the event name as the dominant title, status, `Editar estrutura`, an `OperationalActionRow` for `Preparar Modo Evento`, all moments, and the audio summary.

- [ ] **Step 5: Implement context actions without stale snapshots**

```dart
Future<void> _edit(SoundTrackEvent event) async {
  final controller = widget.createEditorController(event);
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => EventEditorPage(
        controller: controller,
        onSelectAudio: widget.onSelectAudio,
      ),
    ),
  );
  controller.dispose();
  if (mounted) await widget.libraryController.load();
}
```

`Preparar Modo Evento` pushes `buildLiveEntryPage(event)`. Export delegates to `onExport`. Duplicate and rename call the controller and remain on the current context. Delete confirms, calls `libraryController.delete`, then pops.
At this stage, both `Editar estrutura` and the audio-summary `Ajustar` action call `_edit(event)`; Task 4 adds direct scrolling to the audio section after that section has a stable key.

- [ ] **Step 6: Change the library row destination**

```dart
Future<void> _open(SoundTrackEvent event) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => EventOverviewPage(
        eventId: event.id,
        libraryController: widget.controller,
        createEditorController: widget.createEditorController,
        onSelectAudio: widget.onSelectAudio,
        onExport: widget.onExport,
        buildLiveEntryPage: widget.buildLiveEntryPage,
      ),
    ),
  );
}
```

- [ ] **Step 7: Run context and composed-app tests**

Run: `flutter test test/features/events/presentation/event_overview_page_test.dart test/features/events/presentation/event_library_page_test.dart test/app/soundtrack_app_test.dart`

Expected: PASS.

- [ ] **Step 8: Commit the context flow**

```powershell
git add lib/features/events/presentation/event_flow_callbacks.dart lib/features/events/presentation/event_overview_page.dart lib/features/events/presentation/event_library_page.dart lib/app/soundtrack_app.dart test/features/events/presentation/event_overview_page_test.dart test/features/events/presentation/event_library_page_test.dart integration_test/event_authoring_flow_test.dart
git commit -m "feat: add event context workspace"
```

---

### Task 4: Edit Structure and Event Audio Controls

**Files:**
- Create: `lib/features/events/presentation/widgets/moment_list_row.dart`
- Create: `lib/features/events/presentation/widgets/event_audio_settings_editor.dart`
- Modify: `lib/features/events/application/event_editor_controller.dart`
- Modify: `lib/features/events/presentation/event_overview_page.dart`
- Modify: `lib/features/events/presentation/event_editor_page.dart`
- Modify: `test/features/events/application/event_editor_controller_test.dart`
- Modify: `test/features/events/presentation/event_overview_page_test.dart`
- Modify: `test/features/events/presentation/event_editor_page_test.dart`
- Delete: `lib/features/events/presentation/widgets/moment_tile.dart`
- Delete: `test/features/events/presentation/moment_tile_accessibility_test.dart`

**Interfaces:**
- Produces: `enum EventEditorInitialSection { top, audio }`.
- Produces: `EventMoment createMomentDraft()` and `void insertMoment(EventMoment)` on `EventEditorController`.
- Produces: `EventAudioSettingsEditor(settings, onChanged)`.
- Retains the existing moment creation and editing dialogs during this task so the commit remains independently compilable. Task 5 migrates those actions to `MomentEditorPage`.

- [ ] **Step 1: Write controller tests for full draft insertion**

```dart
test('creates and inserts a complete moment draft', () {
  final controller = EventEditorController(
    repository: InMemoryEventRepository(),
    initial: SoundTrackEvent.create(id: 'event', name: 'Jaleco'),
    newId: () => 'moment-1',
  );
  final draft = controller.createMomentDraft().copyWith(
    name: 'Entrada',
    narrationEnabled: true,
  );
  controller.insertMoment(draft);
  expect(controller.draft.moments.single.name, 'Entrada');
  expect(controller.draft.moments.single.narrationEnabled, isTrue);
  expect(controller.dirty, isTrue);
});
```

- [ ] **Step 2: Implement the controller API without changing persistence**

```dart
EventMoment createMomentDraft() => EventMoment.create(
  id: _newId(),
  position: _draft.moments.length,
  name: '',
);

void insertMoment(EventMoment moment) {
  if (_draft.moments.any((candidate) => candidate.id == moment.id)) {
    throw ArgumentError.value(moment.id, 'moment.id', 'already exists');
  }
  _replaceDraft(_draft.addMoment(moment));
}
```

Keep `addMoment(String)` during migration only if another test still calls it; remove it when all callers use the full-screen editor.

- [ ] **Step 3: Write failing structure layout tests**

Assert `Editar estrutura`, `Salvar`, `Nome do evento`, `Momentos`, `Adicionar`, `Áudio do evento`, `Master`, `Música`, `Música durante a narração`, `Fade-in`, and `Fade-out`. Assert `Identificação`, `Modo Evento`, and the FAB are absent.

```dart
expect(find.text('Identificação'), findsNothing);
expect(find.text('Música durante a narração'), findsOneWidget);
expect(find.byKey(addMomentKey), findsOneWidget);
expect(find.byType(FloatingActionButton), findsNothing);
```

- [ ] **Step 4: Extract the event audio settings editor**

```dart
class EventAudioSettingsEditor extends StatelessWidget {
  const EventAudioSettingsEditor({
    required this.settings,
    required this.onChanged,
    super.key,
  });

  final EventAudioSettings settings;
  final ValueChanged<EventAudioSettings> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      LabeledVolumeControl(
        label: 'Master',
        description: 'Limite geral da saída do aplicativo',
        value: settings.masterVolume,
        onChanged: (value) => onChanged(settings.copyWith(masterVolume: value)),
      ),
      LabeledVolumeControl(
        label: 'Música',
        description: 'Nível normal da trilha sonora',
        value: settings.musicVolume,
        onChanged: (value) => onChanged(settings.copyWith(musicVolume: value)),
      ),
      LabeledVolumeControl(
        label: 'Música durante a narração',
        description: 'Nível usado enquanto Narração estiver ativa',
        value: settings.narrationVolume,
        onChanged: (value) => onChanged(settings.copyWith(narrationVolume: value)),
      ),
      AdaptiveFadeFields(settings: settings, onChanged: onChanged),
    ],
  );
}
```

`AdaptiveFadeFields` uses `LayoutBuilder`; stack fields vertically when width is below 360 dp or text scale exceeds 1.4.

- [ ] **Step 5: Rebuild `EventEditorPage` as one vertical editor**

Use one `ReorderableListView` with a natural-height header. Replace the save icon with a `TextButton` labeled `Salvar`, move `Adicionar` to `EditorialSectionHeader`, and render `MomentListRow` with the drag handle at the trailing edge.

```dart
enum EventEditorInitialSection { top, audio }

const addMomentKey = Key('add-moment');
const eventAudioSectionKey = Key('event-audio-section');

TextButton(
  onPressed: canSave ? _save : null,
  child: _saving
      ? const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : const Text('Salvar'),
)
```

In `initState`, when `initialSection == EventEditorInitialSection.audio`, schedule `Scrollable.ensureVisible` for `eventAudioSectionKey` after the first frame.

Update the `Ajustar` action in `EventOverviewPage` to open `EventEditorPage` with `initialSection: EventEditorInitialSection.audio`. The regular `Editar estrutura` action continues using the default `top` section.

- [ ] **Step 6: Run controller and structure tests**

Run: `flutter test test/features/events/application/event_editor_controller_test.dart test/features/events/presentation/event_overview_page_test.dart test/features/events/presentation/event_editor_page_test.dart`

Expected: PASS, including all accessibility cases.

- [ ] **Step 7: Commit the structure editor**

```powershell
git add lib/features/events/application/event_editor_controller.dart lib/features/events/presentation/event_overview_page.dart lib/features/events/presentation/event_editor_page.dart lib/features/events/presentation/widgets/moment_list_row.dart lib/features/events/presentation/widgets/event_audio_settings_editor.dart test/features/events/application/event_editor_controller_test.dart test/features/events/presentation/event_overview_page_test.dart test/features/events/presentation/event_editor_page_test.dart
git rm lib/features/events/presentation/widgets/moment_tile.dart test/features/events/presentation/moment_tile_accessibility_test.dart
git commit -m "feat: redesign event structure editor"
```

---

### Task 5: Full-Screen Moment Editor

**Files:**
- Create: `lib/features/events/presentation/moment_editor_page.dart`
- Create: `test/features/events/presentation/moment_editor_page_test.dart`
- Modify: `lib/features/events/presentation/event_editor_page.dart`
- Delete: `lib/features/events/presentation/moment_editor_sheet.dart`
- Delete: `test/features/events/presentation/moment_editor_sheet_test.dart`

**Interfaces:**
- Produces: `MomentEditorPage(moment, onSave, onDelete?, onSelectAudio?)`.
- Returns to the structure editor only after `Salvar` or confirmed deletion.
- Consumes: `EventEditorController.updateMoment`, `insertMoment`, and `removeMoment`.

- [ ] **Step 1: Write failing editor behavior tests**

Cover save vocabulary, audio picker reentry, loop/stop selection, Narration, volume range, inherited fades, deletion confirmation, and 200% geometry.

```dart
expect(find.text('Salvar'), findsOneWidget);
expect(find.text('Concluir'), findsNothing);
expect(find.text('Conteúdo'), findsNothing);
expect(find.text('Volume da faixa'), findsOneWidget);
expect(find.byIcon(Icons.loop), findsOneWidget);
expect(find.byIcon(Icons.stop), findsOneWidget);
```

For the audio row, assert the `Trocar` action remains within the 320 dp viewport at 200%:

```dart
final actionRect = tester.getRect(find.text('Trocar'));
expect(actionRect.right, lessThanOrEqualTo(320));
```

- [ ] **Step 2: Run the new moment editor test and verify failure**

Run: `flutter test test/features/events/presentation/moment_editor_page_test.dart`

Expected: FAIL because `MomentEditorPage` does not exist.

- [ ] **Step 3: Implement the full-screen editor shell and save contract**

```dart
class MomentEditorPage extends StatefulWidget {
  const MomentEditorPage({
    required this.moment,
    required this.onSave,
    this.onDelete,
    this.onSelectAudio,
    super.key,
  });

  final EventMoment moment;
  final ValueChanged<EventMoment> onSave;
  final VoidCallback? onDelete;
  final AudioSelectionCallback? onSelectAudio;
}
```

Use `Scaffold`, `AppBar`, and `ListView`. The app-bar `Salvar` action trims the name, invokes `onSave(_draft.copyWith(name: trimmed))`, and pops once. Disable it for an empty name or while selecting audio.

- [ ] **Step 4: Implement exclusive loop/stop without radio visuals**

```dart
SegmentedButton<EndBehavior>(
  showSelectedIcon: false,
  segments: const [
    ButtonSegment(
      value: EndBehavior.loop,
      icon: Icon(Icons.loop),
      label: Text('Repetir em loop'),
    ),
    ButtonSegment(
      value: EndBehavior.stop,
      icon: Icon(Icons.stop),
      label: Text('Parar'),
    ),
  ],
  selected: {_draft.endBehavior},
  onSelectionChanged: (value) {
    setState(() => _draft = _draft.copyWith(endBehavior: value.single));
  },
)
```

Wrap the selected segment in semantics that announces `Ativo`; selection must also remain visible through border/surface contrast.

- [ ] **Step 5: Implement adaptive audio, volume, fades, and deletion**

The audio row uses `Expanded` around the filename and a fixed trailing `TextButton('Trocar')`. At text scale above 1.4, switch to a `Column` so `Trocar` occupies its own 48 dp row.

```dart
Slider(
  min: -12,
  max: 6,
  divisions: 18,
  value: _draft.gainDb,
  label: '${_draft.gainDb.toStringAsFixed(0)} dB',
  onChanged: (value) => setState(
    () => _draft = _draft.copyWith(gainDb: value),
  ),
)
```

Use the existing fade values. Place `Excluir este momento` after a divider; confirmation actions are `Cancelar` and `Excluir`, and the message states that the device file is not deleted.

- [ ] **Step 6: Connect new and existing moments from the structure editor**

```dart
Future<void> _addMoment() async {
  final draft = widget.controller.createMomentDraft();
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => MomentEditorPage(
        moment: draft,
        onSave: widget.controller.insertMoment,
        onSelectAudio: widget.onSelectAudio,
      ),
    ),
  );
}

Future<void> _editMoment(EventMoment moment) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => MomentEditorPage(
        moment: moment,
        onSave: widget.controller.updateMoment,
        onDelete: () => widget.controller.removeMoment(moment.id),
        onSelectAudio: widget.onSelectAudio,
      ),
    ),
  );
}
```

For a not-yet-inserted draft, hide the delete action instead of supplying an empty target; implement this with `VoidCallback? onDelete` and render only when non-null.

- [ ] **Step 7: Run editor tests**

Run: `flutter test test/features/events/presentation/moment_editor_page_test.dart test/features/events/presentation/event_editor_page_test.dart`

Expected: PASS.

- [ ] **Step 8: Commit the moment editor migration**

```powershell
git add lib/features/events/presentation/moment_editor_page.dart lib/features/events/presentation/event_editor_page.dart test/features/events/presentation/moment_editor_page_test.dart test/features/events/presentation/event_editor_page_test.dart
git rm lib/features/events/presentation/moment_editor_sheet.dart test/features/events/presentation/moment_editor_sheet_test.dart
git commit -m "feat: add full screen moment editor"
```

---

### Task 6: Editorial Preflight Verification

**Files:**
- Create: `lib/features/live/presentation/preflight_summary.dart`
- Create: `test/features/live/presentation/preflight_summary_test.dart`
- Modify: `lib/features/live/presentation/preflight_page.dart`
- Modify: `test/features/live/presentation/preflight_page_test.dart`

**Interfaces:**
- Produces: immutable `PreflightSummary(readyAudioCount, totalMomentCount, warningCount, errorCount)`.
- Produces: `summarizePreflight(PreflightResult result, int totalMomentCount)`.
- Consumes existing `PreflightService` and `PreflightResult`; does not perform probes in widgets.

- [ ] **Step 1: Write failing summary derivation tests**

```dart
test('summarizes ready audio, warnings, and errors', () {
  final result = PreflightResult(
    items: const [
      PreflightItem(
        code: PreflightCode.lowBattery,
        severity: PreflightSeverity.warning,
        message: 'Bateria baixa.',
      ),
      PreflightItem(
        code: PreflightCode.audioPending,
        severity: PreflightSeverity.error,
        message: 'Áudio pendente.',
      ),
    ],
    readyMomentIds: const {'one', 'two'},
  );
  expect(
    summarizePreflight(result, 3),
    const PreflightSummary(
      readyAudioCount: 2,
      totalMomentCount: 3,
      warningCount: 1,
      errorCount: 1,
    ),
  );
});
```

- [ ] **Step 2: Implement the pure summary**

```dart
typedef PreflightSummary = ({
  int readyAudioCount,
  int totalMomentCount,
  int warningCount,
  int errorCount,
});

PreflightSummary summarizePreflight(
  PreflightResult result,
  int totalMomentCount,
) => (
  readyAudioCount: result.readyMomentIds.length,
  totalMomentCount: totalMomentCount,
  warningCount: result.items
      .where((item) => item.severity == PreflightSeverity.warning)
      .length,
  errorCount: result.items
      .where((item) => item.severity == PreflightSeverity.error)
      .length,
);
```

- [ ] **Step 3: Write failing preflight presentation tests**

Assert event name prominence, `5/5`, `AVISOS`, `ERROS`, `Reverificar`, `Entrar no Modo Evento`, and no `FilledButton`. Preserve existing serialization, disposal, confirmation, immutable snapshot, and no-autoplay assertions.

```dart
expect(find.text('Jaleco'), findsOneWidget);
expect(find.text('1'), findsWidgets);
expect(find.text('Entrar no Modo Evento'), findsOneWidget);
expect(find.widgetWithText(FilledButton, 'Entrar no Modo Evento'), findsNothing);
```

- [ ] **Step 4: Rebuild preflight as editorial groups**

Use `ListView`, event title, a wrapping metric strip, `EditorialSectionHeader`, `StatusIndicator`, and one final `OperationalActionRow`. Show one success audio row only when `readyAudioCount == totalMomentCount` and total is greater than zero.

```dart
OperationalActionRow(
  icon: Icons.play_arrow,
  title: result.hasErrors
      ? 'Entrar mesmo assim'
      : 'Entrar no Modo Evento',
  description: result.hasErrors
      ? 'Alguns momentos podem ficar sem áudio'
      : 'Abre o Dashboard sem iniciar uma faixa',
  destructive: result.hasErrors,
  onTap: _entering ? null : _enter,
)
```

Keep `_check`, generation guards, `_entering`, and the existing error confirmation flow.

- [ ] **Step 5: Run preflight tests**

Run: `flutter test test/features/live/presentation/preflight_summary_test.dart test/features/live/presentation/preflight_page_test.dart test/features/live/application/preflight_service_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit preflight**

```powershell
git add lib/features/live/presentation/preflight_summary.dart lib/features/live/presentation/preflight_page.dart test/features/live/presentation/preflight_summary_test.dart test/features/live/presentation/preflight_page_test.dart
git commit -m "feat: redesign preflight verification"
```

---

### Task 7: Auxiliary States and Audio Relinking

**Files:**
- Modify: `lib/features/events/presentation/audio_relink_page.dart`
- Modify: `lib/features/events/presentation/event_library_page.dart`
- Modify: `lib/features/events/presentation/event_overview_page.dart`
- Modify: `test/features/events/presentation/audio_relink_page_test.dart`
- Modify: `test/features/events/presentation/event_library_page_test.dart`
- Modify: `test/features/events/presentation/event_overview_page_test.dart`

**Interfaces:**
- Preserves: `AudioRelinkPage(event, controller)` and immediate per-file persistence.
- Produces consistent states: skeleton, empty, recoverable error, pending audio, and destructive confirmation.

- [ ] **Step 1: Write failing relink vocabulary and geometry tests**

```dart
expect(find.text('Áudios pendentes'), findsOneWidget);
expect(find.text('Selecionar'), findsWidgets);
expect(find.text('Resolver depois'), findsOneWidget);
expect(find.text('Localizar músicas'), findsNothing);
expect(find.text('Escolher música'), findsNothing);
```

After the last pending audio is resolved, assert `Voltar ao evento` and no `Concluir`.

- [ ] **Step 2: Rebuild pending audio as editorial rows**

```dart
Widget _pendingRow(EventMoment moment) => EditorialRow(
  leading: const StatusIndicator.warning(),
  title: moment.audio?.displayName ?? 'Nenhum arquivo selecionado',
  subtitle: 'Momento: ${moment.name}',
  trailing: TextButton(
    onPressed: _busyMomentId == null ? () => _relink(moment.id) : null,
    child: const Text('Selecionar'),
  ),
);
```

Use `Resolver depois` while pending and `Voltar ao evento` after completion. Keep `_busyMomentId`, `_error`, and controller behavior.

- [ ] **Step 3: Add library skeleton and canonical error state**

When the first load is active, render three fixed-shape editorial skeleton rows. When the first load fails, render `Não foi possível carregar os eventos`, a simple storage hint, and `Tentar novamente`. Preserve the existing list on refresh failure and continue using the snackbar.

```dart
TextButton.icon(
  onPressed: widget.controller.load,
  icon: const Icon(Icons.refresh),
  label: const Text('Tentar novamente'),
)
```

- [ ] **Step 4: Standardize destructive confirmations**

Use `Cancelar` and `Excluir`, name the target, and explain the consequence. Moment deletion copy must state that the audio file remains on the device. Event deletion copy must state that the event structure is removed.

- [ ] **Step 5: Run auxiliary-state tests**

Run: `flutter test test/features/events/presentation/audio_relink_page_test.dart test/features/events/presentation/event_library_page_test.dart test/features/events/presentation/event_overview_page_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit auxiliary states**

```powershell
git add lib/features/events/presentation/audio_relink_page.dart lib/features/events/presentation/event_library_page.dart lib/features/events/presentation/event_overview_page.dart test/features/events/presentation/audio_relink_page_test.dart test/features/events/presentation/event_library_page_test.dart test/features/events/presentation/event_overview_page_test.dart
git commit -m "feat: unify auxiliary event states"
```

---

### Task 8: Live Command Panel and Editorial Moments

**Files:**
- Modify: `lib/features/live/presentation/widgets/now_playing_panel.dart`
- Modify: `lib/features/live/presentation/widgets/moment_action_button.dart`
- Modify: `lib/features/live/presentation/live_dashboard_page.dart`
- Modify: `test/features/live/presentation/live_status_panels_test.dart`
- Modify: `test/features/live/presentation/moment_action_button_accessibility_test.dart`
- Modify: `test/features/live/presentation/live_dashboard_page_test.dart`
- Modify: `test/features/live/presentation/dashboard_accessibility_test.dart`

**Interfaces:**
- Preserves: `NowPlayingPanel(state, compact)`.
- Preserves: `MomentActionButton(number, moment, status, onPressed, commandEnabled)`.
- Preserves all controller commands and existing widget keys.

- [ ] **Step 1: Write failing command-panel tests**

Assert a lateral accent, progress indicator, moment name, ticker, status, and time. Require natural height at 200% and verify no clipping when the track is long.

```dart
expect(find.byKey(nowPlayingPanelKey), findsOneWidget);
expect(find.byType(LinearProgressIndicator), findsOneWidget);
expect(find.byType(TrackNameTicker), findsOneWidget);
expect(tester.takeException(), isNull);
```

- [ ] **Step 2: Implement the command panel without changing ticker behavior**

Compute progress safely:

```dart
final duration = state.currentAudioDuration;
final progress = duration == null || duration.inMilliseconds <= 0
    ? null
    : (playback.position.inMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 1.0);
```

Render a `DecoratedBox` with an accent border, natural `Column`, `TrackNameTicker`, status/time wrap, and `LinearProgressIndicator(value: progress)`. Keep compact details dialog and semantics.

- [ ] **Step 3: Write failing editorial moment tests**

Assert rows are not `FilledButton`, whole rows remain tappable, current state is exposed semantically, and long track names are a single ellipsized line.

```dart
expect(
  find.descendant(
    of: find.byType(MomentActionButton),
    matching: find.byType(FilledButton),
  ),
  findsNothing,
);
expect(tester.getSize(find.byType(MomentActionButton)).height, greaterThanOrEqualTo(64));
```

- [ ] **Step 4: Replace pill buttons with editorial material rows**

Use `Material` + `InkWell`, a numeric leading column, `Expanded` text, a 3–4 dp current-state accent, and bottom divider. Keep the full row as the command target and disable pending/error/current rows as before.

```dart
final enabled = status == MomentStatus.ready && commandEnabled;
return Semantics(
  button: true,
  enabled: enabled,
  selected: status == MomentStatus.current,
  label: '$number. ${moment.name}. $track. $statusText',
  excludeSemantics: true,
  child: Material(
    color: status == MomentStatus.current
        ? Theme.of(context).colorScheme.surfaceContainerHigh
        : Colors.transparent,
    child: InkWell(onTap: enabled ? onPressed : null, child: row),
  ),
);
```

- [ ] **Step 5: Update Dashboard section spacing**

Change the title to `MOMENTOS`, keep only the list inside `liveDashboardScrollKey`, remove 8 dp gaps that make each row appear as a card, and use dividers/section spacing from `SoundTrackTokens`.

- [ ] **Step 6: Run live status and moment tests**

Run: `flutter test test/features/live/presentation/live_status_panels_test.dart test/features/live/presentation/moment_action_button_accessibility_test.dart test/features/live/presentation/live_dashboard_page_test.dart test/features/live/presentation/dashboard_accessibility_test.dart test/features/live/presentation/track_name_ticker_test.dart`

Expected: PASS; ticker still pauses, scrolls left, resets to the start, and respects reduced motion.

- [ ] **Step 7: Commit the live content redesign**

```powershell
git add lib/features/live/presentation/widgets/now_playing_panel.dart lib/features/live/presentation/widgets/moment_action_button.dart lib/features/live/presentation/live_dashboard_page.dart test/features/live/presentation/live_status_panels_test.dart test/features/live/presentation/moment_action_button_accessibility_test.dart test/features/live/presentation/live_dashboard_page_test.dart test/features/live/presentation/dashboard_accessibility_test.dart
git commit -m "feat: add live command panel and editorial moments"
```

---

### Task 9: Segmented Playback Dock and Volume Curtain

**Files:**
- Create: `lib/features/live/presentation/widgets/emergency_volume_toggle_bar.dart`
- Modify: `lib/features/live/presentation/widgets/playback_controls.dart`
- Modify: `lib/features/live/presentation/widgets/emergency_volume_panel.dart`
- Modify: `lib/features/live/presentation/live_dashboard_page.dart`
- Modify: `test/features/live/presentation/playback_controls_layout_test.dart`
- Modify: `test/features/live/presentation/playback_controls_contrast_test.dart`
- Modify: `test/features/live/presentation/emergency_volume_curtain_test.dart`
- Modify: `test/features/live/presentation/live_dashboard_page_test.dart`
- Modify: `test/features/live/presentation/dashboard_accessibility_test.dart`

**Interfaces:**
- Changes `PlaybackControls` to three actions: pause/resume, stop, narration.
- Produces `EmergencyVolumeToggleBar(expanded, onToggle)` using existing `volumesToggleKey`.
- Preserves `EmergencyVolumePanel` volume queue, restore, drag, and acknowledgement behavior.

- [ ] **Step 1: Write failing three-zone dock tests**

```dart
expect(find.byKey(pausePlaybackKey), findsOneWidget);
expect(find.byKey(stopPlaybackKey), findsOneWidget);
expect(find.byKey(narrationKey), findsOneWidget);
expect(find.byKey(volumesToggleKey), findsNothing);

final pause = tester.getRect(find.byKey(pausePlaybackKey));
final stop = tester.getRect(find.byKey(stopPlaybackKey));
final narration = tester.getRect(find.byKey(narrationKey));
expect(narration.width, greaterThan(pause.width));
expect(pause.overlaps(stop), isFalse);
expect(stop.overlaps(narration), isFalse);
```

- [ ] **Step 2: Refactor `PlaybackControls` to the approved API**

Remove `volumesExpanded` and `onVolumesToggle` from the constructor. Use a 1:1:1.35 `Flex` layout, natural minimum height, and no fixed label cutoff.

```dart
Row(
  children: [
    Expanded(flex: 100, child: pauseControl),
    Expanded(flex: 100, child: stopControl),
    Expanded(flex: 135, child: narrationControl),
  ],
)
```

Pausar/Retomar uses a contained tonal surface, Parar uses a discrete destructive border/foreground, and Narração uses the accent only when available/active. Keep busy guards and semantics.

- [ ] **Step 3: Write failing curtain-toggle tests**

Assert `EmergencyVolumeToggleBar` is always visible above the dock, tapping it reveals `emergencyVolumesCurtainKey`, the panel slides from below, and fixed regions do not move when the curtain opens.

```dart
final nowBefore = tester.getRect(find.byKey(nowPlayingPanelKey));
final footerBefore = tester.getRect(find.byKey(playbackFooterKey));
await tester.tap(find.byKey(volumesToggleKey));
await tester.pumpAndSettle();
expect(find.byKey(emergencyVolumesCurtainKey), findsOneWidget);
expect(tester.getRect(find.byKey(nowPlayingPanelKey)), nowBefore);
expect(tester.getRect(find.byKey(playbackFooterKey)), footerBefore);
```

- [ ] **Step 4: Implement the persistent volume toggle bar**

```dart
class EmergencyVolumeToggleBar extends StatelessWidget {
  const EmergencyVolumeToggleBar({
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: expanded,
    label: 'Volumes de emergência',
    child: InkWell(
      key: volumesToggleKey,
      onTap: onToggle,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            const Expanded(child: Text('Volumes de emergência')),
            Icon(expanded ? Icons.expand_more : Icons.expand_less),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 5: Recompose the curtain behind the dock**

Keep the moments scroll in the center. Align the animated `EmergencyVolumePanel` to the center bottom, then place `EmergencyVolumeToggleBar` and `PlaybackControls` after the center in the fixed footer column. The panel overlays the lower portion of moments while expanded and slides down behind the toggle/dock when closed.

```dart
Expanded(
  key: liveDashboardCenterKey,
  child: Stack(
    fit: StackFit.expand,
    children: [
      momentsScroll,
      AnimatedSlide(
        key: emergencyVolumesCurtainKey,
        offset: volumesExpanded ? Offset.zero : const Offset(0, 1),
        duration: duration,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: _buildVolumes(compact: compact),
        ),
      ),
    ],
  ),
),
EmergencyVolumeToggleBar(
  expanded: volumesExpanded,
  onToggle: widget.controller.toggleControlsExpanded,
),
_buildControls(compact: compact),
```

When closed, exclude the panel from pointer input and semantics. Keep Back behavior: close the curtain first, then ask to exit.

- [ ] **Step 6: Rename the third emergency slider**

Change only its visible label from `Narração` to `Música durante a narração`; preserve `narrationVolume` and all queue behavior.

- [ ] **Step 7: Run dock and curtain tests**

Run: `flutter test test/features/live/presentation/playback_controls_layout_test.dart test/features/live/presentation/playback_controls_contrast_test.dart test/features/live/presentation/emergency_volume_curtain_test.dart test/features/live/presentation/live_dashboard_page_test.dart test/features/live/presentation/dashboard_accessibility_test.dart`

Expected: PASS in 100%–200%, portrait and landscape.

- [ ] **Step 8: Commit the live controls**

```powershell
git add lib/features/live/presentation/widgets/emergency_volume_toggle_bar.dart lib/features/live/presentation/widgets/playback_controls.dart lib/features/live/presentation/widgets/emergency_volume_panel.dart lib/features/live/presentation/live_dashboard_page.dart test/features/live/presentation/playback_controls_layout_test.dart test/features/live/presentation/playback_controls_contrast_test.dart test/features/live/presentation/emergency_volume_curtain_test.dart test/features/live/presentation/live_dashboard_page_test.dart test/features/live/presentation/dashboard_accessibility_test.dart
git commit -m "feat: add segmented live dock and volume curtain"
```

---

### Task 10: Whole-Flow Accessibility, Integration, and Documentation

**Files:**
- Modify: `test/support/accessibility_test_harness.dart`
- Modify: all main presentation tests touched above
- Modify: `integration_test/event_authoring_flow_test.dart`
- Modify: `integration_test/live_event_flow_test.dart`
- Modify: `README.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes all UI delivered by Tasks 1–9.
- Produces complete automated and emulator evidence for the permanent spec acceptance criteria.

- [ ] **Step 1: Add reusable geometry assertions**

```dart
void expectInsideViewport(
  WidgetTester tester,
  Finder finder,
  Size viewport,
) {
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(viewport.width));
  expect(rect.bottom, lessThanOrEqualTo(viewport.height));
}

void expectMinimumTapTarget(WidgetTester tester, Finder finder) {
  final size = tester.getSize(finder);
  expect(size.width, greaterThanOrEqualTo(48));
  expect(size.height, greaterThanOrEqualTo(48));
}
```

Use these helpers in library, context, structure editor, moment editor, preflight, relink, Dashboard, curtain, and destructive-dialog tests.

- [ ] **Step 2: Add final 200% reachability tests per main screen**

For each `accessibilityTestCase`, pump the screen, scroll to the last meaningful element, and assert `tester.takeException()` is null. Essential targets:

- Library: final event row and sort/menu actions.
- Event context: final audio summary and `Preparar Modo Evento`.
- Edit structure: fade-out control and save action.
- Edit moment: delete action and save action.
- Preflight: entry operation and retry state.
- Relink: final pending row and `Resolver depois`.
- Dashboard: fixed top, moments scroll, volume toggle, dock, and alert.

- [ ] **Step 3: Update the authoring integration flow to the new navigation**

```dart
await tester.tap(find.byKey(addEventKey));
await tester.pumpAndSettle();
await tester.enterText(find.byKey(eventNameFieldKey), 'Casamento');
await tester.tap(find.text('Criar'));
await tester.pumpAndSettle();
await tester.tap(find.text('Casamento'));
await tester.pumpAndSettle();
expect(find.byType(EventOverviewPage), findsOneWidget);
await tester.tap(find.text('Editar estrutura'));
await tester.pumpAndSettle();
await tester.tap(find.byKey(addMomentKey));
await tester.pumpAndSettle();
await tester.enterText(find.byKey(momentNameFieldKey), 'Entrada');
await tester.tap(find.text('Salvar'));
```

Continue through export from the event menu, import from the library menu, `Áudios pendentes`, `Selecionar`, and `Voltar ao evento`.

- [ ] **Step 4: Preserve and extend the live integration flow**

Verify `Preparar Modo Evento` → `Entrar no Modo Evento` → Dashboard, then start a moment, pause/resume, toggle Narration, open/close emergency volumes, change a volume, and stop. Assert no track begins before tapping a moment.

- [ ] **Step 5: Run formatting and the complete automated suite**

Run: `dart format lib test integration_test`

Expected: exit 0 with all touched Dart files formatted.

Run: `flutter analyze`

Expected: `No issues found!`

Run: `flutter test`

Expected: PASS for the complete test suite.

Run: `git diff --check`

Expected: no output and exit 0.

- [ ] **Step 6: Run the two main integration suites on the Android emulator**

Run in PowerShell:

```powershell
$devices = flutter devices --machine | ConvertFrom-Json
$emulatorId = ($devices | Where-Object { $_.targetPlatform -like 'android*' -and $_.emulator } | Select-Object -First 1).id
if (-not $emulatorId) { throw 'Nenhum emulador Android ativo.' }
flutter test integration_test/event_authoring_flow_test.dart -d $emulatorId
flutter test integration_test/live_event_flow_test.dart -d $emulatorId
```

Expected: both integration suites PASS. Do not run the physical-device suite in this round.

- [ ] **Step 7: Perform visual emulator QA at 100% and 200%**

Use the `test-android-apps:android-emulator-qa` skill. Capture screenshots and UI trees for:

1. Biblioteca with multiple events.
2. Event context.
3. Edit structure at the audio section.
4. Edit moment with a long filename.
5. Preflight with warning and with error.
6. Dashboard with long track name.
7. Dashboard with volume curtain open.

Check: no overlap, no clipped action, target labels present, current moment visually distinct, dock fixed, and only moments scroll.

- [ ] **Step 8: Update durable documentation**

In `CHANGELOG.md` under `[Unreleased]`, replace the old four-action wording and add the library/context/editor/preflight redesign, ordering, vocabulary, auxiliary states, 200% validation, and emulator evidence.

In `README.md`, update feature descriptions only where the current interface wording is obsolete. Keep `docs/design/soundtrack-visual-system.md` as the canonical link and do not duplicate the entire design.

- [ ] **Step 9: Run final verification after documentation edits**

Run: `git diff --check`

Expected: no output.

Run: `flutter analyze`

Expected: `No issues found!`

Run: `flutter test`

Expected: PASS.

- [ ] **Step 10: Commit the final acceptance evidence**

```powershell
git add lib test integration_test README.md CHANGELOG.md docs/design/soundtrack-visual-system.md
git commit -m "test: validate broad visual refinement"
```

## Completion Gate

Before opening a pull request, confirm all of the following:

- `git status --short` shows only the pre-existing `.codex-remote-attachments/` entry.
- `flutter analyze` passes.
- `flutter test` passes.
- Both emulator integration suites pass.
- Emulator screenshots cover 100% and 200% text scaling.
- No app code under `lib/features/playback/` changed except presentation-facing imports that are strictly necessary.
- Audio Engine Lab behavior and route remain unchanged.
- The implementation matches `docs/design/soundtrack-visual-system.md` and any necessary design correction is made in that document before code divergence is accepted.
