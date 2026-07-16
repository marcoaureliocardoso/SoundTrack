# SoundTrack

SoundTrack é um aplicativo Android para organizar e executar a trilha sonora
de eventos por momentos. Cada momento pode iniciar uma música local com fade,
crossfade, repetição e volume próprio, enquanto o Modo Narração reduz a música
para permitir uma fala sobre a trilha.

## Estado da versão

A versão atual publicada é `1.1.0+4`, que amplia e unifica a experiência visual
da Biblioteca ao Modo Evento. O APK assinado e seu checksum estão disponíveis
na [GitHub Release `v1.1.0`](https://github.com/marcoaureliocardoso/SoundTrack/releases/tag/v1.1.0).

## Funcionalidades

- Biblioteca local de eventos com quatro ordenações, criação, duplicação,
  renomeação, exportação e exclusão pelo contexto de cada evento.
- Linha do tempo ordenável com música, loop ou parada, ganho e fades por
  momento.
- Verificação pré-evento de músicas, bateria, volume e saída de áudio.
- Dashboard ao vivo com “Tocando agora” fixo no topo, dock segmentado de
  Pausar/Retomar, Parar e Narração no rodapé e rolagem exclusiva dos momentos.
- Cortina de volumes de emergência no espaço central, sem perder a posição da
  lista de momentos ao abrir ou fechar.
- Fade entre momentos e preservação da faixa atual quando a próxima falha.
- Continuidade do áudio ao alternar para outros aplicativos.
- Persistência e restauração segura da sessão ativa.
- Exportação e importação de eventos em JSON versionado.
- Religamento manual em “Áudios pendentes” após importação; os arquivos são
  escolhidos novamente no dispositivo.
- Layout responsivo a fontes Android ampliadas até 200%, com rolagem e sem
  sobreposição entre “Tocando agora”, momentos e controles.
- Nome longo da faixa em execução com deslocamento horizontal pausado e
  previsível; o movimento é desativado quando o sistema solicita redução de
  animações.

## Limitações conhecidas

- O JSON exportado contém a configuração do evento, mas não os bytes das
  músicas.
- A normalização automática de volume permanece fora do MVP; o ganho por
  momento é manual.
- Os testes manuais de Bluetooth, cabo, ligação recebida, alternância real para
  WhatsApp e sessão prolongada estão adiados.
- Somente Android está no escopo desta versão.

## Requisitos

- Flutter 3.44.2 com Dart 3.12.2.
- Android SDK 36.1 e Java 17 ou superior compatível com o Gradle do projeto.
- Emulador ou aparelho Android para os fluxos que usam o Storage Access
  Framework (SAF).

## Desenvolvimento

```powershell
flutter pub get
flutter run
```

Para listar os destinos e executar em um dispositivo específico:

```powershell
flutter devices
flutter run -d emulator-5554
```

## Testes

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --coverage
flutter test integration_test\event_authoring_flow_test.dart -d emulator-5554
flutter test integration_test\audio_engine_flow_test.dart -d emulator-5554
flutter test integration_test\live_event_flow_test.dart -d emulator-5554
```

O runner executa análise, suíte Flutter, três fluxos integrados e verificação
do diff. O destino padrão é `emulator-5554`; para outro emulador ou aparelho,
defina `SOUNDTRACK_ANDROID_DEVICE`:

```powershell
$env:SOUNDTRACK_ANDROID_DEVICE='<serial-ou-endereco-do-dispositivo>'
.\tool\run_android_acceptance.ps1
```

O endereço de depuração Wi-Fi pode mudar. Consulte `flutter devices` antes de
reutilizá-lo.

No Modo Evento, o botão Voltar fecha primeiro a cortina de volumes, quando ela
estiver aberta. Um novo Voltar então solicita confirmação antes de encerrar a
sessão e interromper a reprodução.

## Build Android

O APK de desenvolvimento não exige chave privada:

```powershell
flutter build apk --debug
```

Builds release são bloqueados enquanto `android/key.properties` e o keystore
privado não estiverem configurados. Consulte
[`docs/release/android-signing.md`](docs/release/android-signing.md) antes de
executar `flutter build apk --release` ou `flutter build appbundle --release`.

## Continuidade de áudio

No Android 12 e versões posteriores, o sistema pode impor fade ou silenciar o
áudio durante perda de foco e chamadas. O SoundTrack preserva o estado da
reprodução e tenta retomá-la quando o foco retorna, desde que o usuário não
tenha escolhido Pausar ou Parar durante a interrupção.

Conectar ou desconectar Bluetooth, fones ou cabos gera um aviso de mudança de
rota; o SoundTrack não pausa voluntariamente. Pedidos de ducking são observados
e avisados sem alterar manualmente os volumes da sessão.

## Documentação

- [`CHANGELOG.md`](CHANGELOG.md): histórico de versões e limitações conhecidas.
- [`docs/design/soundtrack-visual-system.md`](docs/design/soundtrack-visual-system.md):
  fonte canônica da linguagem visual, navegação, vocabulário, acessibilidade e
  critérios de aceitação da interface.
- [`docs/release/versioning.md`](docs/release/versioning.md): política de versão,
  build number e tags.
- [`docs/release/android-signing.md`](docs/release/android-signing.md): assinatura
  e custódia do keystore.
- [`docs/qa/mvp-acceptance-checklist.md`](docs/qa/mvp-acceptance-checklist.md):
  evidências de aceitação.
- [`docs/superpowers/README.md`](docs/superpowers/README.md): relação entre
  especificações e planos históricos.
