# SoundTrack

SoundTrack é um aplicativo Android para organizar e executar a trilha sonora
de eventos por momentos. Cada momento pode iniciar uma música local com fade,
crossfade, repetição e volume próprio, enquanto o Modo Narração reduz a música
para permitir uma fala sobre a trilha.

## Estado da versão

A versão atual é `1.0.0-rc.1+1`, o primeiro candidato à versão estável. O RC
ainda não possui APK oficial: a publicação depende da configuração do keystore
privado, geração do artefato assinado e validação desse mesmo artefato.

## Funcionalidades

- Catálogo local de eventos com criação, duplicação, edição e exclusão.
- Linha do tempo ordenável com música, loop ou parada, ganho e fades por
  momento.
- Verificação pré-evento de músicas, bateria, volume e saída de áudio.
- Dashboard ao vivo com “Tocando agora”, controles de transporte, Modo
  Narração e volumes de emergência.
- Fade entre momentos e preservação da faixa atual quando a próxima falha.
- Continuidade do áudio ao alternar para outros aplicativos.
- Persistência e restauração segura da sessão ativa.
- Exportação e importação de eventos em JSON versionado.
- Religamento manual de músicas indisponíveis após importação.

## Limitações do release candidate

- O JSON exportado contém a configuração do evento, mas não os bytes das
  músicas.
- A normalização automática de volume permanece fora do MVP; o ganho por
  momento é manual.
- Os testes manuais de Bluetooth, cabo, ligação recebida, alternância real para
  WhatsApp e sessão prolongada estão adiados.
- Somente Android está no escopo deste candidato.

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
$env:SOUNDTRACK_ANDROID_DEVICE='192.168.1.186:38213'
.\tool\run_android_acceptance.ps1
```

O endereço de depuração Wi-Fi pode mudar. Consulte `flutter devices` antes de
reutilizá-lo.

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
- [`docs/release/versioning.md`](docs/release/versioning.md): política de versão,
  build number e tags.
- [`docs/release/android-signing.md`](docs/release/android-signing.md): assinatura
  e custódia do keystore.
- [`docs/qa/mvp-acceptance-checklist.md`](docs/qa/mvp-acceptance-checklist.md):
  evidências de aceitação.
- [`docs/superpowers/README.md`](docs/superpowers/README.md): relação entre
  especificações e planos históricos.
