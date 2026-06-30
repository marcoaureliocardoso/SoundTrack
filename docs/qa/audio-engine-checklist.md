# Audio engine checkpoint

Data: 2026-06-30

## Escopo e ambiente

- Escopo autorizado: somente emulador; nenhum aparelho físico foi conectado ou
  usado.
- AVD: `Codex_API_35`
- Serial: `emulator-5554`
- Dispositivo reportado pelo Flutter: `sdk gphone64 x86 64`
- ABI: x86_64
- Sistema: Android 15, API 35
- A automação valida estado, transições e tolerância a falhas. Ela não afirma
  que o áudio foi audível.

## Executado

- [x] `flutter devices`: emulador identificado como Android 15 (API 35).
- [x] `flutter analyze`: sem issues.
- [x] Testes de widget do lab e navegação debug-only: 4 testes passaram.
- [x] `flutter test integration_test\audio_engine_flow_test.dart -d
  emulator-5554`: 2 testes passaram.
- [x] Primeiro play com WAV PCM gerado deterministicamente no armazenamento
  temporário do app.
- [x] Crossfade A→B: snapshots observados em ordem `loading` →
  `transitioning` (endpoint ativo A) → `playing` (endpoint ativo B).
- [x] Fonte inexistente preservou B ativo e emitiu `sourceFailed`.
- [x] Fonte criada e apagada antes do load preservou B ativo e emitiu
  `sourceFailed`.
- [x] Narração ligou e desligou no snapshot.
- [x] Stop terminou em `stopped`, sem momento ativo e sem playback.
- [x] 50 crossfades consecutivos com engine real.
- [x] 12 taps rápidos durante fades; o último pedido venceu e terminou em
  `playing`.
- [x] Cleanup do handler, players e arquivos temporários executado em
  `tearDownAll`.

## Adiado por decisão do usuário

Os itens abaixo não foram executados. Isso é adiamento explícito, não falha do
checkpoint:

- [ ] ADIADO — saída por cabo em aparelho físico.
- [ ] ADIADO — desconexão/reconexão Bluetooth em aparelho físico.
- [ ] ADIADO — chamada telefônica recebida em aparelho físico.
- [ ] ADIADO — alternância para WhatsApp em aparelho físico.
- [ ] ADIADO — loop contínuo por duas horas.
