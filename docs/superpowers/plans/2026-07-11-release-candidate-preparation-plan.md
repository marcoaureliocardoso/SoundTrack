# SoundTrack Release Candidate Preparation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preparar o SoundTrack `1.0.0-rc.1+1` com identidade Android definitiva, assinatura release protegida e documentação coerente, entregando uma Pull Request sem publicar artefatos.

**Architecture:** A identidade Android será migrada como uma unidade entre Gradle, Kotlin, MethodChannels e configuração do serviço de áudio. A assinatura será uma capacidade opcional para debug e obrigatória para qualquer task release, com credenciais externas ao Git. Documentação e checklist formarão a fonte operacional para promover o RC depois da criação do keystore.

**Tech Stack:** Flutter 3.44.2, Dart 3.12.2, Android Gradle Plugin 9.0.1, Kotlin 2.3.20, Gradle Kotlin DSL, PowerShell, GitHub CLI.

## Global Constraints

- Versão Flutter/Android: `1.0.0-rc.1+1`.
- Identidade Android: `br.com.marcocardoso.soundtrack`.
- Nome exibido: `SoundTrack`.
- Pacote Dart permanece `soundtrack`.
- Esquema de exportação permanece `schemaVersion: 1`.
- Builds debug não dependem de keystore.
- Builds release sem `android/key.properties` falham com mensagem explícita.
- Nenhuma credencial, chave ou caminho pessoal entra no Git.
- Testes físicos manuais adiados não são marcados como aprovados.
- Nenhuma tag, GitHub Release ou APK oficial é publicado nesta rodada.

---

### Task 1: Migrar versão e identidade Android

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Move/Modify: `android/app/src/main/kotlin/com/soundtrack/soundtrack/MainActivity.kt` → `android/app/src/main/kotlin/br/com/marcocardoso/soundtrack/MainActivity.kt`
- Move/Modify: `android/app/src/main/kotlin/com/soundtrack/soundtrack/DocumentChannel.kt` → `android/app/src/main/kotlin/br/com/marcocardoso/soundtrack/DocumentChannel.kt`
- Move/Modify: `android/app/src/main/kotlin/com/soundtrack/soundtrack/DocumentIo.kt` → `android/app/src/main/kotlin/br/com/marcocardoso/soundtrack/DocumentIo.kt`
- Move/Modify: `android/app/src/main/kotlin/com/soundtrack/soundtrack/SystemStatusChannel.kt` → `android/app/src/main/kotlin/br/com/marcocardoso/soundtrack/SystemStatusChannel.kt`
- Move/Modify: `android/app/src/test/kotlin/com/soundtrack/soundtrack/DocumentIoTest.kt` → `android/app/src/test/kotlin/br/com/marcocardoso/soundtrack/DocumentIoTest.kt`
- Move/Modify: `android/app/src/test/kotlin/com/soundtrack/soundtrack/DocumentMetadataTest.kt` → `android/app/src/test/kotlin/br/com/marcocardoso/soundtrack/DocumentMetadataTest.kt`
- Move/Modify: `android/app/src/test/kotlin/com/soundtrack/soundtrack/SystemStatusMappingTest.kt` → `android/app/src/test/kotlin/br/com/marcocardoso/soundtrack/SystemStatusMappingTest.kt`
- Modify: `lib/main.dart`
- Modify: `lib/platform/documents/method_channel_document_gateway.dart`
- Modify: `lib/platform/system/method_channel_system_status_gateway.dart`
- Modify: `test/app/startup_test.dart`
- Modify: `test/platform/documents/method_channel_document_gateway_test.dart`
- Modify: `test/platform/system/method_channel_system_status_gateway_test.dart`
- Create: `test/app/release_metadata_test.dart`

**Interfaces:**
- Consumes: `AudioServiceConfig`, Flutter `MethodChannel`, Android `MainActivity`.
- Produces: application ID, namespace and package `br.com.marcocardoso.soundtrack`; channels `br.com.marcocardoso.soundtrack/documents`, `br.com.marcocardoso.soundtrack/system_status` and `br.com.marcocardoso.soundtrack.playback`.

- [ ] **Step 1: Escrever testes vermelhos da identidade aprovada**

Add to `test/app/startup_test.dart`:

```dart
test('uses the final Android notification channel', () {
  expect(
    app.soundTrackAudioServiceConfig.androidNotificationChannelId,
    'br.com.marcocardoso.soundtrack.playback',
  );
});
```

Change the channel constants in the two MethodChannel tests to:

```dart
const channel = MethodChannel(
  'br.com.marcocardoso.soundtrack/documents',
);
```

and:

```dart
const channel = MethodChannel(
  'br.com.marcocardoso.soundtrack/system_status',
);
```

Create `test/app/release_metadata_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RC metadata uses the approved version and Android identity', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(pubspec, contains('version: 1.0.0-rc.1+1'));
    expect(
      pubspec,
      contains(
        'description: "Trilha sonora contínua e controlada para eventos."',
      ),
    );
    expect(
      gradle,
      contains('namespace = "br.com.marcocardoso.soundtrack"'),
    );
    expect(
      gradle,
      contains('applicationId = "br.com.marcocardoso.soundtrack"'),
    );
    expect(manifest, contains('android:label="SoundTrack"'));
  });
}
```

- [ ] **Step 2: Executar os testes e confirmar o estado vermelho**

Run:

```powershell
flutter test test\app\startup_test.dart test\app\release_metadata_test.dart test\platform\documents\method_channel_document_gateway_test.dart test\platform\system\method_channel_system_status_gateway_test.dart
```

Expected: FAIL nas quatro expectativas novas porque a versão, identidade e canais antigos ainda estão presentes.

- [ ] **Step 3: Aplicar a versão, metadados e canais**

Set in `pubspec.yaml`:

```yaml
description: "Trilha sonora contínua e controlada para eventos."
version: 1.0.0-rc.1+1
```

Set in `android/app/build.gradle.kts`:

```kotlin
namespace = "br.com.marcocardoso.soundtrack"
```

and:

```kotlin
applicationId = "br.com.marcocardoso.soundtrack"
```

Set in the manifest:

```xml
android:label="SoundTrack"
```

Change the four main Kotlin files and three Kotlin tests to:

```kotlin
package br.com.marcocardoso.soundtrack
```

Move them to the matching `br/com/marcocardoso/soundtrack` directories. Change the native and Dart MethodChannel values to:

```text
br.com.marcocardoso.soundtrack/documents
br.com.marcocardoso.soundtrack/system_status
```

Change `soundTrackAudioServiceConfig` to:

```dart
androidNotificationChannelId: 'br.com.marcocardoso.soundtrack.playback',
```

- [ ] **Step 4: Validar testes Dart, Kotlin e APK debug**

Run:

```powershell
flutter test test\app\startup_test.dart test\app\release_metadata_test.dart test\platform\documents\method_channel_document_gateway_test.dart test\platform\system\method_channel_system_status_gateway_test.dart
Push-Location android
.\gradlew.bat testDebugUnitTest
Pop-Location
flutter build apk --debug
rg -n "com\.soundtrack" android lib test integration_test
```

Expected: testes e build PASS; a busca termina sem ocorrências.

- [ ] **Step 5: Commitar a migração de identidade**

```powershell
git add pubspec.yaml android lib test
git commit -m "build: prepare Android RC identity"
```

---

### Task 2: Proteger a assinatura release

**Files:**
- Modify: `android/app/build.gradle.kts`
- Verify: `android/.gitignore`
- Create: `test/app/release_signing_configuration_test.dart`

**Interfaces:**
- Consumes: `android/key.properties` com `storeFile`, `storePassword`, `keyAlias` e `keyPassword`.
- Produces: signing config `release` quando completa e task `validateReleaseSigning` que bloqueia todas as tasks release sem credenciais.

- [ ] **Step 1: Escrever o teste vermelho da proteção de assinatura**

Create `test/app/release_signing_configuration_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release signing never falls back to the debug key', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final ignore = File('android/.gitignore').readAsStringSync();

    expect(gradle, contains('rootProject.file("key.properties")'));
    expect(gradle, contains('validateReleaseSigning'));
    expect(
      gradle,
      contains('Release signing is not configured'),
    );
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
    expect(ignore, contains('key.properties'));
    expect(ignore, contains('**/*.jks'));
  });
}
```

- [ ] **Step 2: Confirmar o teste vermelho e o comportamento inseguro atual**

Run:

```powershell
flutter test test\app\release_signing_configuration_test.dart
flutter build apk --release
```

Expected: o teste FAIL e o build release atual conclui usando a chave debug, demonstrando o problema.

- [ ] **Step 3: Implementar carregamento e validação do key.properties**

Add at the top of `android/app/build.gradle.kts`:

```kotlin
import java.util.Properties
import org.gradle.api.GradleException

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use(::load)
    }
}
val releaseSigningKeys =
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val releaseSigningConfigured =
    keystorePropertiesFile.exists() &&
        releaseSigningKeys.all { key ->
            !keystoreProperties.getProperty(key).isNullOrBlank()
        }
```

Inside `android {}` add:

```kotlin
signingConfigs {
    create("release") {
        if (releaseSigningConfigured) {
            storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
        }
    }
}
```

Replace the existing release block with:

```kotlin
buildTypes {
    release {
        if (releaseSigningConfigured) {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

After `android {}` add:

```kotlin
val validateReleaseSigning = tasks.register("validateReleaseSigning") {
    doLast {
        if (!releaseSigningConfigured) {
            throw GradleException(
                "Release signing is not configured. Create android/key.properties " +
                    "with storeFile, storePassword, keyAlias and keyPassword.",
            )
        }
    }
}

tasks.configureEach {
    if (name.contains("Release") && name != "validateReleaseSigning") {
        dependsOn(validateReleaseSigning)
    }
}
```

- [ ] **Step 4: Verificar debug permitido e release bloqueado**

Run:

```powershell
flutter test test\app\release_signing_configuration_test.dart
flutter build apk --debug
flutter build apk --release
```

Expected: teste e debug PASS; release FAIL com `Release signing is not configured`; nenhum APK release é publicado.

- [ ] **Step 5: Commitar a proteção de assinatura**

```powershell
git add android\app\build.gradle.kts test\app\release_signing_configuration_test.dart
git commit -m "build: require private release signing"
```

---

### Task 3: Atualizar documentação e evidências do RC

**Files:**
- Modify: `README.md`
- Create: `CHANGELOG.md`
- Create: `docs/release/versioning.md`
- Create: `docs/release/android-signing.md`
- Create: `docs/superpowers/README.md`
- Modify: `docs/qa/mvp-acceptance-checklist.md`

**Interfaces:**
- Consumes: decisões da especificação e evidências de 344 testes mais três fluxos no moto g54 5G.
- Produces: instruções de desenvolvimento, versionamento, assinatura, histórico e checklist auditável.

- [ ] **Step 1: Reescrever o README como porta de entrada do produto**

Use these sections, in order:

```markdown
# SoundTrack

SoundTrack é um aplicativo Android para organizar e executar a trilha sonora de eventos por momentos.

## Estado da versão
## Funcionalidades
## Limitações do release candidate
## Requisitos
## Desenvolvimento
## Testes
## Build Android
## Continuidade de áudio
## Documentação
```

Document `1.0.0-rc.1+1`, Flutter 3.44.2, Dart 3.12.2, Android SDK 36.1, the three integration commands, `SOUNDTRACK_ANDROID_DEVICE`, debug build, release signing link, JSON without audio bytes, postponed manual scenarios and links to changelog/checklist/release docs.

- [ ] **Step 2: Criar CHANGELOG e política de versionamento**

Create `CHANGELOG.md` with:

```markdown
# Changelog

Todas as mudanças relevantes deste projeto serão documentadas neste arquivo.

## [Unreleased]

## [1.0.0-rc.1] - 2026-07-11

### Added

- Catálogo, editor e persistência local de eventos e momentos.
- Reprodução por momentos com fade, crossfade, loop e Modo Narração.
- Dashboard ao vivo com volumes de emergência e continuidade em segundo plano.
- Exportação e importação JSON com religamento manual de áudios.
- Restauração segura da sessão ativa e saída explícita para a biblioteca.

### Changed

- Identidade Android definida como `br.com.marcocardoso.soundtrack`.
- Stop interrompe a reprodução sem encerrar o Modo Evento; Sair encerra a sessão.

### Known limitations

- Normalização automática de volume permanece fora do MVP.
- Testes manuais de Bluetooth, cabo, ligação, WhatsApp e sessão prolongada estão adiados.
- O APK oficial depende da configuração do keystore privado.
```

Create `docs/release/versioning.md` documenting SemVer, monotonic Android build number, independent JSON schema, RC promotion and tag-after-signed-artifact rule.

- [ ] **Step 3: Documentar assinatura sem expor segredos**

Create `docs/release/android-signing.md` documenting:

- `android/key.properties` is ignored and must contain the four required property names with real private values;
- keystore stays outside Git and needs encrypted backup;
- `storeFile` is resolved relative to `android/`;
- `flutter build apk --release` and `flutter build appbundle --release` are allowed only after configuration;
- debug builds need no keystore;
- losing the signing key prevents publishing compatible updates.

Do not include passwords, real paths or commands that echo secrets.

- [ ] **Step 4: Corrigir checklist e natureza dos planos históricos**

Update `docs/qa/mvp-acceptance-checklist.md` to record:

```markdown
- [x] Parar reprodução preserva a sessão do Modo Evento.
- [x] Sair do Modo Evento interrompe o áudio e encerra a sessão.
- [x] Suíte completa executada com geração de cobertura: 344 testes aprovados.
```

Add a physical-device automation section with moto g54 5G, Android 15/API 35, and the three passing integration flows plus normal APK startup without crash. Keep Bluetooth, cable, incoming call, WhatsApp and long-session checks marked `ADIADO`.

Create `docs/superpowers/README.md` stating that `plans/` are historical execution records, `specs/` hold approved behavior, and current release/QA docs prevail over superseded plan text.

- [ ] **Step 5: Validar links, conteúdo obsoleto e formatação**

Run:

```powershell
rg -n "A new Flutter project|340 testes|Stop com confirmação encerra sessão ativa|aparelho físico Android: adiado" README.md CHANGELOG.md docs pubspec.yaml
git diff --check
```

Expected: no stale phrases; diff check PASS.

Run the local Markdown link check:

```powershell
$missing = @()
Get-ChildItem -Recurse -Filter *.md -File | ForEach-Object {
  $file = $_
  $content = Get-Content -LiteralPath $file.FullName -Raw
  [regex]::Matches($content, '\[[^\]]+\]\(([^)]+)\)') | ForEach-Object {
    $target = $_.Groups[1].Value.Split('#')[0]
    if ($target -and $target -notmatch '^(https?://|mailto:|#)') {
      $resolved = Join-Path $file.DirectoryName $target
      if (-not (Test-Path -LiteralPath $resolved)) {
        $missing += "$($file.FullName): $target"
      }
    }
  }
}
if ($missing.Count) { throw ($missing -join "`n") }
```

Expected: exit 0 with no missing local links.

- [ ] **Step 6: Commitar a documentação**

```powershell
git add README.md CHANGELOG.md docs pubspec.yaml
git commit -m "docs: prepare SoundTrack release candidate"
```

---

### Task 4: Executar gates, validar no aparelho e abrir a PR

**Files:**
- Verify: entire repository
- Verify: moto g54 5G at the currently connected ADB serial
- Update: remote branch `codex/rc-preparation`

**Interfaces:**
- Consumes: Tasks 1–3 completas.
- Produces: branch limpa, commit validado e Pull Request draft de preparação do RC.

- [ ] **Step 1: Executar gates locais completos**

Run:

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --coverage --reporter compact
Push-Location android
.\gradlew.bat testDebugUnitTest
Pop-Location
flutter build apk --debug
git diff --check
```

Expected: format unchanged; analyze clean; 347 tests PASS (344 baseline + notification channel, metadata and signing tests); Kotlin tests PASS; debug APK built; diff check PASS.

- [ ] **Step 2: Confirmar o bloqueio release e ausência da identidade antiga**

Run:

```powershell
flutter build apk --release
rg -n "com\.soundtrack" android lib test integration_test
```

Expected: release FAIL only with the configured signing message; search has no results.

- [ ] **Step 3: Instalar o APK normal e validar a nova identidade**

Resolve the connected moto g54 serial programmatically and run with that serial:

```powershell
$adb = 'C:\Users\Marco\AppData\Local\Android\Sdk\platform-tools\adb.exe'
$device = flutter devices --machine |
  ConvertFrom-Json |
  Where-Object {
    $_.name -eq 'moto g54 5G' -and $_.targetPlatform -eq 'android-arm64'
  } |
  Select-Object -First 1 -ExpandProperty id
if (-not $device) { throw 'moto g54 5G não está conectado.' }
& $adb -s $device install -r build\app\outputs\flutter-apk\app-debug.apk
& $adb -s $device shell cmd package resolve-activity --brief br.com.marcocardoso.soundtrack
& $adb -s $device shell am start -n br.com.marcocardoso.soundtrack/.MainActivity
& $adb -s $device logcat -b crash -d
```

Expected: install succeeds; activity resolves to `br.com.marcocardoso.soundtrack/.MainActivity`; app opens; crash buffer contains no SoundTrack crash. The command discovers the current serial instead of reusing an expired Wi-Fi endpoint.

- [ ] **Step 4: Sincronizar a master local com o merge já publicado**

Run from `C:\projects\SoundTrack`:

```powershell
git fetch origin
git merge --ff-only origin/master
git status -sb
```

Expected: local `master` fast-forwards to the GitHub merge and stays clean. This does not include the RC branch before its PR is merged.

- [ ] **Step 5: Revisar e publicar a branch**

Run:

```powershell
git status --short
git log --oneline origin/master..HEAD
git diff --stat origin/master...HEAD
git push -u origin codex/rc-preparation
```

Expected: clean worktree, intentional commit list and successful push.

- [ ] **Step 6: Abrir Pull Request draft**

Create a draft PR titled `build: prepare SoundTrack 1.0.0-rc.1` with a body containing:

```markdown
## Resumo
- define `1.0.0-rc.1+1` e a identidade `br.com.marcocardoso.soundtrack`
- exige assinatura privada para builds release
- atualiza README, changelog, versionamento, assinatura e aceitação

## Validação
- Flutter analyze
- suíte Flutter completa
- testes Kotlin
- APK debug e inicialização no moto g54 5G
- build release bloqueado sem keystore, conforme esperado

## Fora de escopo
- keystore, APK oficial, tag e GitHub Release
- testes físicos manuais explicitamente adiados
```

Verify the PR is open, draft, points to `master`, and uses the pushed head SHA.
