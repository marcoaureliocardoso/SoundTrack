# Checklist de aceitação do MVP SoundTrack

Data: 10 de julho de 2026.

## Escopo desta rodada

- Escopo autorizado pelo usuário: validação automatizada/local e emulador Android.
- Aparelho físico Android: adiado nesta rodada para controlar custo de tokens e tempo.
- Comando reprodutível: `.\tool\run_android_acceptance.ps1`.
- Dispositivo padrão esperado pelo runner: `emulator-5554`.
- Para outro emulador, definir `SOUNDTRACK_ANDROID_DEVICE` antes de executar.

## Automação obrigatória

- [x] `flutter analyze`
- [x] `flutter test`
- [x] `flutter test integration_test/event_authoring_flow_test.dart -d emulator-5554`
- [x] `flutter test integration_test/audio_engine_flow_test.dart -d emulator-5554`
- [x] `flutter test integration_test/live_event_flow_test.dart -d emulator-5554`
- [x] `git diff --check`

## Critérios cobertos pelo novo fluxo live automatizado

- [x] Evento com três momentos.
- [x] Momento com loop.
- [x] Momento com fim em parar.
- [x] Momento com Narração habilitada.
- [x] Momento com fade customizado.
- [x] Verificação pré-evento antes de entrar no Dashboard.
- [x] Entrada no Modo Evento mesmo com áudio pendente, mediante confirmação.
- [x] Troca de momento sem pausar automaticamente.
- [x] Narração liga, desliga e publica estado no snapshot.
- [x] Volumes de sessão podem ser ajustados e restaurados.
- [x] Tentativa de momento pendente preserva o momento atual.
- [x] Alternância background/resume não chama pause nem stop.
- [x] Stop com confirmação encerra sessão ativa.
- [x] Exportação gera JSON.
- [x] Importação marca áudios como pendentes.
- [x] Religamento de áudio pendente exige escolha explícita no novo dispositivo.

## Verificação de qualidade de release

- [x] Formatação verificada em `lib`, `test` e `integration_test`.
- [x] Suíte completa executada com geração de cobertura: 340 testes aprovados.
- [x] APK debug compilado em `build/app/outputs/flutter-apk/app-debug.apk`.

## Aceitação física adiada

Os itens abaixo continuam necessários antes de release em campo, mas não foram
executados nesta rodada:

- [ ] ADIADO — evento com pelo menos 20 momentos em aparelho físico.
- [ ] ADIADO — saída por cabo.
- [ ] ADIADO — saída Bluetooth.
- [ ] ADIADO — alternância para WhatsApp enquanto toca.
- [ ] ADIADO — chamada recebida.
- [ ] ADIADO — desconexão/reconexão de rota.
- [ ] ADIADO — sessão contínua de duas horas.
- [ ] ADIADO — 100 mudanças de momento.
- [ ] ADIADO — taps rápidos repetidos no Dashboard em aparelho físico.
- [ ] ADIADO — auditoria audível do volume de Narração.
- [ ] ADIADO — importação em segundo aparelho e religamento manual.
- [ ] ADIADO — observações de bateria e memória em sessão longa.

Qualquer item físico com falha deve bloquear release e registrar reprodução,
ambiente, evidência e decisão de correção.
