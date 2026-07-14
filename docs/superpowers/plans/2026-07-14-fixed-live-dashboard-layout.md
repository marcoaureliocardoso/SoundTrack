# Fixed Live Dashboard Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fixar **Tocando agora** e os controles de reprodução, deixando somente a região central dos Momentos ou Volumes rolável e acessível até 200% de fonte.

**Architecture:** `LiveDashboardPage` será uma `Column` com cabeçalho, alerta, centro `Expanded` e rodapé fixo. A região central manterá Momentos e Volumes montados dentro de um `Stack` delimitado e alternará visibilidade com `AnimatedSlide`, preservando posição e estado; componentes isolados cuidarão do nome longo, das variantes compactas e do botão de Volumes.

**Tech Stack:** Flutter/Dart, Material 3, `ValueNotifier`, widget tests, Semantics, Android emulator/ADB.

## Global Constraints

- A mudança fica restrita à camada de apresentação; não alterar motor de áudio, fades, persistência ou modelos de evento.
- **Tocando agora**, alertas e barra inferior não participam da rolagem dos Momentos.
- Somente a região central alterna entre Momentos e Volumes.
- Fontes Android de 100%, 150% e 200% não podem causar recorte ou sobreposição.
- Todo alvo de ação da barra inferior deve medir no mínimo 48 x 48 dp.
- Redução de animações desativa movimento da faixa e da cortina.
- O nome animado expõe uma única descrição semântica completa.
- Nomes de faixa fora de **Tocando agora** continuam estáticos e truncados.
- A cortina de Volumes não aceita arraste e não pode desmontar seu estado durante comandos assíncronos.
- O botão Voltar fecha Volumes, depois fecha diálogos e somente então confirma a saída.
- Validar somente no emulador Android; não usar o aparelho físico.
- Não adicionar dependências ao `pubspec.yaml`.

---

## File Map

- Create: `lib/features/live/presentation/widgets/track_name_ticker.dart` — anima somente nomes que excedem a largura e respeita redução de animações.
- Create: `test/features/live/presentation/track_name_ticker_test.dart` — cobre medidas, ciclo temporal e semântica do ticker.
- Modify: `lib/features/live/presentation/widgets/now_playing_panel.dart` — variantes normal/compacta, ticker e diálogo de faixa.
- Modify: `lib/features/live/presentation/widgets/live_alert_banner.dart` — banner compacto e diálogo de detalhes.
- Modify: `lib/features/live/presentation/widgets/playback_controls.dart` — barra fixa com quatro ações, incluindo Volumes.
- Modify: `lib/features/live/presentation/widgets/emergency_volume_panel.dart` — transforma o `ExpansionTile` em conteúdo sempre expandido controlado pelo Dashboard.
- Modify: `lib/features/live/presentation/live_dashboard_keys.dart` — chaves estáveis para regiões, ticker, cortina e botão de Volumes.
- Modify: `lib/features/live/presentation/live_dashboard_page.dart` — composição fixa, centro animado, preservação de estado e prioridade de Voltar.
- Modify: `test/features/live/presentation/live_dashboard_page_test.dart` — comportamento integrado, comandos, alertas e navegação.
- Modify: `test/features/live/presentation/dashboard_accessibility_test.dart` — contratos geométricos e fontes ampliadas.
- Modify: `test/features/live/presentation/playback_controls_contrast_test.dart` — mantém contraste ao acrescentar Volumes.
- Modify: `README.md` — descreve o novo Dashboard.
- Modify: `CHANGELOG.md` — registra a mudança em `Unreleased`.
- Modify: `docs/qa/mvp-acceptance-checklist.md` — registra matriz automatizada e evidência do emulador.

---

### Task 1: Nome de faixa de uma linha com ciclo controlado

**Files:**
- Create: `lib/features/live/presentation/widgets/track_name_ticker.dart`
- Create: `test/features/live/presentation/track_name_ticker_test.dart`

**Interfaces:**
- Consumes: `MediaQuery.disableAnimationsOf(context)`, largura do `LayoutBuilder` e `TextStyle` efetivo.
- Produces: `TrackNameTicker({required String text, TextStyle? style, Duration initialPause, Duration endPause, Duration startHold, Duration resetFade, double pixelsPerSecond, Key? key})`.

- [ ] **Step 1: Escrever testes vermelhos para texto curto, overflow, semântica e redução de animações**

Criar um harness com largura fixa e relógio controlado:

```dart
Widget _ticker({required String text, bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Center(
        child: SizedBox(
          width: 180,
          child: TrackNameTicker(
            text: text,
            initialPause: const Duration(seconds: 2),
            endPause: const Duration(seconds: 1),
            startHold: const Duration(seconds: 3),
            resetFade: const Duration(milliseconds: 100),
            pixelsPerSecond: 1000,
          ),
        ),
      ),
    ),
  );
}
```

Os testes devem comprovar:

```dart
testWidgets('short track stays at the start without scheduling animation', (tester) async {
  await tester.pumpWidget(_ticker(text: 'entrada.mp3'));
  await tester.pump(const Duration(seconds: 10));
  expect(tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView)).controller!.offset, 0);
  expect(tester.takeException(), isNull);
});

testWidgets('long track pauses, scrolls once, then resets without reverse travel', (tester) async {
  await tester.pumpWidget(_ticker(text: 'Abertura oficial - versão instrumental definitiva.mp3'));
  final scrollable = tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
  await tester.pump(const Duration(milliseconds: 1900));
  expect(scrollable.controller!.offset, 0);
  await tester.pump(const Duration(milliseconds: 300));
  expect(scrollable.controller!.offset, greaterThan(0));
  await tester.pump(const Duration(seconds: 2));
  expect(scrollable.controller!.offset, 0);
});

testWidgets('reduced animation keeps overflow static with one semantic label', (tester) async {
  const track = 'Abertura oficial - versão instrumental definitiva.mp3';
  await tester.pumpWidget(_ticker(text: track, disableAnimations: true));
  await tester.pump(const Duration(seconds: 10));
  expect(find.bySemanticsLabel(track), findsOneWidget);
  expect(tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView)).controller!.offset, 0);
});
```

- [ ] **Step 2: Rodar os testes e confirmar falha pela ausência do componente**

Run:

```powershell
flutter test test/features/live/presentation/track_name_ticker_test.dart
```

Expected: FAIL porque `TrackNameTicker` e seu arquivo ainda não existem.

- [ ] **Step 3: Implementar medição, ciclo cancelável e transição cruzada**

Implementar `TrackNameTicker` como `StatefulWidget` com `ScrollController`, uma geração cancelável e `AnimatedOpacity`. O texto fica em `SingleChildScrollView` horizontal com `NeverScrollableScrollPhysics`:

```dart
class TrackNameTicker extends StatefulWidget {
  const TrackNameTicker({
    required this.text,
    this.style,
    this.initialPause = const Duration(seconds: 2),
    this.endPause = const Duration(seconds: 1),
    this.startHold = const Duration(seconds: 3),
    this.resetFade = const Duration(milliseconds: 120),
    this.pixelsPerSecond = 36,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final Duration initialPause;
  final Duration endPause;
  final Duration startHold;
  final Duration resetFade;
  final double pixelsPerSecond;
}
```

No `LayoutBuilder`, medir com `TextPainter`, manter `maxLines: 1` e iniciar o ciclo somente quando `textWidth > constraints.maxWidth`. A rotina deve usar `generation` em cada `await`, aguardar 2 s no primeiro ciclo e 3 s nos seguintes, animar linearmente até `maxScrollExtent`, pausar 1 s, reduzir opacidade, executar `jumpTo(0)` e restaurar opacidade. `didUpdateWidget`, mudança de largura e `dispose` incrementam a geração para cancelar ciclos antigos.

Quando `MediaQuery.disableAnimationsOf(context)` for verdadeiro, renderizar `Text(widget.text, maxLines: 1, overflow: TextOverflow.ellipsis)` sem iniciar o ciclo. Envolver ambos os caminhos em:

```dart
Semantics(
  label: widget.text,
  excludeSemantics: true,
  child: child,
)
```

- [ ] **Step 4: Rodar testes do ticker e formatar**

Run:

```powershell
dart format lib/features/live/presentation/widgets/track_name_ticker.dart test/features/live/presentation/track_name_ticker_test.dart
flutter test test/features/live/presentation/track_name_ticker_test.dart
```

Expected: todos os testes do arquivo passam, sem timers pendentes.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/live/presentation/widgets/track_name_ticker.dart test/features/live/presentation/track_name_ticker_test.dart
git commit -m "feat: add accessible now-playing track ticker"
```

---

### Task 2: Painel Tocando agora e alertas responsivos

**Files:**
- Modify: `lib/features/live/presentation/widgets/now_playing_panel.dart`
- Modify: `lib/features/live/presentation/widgets/live_alert_banner.dart`
- Modify: `lib/features/live/presentation/live_dashboard_keys.dart`
- Create: `test/features/live/presentation/live_status_panels_test.dart`

**Interfaces:**
- Consumes: `TrackNameTicker` da Task 1, `LiveEventState` e `PlaybackAlert`.
- Produces: `NowPlayingPanel({required LiveEventState state, bool compact = false, Key? key})` e `LiveAlertBanner({required PlaybackAlert alert, required VoidCallback onDismiss, bool compact = false, Key? key})` com diálogos internos de detalhes.

- [ ] **Step 1: Acrescentar chaves públicas para testes sem depender de textos internos**

Adicionar a `live_dashboard_keys.dart`:

```dart
const nowPlayingTrackKey = Key('now-playing-track');
const nowPlayingDetailsKey = Key('now-playing-details');
const liveAlertBannerKey = Key('live-alert-banner');
const liveAlertDetailsKey = Key('live-alert-details');
const liveDashboardCenterKey = Key('live-dashboard-center');
const playbackFooterKey = Key('playback-footer');
const volumesToggleKey = Key('volumes-toggle');
const emergencyVolumesCurtainKey = Key('emergency-volumes-curtain');
```

- [ ] **Step 2: Escrever testes vermelhos para variantes normal e compacta**

Em `live_status_panels_test.dart`, criar `LiveEventState` com faixa longa e comprovar:

```dart
expect(find.byType(TrackNameTicker), findsOneWidget);
expect(find.byKey(nowPlayingTrackKey), findsOneWidget);
expect(find.text('AGORA'), findsOneWidget);
```

No modo compacto, comprovar que o ticker não ocupa o painel, que momento/estado/tempo continuam visíveis e que tocar abre diálogo com a faixa completa:

```dart
await tester.tap(find.byKey(nowPlayingPanelKey));
await tester.pumpAndSettle();
expect(find.byKey(nowPlayingDetailsKey), findsOneWidget);
expect(find.text(longTrack), findsOneWidget);
```

Para alertas compactos, verificar uma linha, sem overflow, semântica completa, alvo de dispensar >= 48 x 48 e diálogo:

```dart
await tester.tap(find.byKey(liveAlertBannerKey));
await tester.pumpAndSettle();
expect(find.byKey(liveAlertDetailsKey), findsOneWidget);
expect(find.text(alert.message), findsWidgets);
```

- [ ] **Step 3: Rodar os testes e confirmar falhas de contrato**

Run:

```powershell
flutter test test/features/live/presentation/live_status_panels_test.dart
```

Expected: FAIL porque o painel ainda usa `Text` simples, o banner não tem modo compacto e as chaves não existem no comportamento atual.

- [ ] **Step 4: Implementar Tocando agora normal, compacto e diálogo**

No modo normal, substituir `Text(track)` por:

```dart
TrackNameTicker(
  key: nowPlayingTrackKey,
  text: track,
  style: Theme.of(context).textTheme.titleMedium,
)
```

No modo compacto, renderizar somente `AGORA`, momento e um `Wrap` de estado/tempo. Envolver o `Card` em `InkWell` somente quando `compact`, com `onTap` chamando:

```dart
showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    key: nowPlayingDetailsKey,
    title: const Text('Faixa atual'),
    content: SelectableText(track),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fechar'),
      ),
    ],
  ),
);
```

Preservar a semântica consolidada `Agora: ... Faixa: ...` e não duplicar o anúncio do ticker.

- [ ] **Step 5: Implementar banner compacto e diálogo de detalhes**

Adicionar `compact` a `LiveAlertBanner`. O modo normal mantém a mensagem quebrável. O modo compacto usa `Text(alert.message, maxLines: 1, overflow: TextOverflow.ellipsis)` dentro de uma região tocável com `Semantics(button: true, label: 'Ver detalhes do aviso: ${alert.message}')`. O botão de dispensar permanece uma ação separada e não dispara o diálogo.

O diálogo usa `liveAlertDetailsKey`, título `Aviso de reprodução`, mensagem completa e ações `Dispensar aviso` e `Fechar`. `Dispensar aviso` chama `onDismiss` antes de fechar.

- [ ] **Step 6: Rodar testes focados e regressões dos painéis**

Run:

```powershell
dart format lib/features/live/presentation/widgets/now_playing_panel.dart lib/features/live/presentation/widgets/live_alert_banner.dart lib/features/live/presentation/live_dashboard_keys.dart test/features/live/presentation/live_status_panels_test.dart
flutter test test/features/live/presentation/live_status_panels_test.dart test/features/live/presentation/playback_controls_contrast_test.dart
```

Expected: todos passam.

- [ ] **Step 7: Commit**

```powershell
git add lib/features/live/presentation/widgets/now_playing_panel.dart lib/features/live/presentation/widgets/live_alert_banner.dart lib/features/live/presentation/live_dashboard_keys.dart test/features/live/presentation/live_status_panels_test.dart
git commit -m "feat: make live status panels responsive"
```

---

### Task 3: Barra inferior fixa com ação de Volumes

**Files:**
- Modify: `lib/features/live/presentation/widgets/playback_controls.dart`
- Modify: `test/features/live/presentation/playback_controls_contrast_test.dart`
- Create: `test/features/live/presentation/playback_controls_layout_test.dart`

**Interfaces:**
- Consumes: `PlaybackSnapshot`, callbacks atuais e as chaves da Task 2.
- Produces: `PlaybackControls` com novos argumentos obrigatórios `bool volumesExpanded` e `VoidCallback onVolumesToggle`; mantém o estado assíncrono interno dos três comandos existentes.

- [ ] **Step 1: Escrever testes vermelhos para quatro ações, seleção e geometria**

Construir `PlaybackControls` em larguras 320 e 800 e escalas 1.0 e 2.0. Verificar:

```dart
expect(find.byKey(pausePlaybackKey), findsOneWidget);
expect(find.byKey(stopPlaybackKey), findsOneWidget);
expect(find.byKey(narrationKey), findsOneWidget);
expect(find.byKey(volumesToggleKey), findsOneWidget);
for (final key in [pausePlaybackKey, stopPlaybackKey, narrationKey, volumesToggleKey]) {
  final size = tester.getSize(find.byKey(key));
  expect(size.width, greaterThanOrEqualTo(48));
  expect(size.height, greaterThanOrEqualTo(48));
}
```

Tocar Volumes deve chamar apenas `onVolumesToggle`; `volumesExpanded: true` deve expor semântica `toggled: true`. Em 200%, não deve haver `RenderFlex overflow` e os quatro ícones devem continuar na mesma linha.

- [ ] **Step 2: Rodar os testes e confirmar falha pela ausência da quarta ação**

Run:

```powershell
flutter test test/features/live/presentation/playback_controls_layout_test.dart
```

Expected: FAIL porque `PlaybackControls` ainda não recebe nem renderiza Volumes.

- [ ] **Step 3: Reestruturar PlaybackControls como barra única de quatro células**

Adicionar ao construtor:

```dart
required this.volumesExpanded,
required this.onVolumesToggle,
```

Usar `LayoutBuilder` para decidir `showLabels`:

```dart
final showLabels = constraints.maxWidth >= 360 &&
    MediaQuery.textScalerOf(context).scale(1) <= 1.4;
```

Renderizar `Card(key: playbackFooterKey, margin: EdgeInsets.zero)` com `Row` e quatro `Expanded`. Cada célula usa um helper `_FooterControl` com `Semantics(button: true, enabled: ..., toggled: ...)`, `InkWell` e `ConstrainedBox(constraints: BoxConstraints(minHeight: 48, minWidth: 48))`. Quando `showLabels` for falso, mostrar somente o ícone e manter `Tooltip`/semântica completos.

O controle de Volumes usa `Icons.tune`, label `Volumes`, `key: volumesToggleKey`, `onPressed: widget.onVolumesToggle` e `selected: widget.volumesExpanded`. Pausar, Parar e Narração preservam `_transportBusy`, `_stopBusy` e `_narrationBusy` sem recriar o `State` ao alternar a cortina.

- [ ] **Step 4: Atualizar testes de contraste para a quarta ação**

Em `playback_controls_contrast_test.dart`, passar os novos argumentos em todos os harnesses:

```dart
volumesExpanded: false,
onVolumesToggle: () {},
```

Verificar contraste >= 4.5:1 do foreground desabilitado e contraste >= 3:1 do estado selecionado de Volumes, reutilizando `test/support/color_contrast.dart`.

- [ ] **Step 5: Rodar testes focados e formatar**

Run:

```powershell
dart format lib/features/live/presentation/widgets/playback_controls.dart test/features/live/presentation/playback_controls_layout_test.dart test/features/live/presentation/playback_controls_contrast_test.dart
flutter test test/features/live/presentation/playback_controls_layout_test.dart test/features/live/presentation/playback_controls_contrast_test.dart
```

Expected: todos passam em escalas 1.0 e 2.0.

- [ ] **Step 6: Commit**

```powershell
git add lib/features/live/presentation/widgets/playback_controls.dart test/features/live/presentation/playback_controls_layout_test.dart test/features/live/presentation/playback_controls_contrast_test.dart
git commit -m "feat: add fixed four-action playback bar"
```

---

### Task 4: Painel de Volumes controlado externamente e estado persistente

**Files:**
- Modify: `lib/features/live/presentation/widgets/emergency_volume_panel.dart`
- Create: `test/features/live/presentation/emergency_volume_curtain_test.dart`

**Interfaces:**
- Consumes: `PlaybackSnapshot`, `SessionVolumesChanged` e callback de restauração atuais.
- Produces: `EmergencyVolumePanel({required PlaybackSnapshot playback, required SessionVolumesChanged onVolumesChanged, required Future<void> Function() onRestore, bool compact = false, Key? key})`, sem `expanded` e `onToggle`.

- [ ] **Step 1: Escrever testes vermelhos para conteúdo sempre expandido e comandos em voo**

Os testes devem montar o painel diretamente e comprovar:

```dart
expect(find.text('Volumes de emergência'), findsOneWidget);
expect(find.byType(Slider), findsNWidgets(3));
expect(find.text('Restaurar predefinições'), findsOneWidget);
expect(find.byType(ExpansionTile), findsNothing);
```

Manter os testes existentes de fila, rollback e restauração, mas alternar visibilidade do mesmo painel com `Offstage` em vez de colapsar um `ExpansionTile`. Iniciar um comando, ocultar, mostrar e comprovar que a fila continua no mesmo `State`.

- [ ] **Step 2: Rodar o teste e confirmar falha pelo ExpansionTile atual**

Run:

```powershell
flutter test test/features/live/presentation/emergency_volume_curtain_test.dart
```

Expected: FAIL porque o componente atual depende de `expanded/onToggle` e contém `ExpansionTile`.

- [ ] **Step 3: Remover responsabilidade de expansão do painel**

Preservar integralmente `_local`, `_queued`, `_awaitingAck`, `_drainFuture`, `_generation`, `_sending`, `_dragging` e `_restoreBusy`. Alterar somente o `build` para:

```dart
return Card(
  key: emergencyVolumesKey,
  margin: widget.compact ? EdgeInsets.zero : null,
  child: SingleChildScrollView(
    primary: false,
    padding: EdgeInsets.all(widget.compact ? 8 : 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Volumes de emergência', style: Theme.of(context).textTheme.titleMedium),
        if (!widget.compact) const Text('Ajustes temporários desta sessão'),
        const SizedBox(height: 8),
        controls,
      ],
    ),
  ),
);
```

Remover apenas os campos `expanded` e `onToggle`. Não alterar a serialização de comandos nem a ordem `volumes`/`restore`.

- [ ] **Step 4: Rodar testes do painel e regressões do controller**

Run:

```powershell
dart format lib/features/live/presentation/widgets/emergency_volume_panel.dart test/features/live/presentation/emergency_volume_curtain_test.dart
flutter test test/features/live/presentation/emergency_volume_curtain_test.dart test/features/live/application/live_event_controller_test.dart
```

Expected: todos passam, incluindo ocultar/reexibir durante comando pendente.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/live/presentation/widgets/emergency_volume_panel.dart test/features/live/presentation/emergency_volume_curtain_test.dart
git commit -m "refactor: make emergency volumes externally controlled"
```

---

### Task 5: Composição fixa, cortina central e prioridade de Voltar

**Files:**
- Modify: `lib/features/live/presentation/live_dashboard_page.dart`
- Modify: `test/features/live/presentation/live_dashboard_page_test.dart`
- Modify: `test/features/live/presentation/dashboard_accessibility_test.dart`

**Interfaces:**
- Consumes: componentes e chaves das Tasks 1–4, `LiveEventState.controlsExpanded` e `LiveEventController.toggleControlsExpanded()`.
- Produces: Dashboard com topo/alerta/rodapé fixos e `CustomScrollView` restrito à área central.

- [ ] **Step 1: Reescrever testes geométricos para o contrato fixo**

Substituir expectativas de “rolar até controles” por medições antes/depois da rolagem da lista:

```dart
final nowBefore = tester.getRect(find.byKey(nowPlayingPanelKey));
final footerBefore = tester.getRect(find.byKey(playbackFooterKey));
final center = tester.getRect(find.byKey(liveDashboardCenterKey));

await tester.drag(find.byKey(liveDashboardScrollKey), const Offset(0, -500));
await tester.pumpAndSettle();

expect(tester.getRect(find.byKey(nowPlayingPanelKey)), nowBefore);
expect(tester.getRect(find.byKey(playbackFooterKey)), footerBefore);
expect(center.top, greaterThanOrEqualTo(nowBefore.bottom));
expect(center.bottom, lessThanOrEqualTo(footerBefore.top));
```

Adicionar matriz com `Size(1080, 2400)`, `Size(2400, 1080)` e viewport curto já usado pelos testes, cada um em escalas 1.0, 1.5 e 2.0. Em todas, verificar `tester.takeException() == null`, centro com altura > 0, alvos >= 48 e nenhuma interseção entre as quatro regiões.

- [ ] **Step 2: Escrever testes vermelhos para alternância, animação e posição preservada**

Rolar a lista, registrar `Scrollable.position.pixels`, tocar `volumesToggleKey`, avançar metade da duração e verificar que a cortina se move de baixo para cima. Após abrir, comprovar que Momentos estão com `IgnorePointer` e o painel tem três sliders. Fechar e verificar o mesmo offset:

```dart
final before = tester.state<ScrollableState>(_dashboardScrollable()).position.pixels;
await tester.tap(find.byKey(volumesToggleKey));
await tester.pumpAndSettle();
expect(find.byKey(emergencyVolumesCurtainKey), findsOneWidget);
await tester.tap(find.byKey(volumesToggleKey));
await tester.pumpAndSettle();
final after = tester.state<ScrollableState>(_dashboardScrollable()).position.pixels;
expect(after, before);
```

Com `MediaQueryData(disableAnimations: true)`, uma única `pump()` deve concluir a troca sem posição intermediária.

- [ ] **Step 3: Escrever teste vermelho para a prioridade de Voltar**

Abrir Volumes, chamar `tester.binding.handlePopRoute()` e comprovar que a cortina fecha sem exibir `Sair do Modo Evento?`. Uma segunda chamada deve abrir a confirmação. Abrir os diálogos de faixa e alerta e comprovar que o primeiro Voltar fecha somente o diálogo, comportamento fornecido pelo `Navigator`.

- [ ] **Step 4: Rodar os testes e confirmar falha pelo fluxo rolável atual**

Run:

```powershell
flutter test test/features/live/presentation/live_dashboard_page_test.dart test/features/live/presentation/dashboard_accessibility_test.dart
```

Expected: FAIL porque `NowPlayingPanel`, controles e Volumes ainda pertencem ao mesmo `CustomScrollView`.

- [ ] **Step 5: Substituir os dois layouts por uma composição única de quatro regiões**

Em `build`, manter `Scaffold/AppBar/SafeArea/LayoutBuilder`, calcular:

```dart
final textScale = MediaQuery.textScalerOf(context).scale(1);
final compact = constraints.maxHeight < 650 || textScale > 1.4;
final veryShort = constraints.maxHeight < 360;
final reduceMotion = MediaQuery.disableAnimationsOf(context);
```

Construir uma única `Column` com padding externo:

```dart
Column(
  children: [
    _buildNowPlaying(compact: compact),
    _buildAlert(compact: compact || veryShort),
    Expanded(
      key: liveDashboardCenterKey,
      child: _buildCenter(
        event: event,
        momentCount: momentCount,
        volumesExpanded: volumesExpanded,
        compact: compact,
        reduceMotion: reduceMotion,
      ),
    ),
    _buildControls(compact: compact || veryShort),
  ],
)
```

Remover `_buildExpandedVolumes` e `_buildNormalDashboard`. O `CustomScrollView(key: liveDashboardScrollKey)` passa a conter somente título, espaçamento e `SliverList.builder`.

- [ ] **Step 6: Implementar centro com ambos os estados permanentemente montados**

Usar `ClipRect` e `Stack(fit: StackFit.expand)` exclusivamente dentro da região central. Manter os dois filhos montados e controlar interação/semântica:

```dart
final duration = reduceMotion ? Duration.zero : const Duration(milliseconds: 250);
return ClipRect(
  child: Stack(
    fit: StackFit.expand,
    children: [
      AnimatedOpacity(
        opacity: volumesExpanded ? 0 : 1,
        duration: duration,
        child: IgnorePointer(
          ignoring: volumesExpanded,
          child: ExcludeSemantics(
            excluding: volumesExpanded,
            child: momentsScroll,
          ),
        ),
      ),
      AnimatedSlide(
        key: emergencyVolumesCurtainKey,
        offset: volumesExpanded ? Offset.zero : const Offset(0, 1),
        duration: duration,
        curve: Curves.easeOutCubic,
        child: IgnorePointer(
          ignoring: !volumesExpanded,
          child: ExcludeSemantics(
            excluding: !volumesExpanded,
            child: volumesPanel,
          ),
        ),
      ),
    ],
  ),
);
```

Não atribuir uma nova `ScrollController` em rebuilds. O `CustomScrollView` com chave estável mantém seu `ScrollPosition`. O `EmergencyVolumePanel` também permanece com o mesmo `State` durante toda a sessão.

- [ ] **Step 7: Conectar controles, alerta e Voltar**

Passar a `PlaybackControls`:

```dart
volumesExpanded: state.controlsExpanded,
onVolumesToggle: widget.controller.toggleControlsExpanded,
```

Passar `compact` a `LiveAlertBanner`. No `PopScope.onPopInvokedWithResult`, antes de `_confirmExit()`:

```dart
if (widget.controller.state.value.controlsExpanded) {
  widget.controller.toggleControlsExpanded();
  return;
}
```

Diálogos ficam acima da rota e são fechados pelo `Navigator` antes que o `PopScope` da página receba o evento.

- [ ] **Step 8: Atualizar testes antigos para o novo ponto de acesso aos Volumes**

Remover `_scrollToEmergencyVolumes`. Em todos os testes, abrir e fechar com `find.byKey(volumesToggleKey)`. Alterar `_dashboardScrollable()` para retornar diretamente o `Scrollable` descendente de `liveDashboardScrollKey`. Testes de fila, rollback, stop single-flight e restauração devem manter as mesmas expectativas de comandos.

O teste de lista grande deve continuar exigindo menos de 20 cartões construídos inicialmente, mas agora confirmar que `pausePlaybackKey` e `volumesToggleKey` já estão visíveis sem rolar.

- [ ] **Step 9: Rodar suíte do Dashboard e corrigir apenas regressões do novo contrato**

Run:

```powershell
dart format lib/features/live/presentation/live_dashboard_page.dart test/features/live/presentation/live_dashboard_page_test.dart test/features/live/presentation/dashboard_accessibility_test.dart
flutter test test/features/live/presentation/live_dashboard_page_test.dart test/features/live/presentation/dashboard_accessibility_test.dart test/features/live/presentation/live_dashboard_lifecycle_test.dart test/features/live/presentation/preflight_page_test.dart
```

Expected: todos passam; não há overflow, timers pendentes ou comandos duplicados.

- [ ] **Step 10: Commit**

```powershell
git add lib/features/live/presentation/live_dashboard_page.dart test/features/live/presentation/live_dashboard_page_test.dart test/features/live/presentation/dashboard_accessibility_test.dart
git commit -m "feat: fix live status and controls around moments"
```

---

### Task 6: Documentação, gates completos e QA no emulador

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/qa/mvp-acceptance-checklist.md`

**Interfaces:**
- Consumes: Dashboard concluído nas Tasks 1–5.
- Produces: documentação atualizada e evidência verificável da aceitação Android.

- [ ] **Step 1: Atualizar documentação de produto**

No `README.md`, substituir a descrição de “rolagem vertical única” do Dashboard por: painel **Tocando agora** e barra de reprodução fixos, lista central rolável e Volumes como cortina central.

No `CHANGELOG.md`, adicionar em `Unreleased / Changed`:

```markdown
- Dashboard do Modo Evento mantém “Tocando agora” e ações de reprodução fixos,
  com Momentos ou Volumes de emergência na região central rolável.
- Nomes longos da faixa atual priorizam o início e rolam de forma controlada,
  respeitando a preferência do sistema por redução de animações.
```

No checklist de QA, registrar matriz automatizada de 100%, 150% e 200%, retrato/horizontal, cortina, Voltar, alerta e redução de animações.

- [ ] **Step 2: Rodar formatação, análise e suíte completa**

Run:

```powershell
dart format lib test integration_test
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build apk --debug
git diff --check
```

Expected: formatação sem mudanças na segunda execução, análise sem issues, todos os testes aprovados, APK debug criado e diff sem whitespace errors.

- [ ] **Step 3: Instalar somente no emulador e preparar cenário de vários Momentos**

Identificar o SDK em `android/local.properties`, escolher explicitamente `emulator-5554` ou o serial de outro emulador listado e nunca um aparelho físico:

```powershell
$sdkDir = ((Select-String -Path android\local.properties -Pattern '^sdk.dir=').Line -replace '^sdk.dir=', '') -replace '\\\\', '\'
$adb = Join-Path $sdkDir 'platform-tools\adb.exe'
& $adb devices
& $adb -s emulator-5554 install -r build\app\outputs\flutter-apk\app-debug.apk
```

Se a assinatura instalada impedir o APK debug, usar a mesma assinatura release privada já configurada localmente, sem copiar `key.properties` ou senhas para o Git, e instalar com `-r` para preservar o cenário.

- [ ] **Step 4: Validar em 100% e 200%, retrato e horizontal**

Para cada combinação, usar árvore de UI para derivar coordenadas e comprovar:

- **Tocando agora** permanece no mesmo limite antes/depois de rolar Momentos;
- barra inferior permanece no mesmo limite;
- somente os cartões mudam de posição;
- Volumes sobe pela região central e fecha pelo botão/Voltar;
- posição da lista reaparece preservada;
- faixa longa executa pausa e deslocamento em animações normais;
- alertas compactos abrem detalhes e podem ser dispensados;
- nenhum elemento se sobrepõe ou fica fora do viewport.

Configurar fonte com:

```powershell
& $adb -s emulator-5554 shell settings put system font_scale 2.0
```

Alternar orientação pelo emulador, redumpando a árvore após cada mudança; não inferir coordenadas pela captura de tela.

- [ ] **Step 5: Capturar evidências e verificar estabilidade**

Salvar em `build/qa/fixed-dashboard/`:

```powershell
& $adb -s emulator-5554 shell uiautomator dump /sdcard/fixed-dashboard.xml
& $adb -s emulator-5554 shell screencap -p /sdcard/fixed-dashboard.png
& $adb -s emulator-5554 pull /sdcard/fixed-dashboard.xml build\qa\fixed-dashboard\fixed-dashboard.xml
& $adb -s emulator-5554 pull /sdcard/fixed-dashboard.png build\qa\fixed-dashboard\fixed-dashboard.png
& $adb -s emulator-5554 shell pidof -s br.com.marcocardoso.soundtrack
& $adb -s emulator-5554 logcat -b crash -d
```

Expected: processo ativo, buffer de crash vazio e limites da árvore sem interseção entre cabeçalho, centro e rodapé.

- [ ] **Step 6: Restaurar o emulador mesmo se a validação falhar**

Executar antes de encerrar a tarefa:

```powershell
& $adb -s emulator-5554 shell settings put system font_scale 1.0
& $adb -s emulator-5554 shell settings put system accelerometer_rotation 1
& $adb -s emulator-5554 shell settings get system font_scale
```

Expected: `1.0`. Confirmar orientação automática restaurada.

- [ ] **Step 7: Registrar resultado no checklist e executar verificação final fresca**

Após incluir evidências textuais no checklist, repetir:

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build apk --debug
git diff --check
git status --short
```

Expected: todos os gates passam; somente arquivos previstos estão modificados.

- [ ] **Step 8: Commit**

```powershell
git add README.md CHANGELOG.md docs/qa/mvp-acceptance-checklist.md
git commit -m "docs: record fixed live dashboard acceptance"
```

---

## Final Review Checklist

- [ ] Reexecutar `flutter analyze`, `flutter test` e `flutter build apk --debug` a partir da branch limpa.
- [ ] Confirmar que nenhuma dependência foi acrescentada.
- [ ] Confirmar que os modelos, controller e motor de áudio não receberam mudanças funcionais.
- [ ] Confirmar que apenas o `CustomScrollView` central move os Momentos.
- [ ] Confirmar que ticker e cortina respeitam `MediaQuery.disableAnimations`.
- [ ] Confirmar que diálogos fecham antes da confirmação de saída.
- [ ] Confirmar que a fila de volumes e comandos single-flight sobrevivem à alternância visual.
- [ ] Confirmar 48 x 48 dp e semântica completa nas quatro ações inferiores.
- [ ] Confirmar fonte e orientação originais do emulador restauradas.
- [ ] Revisar `git diff master...HEAD` antes de oferecer merge ou Pull Request.
