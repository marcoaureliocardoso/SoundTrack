# Checklist de aceitação do MVP SoundTrack

Atualizado em 14 de julho de 2026.

## Escopo das rodadas

- Validação automatizada local executada em Windows.
- Fluxos Android executados no emulador API 35.
- Fluxos Android automatizados executados em um moto g54 5G com Android 15,
  API 35 e conexão ADB por Wi-Fi.
- Testes físicos manuais específicos permanecem adiados por decisão do
  stakeholder.
- Comando reprodutível: `.\tool\run_android_acceptance.ps1`.
- Destino padrão do runner: `emulator-5554`.
- Para outro destino, definir `SOUNDTRACK_ANDROID_DEVICE` antes de executar.

## Automação obrigatória

- [x] `flutter analyze`
- [x] `flutter test`
- [x] `flutter test integration_test/event_authoring_flow_test.dart -d emulator-5554`
- [x] `flutter test integration_test/audio_engine_flow_test.dart -d emulator-5554`
- [x] `flutter test integration_test/live_event_flow_test.dart -d emulator-5554`
- [x] `git diff --check`

## Critérios cobertos pelo fluxo live automatizado

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
- [x] Parar reprodução preserva a sessão do Modo Evento.
- [x] Sair do Modo Evento interrompe o áudio e encerra a sessão.
- [x] Exportação gera JSON.
- [x] Importação marca áudios como pendentes.
- [x] Religamento de áudio pendente exige escolha explícita no novo dispositivo.

## Evidência automatizada no aparelho físico

No moto g54 5G, Android 15/API 35:

- [x] Criação, exportação, importação e religamento pela interface composta.
- [x] Motor real reproduz, faz crossfade, preserva a faixa após falha, alterna
  Narração e para.
- [x] Motor real suporta 50 crossfades e toques rápidos automatizados.
- [x] Modo Evento alterna para background, retoma, para, sai, exporta e importa.
- [x] APK debug normal instala, inicia em “Meus Eventos” e não registra crash.
- [x] APK assinado publicado do RC teve o SHA-256 conferido, foi instalado,
  iniciou em “Meus Eventos”, alternou para outro app e retornou sem crash.

## Verificação de qualidade do MVP

- [x] Formatação verificada em `lib`, `test` e `integration_test`.
- [x] Baseline funcional executada com cobertura: 344 testes aprovados.
- [x] Gate do RC executado com cobertura: 347 testes aprovados, incluindo
  metadados, canal de notificação e proteção de assinatura.
- [x] Gate de acessibilidade executado: 388 testes aprovados, incluindo a
  matriz de fontes de 100%, 150% e 200% em viewports pequenos de retrato e
  paisagem nas seis telas críticas.
- [x] Gate da versão `1.0.1+3` repetido: 388 testes e análise estática
  aprovados.
- [x] Dashboard usa rolagem vertical e preserva pelo menos 16 px entre
  “Tocando agora” e “Momentos”, sem sobreposição.
- [x] Biblioteca, editores, religamento, pré-evento, controles e volumes foram
  exercitados com fonte a 200% sem overflow.
- [x] APK debug normal inspecionado no emulador Android 15/API 35 com fonte a
  200% em retrato e paisagem; árvore de UI carregada e buffer de crashes vazio.
- [x] Escala de fonte e orientação originais do emulador foram restauradas
  depois da inspeção.
- [x] APK debug compilado em `build/app/outputs/flutter-apk/app-debug.apk`.
- [x] Testes Kotlin Android aprovados.
- [x] Build release bloqueado sem keystore privado, sem fallback para chave
  debug.
- [x] APK release `1.0.1+3` assinado com o certificado oficial, instalado e
  iniciado no emulador Android 15/API 35; tela “Meus Eventos” e buffer de
  crashes vazio confirmados.

## Aceitação física manual adiada

Os itens abaixo não bloqueiam a publicação da correção `1.0.1`, mas continuam
pendentes antes de uma decisão de uso em campo:

- [ ] ADIADO — evento manual com pelo menos 20 momentos.
- [ ] ADIADO — saída por cabo.
- [ ] ADIADO — saída Bluetooth.
- [ ] ADIADO — alternância manual para WhatsApp enquanto toca.
- [ ] ADIADO — chamada recebida.
- [ ] ADIADO — desconexão/reconexão manual de rota.
- [ ] ADIADO — sessão contínua de duas horas.
- [ ] ADIADO — 100 mudanças manuais de momento.
- [ ] ADIADO — taps rápidos repetidos manualmente no Dashboard.
- [ ] ADIADO — auditoria audível do volume de Narração.
- [ ] ADIADO — importação em segundo aparelho e religamento manual.
- [ ] ADIADO — observações de bateria e memória em sessão longa.

Uma falha futura deve registrar reprodução, ambiente, evidência e decisão de
correção. Itens adiados não podem ser descritos como aprovados.
