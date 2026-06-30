# Checklist de aceitação da fundação

Data da execução manual: 29 de junho de 2026.

## Ambiente

- Emulador: `Codex_API_35`
- Modelo: `sdk gphone64 x86 64`
- Android: 15 (API 35)
- Destino ADB: `emulator-5554`
- Aparelho físico: não executado. Nenhum telefone físico apareceu em
  `flutter devices` ou `adb devices -l`; somente o emulador Android foi
  detectado, além dos destinos desktop/web exibidos pelo Flutter.

## Resultados

| Critério | Resultado | Evidência |
| --- | --- | --- |
| Fresh install creates an event | Passou | Após uma instalação limpa, um evento foi criado com sucesso. |
| Event survives process restart | Passou | Depois de `force-stop` e reinício do processo, o evento continuou disponível. |
| Moments reorder correctly | Passou | Dois momentos foram reordenados por gesto e permaneceram na ordem escolhida. |
| Moved/deleted audio shows pending | Passou para arquivo removido | A seleção de áudio pelo SAF funcionou. Após remover `/sdcard/Music/saida.ogg` e reiniciar o processo, a interface exibiu `Áudio pendente: saida.ogg`. Um movimento de arquivo separado não foi exercitado. |
| Export opens Android create-document picker | Passou | A exportação abriu o seletor `CreateDocument` do Android e gerou `/sdcard/Download/Formatura.soundtrack.json`. |
| Exported JSON readable UTF-8 | Passou | O arquivo de 1133 bytes foi lido e interpretado como UTF-8; continha `format` igual a `soundtrack-event` e `schema` igual a `1`. |
| Import creates a new ID | Passou | A importação criou um segundo evento chamado `Formatura`, com um novo ID. |
| Invalid import creates no event | Passou | Um JSON inválido exibiu erro e não alterou a contagem de eventos. |
| Relinking requires explicit file choice | Passou | O religamento exigiu uma seleção explícita no SAF; depois da escolha, todas as músicas apareceram como localizadas. |

## Automação relacionada

Antes da reinstalação usada no roteiro manual, o fluxo de integração passou no
mesmo emulador:

```powershell
flutter test integration_test\event_authoring_flow_test.dart -d emulator-5554
```

O teste automatizado não substitui as verificações manuais acima; ele registra
o fluxo composto de criação, exportação, importação e religamento.
