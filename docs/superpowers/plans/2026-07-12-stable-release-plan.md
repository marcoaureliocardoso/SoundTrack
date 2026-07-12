# SoundTrack 1.0.0 Stable Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Promover o RC aprovado para a versão Android estável `1.0.0+2` e publicar a tag e GitHub Release `v1.0.0` com APK assinado verificável.

**Architecture:** A promoção não altera comportamento do aplicativo. O trabalho limita-se a metadados de versão, documentação, gates automatizados, build assinado e publicação do artefato correspondente ao commit tagueado.

**Tech Stack:** Flutter 3.44.2, Dart 3.12.2, Android SDK 36.1, Gradle/Kotlin, Git e GitHub CLI.

## Global Constraints

- Application ID permanece `br.com.marcocardoso.soundtrack`.
- Versão Flutter/Android estável: `1.0.0+2`.
- Tag e GitHub Release: `v1.0.0`.
- O `versionCode 2` deve ser maior que o `versionCode 1` já distribuído no RC.
- O mesmo keystore do RC deve assinar o APK estável.
- Cenários manuais adiados continuam explicitamente documentados.
- Nenhuma senha, keystore ou `key.properties` pode entrar no Git ou na Release.

---

### Task 1: Metadados e documentação estável

**Files:**
- Modify: `test/app/release_metadata_test.dart`
- Modify: `pubspec.yaml`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/release/versioning.md`

**Interfaces:**
- Consumes: RC `1.0.0-rc.1+1`, tag publicada `v1.0.0-rc.1` e validação física já concluída.
- Produces: árvore documentada e testável para `1.0.0+2`.

- [ ] **Step 1: Atualizar o teste de metadados para exigir `version: 1.0.0+2` e manter a identidade Android.**
- [ ] **Step 2: Executar `flutter test test/app/release_metadata_test.dart` e confirmar falha contra o metadado do RC.**
- [ ] **Step 3: Atualizar `pubspec.yaml`, README, changelog e política de versionamento para a versão estável e para o estado real dos artefatos.**
- [ ] **Step 4: Executar novamente o teste de metadados e confirmar aprovação.**

### Task 2: Gates e artefato assinado

**Files:**
- Verify: `lib/`, `test/`, `integration_test/`, `android/`
- Generate ignored: `build/app/outputs/flutter-apk/app-release.apk`
- Generate ignored: `build/app/outputs/flutter-apk/app-release.apk.sha256`

**Interfaces:**
- Consumes: metadados estáveis e configuração privada de assinatura existente.
- Produces: APK `1.0.0 (2)` assinado e checksum SHA-256.

- [ ] **Step 1: Executar formatação em modo de verificação, `flutter analyze`, suíte Flutter e testes Kotlin.**
- [ ] **Step 2: Executar os fluxos de integração no emulador já aprovado.**
- [ ] **Step 3: Gerar `flutter build apk --release`.**
- [ ] **Step 4: Verificar esquema de assinatura, certificado, versão e SHA-256 do APK.**
- [ ] **Step 5: Instalar no emulador e executar smoke test com captura e logcat.**

### Task 3: Commit, tag e GitHub Release

**Files:**
- Commit: arquivos versionados das Tasks 1 e plano atual.
- Publish: tag `v1.0.0`, APK e checksum.

**Interfaces:**
- Consumes: commit limpo e artefato assinado comprovadamente gerado desse commit.
- Produces: Release estável pública e auditável.

- [ ] **Step 1: Revisar diff, ausência de segredos e coerência documental.**
- [ ] **Step 2: Criar commit de promoção e enviar `master`.**
- [ ] **Step 3: Confirmar que o commit remoto é o commit usado no build.**
- [ ] **Step 4: Criar e enviar a tag anotada `v1.0.0`.**
- [ ] **Step 5: Publicar GitHub Release estável com APK, checksum, validações e limitações conhecidas.**
- [ ] **Step 6: Reler tag, Release e digests remotos antes de declarar conclusão.**

## Self-Review

- Cobertura: versionamento incremental, documentação, gates, assinatura, emulador, Git e publicação estão contemplados.
- Escopo: nenhuma mudança funcional ou novo esquema JSON foi incluído.
- Segurança: credenciais privadas ficam fora do Git e dos artefatos públicos.
