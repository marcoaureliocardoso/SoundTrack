# Live Session Exit Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separar Stop de encerramento do Modo Evento, preservar a sessão ao reiniciar músicas e fazer o Dashboard restaurado retornar corretamente à biblioteca.

**Architecture:** `LiveEventController` passa a expor comandos distintos para parar a reprodução e encerrar a sessão. `LiveDashboardPage` recebe um callback opcional de saída da rota raiz, enquanto `SoundTrackApp` torna a seleção da tela inicial substituível e descarta snapshots sem momento ativo.

**Tech Stack:** Flutter 3.44.2, Dart 3.12.2, Flutter Test, Integration Test e GitHub CLI.

## Global Constraints

- Stop interrompe apenas a reprodução atual e mantém o Modo Evento ativo.
- Somente a saída confirmada limpa `ActiveLiveSessionStore`.
- Falha no Stop não limpa a sessão nem navega.
- Estados `idle`, `stopped` ou sem `activeMomentId` não restauram Dashboard.
- Não alterar foco de áudio, interrupções, fades ou controles visuais.
- Não executar testes em aparelho físico.

---

### Task 1: Separar Stop de encerramento da sessão

**Files:**
- Modify: `test/features/live/application/live_event_lifecycle_test.dart`
- Modify: `lib/features/live/application/live_event_controller.dart:117-128`

**Interfaces:**
- Consumes: `LivePlaybackPort.stop() -> Future<void>` e `ActiveLiveSessionStore.clear() -> Future<void>`.
- Produces: `confirmStop() -> Future<void>` para transporte e `confirmExit() -> Future<void>` para transporte mais encerramento.

- [ ] **Step 1: Substituir o teste de limpeza após Stop por dois testes vermelhos**

Adicionar:

```dart
test('confirmed stop preserves the active live session', () async {
  final playback = FakeLivePlaybackPort();
  final store = MemoryActiveLiveSessionStore();
  final controller = LiveEventController(
    event: SoundTrackEvent.create(id: 'event-1', name: 'Evento'),
    playback: playback,
    activeSessionStore: store,
  );

  await controller.activateSession();
  await controller.confirmStop();

  expect(playback.stopCalls, 1);
  expect(await store.readEventId(), 'event-1');
  await controller.dispose();
});

test('confirmed exit clears the session only after playback stops', () async {
  final playback = FakeLivePlaybackPort();
  final store = MemoryActiveLiveSessionStore();
  final controller = LiveEventController(
    event: SoundTrackEvent.create(id: 'event-1', name: 'Evento'),
    playback: playback,
    activeSessionStore: store,
  );

  await controller.activateSession();
  playback.onStop = () async {
    expect(await store.readEventId(), 'event-1');
  };
  await controller.confirmExit();

  expect(playback.stopCalls, 1);
  expect(await store.readEventId(), isNull);
  await controller.dispose();
});

test('starting again after stop keeps the session restorable', () async {
  final playback = FakeLivePlaybackPort();
  final store = MemoryActiveLiveSessionStore();
  final controller = LiveEventController(
    event: _eventWithReadyMoment(),
    playback: playback,
    activeSessionStore: store,
  );

  await controller.activateSession();
  await controller.confirmStop();
  await controller.startMoment('moment-1');

  expect(playback.requests.last.momentId, 'moment-1');
  expect(await store.readEventId(), 'event-1');
  await controller.dispose();
});

SoundTrackEvent _eventWithReadyMoment() {
  return SoundTrackEvent.create(id: 'event-1', name: 'Evento').addMoment(
    EventMoment.create(
      id: 'moment-1',
      position: 0,
      name: 'Entrada',
    ).copyWith(
      audio: const AudioReference(
        uri: 'file:///entrada.mp3',
        displayName: 'entrada.mp3',
        pending: false,
        artist: null,
        duration: Duration(minutes: 3),
      ),
    ),
  );
}
```

Adicionar os imports de `AudioReference` e `EventMoment` usados pelo helper.

- [ ] **Step 2: Executar os testes e confirmar RED**

Run:

```powershell
flutter test test/features/live/application/live_event_lifecycle_test.dart
```

Expected: FAIL porque `confirmExit` ainda não existe e `confirmStop` limpa a sessão.

- [ ] **Step 3: Implementar a separação mínima no controlador**

Substituir os comandos por:

```dart
Future<void> stop({required bool confirmed}) async {
  if (!confirmed) return;
  await _invokeAndReport(
    _playback.stop,
    'Não foi possível parar a reprodução.',
  );
}

Future<void> confirmStop() => stop(confirmed: true);

Future<void> confirmExit() async {
  await stop(confirmed: true);
  await activeSessionStore?.clear();
}
```

- [ ] **Step 4: Executar os testes e confirmar GREEN**

Run:

```powershell
flutter test test/features/live/application/live_event_lifecycle_test.dart
flutter test test/features/live/application/live_event_controller_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commitar a semântica do controlador**

```powershell
git add lib/features/live/application/live_event_controller.dart test/features/live/application/live_event_lifecycle_test.dart
git commit -m "fix: keep live session active after stop"
```

---

### Task 2: Corrigir saída e restauração da rota raiz

**Files:**
- Modify: `test/features/live/presentation/live_dashboard_lifecycle_test.dart`
- Modify: `lib/features/live/presentation/live_dashboard_page.dart:24-46,431-458`
- Modify: `lib/app/soundtrack_app.dart:20-120`

**Interfaces:**
- Consumes: `LiveEventController.confirmExit() -> Future<void>` da Task 1.
- Produces: parâmetro opcional `Future<void> Function()? onSessionExit` em `LiveDashboardPage`.

- [ ] **Step 1: Escrever teste vermelho para saída do Dashboard restaurado**

Adicionar ao teste de lifecycle:

```dart
testWidgets('restored dashboard exit returns to the event library', (
  tester,
) async {
  final event = _event();
  final playback = FakeLivePlaybackPort();
  playback.snapshotNotifier.value = const PlaybackSnapshot.idle().copyWith(
    phase: PlaybackPhase.playing,
    playing: true,
    activeMomentId: 'moment-1',
  );
  final store = MemoryActiveLiveSessionStore();
  await store.saveEventId(event.id);

  await tester.pumpWidget(
    SoundTrackApp(
      dependencies: AppDependencies(
        eventRepository: InMemoryEventRepository([event]),
        newEventId: () => 'unused',
        newMomentId: () => 'unused',
        playback: playback,
        activeLiveSessionStore: store,
        systemStatus: _SystemStatus(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(LiveDashboardPage), findsOneWidget);

  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sair'));
  await tester.pumpAndSettle();

  expect(find.byType(EventLibraryPage), findsOneWidget);
  expect(find.byType(LiveDashboardPage), findsNothing);
  expect(await store.readEventId(), isNull);
});
```

- [ ] **Step 2: Escrever teste vermelho para snapshot stopped obsoleto**

Duplicar o teste de sessão idle, mas configurar:

```dart
playback.snapshotNotifier.value = const PlaybackSnapshot.idle().copyWith(
  phase: PlaybackPhase.stopped,
);
```

Esperar biblioteca visível e store limpo.

- [ ] **Step 3: Executar os testes e confirmar RED**

Run:

```powershell
flutter test test/features/live/presentation/live_dashboard_lifecycle_test.dart
```

Expected: FAIL porque a rota raiz não revela a biblioteca e `stopped` ainda é restaurado.

- [ ] **Step 4: Adicionar callback de encerramento ao Dashboard**

Adicionar ao widget:

```dart
const LiveDashboardPage({
  required this.controller,
  this.onSessionExit,
  this.outputRouteLabel = 'Saída não confirmada',
  this.readOutputRoute,
  this.systemStatus,
  this.momentBuilder,
  super.key,
});

final Future<void> Function()? onSessionExit;
```

Após a confirmação:

```dart
await widget.controller.confirmExit();
if (!mounted) return;
final onSessionExit = widget.onSessionExit;
if (onSessionExit != null) {
  await onSessionExit();
  return;
}
setState(() => _allowPop = true);
Navigator.of(context).pop();
```

- [ ] **Step 5: Tornar a tela inicial substituível e rejeitar sessão obsoleta**

Em `SoundTrackApp`, tornar `_activeEvent` mutável e adicionar:

```dart
Future<void> _leaveRestoredSession() async {
  if (!mounted) return;
  setState(() => _activeEvent = Future<SoundTrackEvent?>.value());
}
```

Passar `onSessionExit: _leaveRestoredSession` apenas em `_buildLiveDashboard`.
Na restauração, usar:

```dart
final inactive =
    playback.phase == PlaybackPhase.idle ||
    playback.phase == PlaybackPhase.stopped ||
    playback.activeMomentId == null;
if (inactive) {
  await store.clear();
  return null;
}
```

- [ ] **Step 6: Executar testes focados e confirmar GREEN**

Run:

```powershell
flutter test test/features/live/presentation/live_dashboard_lifecycle_test.dart
flutter test test/app/soundtrack_app_test.dart
flutter test test/features/live/presentation/live_dashboard_page_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commitar restauração e saída**

```powershell
git add lib/app/soundtrack_app.dart lib/features/live/presentation/live_dashboard_page.dart test/features/live/presentation/live_dashboard_lifecycle_test.dart
git commit -m "fix: exit restored live dashboard to library"
```

---

### Task 3: Atualizar o fluxo integrado e publicar a correção

**Files:**
- Modify: `integration_test/live_event_flow_test.dart`

**Interfaces:**
- Consumes: semântica de `confirmStop` e `confirmExit` das Tasks 1 e 2.
- Produces: cobertura de regressão end-to-end e atualização do PR #1.

- [ ] **Step 1: Atualizar o teste integrado para preservar a sessão após Stop**

Após confirmar Stop, esperar:

```dart
expect(playback.stopCalls, 1);
expect(await activeSessionStore.readEventId(), event.id);
```

Depois de confirmar Sair, esperar:

```dart
expect(await activeSessionStore.readEventId(), isNull);
```

- [ ] **Step 2: Executar o fluxo integrado no emulador**

Run:

```powershell
flutter test integration_test/live_event_flow_test.dart -d emulator-5554 --reporter compact
```

Expected: PASS.

- [ ] **Step 3: Executar o gate completo**

Run:

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --coverage
flutter build apk --debug
git diff --check
git status --short
```

Expected: formatação sem alterações, análise limpa, 343 ou mais testes aprovados, APK gerado e apenas arquivos intencionais modificados.

- [ ] **Step 4: Commitar a regressão integrada**

```powershell
git add integration_test/live_event_flow_test.dart
git commit -m "test: cover restored live session exit"
```

- [ ] **Step 5: Publicar a branch e responder aos threads**

```powershell
git push origin feature/soundtrack-mvp
```

Responder em cada thread com o commit correspondente e o teste executado. Depois, resolver os threads GraphQL `PRRT_kwDOTI1VCc6QAfwr` e `PRRT_kwDOTI1VCc6QAfwt` somente após o push ser confirmado.
