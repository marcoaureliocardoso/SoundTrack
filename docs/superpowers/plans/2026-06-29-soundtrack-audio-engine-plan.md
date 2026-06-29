# SoundTrack Audio Engine and Background Playback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar reprodução local confiável com dois players, crossfade cancelável, volumes compostos, Narração, repetição, continuidade em segundo plano e retomada após interrupções impostas pelo Android.

**Architecture:** Regras e estado vivem em Dart puro, atrás de `LivePlaybackPort`. `PlaybackCoordinator` controla dois `PlayerPort`s e é a única unidade que troca o momento atual. `SoundTrackAudioHandler` adapta o coordenador ao `audio_service`; `JustAudioPlayerPort` adapta cada `AudioPlayer`.

**Tech Stack:** Flutter 3.44.2, Dart 3.12.2, `just_audio`, `audio_service`, `audio_session`, Kotlin/Android e Flutter Test.

---

## File map

- `lib/features/playback/domain/playback_snapshot.dart`: estado imutável exposto à UI.
- `lib/features/playback/domain/playback_alert.dart`: falhas e mudanças de rota não bloqueantes.
- `lib/features/playback/domain/volume_policy.dart`: composição Master × modo × ganho.
- `lib/features/playback/application/live_playback_port.dart`: contrato usado pelo Dashboard.
- `lib/features/playback/application/player_port.dart`: menor contrato de um player.
- `lib/features/playback/application/playback_coordinator.dart`: máquina de estados e dois players.
- `lib/features/playback/application/fade_driver.dart`: rampas canceláveis testáveis.
- `lib/features/playback/infrastructure/just_audio_player_port.dart`: adaptador `just_audio`.
- `lib/features/playback/infrastructure/soundtrack_audio_handler.dart`: `BaseAudioHandler`.
- `lib/features/playback/infrastructure/audio_session_observer.dart`: foco, chamada e rota.
- `lib/features/playback/infrastructure/audio_engine_factory.dart`: composição de produção.
- `lib/features/playback/presentation/audio_engine_lab_page.dart`: tela técnica temporária.
- `test/features/playback/`: regras, coordinator, handler e fakes.
- `integration_test/audio_engine_flow_test.dart`: integração com fonte local.

### Task 1: Add audio dependencies and playback contracts

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/features/playback/domain/playback_alert.dart`
- Create: `lib/features/playback/domain/playback_snapshot.dart`
- Create: `lib/features/playback/application/live_playback_port.dart`
- Create: `lib/features/playback/application/player_port.dart`
- Test: `test/features/playback/domain/playback_snapshot_test.dart`

- [ ] **Step 1: Add compatible audio packages**

Run:

```powershell
flutter pub add just_audio audio_service audio_session
```

Expected: the lockfile resolves one version of each package compatible with Dart 3.12.2. Record resolved versions in the plan execution notes; do not hand-edit `pubspec.lock`.

- [ ] **Step 2: Write a failing snapshot test**

Create `test/features/playback/domain/playback_snapshot_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/playback/domain/playback_snapshot.dart';

void main() {
  test('idle snapshot has no active moment and zero position', () {
    const snapshot = PlaybackSnapshot.idle();
    expect(snapshot.activeMomentId, isNull);
    expect(snapshot.position, Duration.zero);
    expect(snapshot.playing, isFalse);
    expect(snapshot.narrationActive, isFalse);
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run:

```powershell
flutter test test/features/playback/domain/playback_snapshot_test.dart
```

Expected: FAIL because the playback domain is missing.

- [ ] **Step 4: Implement immutable state and ports**

Create `playback_alert.dart`:

```dart
enum PlaybackAlertCode {
  sourceUnavailable,
  sourceFailed,
  routeChanged,
  interruptionStarted,
  interruptionEnded,
}

class PlaybackAlert {
  const PlaybackAlert(this.code, this.message, {this.momentId});
  final PlaybackAlertCode code;
  final String message;
  final String? momentId;
}
```

Create `playback_snapshot.dart`:

```dart
enum PlaybackPhase { idle, loading, playing, paused, transitioning, stopped }

class PlaybackSnapshot {
  const PlaybackSnapshot({
    required this.phase,
    required this.playing,
    required this.position,
    required this.duration,
    required this.narrationActive,
    required this.masterVolume,
    required this.musicVolume,
    required this.narrationVolume,
    this.activeMomentId,
  });

  const PlaybackSnapshot.idle()
      : phase = PlaybackPhase.idle,
        playing = false,
        position = Duration.zero,
        duration = null,
        narrationActive = false,
        masterVolume = 0.8,
        musicVolume = 1,
        narrationVolume = 0.25,
        activeMomentId = null;

  final PlaybackPhase phase;
  final bool playing;
  final Duration position;
  final Duration? duration;
  final bool narrationActive;
  final double masterVolume;
  final double musicVolume;
  final double narrationVolume;
  final String? activeMomentId;

  PlaybackSnapshot copyWith({
    PlaybackPhase? phase,
    bool? playing,
    Duration? position,
    Duration? duration,
    bool? narrationActive,
    double? masterVolume,
    double? musicVolume,
    double? narrationVolume,
    String? activeMomentId,
    bool clearActiveMoment = false,
  }) {
    return PlaybackSnapshot(
      phase: phase ?? this.phase,
      playing: playing ?? this.playing,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      narrationActive: narrationActive ?? this.narrationActive,
      masterVolume: masterVolume ?? this.masterVolume,
      musicVolume: musicVolume ?? this.musicVolume,
      narrationVolume: narrationVolume ?? this.narrationVolume,
      activeMomentId:
          clearActiveMoment ? null : activeMomentId ?? this.activeMomentId,
    );
  }
}
```

Define `LivePlaybackPort` with `ValueListenable<PlaybackSnapshot> snapshot`, `Stream<PlaybackAlert> alerts`, and async commands `startMoment`, `pause`, `resume`, `stop`, `setNarration`, `setSessionVolumes`, `restorePresetVolumes`, `dispose`.

Define `PlayerPort` with `load(Uri)`, `play`, `pause`, `stop`, `seek`, `setVolume`, `setLooping`, `position`, `duration`, `completed`, `errors`, and `dispose`.

- [ ] **Step 5: Verify and commit**

Run:

```powershell
dart format lib/features/playback test/features/playback
flutter analyze
flutter test test/features/playback/domain
```

Expected: snapshot test passes and analyzer is clean.

Commit:

```powershell
git add pubspec.yaml pubspec.lock lib/features/playback test/features/playback
git commit -m "feat: define playback contracts"
```

### Task 2: Implement volume policy and cancelable fades

**Files:**
- Create: `lib/features/playback/domain/volume_policy.dart`
- Create: `lib/features/playback/application/fade_driver.dart`
- Test: `test/features/playback/domain/volume_policy_test.dart`
- Test: `test/features/playback/application/fade_driver_test.dart`

- [ ] **Step 1: Write failing volume tests**

Create `volume_policy_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/playback/domain/volume_policy.dart';

void main() {
  test('composes master music and zero dB gain', () {
    expect(
      effectiveVolume(
        master: 0.8,
        modeVolume: 0.5,
        gainDb: 0,
      ),
      closeTo(0.4, 0.0001),
    );
  });

  test('clamps positive gain to player range', () {
    expect(
      effectiveVolume(master: 1, modeVolume: 1, gainDb: 6),
      1,
    );
  });
}
```

Use the dB conversion `pow(10, gainDb / 20)`.

- [ ] **Step 2: Write a failing fade cancellation test**

Inject a `FadeScheduler` that emits deterministic fractions. Assert that starting fade B cancels fade A and B begins from the most recently applied value, not from its original endpoint.

Scheduler contract used by the test:

```dart
abstract interface class FadeScheduler {
  Stream<double> fractions(Duration duration);
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```powershell
flutter test test/features/playback/domain/volume_policy_test.dart test/features/playback/application/fade_driver_test.dart
```

Expected: FAIL because policy and driver are missing.

- [ ] **Step 4: Implement policy and driver**

Create `volume_policy.dart`:

```dart
import 'dart:math';

double effectiveVolume({
  required double master,
  required double modeVolume,
  required double gainDb,
}) {
  final linearGain = pow(10, gainDb / 20).toDouble();
  return (master * modeVolume * linearGain).clamp(0.0, 1.0).toDouble();
}
```

Add:

```dart
import 'dart:math';

class TimerFadeScheduler implements FadeScheduler {
  const TimerFadeScheduler();

  @override
  Stream<double> fractions(Duration duration) async* {
    if (duration == Duration.zero) {
      yield 1;
      return;
    }
    final steps = max(1, duration.inMilliseconds ~/ 50);
    for (var step = 1; step <= steps; step++) {
      await Future<void>.delayed(duration ~/ steps);
      yield step / steps;
    }
  }
}

class FadeDriver {
  FadeDriver({required FadeScheduler scheduler}) : _scheduler = scheduler;

  final FadeScheduler _scheduler;
  int _generation = 0;

  Future<void> run({
    required double from,
    required double to,
    required Duration duration,
    required Future<void> Function(double value) apply,
  }) async {
    final generation = ++_generation;
    for await (final fraction in _scheduler.fractions(duration)) {
      if (generation != _generation) return;
      await apply(from + ((to - from) * fraction));
    }
  }

  void cancel() {
    _generation += 1;
  }
}
```

The coordinator records the last applied player volume and supplies it as `from` when a new request supersedes an existing fade.

- [ ] **Step 5: Verify and commit**

Run:

```powershell
dart format lib/features/playback test/features/playback
flutter test test/features/playback/domain test/features/playback/application/fade_driver_test.dart
flutter analyze
```

Expected: volume and cancellation tests pass.

Commit:

```powershell
git add lib/features/playback test/features/playback
git commit -m "feat: add volume policy and fade driver"
```

### Task 3: Implement PlaybackCoordinator with two fakeable players

**Files:**
- Create: `lib/features/playback/application/playback_coordinator.dart`
- Create: `test/support/fake_player_port.dart`
- Test: `test/features/playback/application/playback_coordinator_test.dart`

- [ ] **Step 1: Write failing coordinator tests**

Cover these cases with two `FakePlayerPort`s:

1. first moment loads at volume 0 and fades in;
2. transition preloads standby before fading active;
3. failed standby load leaves active playing and snapshot unchanged;
4. tapping active moment is a no-op;
5. loop/stop end behavior is applied;
6. Narração changes mode volume and resets on transition;
7. pause preserves position and resume continues;
8. stop clears active moment;
9. latest tap supersedes an in-flight transition.

Define command input:

```dart
class MomentPlaybackRequest {
  const MomentPlaybackRequest({
    required this.momentId,
    required this.uri,
    required this.loop,
    required this.narrationEnabled,
    required this.gainDb,
    required this.fadeIn,
    required this.fadeOut,
  });
  final String momentId;
  final Uri uri;
  final bool loop;
  final bool narrationEnabled;
  final double gainDb;
  final Duration fadeIn;
  final Duration fadeOut;
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```powershell
flutter test test/features/playback/application/playback_coordinator_test.dart
```

Expected: FAIL because coordinator is missing.

- [ ] **Step 3: Implement the state machine**

`PlaybackCoordinator` constructor:

```dart
PlaybackCoordinator({
  required PlayerPort playerA,
  required PlayerPort playerB,
  required FadeDriver outgoingFade,
  required FadeDriver incomingFade,
  required EventAudioSettings presetVolumes,
});
```

Transition invariants:

- `_active` is never replaced before `_standby.load` succeeds;
- standby starts at zero volume;
- incoming/outgoing fades run concurrently with `Future.wait`;
- on success, old active stops and roles swap;
- on failure, standby stops and active volume returns to its effective target;
- each request increments `_requestGeneration`; stale work cannot commit state;
- the current snapshot is updated from one method `_publish`.

Subscribe once to player completion/error streams and cancel all subscriptions in `dispose()`.

- [ ] **Step 4: Verify and commit**

Run:

```powershell
dart format lib/features/playback test/features/playback test/support
flutter test test/features/playback/application
flutter analyze
```

Expected: all coordinator invariants pass.

Commit:

```powershell
git add lib/features/playback test/features/playback test/support
git commit -m "feat: coordinate dual-player transitions"
```

### Task 4: Adapt just_audio to PlayerPort

**Files:**
- Create: `lib/features/playback/infrastructure/just_audio_player_port.dart`
- Test: `test/features/playback/infrastructure/just_audio_player_port_contract_test.dart`

- [ ] **Step 1: Write a contract test around an injected backend**

Extract a private-independent `JustAudioBackend` interface so unit tests can verify mappings without platform audio. Test that:

- `load(content://...)` delegates to `setAudioSource(AudioSource.uri(uri))`;
- loop maps to `LoopMode.one` or `LoopMode.off`;
- `PlayerException` becomes `PlayerPortError`;
- `stop()` releases decoder state but `dispose()` is final.

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test/features/playback/infrastructure/just_audio_player_port_contract_test.dart
```

Expected: FAIL because adapter is missing.

- [ ] **Step 3: Implement production adapter**

Create each production player as:

```dart
AudioPlayer(
  handleInterruptions: false,
  handleAudioSessionActivation: true,
)
```

Manual interruption handling is required by the continuity policy. Keep Android offload disabled, because crossfade and simultaneous players require predictable per-player volume.

Map:

```dart
await player.setAudioSource(AudioSource.uri(uri));
await player.setLoopMode(looping ? LoopMode.one : LoopMode.off);
await player.setVolume(volume.clamp(0.0, 1.0));
```

Forward `positionStream`, `durationStream`, `processingStateStream` completion and `errorStream`.

- [ ] **Step 4: Verify and commit**

Run:

```powershell
dart format lib/features/playback/infrastructure test/features/playback/infrastructure
flutter test test/features/playback/infrastructure
flutter analyze
```

Expected: adapter contract tests pass.

Commit:

```powershell
git add lib/features/playback/infrastructure test/features/playback/infrastructure
git commit -m "feat: adapt just_audio players"
```

### Task 5: Add AudioService handler and foreground playback configuration

**Files:**
- Create: `lib/features/playback/infrastructure/soundtrack_audio_handler.dart`
- Create: `lib/features/playback/infrastructure/audio_engine_factory.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `lib/app/app_dependencies.dart`
- Modify: `lib/main.dart`
- Test: `test/features/playback/infrastructure/soundtrack_audio_handler_test.dart`

- [ ] **Step 1: Write failing AudioHandler tests**

With a fake `PlaybackCoordinator`, assert:

- `playMediaItem` decodes `MomentPlaybackRequest` from `MediaItem.extras`;
- `pause`, `play` and `stop` delegate;
- playback state mirrors snapshot;
- notification has only safe controls: pause/resume and return-to-app; no next/previous;
- active media item contains moment name and audio filename.

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test/features/playback/infrastructure/soundtrack_audio_handler_test.dart
```

Expected: FAIL because the handler is missing.

- [ ] **Step 3: Implement SoundTrackAudioHandler**

Extend `BaseAudioHandler` and implement `LivePlaybackPort` on the same class. The Flutter UI receives this handler through `AppDependencies`, so every UI command passes through the background owner rather than reaching `PlaybackCoordinator` directly. Subscribe to coordinator snapshot and map phases:

```dart
playbackState.add(PlaybackState(
  controls: snapshot.playing
      ? const [MediaControl.pause]
      : const [MediaControl.play],
  androidCompactActionIndices: const [0],
  processingState: switch (snapshot.phase) {
    PlaybackPhase.loading || PlaybackPhase.transitioning =>
      AudioProcessingState.loading,
    PlaybackPhase.idle || PlaybackPhase.stopped =>
      AudioProcessingState.idle,
    _ => AudioProcessingState.ready,
  },
  playing: snapshot.playing,
  updatePosition: snapshot.position,
));
```

Use `customAction` for `startMoment`, `setNarration`, `setSessionVolumes`, and `restorePresetVolumes`; validate every payload before delegating.

- [ ] **Step 4: Initialize AudioService and Android manifest**

`AudioEngineFactory.create()` builds the two players, fades, coordinator, observer and handler. Initialize once before `runApp`:

```dart
final audioHandler = await AudioService.init(
  builder: dependencies.audioHandlerBuilder,
  config: const AudioServiceConfig(
    androidNotificationChannelId: 'com.soundtrack.playback',
    androidNotificationChannelName: 'Evento em execução',
    androidNotificationClickStartsActivity: true,
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: false,
  ),
);
```

Follow the installed `audio_service` package manifest instructions exactly. Confirm the merged manifest declares:

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
```

and the service has `android:foregroundServiceType="mediaPlayback"`.

- [ ] **Step 5: Verify and commit**

Run:

```powershell
dart format lib test
flutter analyze
flutter test test/features/playback
Set-Location android
.\gradlew.bat processDebugMainManifest
Set-Location ..
```

Expected: handler tests pass and merged manifest contains media playback service type.

Commit:

```powershell
git add lib android/app/src/main/AndroidManifest.xml test
git commit -m "feat: run playback through audio service"
```

### Task 6: Implement continuity-first interruption and route policy

**Files:**
- Create: `lib/features/playback/infrastructure/audio_session_observer.dart`
- Modify: `lib/features/playback/application/playback_coordinator.dart`
- Test: `test/features/playback/infrastructure/audio_session_observer_test.dart`
- Test: `test/features/playback/application/playback_interruption_test.dart`

- [ ] **Step 1: Write failing policy tests**

Test:

- `becomingNoisy` emits route alert and never calls pause;
- interruption begin records whether playback was active;
- interruption end automatically resumes only if playback was active and user did not press Pause/Stop during interruption;
- system duck is observed but does not alter session sliders;
- repeated end events do not double-resume.

- [ ] **Step 2: Run tests to verify they fail**

Run:

```powershell
flutter test test/features/playback/infrastructure/audio_session_observer_test.dart test/features/playback/application/playback_interruption_test.dart
```

Expected: FAIL because observer behavior is missing.

- [ ] **Step 3: Implement AudioSessionObserver**

Configure:

```dart
await session.configure(
  const AudioSessionConfiguration.music().copyWith(
    androidWillPauseWhenDucked: false,
  ),
);
```

Subscribe to `interruptionEventStream`, `becomingNoisyEventStream`, and `devicesChangedEventStream`. Emit typed events to coordinator. Do not call player methods from the observer.

Coordinator stores `_resumeAfterInterruption`. User pause/stop clears it; interruption end attempts `resume()`, and emits an alert if focus activation is denied.

- [ ] **Step 4: Verify on unit tests and document OS limitation**

Run:

```powershell
dart format lib test
flutter analyze
flutter test test/features/playback
```

Expected: all policy tests pass.

Add to `README.md`: Android 12+ may force fade/mute on focus loss or calls; SoundTrack preserves state and resumes automatically when focus returns.

Commit:

```powershell
git add lib test README.md
git commit -m "feat: preserve playback across interruptions"
```

### Task 7: Audio engine lab and integration checkpoint

**Files:**
- Create: `lib/features/playback/presentation/audio_engine_lab_page.dart`
- Create: `integration_test/audio_engine_flow_test.dart`
- Create: `docs/qa/audio-engine-checklist.md`
- Modify: `lib/app/soundtrack_app.dart`

- [ ] **Step 1: Build a debug-only audio lab**

The lab accepts two `content://` URIs from the existing document gateway and exposes:

- Load A;
- Load B;
- Crossfade A→B and B→A;
- loop toggle;
- Master, Música, Narração and gain controls;
- Narração toggle;
- live snapshot and last alert.

Expose the page only under `kDebugMode`; production navigation must not show it.

- [ ] **Step 2: Add integration tests**

Use bundled test assets copied to app storage for deterministic emulator tests. Assert snapshot order and volume endpoints; do not assert audible output in automation.

Run:

```powershell
flutter test integration_test/audio_engine_flow_test.dart
```

Expected: first play, crossfade, failed target preservation, Narração and stop scenarios pass.

- [ ] **Step 3: Execute physical-device checklist**

`docs/qa/audio-engine-checklist.md` records:

- device and Android version;
- wired output transition;
- Bluetooth disconnect/reconnect;
- incoming call behavior;
- WhatsApp switch while playing;
- 50 consecutive crossfades;
- two-hour loop;
- rapid taps during fade;
- missing/deleted source.

Record observed gaps as issues before proceeding to the live plan.

- [ ] **Step 4: Run full verification and commit**

Run:

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test/audio_engine_flow_test.dart
git diff --check
```

Expected: all automated checks pass; physical checklist contains explicit results.

Commit:

```powershell
git add lib test integration_test docs/qa README.md
git commit -m "test: validate audio engine flows"
```
