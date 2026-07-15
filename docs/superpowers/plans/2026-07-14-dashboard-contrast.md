# Dashboard Contrast Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corrigir o contraste dos cartões de momentos e dos controles inativos do Dashboard sem alterar layout, fluxo ou identidade visual.

**Architecture:** Cada widget resolverá um foreground único a partir do `ColorScheme` e do seu estado, aplicando-o explicitamente a textos, ícones e bordas. Um helper exclusivo de testes calculará luminância relativa WCAG para impedir regressões de contraste.

**Tech Stack:** Flutter 3.44.2, Dart 3.12.2, Material 3, `flutter_test`.

## Global Constraints

- Preservar o fundo turquesa dos cartões disponíveis e o tema escuro atual.
- Exigir contraste mínimo de 4,5:1 para texto e 3:1 para ícones, bordas e indicadores.
- Preservar layout, tamanhos, truncamento, alvos de toque e semântica.
- Não criar tema alternativo nem alterar reprodução, persistência ou esquema JSON.
- Registrar a correção em `[Unreleased]`; não alterar `1.0.1+3` nesta tarefa.
- QA Android somente no emulador; não usar aparelho físico.

---

## File Structure

- Create: `test/support/color_contrast.dart` — cálculo WCAG reutilizável apenas em testes.
- Modify: `test/features/live/presentation/moment_action_button_accessibility_test.dart` — regressões dos cartões por estado.
- Modify: `lib/features/live/presentation/widgets/moment_action_button.dart` — resolução uniforme de background e foreground.
- Create: `test/features/live/presentation/playback_controls_contrast_test.dart` — contraste e semântica dos controles inativos.
- Modify: `lib/features/live/presentation/widgets/playback_controls.dart` — token inativo compartilhado por texto, ícone e borda.
- Modify: `CHANGELOG.md` — registro da correção ainda não publicada.

---

### Task 1: Foreground uniforme nos cartões de momentos

**Files:**
- Create: `test/support/color_contrast.dart`
- Modify: `test/features/live/presentation/moment_action_button_accessibility_test.dart`
- Modify: `lib/features/live/presentation/widgets/moment_action_button.dart:23-89`

**Interfaces:**
- Produces: `double contrastRatio(Color foreground, Color background)` para testes.
- Produces: `MomentActionButton` com cor explícita e uniforme em todos os seus `Text`.

- [ ] **Step 1: Criar o helper WCAG de teste**

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

double contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = _relativeLuminance(foreground);
  final backgroundLuminance = _relativeLuminance(background);
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

double _relativeLuminance(Color color) {
  double linearize(double channel) => channel <= 0.04045
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * linearize(color.r) +
      0.7152 * linearize(color.g) +
      0.0722 * linearize(color.b);
}
```

- [ ] **Step 2: Escrever o teste que reproduz o cartão disponível**

Adicionar ao teste existente um tema escuro idêntico ao aplicativo, um momento
com áudio e o seguinte caso:

```dart
testWidgets('uses one accessible foreground for every ready moment label', (
  tester,
) async {
  final theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );
  final moment = _momentWithAudio();

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: MomentActionButton(
          number: 1,
          moment: moment,
          status: MomentStatus.ready,
          onPressed: () {},
        ),
      ),
    ),
  );

  for (final label in ['1', moment.name, moment.audio!.displayName, 'TOQUE PARA INICIAR']) {
    expect(tester.widget<Text>(find.text(label)).style?.color, theme.colorScheme.onPrimary);
  }
  expect(
    contrastRatio(theme.colorScheme.onPrimary, theme.colorScheme.primary),
    greaterThanOrEqualTo(4.5),
  );
});
```

Implementar `_momentWithAudio()` com `EventMoment.create(...).copyWith(audio:
const AudioReference(uri: 'content://track', displayName: 'faixa.mp3', pending:
false, artist: null, duration: null))`.

- [ ] **Step 3: Executar o teste e confirmar RED**

Run:

```powershell
flutter test test\features\live\presentation\moment_action_button_accessibility_test.dart
```

Expected: FAIL porque número, nome e estado resolvem para `onSurface`, enquanto
a faixa não tem cor explícita.

- [ ] **Step 4: Implementar a resolução mínima por estado**

Em `MomentActionButton.build`, resolver uma única dupla:

```dart
final enabled = status == MomentStatus.ready && commandEnabled;
final (backgroundColor, foregroundColor) = switch (status) {
  MomentStatus.current => (
    colors.primaryContainer,
    colors.onPrimaryContainer,
  ),
  MomentStatus.ready when enabled => (colors.primary, colors.onPrimary),
  _ => (colors.surfaceContainerHighest, colors.onSurfaceVariant),
};
```

Passar a mesma dupla para estados habilitado e desabilitado do botão:

```dart
style: FilledButton.styleFrom(
  alignment: Alignment.centerLeft,
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  backgroundColor: backgroundColor,
  foregroundColor: foregroundColor,
  disabledBackgroundColor: backgroundColor,
  disabledForegroundColor: foregroundColor,
),
```

Aplicar `copyWith(color: foregroundColor)` ao `titleLarge`, `titleMedium`,
`bodyMedium` da faixa e `labelMedium`, preservando `maxLines` e `overflow`.

- [ ] **Step 5: Confirmar GREEN do cartão disponível**

Run: mesmo comando do Step 3.

Expected: PASS.

- [ ] **Step 6: Cobrir atual, pendente, erro e comando indisponível**

Adicionar uma tabela de casos:

```dart
final cases = [
  (MomentStatus.current, true, colors.primaryContainer, colors.onPrimaryContainer),
  (MomentStatus.pending, true, colors.surfaceContainerHighest, colors.onSurfaceVariant),
  (MomentStatus.error, true, colors.surfaceContainerHighest, colors.onSurfaceVariant),
  (MomentStatus.ready, false, colors.surfaceContainerHighest, colors.onSurfaceVariant),
];
```

Para cada caso, bombear o widget, resolver `FilledButton.style` com
`WidgetState.disabled` quando necessário, conferir as quatro cores textuais e
exigir `contrastRatio(foreground, background) >= 4.5`.

- [ ] **Step 7: Executar os testes do cartão**

Run:

```powershell
flutter test test\features\live\presentation\moment_action_button_accessibility_test.dart
```

Expected: todos os casos PASS e a semântica existente continua aprovada.

- [ ] **Step 8: Commit da tarefa**

```powershell
git add test/support/color_contrast.dart test/features/live/presentation/moment_action_button_accessibility_test.dart lib/features/live/presentation/widgets/moment_action_button.dart
git commit -m "fix: enforce accessible moment card contrast"
```

---

### Task 2: Contraste dos controles inativos

**Files:**
- Create: `test/features/live/presentation/playback_controls_contrast_test.dart`
- Modify: `lib/features/live/presentation/widgets/playback_controls.dart:34-139,184-217`
- Test: `test/support/color_contrast.dart`

**Interfaces:**
- Consumes: `contrastRatio(Color, Color)` da Task 1.
- Produces: `_Control` com `disabledForegroundColor` obrigatório.
- Produces: Narração compacta e expandida com foreground inativo uniforme.

- [ ] **Step 1: Escrever o teste dos controles inativos expandidos**

```dart
testWidgets('keeps inactive transport and narration controls legible', (
  tester,
) async {
  final theme = _darkTheme();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: PlaybackControls(
          playback: const PlaybackSnapshot.idle(),
          narrationAvailable: false,
          onPause: _noop,
          onResume: _noop,
          onStop: _noop,
          onNarrationChanged: (_) async {},
        ),
      ),
    ),
  );

  final inactive = theme.colorScheme.onSurfaceVariant;
  for (final label in ['Pausar', 'Parar', 'Narração inativa']) {
    expect(tester.widget<Text>(find.text(label)).style?.color, inactive);
  }
  for (final key in [pausePlaybackKey, stopPlaybackKey]) {
    final button = tester.widget<IconButton>(
      find.descendant(of: find.byKey(key), matching: find.byType(IconButton)),
    );
    expect(
      button.style?.foregroundColor?.resolve({WidgetState.disabled}),
      inactive,
    );
  }
  final chip = tester.widget<FilterChip>(find.byKey(narrationKey));
  expect((chip.avatar! as Icon).color, inactive);
  expect(chip.side?.color, inactive);
  expect(
    contrastRatio(inactive, theme.colorScheme.surfaceContainerLow),
    greaterThanOrEqualTo(4.5),
  );
});
```

Definir `_noop() async {}` e `_darkTheme()` com o mesmo seed/brightness do app.

- [ ] **Step 2: Executar e confirmar RED**

Run:

```powershell
flutter test test\features\live\presentation\playback_controls_contrast_test.dart
```

Expected: FAIL porque labels, ícones e borda não expõem o token inativo
uniforme.

- [ ] **Step 3: Implementar o token inativo nos transportes**

Em `PlaybackControls.build`:

```dart
final colors = Theme.of(context).colorScheme;
final inactiveForeground = colors.onSurfaceVariant;
```

Passar `disabledForegroundColor: inactiveForeground` para ambos `_Control`.
Adicionar o campo ao construtor e aplicar:

```dart
final enabled = onPressed != null;
final labelColor = enabled ? null : disabledForegroundColor;

IconButton(
  style: IconButton.styleFrom(
    disabledForegroundColor: disabledForegroundColor,
  ),
  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
  onPressed: onPressed,
  tooltip: label,
  icon: Icon(icon),
),
if (!compact)
  Text(
    label,
    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: labelColor),
  ),
```

- [ ] **Step 4: Aplicar o token à Narração compacta e expandida**

Resolver:

```dart
final narrationEnabled = widget.narrationAvailable && !_narrationBusy;
final compactNarrationForeground = playback.narrationActive
    ? colors.onSecondaryContainer
    : narrationEnabled
    ? colors.onSurface
    : inactiveForeground;
```

No compacto, aplicar a cor explicitamente ao `Icon` e ao `Text`. No
`FilterChip`, quando `narrationEnabled` for falso, definir:

```dart
avatar: Icon(Icons.mic, size: 20, color: inactiveForeground),
labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
  color: inactiveForeground,
),
side: BorderSide(color: inactiveForeground),
```

Quando habilitado, manter avatar, label e side sem override para preservar o
Material 3. Reutilizar `narrationEnabled` em `Semantics.enabled`, `onTap` e
`onSelected`.

- [ ] **Step 5: Confirmar GREEN expandido e adicionar caso compacto**

Run: mesmo comando do Step 2.

Expected: PASS.

Adicionar um segundo teste com `compact: true`; conferir `Icon.color`,
`Text.style.color`, contraste >= 4,5:1 e `InkWell.onTap == null`.

- [ ] **Step 6: Confirmar semântica e regressões dos controles**

Run:

```powershell
flutter test test\features\live\presentation\playback_controls_contrast_test.dart test\features\live\presentation\dashboard_accessibility_test.dart test\features\live\presentation\live_dashboard_page_test.dart
```

Expected: PASS; Narração continua com label “Narração inativa” e estado
desabilitado, e todos os alvos continuam com pelo menos 48 px.

- [ ] **Step 7: Commit da tarefa**

```powershell
git add test/features/live/presentation/playback_controls_contrast_test.dart lib/features/live/presentation/widgets/playback_controls.dart
git commit -m "fix: improve inactive playback control contrast"
```

---

### Task 3: Documentação, gates e QA Android

**Files:**
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: widgets e testes concluídos nas Tasks 1 e 2.
- Produces: correção documentada e evidência reproduzível.

- [ ] **Step 1: Registrar a correção não publicada**

Adicionar em `## [Unreleased]`:

```markdown
### Fixed

- Cartões de momentos agora usam foreground uniforme e contraste WCAG AA em
  número, nome, faixa e estado.
- Controles inativos de transporte e Narração permanecem visualmente inativos,
  mas legíveis no Dashboard escuro.
```

Se já existir `### Fixed`, acrescentar os itens sem duplicar o cabeçalho.

- [ ] **Step 2: Executar formatação e gates completos**

```powershell
dart format lib test integration_test
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
git diff --check
```

Expected: 0 arquivos pendentes de formatação, “No issues found”, pelo menos 388
testes aprovados mais os novos casos, e `git diff --check` com exit code 0.

- [ ] **Step 3: Gerar APK debug**

```powershell
flutter build apk --debug
```

Expected: `build\app\outputs\flutter-apk\app-debug.apk` criado com sucesso.

- [ ] **Step 4: Validar no emulador sem tocar no aparelho físico**

Usar `emulator-5554`. Primeiro tentar `adb install -r app-debug.apk`. Se o
Android recusar por incompatibilidade entre a assinatura release já instalada
e a assinatura debug, parar e pedir autorização antes de desinstalar o pacote,
pois `adb uninstall br.com.marcocardoso.soundtrack` apaga dados do emulador.

Após instalação autorizada, configurar fonte em 200%, abrir o Dashboard com o
fluxo de teste existente, capturar árvore de UI e screenshot, confirmar ausência
de sobreposição e de crashes e restaurar a escala original. Seguir o skill
`test-android-apps:android-emulator-qa`; coordenadas de toque devem vir da árvore
de UI, nunca da screenshot.

- [ ] **Step 5: Commit final da documentação**

```powershell
git add CHANGELOG.md
git commit -m "docs: record dashboard contrast correction"
```

- [ ] **Step 6: Revisar estado final**

```powershell
git status --short
git log --oneline master..HEAD
```

Expected: worktree limpa e três commits da implementação após o commit da
especificação.
