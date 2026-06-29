# SoundTrack Live Event Dashboard and Acceptance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrar catálogo e motor de áudio em um Modo Evento protegido, legível, contínuo em segundo plano e pronto para validação física do MVP.

**Architecture:** `PreflightService` avalia o evento sem reproduzi-lo. `LiveEventController` converte momentos em comandos do `LivePlaybackPort`, preserva volumes temporários e apresenta um único estado à UI. O Dashboard é uma projeção desse estado e nunca manipula players diretamente.

**Tech Stack:** Flutter 3.44.2, Dart 3.12.2, contratos dos dois planos anteriores, Flutter Test, Integration Test e Android Emulator/ADB.

---

## File map

- `lib/features/live/domain/preflight_result.dart`: itens de verificação.
- `lib/features/live/application/preflight_service.dart`: arquivo, bateria, rota e volume.
- `lib/features/live/application/preflight_record_repository.dart`: último resultado por evento para Meus Eventos.
- `lib/features/live/application/live_event_state.dart`: evento + snapshot + alertas.
- `lib/features/live/application/live_event_controller.dart`: comandos seguros da sessão.
- `lib/features/live/application/active_live_session_store.dart`: evento atualmente controlado pelo handler.
- `lib/features/live/presentation/preflight_page.dart`: pronto, avisos e erros.
- `lib/features/live/presentation/live_dashboard_page.dart`: composição do Dashboard.
- `lib/features/live/presentation/widgets/now_playing_panel.dart`: painel não interativo.
- `lib/features/live/presentation/widgets/moment_action_button.dart`: botão de momento.
- `lib/features/live/presentation/widgets/emergency_volume_panel.dart`: três sliders e restauração.
- `lib/features/live/presentation/widgets/playback_controls.dart`: pausa, parada e Narração.
- `lib/features/live/presentation/widgets/live_alert_banner.dart`: alertas não bloqueantes.
- `lib/platform/system/system_status_gateway.dart`: bateria, volume e rota.
- `lib/platform/system/method_channel_system_status_gateway.dart`: Android.
- `android/app/src/main/kotlin/com/soundtrack/soundtrack/SystemStatusChannel.kt`: leituras do sistema.
- `test/features/live/`: domínio, controller e widgets.
- `integration_test/live_event_flow_test.dart`: jornada final.
- `tool/run_android_acceptance.ps1`: comandos reprodutíveis de QA.

### Task 1: Implement preflight domain and service

**Files:**
- Create: `lib/features/live/domain/preflight_result.dart`
- Create: `lib/features/live/application/preflight_service.dart`
- Create: `lib/features/live/application/preflight_record_repository.dart`
- Create: `lib/platform/system/system_status_gateway.dart`
- Modify: `lib/features/events/application/event_library_controller.dart`
- Modify: `lib/features/events/presentation/event_library_page.dart`
- Test: `test/features/live/application/preflight_service_test.dart`
- Test: `test/features/live/application/preflight_record_repository_test.dart`

- [ ] **Step 1: Write failing preflight tests**

Cover:

- ready when every source is readable and preparable;
- warning for Android media volume below 30%;
- warning for battery below 20% and not charging;
- warning when Do Not Disturb is not known to be enabled;
- error per missing/pending moment;
- route name is included for operator confirmation;
- errors do not delete or edit the event.

Define:

```dart
enum PreflightSeverity { info, warning, error }

enum PreflightCode {
  audioPending,
  audioUnreadable,
  audioUnpreparable,
  lowSystemVolume,
  lowBattery,
  outputRoute,
  doNotDisturb,
}

class PreflightItem {
  const PreflightItem({
    required this.code,
    required this.severity,
    required this.message,
    this.momentId,
  });
  final PreflightCode code;
  final PreflightSeverity severity;
  final String message;
  final String? momentId;
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```powershell
flutter test test/features/live/application/preflight_service_test.dart
```

Expected: FAIL because preflight code is missing.

- [ ] **Step 3: Implement gateways and service**

`SystemStatusGateway` exposes:

```dart
Future<double> mediaVolume();
Future<int> batteryPercent();
Future<bool> charging();
Future<String> outputRouteLabel();
Future<bool?> doNotDisturbEnabled();
Future<void> setKeepScreenOn(bool enabled);
```

`PreflightService.check(event)` uses injected functions:

```dart
Future<bool> Function(String uri) canRead;
Future<bool> Function(String uri) canPrepare;
SystemStatusGateway systemStatus;
```

Check every moment independently so one failure does not hide others. Return `PreflightResult(items)` with `hasErrors`, `hasWarnings`, and `readyMomentIds`. Save a compact `PreflightRecord(eventId, checkedAt, errorCount, warningCount)` after each completed check; `EventLibraryPage` reads these records to show `Não verificado`, `Pronto`, `Avisos` or `Erros`.

Persist records in `preflight-records.json` using the same temporary-file-then-rename strategy as the event repository. Deleting an event also deletes its record; editing an event marks the previous record stale by comparing `event.updatedAt` with `checkedAt`.

- [ ] **Step 4: Verify and commit**

Run:

```powershell
dart format lib/features/live lib/platform/system test/features/live
flutter test test/features/live/application
flutter analyze
```

Expected: preflight tests pass.

Commit:

```powershell
git add lib/features/live lib/platform/system test/features/live
git commit -m "feat: add event preflight checks"
```

### Task 2: Add Android system status channel

**Files:**
- Create: `lib/platform/system/method_channel_system_status_gateway.dart`
- Create: `android/app/src/main/kotlin/com/soundtrack/soundtrack/SystemStatusChannel.kt`
- Modify: `android/app/src/main/kotlin/com/soundtrack/soundtrack/MainActivity.kt`
- Test: `test/platform/system/method_channel_system_status_gateway_test.dart`
- Test: `android/app/src/test/kotlin/com/soundtrack/soundtrack/SystemStatusMappingTest.kt`

- [ ] **Step 1: Write failing Dart channel tests**

Mock `com.soundtrack/system_status` and verify mapping for:

- `mediaVolume`: current/max as normalized double;
- `battery`: percent and charging;
- `outputRoute`: human-readable label;
- `doNotDisturb`: nullable when policy access is unavailable;
- `setKeepScreenOn`: boolean command.

- [ ] **Step 2: Run tests to verify they fail**

Run:

```powershell
flutter test test/platform/system/method_channel_system_status_gateway_test.dart
```

Expected: FAIL because adapter is missing.

- [ ] **Step 3: Implement Android reads**

`SystemStatusChannel` uses:

- `AudioManager.getStreamVolume(STREAM_MUSIC)` and max;
- sticky `ACTION_BATTERY_CHANGED`;
- `AudioManager.getDevices(GET_DEVICES_OUTPUTS)` with priority Bluetooth → wired → USB → speaker;
- `NotificationManager.currentInterruptionFilter` only when policy access is granted.

No method changes system volume, output route or DND state. `setKeepScreenOn(true)` applies `WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON`; `false` clears it. This method affects only the SoundTrack window.

- [ ] **Step 4: Verify and commit**

Run:

```powershell
dart format lib/platform/system test/platform/system
flutter test test/platform/system
Set-Location android
.\gradlew.bat testDebugUnitTest
Set-Location ..
flutter analyze
```

Expected: Dart and Kotlin tests pass.

Commit:

```powershell
git add lib/platform/system android/app/src test/platform/system
git commit -m "feat: read Android preflight status"
```

### Task 3: Implement LiveEventController

**Files:**
- Create: `lib/features/live/application/live_event_state.dart`
- Create: `lib/features/live/application/live_event_controller.dart`
- Test: `test/features/live/application/live_event_controller_test.dart`

- [ ] **Step 1: Write failing live-controller tests**

With `FakeLivePlaybackPort`, assert:

- tapping a valid moment sends one `MomentPlaybackRequest`;
- tapping active moment sends nothing;
- pending moment produces alert and leaves playback unchanged;
- moment-specific fades override globals;
- Narração is available only for enabled active moment;
- changing moments requests Narração false first;
- session volumes do not mutate the stored event;
- restore resets to event presets;
- stop requires a confirmed controller call;
- `dispose` detaches listeners but does not stop playback automatically.

- [ ] **Step 2: Run tests to verify they fail**

Run:

```powershell
flutter test test/features/live/application/live_event_controller_test.dart
```

Expected: FAIL because controller is missing.

- [ ] **Step 3: Implement immutable LiveEventState**

State fields:

```dart
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
}
```

Derive:

- `activeMoment`;
- `narrationAvailable`;
- `momentStatus(id)` returning ready/current/pending/error;
- effective current display metadata.

- [ ] **Step 4: Implement command mapping**

`startMoment(id)` validates the moment and builds:

```dart
MomentPlaybackRequest(
  momentId: moment.id,
  uri: Uri.parse(moment.audio!.uri!),
  loop: moment.endBehavior == EndBehavior.loop,
  narrationEnabled: moment.narrationEnabled,
  gainDb: moment.gainDb,
  fadeIn: moment.fadeIn ?? event.audioSettings.fadeIn,
  fadeOut: activeMoment?.fadeOut ?? event.audioSettings.fadeOut,
)
```

The controller subscribes to `snapshot` and `alerts` once and publishes one `LiveEventState`.

- [ ] **Step 5: Verify and commit**

Run:

```powershell
dart format lib/features/live test/features/live
flutter test test/features/live/application
flutter analyze
```

Expected: live-controller tests pass.

Commit:

```powershell
git add lib/features/live test/features/live
git commit -m "feat: coordinate live event session"
```

### Task 4: Build preflight page and protected entry

**Files:**
- Create: `lib/features/live/presentation/preflight_page.dart`
- Modify: `lib/features/events/presentation/event_editor_page.dart`
- Modify: `lib/app/soundtrack_app.dart`
- Test: `test/features/live/presentation/preflight_page_test.dart`

- [ ] **Step 1: Write failing widget tests**

Test:

- progress while checks run;
- grouped errors and warnings;
- each audio issue names its moment;
- `Reverificar` reruns;
- `Entrar mesmo assim` requires confirmation when errors exist;
- clean preflight shows `Iniciar Modo Evento`.

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test/features/live/presentation/preflight_page_test.dart
```

Expected: FAIL because page is missing.

- [ ] **Step 3: Implement page and navigation**

Enable the editor's Modo Evento button. Navigate:

```text
EventEditorPage → PreflightPage → LiveDashboardPage
```

Do not start audio in preflight. Entering the Dashboard constructs `LiveEventController` with the event snapshot that was checked.

- [ ] **Step 4: Verify and commit**

Run:

```powershell
dart format lib test
flutter test test/features/live/presentation/preflight_page_test.dart
flutter analyze
```

Expected: preflight widget tests pass.

Commit:

```powershell
git add lib test
git commit -m "feat: add protected live-mode entry"
```

### Task 5: Build the live Dashboard

**Files:**
- Create: `lib/features/live/presentation/live_dashboard_page.dart`
- Create: `lib/features/live/presentation/widgets/now_playing_panel.dart`
- Create: `lib/features/live/presentation/widgets/moment_action_button.dart`
- Create: `lib/features/live/presentation/widgets/emergency_volume_panel.dart`
- Create: `lib/features/live/presentation/widgets/playback_controls.dart`
- Create: `lib/features/live/presentation/widgets/live_alert_banner.dart`
- Test: `test/features/live/presentation/live_dashboard_page_test.dart`
- Test: `test/features/live/presentation/dashboard_accessibility_test.dart`

- [ ] **Step 1: Write failing Dashboard tests**

Use stable keys:

```dart
const nowPlayingPanelKey = Key('now-playing-panel');
const emergencyVolumesKey = Key('emergency-volumes');
const pausePlaybackKey = Key('pause-playback');
const stopPlaybackKey = Key('stop-playback');
const narrationKey = Key('narration');
Key liveMomentKey(String id) => Key('live-moment-$id');
```

Assert:

- now-playing panel has no tap callback or button semantics;
- each moment is a button with number, name, track and status;
- active and pending states include text, not color only;
- Narração is absent or disabled when unavailable;
- the three volume sliders are present when expanded;
- stop opens confirmation;
- system back opens exit confirmation and does not stop implicitly.

- [ ] **Step 2: Run tests to verify they fail**

Run:

```powershell
flutter test test/features/live/presentation
```

Expected: FAIL because Dashboard widgets are missing.

- [ ] **Step 3: Implement the visual hierarchy**

`LiveDashboardPage` uses:

```text
Scaffold
 ├─ AppBar: event name, "Modo Evento", output route status
 ├─ LiveAlertBanner
 ├─ NowPlayingPanel (information only)
 ├─ "MOMENTOS — TOQUE PARA INICIAR"
 ├─ Expanded ListView of MomentActionButton
 ├─ PlaybackControls
 └─ EmergencyVolumePanel
```

`MomentActionButton` minimum height is 64 logical pixels. The current button says `ATUAL`; pending says `ÁUDIO PENDENTE`; ready says `TOQUE PARA INICIAR`.

- [ ] **Step 4: Implement controls**

- Pause/resume is immediate and reversible.
- Stop confirmation names the current moment and calls `controller.confirmStop()`.
- Narração is a toggle; active state includes `Narração ativa`.
- Volume changes use values 0–100 in UI and convert to 0–1 in controller.
- `Restaurar predefinições` calls one controller method.
- Session controls are never persisted unless the user later chooses a separate save action outside Modo Evento.

- [ ] **Step 5: Verify and commit**

Run:

```powershell
dart format lib test
flutter test test/features/live/presentation
flutter analyze
```

Expected: Dashboard and accessibility tests pass.

Commit:

```powershell
git add lib test
git commit -m "feat: build protected live Dashboard"
```

### Task 6: Preserve UI state across app switching

**Files:**
- Modify: `lib/features/live/presentation/live_dashboard_page.dart`
- Modify: `lib/features/live/application/live_event_controller.dart`
- Modify: `lib/features/playback/infrastructure/soundtrack_audio_handler.dart`
- Create: `lib/features/live/application/active_live_session_store.dart`
- Modify: `lib/app/soundtrack_app.dart`
- Test: `test/features/live/application/live_event_lifecycle_test.dart`
- Test: `test/features/live/presentation/live_dashboard_lifecycle_test.dart`

- [ ] **Step 1: Write failing lifecycle tests**

Assert:

- `AppLifecycleState.inactive`, `hidden` and `paused` do not call pause or stop;
- returning `resumed` reads current snapshot instead of restarting;
- disposing Dashboard detaches UI listeners but leaves handler playing;
- reopening from the playback notification routes to the active event Dashboard;
- navigating back requires confirmation;
- confirmed exit calls stop and clears session;
- notification remains ongoing while paused during Modo Evento.

- [ ] **Step 2: Run tests to verify they fail**

Run:

```powershell
flutter test test/features/live/application/live_event_lifecycle_test.dart test/features/live/presentation/live_dashboard_lifecycle_test.dart
```

Expected: FAIL until lifecycle policy is explicit.

- [ ] **Step 3: Implement lifecycle policy**

When Modo Evento starts, save its event ID in `ActiveLiveSessionStore`; clear it only after confirmed exit/stop. At app startup and notification return, `SoundTrackApp` reads the store and opens that event's Dashboard when the handler snapshot is not idle.

Use `WidgetsBindingObserver` only to refresh UI metadata and maintain the visible-window flag. Its callback must not invoke playback commands:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    systemStatus.setKeepScreenOn(true);
    controller.refreshFromPlaybackSnapshot();
  } else if (state == AppLifecycleState.inactive ||
      state == AppLifecycleState.hidden ||
      state == AppLifecycleState.paused) {
    systemStatus.setKeepScreenOn(false);
  }
}
```

Enable the flag in `initState` and clear it in `dispose`. Store playback state in the audio handler/coordinator, not widget state. The Dashboard may be recreated and must render from the current snapshot.

- [ ] **Step 4: Verify and commit**

Run:

```powershell
dart format lib test
flutter test test/features/live
flutter analyze
```

Expected: lifecycle tests pass without any automatic pause on app switching.

Commit:

```powershell
git add lib test
git commit -m "feat: preserve live session across app switching"
```

### Task 7: Add final end-to-end and device acceptance

**Files:**
- Create: `integration_test/live_event_flow_test.dart`
- Create: `tool/run_android_acceptance.ps1`
- Create: `docs/qa/mvp-acceptance-checklist.md`
- Modify: `README.md`

- [ ] **Step 1: Write the integration flow**

The test must:

1. create an event;
2. add three moments;
3. select deterministic fixture audio;
4. configure loop, stop, Narração and custom fade;
5. run preflight;
6. enter Dashboard;
7. start moment 1;
8. switch to moment 2;
9. enable and disable Narração;
10. change and restore session volumes;
11. background and resume the app;
12. attempt a missing moment and verify current remains;
13. stop with confirmation;
14. export and import;
15. verify imported audio pending/relink behavior.

- [ ] **Step 2: Create the Android acceptance runner**

`tool/run_android_acceptance.ps1`:

```powershell
$ErrorActionPreference = 'Stop'
flutter analyze
flutter test
flutter test integration_test/event_authoring_flow_test.dart
flutter test integration_test/audio_engine_flow_test.dart
flutter test integration_test/live_event_flow_test.dart
git diff --check
```

The script exits on the first failure and writes no source files.

- [ ] **Step 3: Execute emulator verification**

Run:

```powershell
.\tool\run_android_acceptance.ps1
```

Expected: analyzer, unit/widget tests, three integration suites and diff check pass.

- [ ] **Step 4: Execute physical-device acceptance**

Complete `docs/qa/mvp-acceptance-checklist.md` with:

- event with at least 20 moments;
- wired and Bluetooth output;
- app switching to WhatsApp while playing;
- incoming call;
- disconnect/reconnect route;
- two-hour session;
- 100 moment changes;
- rapid repeated taps;
- narration volume audit;
- import on a second device and manual relinking;
- battery and memory observations.

Any failed acceptance item blocks release and records reproduction steps.

- [ ] **Step 5: Run release-quality verification**

Run:

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --coverage
flutter build apk --debug
git diff --check
git status --short
```

Expected: formatting, analyzer, tests and debug APK build succeed; only acceptance documentation edits remain.

- [ ] **Step 6: Commit final MVP verification**

```powershell
git add README.md docs/qa tool integration_test
git commit -m "test: complete SoundTrack MVP acceptance"
```
