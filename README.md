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
```

O teste de integração precisa de um dispositivo Android ativo. O checklist e as
evidências manuais da fundação ficam em
[`docs/qa/foundation-checklist.md`](docs/qa/foundation-checklist.md).
