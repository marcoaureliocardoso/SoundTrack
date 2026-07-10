# SoundTrack

SoundTrack é um aplicativo Flutter para preparar eventos e seus momentos de
áudio. A fundação atual permite criar e persistir eventos, ordenar momentos,
selecionar e religar arquivos de áudio pelo seletor de documentos do Android e
exportar/importar eventos em JSON.

## Requisitos

- Flutter com uma versão do Dart compatível com `pubspec.yaml`.
- Android SDK e um emulador ou aparelho Android para os fluxos que usam o
  Storage Access Framework (SAF).

## Desenvolvimento

```powershell
flutter pub get
flutter run
```

Para listar os destinos disponíveis e executar no Android:

```powershell
flutter devices
flutter run -d emulator-5554
```

## Qualidade e testes

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test\event_authoring_flow_test.dart -d emulator-5554
flutter test integration_test\audio_engine_flow_test.dart -d emulator-5554
flutter test integration_test\live_event_flow_test.dart -d emulator-5554
```

Os testes de integração precisam de um dispositivo Android ativo. Para a
aceitação automatizada do MVP no emulador:

```powershell
.\tool\run_android_acceptance.ps1
```

O checklist de aceitação do MVP fica em
[`docs/qa/mvp-acceptance-checklist.md`](docs/qa/mvp-acceptance-checklist.md).
Os checklists anteriores ficam em
[`docs/qa/foundation-checklist.md`](docs/qa/foundation-checklist.md) e
[`docs/qa/audio-engine-checklist.md`](docs/qa/audio-engine-checklist.md).

## Continuidade de áudio

No Android 12 e versões posteriores, o sistema pode impor fade ou silenciar o
áudio durante perda de foco e chamadas. O SoundTrack preserva o estado da
reprodução e tenta retomá-la quando o foco retorna, desde que o usuário não
tenha escolhido Pausar ou Parar durante a interrupção.

Conectar ou desconectar Bluetooth, fones ou cabos apenas gera um aviso de
mudança de rota; o SoundTrack não pausa automaticamente. Pedidos de ducking
também são observados e avisados sem alterar manualmente os volumes da sessão.
