# SoundTrack Text Scaling Accessibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Garantir que todas as telas de produção do SoundTrack permaneçam legíveis, separadas e operáveis com escala de texto de até 200% em retrato e paisagem.

**Architecture:** Substituir limites rígidos em torno de texto por fluxo vertical com alturas naturais, quebra responsiva e rolagem. O Dashboard usará uma única rolagem ordenada; componentes reutilizáveis preservarão texto primário e truncarão apenas nomes de arquivo secundários, mantendo semântica completa.

**Tech Stack:** Flutter 3.44.2, Dart 3.12.2, Material 3, flutter_test e Android 15/API 35.

## Global Constraints

- Escalas obrigatórias: 100%, 150% e 200%.
- Viewports mínimos: 320 × 480 em retrato e 480 × 320 em paisagem.
- Nenhum clamp global de `TextScaler`.
- Nenhum marquee ou rolagem automática de texto.
- Área de toque mínima: 48 dp.
- Separação mínima entre “Tocando agora” e “Momentos”: 16 px.
- Nome do momento: no máximo duas linhas em cartões e botões.
- Nome do arquivo: uma linha com reticências no Dashboard e lista do editor; nome completo na semântica.
- Nome do arquivo: até duas linhas em edição, importação e religamento.
- Application ID permanece `br.com.marcocardoso.soundtrack`.

---

### Task 1: Harness e contrato geométrico do Dashboard

**Files:**
- Create: `test/support/accessibility_test_harness.dart`
- Modify: `test/features/live/presentation/dashboard_accessibility_test.dart`

**Interfaces:**
- Produces: `pumpAccessibleApp`, matriz de viewports/escalas e helpers de interseção reutilizados pelos testes seguintes.

- [ ] **Step 1: Criar o harness de escala e viewport.**

```dart
const accessibilityTextScales = <double>[1, 1.5, 2];
const accessibilityViewports = <Size>[
  Size(320, 480),
  Size(480, 320),
];

Future<void> pumpAccessibleApp(
  WidgetTester tester, {
  required Widget home,
  required Size viewport,
  required double textScale,
}) async {
  tester.view
    ..physicalSize = viewport
    ..devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: home,
    ),
  );
  await tester.pump();
}

bool intersects(WidgetTester tester, Finder first, Finder second) =>
    tester.getRect(first).overlaps(tester.getRect(second));
```

- [ ] **Step 2: Adicionar keys estáveis para o título da seção e fluxo rolável.**

Usar `momentsSectionTitleKey` e `liveDashboardScrollKey` em
`live_dashboard_keys.dart`; o teste não deve depender de localizar um `Text`
ambíguo.

- [ ] **Step 3: Escrever testes falhos para escala 200%.**

Os testes devem posicionar “Tocando agora” e “Momentos” na mesma área visível,
comparar `nowPlayingRect.bottom + 16 <= momentsRect.top`, confirmar uma única
rolagem principal e rolar até Pausar, Parar, Narração e volumes.

- [ ] **Step 4: Executar o teste e confirmar a falha atual.**

Run: `flutter test test/features/live/presentation/dashboard_accessibility_test.dart`

Expected: FAIL porque `_BoundedPanel(maxHeight: 52)` comprime “Tocando agora”
e o `Column` mantém controles fora da rolagem principal.

### Task 2: Fluxo responsivo do Dashboard

**Files:**
- Modify: `lib/features/live/presentation/live_dashboard_keys.dart`
- Modify: `lib/features/live/presentation/live_dashboard_page.dart`
- Modify: `lib/features/live/presentation/widgets/now_playing_panel.dart`
- Modify: `lib/features/live/presentation/widgets/playback_controls.dart`
- Modify: `lib/features/live/presentation/widgets/emergency_volume_panel.dart`
- Test: `test/features/live/presentation/dashboard_accessibility_test.dart`
- Test: `test/features/live/presentation/live_dashboard_page_test.dart`

**Interfaces:**
- Consumes: keys e helpers da Task 1.
- Produces: Dashboard com uma rolagem vertical, alturas naturais e controles alcançáveis.

- [ ] **Step 1: Trocar o `Column` normal por `CustomScrollView`.**

A ordem dos slivers será alerta, NowPlayingPanel, `SizedBox(height: 16)`, título
de Momentos, `SliverList` de momentos, PlaybackControls e
EmergencyVolumePanel. O `CustomScrollView` receberá `liveDashboardScrollKey`.

- [ ] **Step 2: Remover `_BoundedPanel` de conteúdo textual.**

Alertas e “Tocando agora” devem usar altura natural. `_BoundedPanel` pode ser
eliminado se nenhum uso não textual permanecer.

- [ ] **Step 3: Tornar AppBar e rota compatíveis com 200%.**

Em texto ampliado, usar título de uma linha com reticências para o nome variável
do evento e calcular altura suficiente para a faixa de rota. A rota pode ter
uma linha com reticências, mas não pode gerar overflow vertical.

- [ ] **Step 4: Tornar PlaybackControls flexível.**

Remover `SizedBox(height: 50)` e `SizedBox(height: 48)` que envolvem texto. Em
viewport compacto com texto ampliado, usar `Wrap` e controles com restrição
mínima de 48 dp. Rótulos visuais usam até duas linhas; semântica e tooltips
preservam os nomes completos.

- [ ] **Step 5: Remover altura fixa e rolagem aninhada dos volumes.**

Os três sliders e “Restaurar predefinições” devem participar da rolagem do
Dashboard. O título “Volumes de emergência” pode ocupar duas linhas.

- [ ] **Step 6: Aplicar a mesma regra ao modo de volumes expandido.**

Usar um `SingleChildScrollView` externo com Column de altura natural para
alerta, estado atual, controles e volumes, sem limites menores que o texto.

- [ ] **Step 7: Rodar testes do Dashboard.**

Run:
`flutter test test/features/live/presentation/dashboard_accessibility_test.dart test/features/live/presentation/live_dashboard_page_test.dart`

Expected: PASS, sem exceções de layout e com controles ainda acionáveis.

### Task 3: Botões e cartões de momentos

**Files:**
- Modify: `lib/features/live/presentation/widgets/moment_action_button.dart`
- Modify: `lib/features/events/presentation/widgets/moment_tile.dart`
- Modify: `test/features/live/presentation/dashboard_accessibility_test.dart`
- Modify: `test/features/events/presentation/event_editor_page_test.dart`

**Interfaces:**
- Produces: nome principal em até duas linhas, arquivo secundário em uma linha e semântica completa.

- [ ] **Step 1: Escrever testes falhos com nome de momento e arquivo extensos.**

Verificar `Text.maxLines == 2` para o momento, `maxLines == 1` e
`TextOverflow.ellipsis` para o arquivo, e confirmar que o rótulo semântico
contém o nome completo do arquivo.

- [ ] **Step 2: Implementar o botão do Dashboard.**

O número usará largura mínima, não largura fixa incapaz de crescer. A coluna de
conteúdo continuará em `Expanded`; nome e arquivo terão os limites definidos e
o estado ficará em sua própria linha.

- [ ] **Step 3: Separar arquivo e metadados no MomentTile.**

O subtitle será uma `Column`: primeiro o arquivo em uma linha com reticências;
depois Loop/Parar/Narração em texto próprio, sem perder estado quando o arquivo
for longo. Envolver o cartão em `Semantics` com nome completo do arquivo.

- [ ] **Step 4: Rodar os testes de Dashboard e editor.**

Run:
`flutter test test/features/live/presentation/dashboard_accessibility_test.dart test/features/events/presentation/event_editor_page_test.dart`

Expected: PASS.

### Task 4: Editor de evento e editor de momento

**Files:**
- Modify: `lib/features/events/presentation/event_editor_page.dart`
- Modify: `lib/features/events/presentation/moment_editor_sheet.dart`
- Modify: `test/features/events/presentation/event_editor_page_test.dart`
- Modify: `test/features/events/presentation/moment_editor_sheet_test.dart`

**Interfaces:**
- Produces: formulários roláveis e controles que refluem em 200% e com teclado.

- [ ] **Step 1: Escrever matriz falha para retrato e paisagem em 200%.**

Abrir o editor e o bottom sheet com nomes longos, focar o campo para simular
insets de teclado, rolar até Modo Evento/Concluir e confirmar ações.

- [ ] **Step 2: Remover linhas rígidas dos controles globais.**

Cada volume usará `Column(crossAxisAlignment: start)` com rótulo acima do
slider. Fade-in e Fade-out usarão `Wrap`/`LayoutBuilder`, lado a lado somente
quando houver largura suficiente.

- [ ] **Step 3: Tornar `_FadeControl` responsivo.**

Em largura pequena, rótulo e dropdown ficam em coluna; em largura ampla podem
ficar na mesma linha. O dropdown não deve receber largura menor que seu texto.

- [ ] **Step 4: Preservar o nome completo no editor de áudio.**

O botão de seleção de áudio aceitará duas linhas e altura natural, sem marquee.

- [ ] **Step 5: Rodar os testes dos editores.**

Run:
`flutter test test/features/events/presentation/event_editor_page_test.dart test/features/events/presentation/moment_editor_sheet_test.dart`

Expected: PASS.

### Task 5: Biblioteca, religamento e verificação pré-evento

**Files:**
- Modify: `lib/features/events/presentation/event_library_page.dart`
- Modify: `lib/features/events/presentation/widgets/event_card.dart`
- Modify: `lib/features/events/presentation/audio_relink_page.dart`
- Modify: `lib/features/live/presentation/preflight_page.dart`
- Modify: `test/features/events/presentation/event_library_page_test.dart`
- Modify: `test/features/events/presentation/audio_relink_page_test.dart`
- Modify: `test/features/live/presentation/preflight_page_test.dart`

**Interfaces:**
- Produces: telas auxiliares sem compressão horizontal em 200%.

- [ ] **Step 1: Adicionar testes parametrizados em 100%, 150% e 200%.**

Cada tela deve ser exercitada nos dois viewports, rolar até sua ação final e
confirmar `tester.takeException() == null`.

- [ ] **Step 2: Reorganizar cartões de religamento.**

Remover o botão largo de `ListTile.trailing`. Colocar detalhes do arquivo em até
duas linhas e “Escolher música” abaixo, em `Align`/`Wrap`, com altura natural.

- [ ] **Step 3: Ajustar cabeçalhos e ações horizontais restantes.**

Textos de grupo no preflight ficam em `Expanded`; ações de AppBar mantêm
ícone/tooltip quando o rótulo não couber; EventCard preserva título e menu sem
interseção.

- [ ] **Step 4: Verificar bottomNavigationBar do religamento.**

“Concluir”/“Resolver depois” deve crescer até duas linhas e continuar acessível
em paisagem com 200%.

- [ ] **Step 5: Rodar os três grupos de teste.**

Run:
`flutter test test/features/events/presentation/event_library_page_test.dart test/features/events/presentation/audio_relink_page_test.dart test/features/live/presentation/preflight_page_test.dart`

Expected: PASS.

### Task 6: Gate completo e QA Android em 200%

**Files:**
- Update: `docs/qa/mvp-acceptance-checklist.md`
- Generate ignored: `build/accessibility-200-portrait.png`
- Generate ignored: `build/accessibility-200-landscape.png`

**Interfaces:**
- Consumes: todas as mudanças responsivas anteriores.
- Produces: evidência automatizada e visual do requisito aceito.

- [ ] **Step 1: Executar formatação e análise.**

Run:
`dart format --output=none --set-exit-if-changed lib test integration_test`

Run: `flutter analyze`

Expected: nenhum arquivo alterado e nenhum issue.

- [ ] **Step 2: Executar toda a suíte e integrações no emulador.**

Run: `flutter test`

Run: `.\tool\run_android_acceptance.ps1`

Expected: todos os testes unitários/widget e os três fluxos integrados passam.

- [ ] **Step 3: Construir APK debug e instalar no emulador.**

Run: `flutter build apk --debug`

Run: `adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk`

Expected: instalação bem-sucedida.

- [ ] **Step 4: Aplicar fonte 200% no Android e validar orientações.**

Salvar o valor atual, executar `adb shell settings put system font_scale 2.0`,
reiniciar a Activity e capturar retrato/paisagem. Inspecionar árvore de UI,
screenshots e `logcat -b crash`. Restaurar o valor original no `finally`, mesmo
se a inspeção falhar.

- [ ] **Step 5: Atualizar o checklist de QA.**

Registrar escalas, viewports, telas exercitadas, screenshots e qualquer limite
remanescente sem marcar testes manuais adiados como aprovados.

- [ ] **Step 6: Revisar diff e segredos.**

Run: `git diff --check`

Run: `git status --short`

Confirmar que screenshots, APKs e configurações do dispositivo permanecem
ignorados e que nenhum `key.properties`/keystore foi rastreado.

### Task 7: Revisão e publicação

**Files:**
- Commit: código, testes e documentação das Tasks 1–6.

**Interfaces:**
- Produces: branch revisada e Pull Request pronta para merge.

- [ ] **Step 1: Executar revisão de requisitos contra a especificação.**

Conferir cada critério de
`docs/superpowers/specs/2026-07-12-font-scaling-accessibility-design.md` contra
teste ou evidência explícita.

- [ ] **Step 2: Criar commit intencional.**

Run: `git add <arquivos revisados>`

Run: `git commit -m "fix: support 200 percent Android text scaling"`

- [ ] **Step 3: Enviar a branch e abrir PR pronta para revisão.**

O corpo da PR deve listar a matriz 100/150/200%, separação de 16 px, regra dos
nomes de arquivo, gates executados e cenários manuais que continuam adiados.

## Self-Review

- Cobertura: Dashboard, controles, volumes, cartões, editores, biblioteca,
  religamento, preflight, diálogos e emulador estão incluídos.
- Ambiguidade: escalas, viewports, distância, linhas de texto e áreas de toque
  têm valores exatos.
- Segurança: nenhuma configuração privada ou artefato gerado entra no Git.
- Escopo: não há mudança no motor de áudio, identidade ou versão pública.
