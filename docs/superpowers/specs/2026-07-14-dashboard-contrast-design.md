# Correção de contraste do Dashboard

## Contexto

Na captura do Dashboard em tema escuro, os cartões disponíveis usam fundo
turquesa e misturam dois foregrounds. O nome da faixa herda corretamente a cor
escura do `FilledButton`, mas número, nome do momento e estado recebem cores
claras explícitas do `TextTheme`. A amostragem da captura encontrou contraste
aproximado de 1,3:1 para esses textos claros e 6,9:1 para a faixa escura. O
painel “Agora” apresentou aproximadamente 10,9:1.

Os controles inativos de transporte e Narração também aparecem com cerca de
2,5:1. Embora componentes desabilitados tenham exceção normativa, o SoundTrack
é uma ferramenta operacional e precisa manter seus estados legíveis sob
pressão.

## Objetivos

- Preservar o tema escuro e o fundo turquesa dos cartões disponíveis.
- Usar um único foreground coerente em todo o conteúdo de cada cartão.
- Garantir contraste mínimo de 4,5:1 para texto e 3:1 para ícones, bordas e
  indicadores de estado.
- Tornar controles inativos legíveis sem fazê-los parecer habilitados.
- Preservar layout, tamanhos, truncamento, alvos de toque e semântica.

Não fazem parte desta correção uma nova paleta, um tema de alto contraste
separado ou alterações de fluxo do Modo Evento.

## Alternativas consideradas

1. **Foreground por estado, mantendo a paleta atual — escolhida.** É a menor
   mudança, mantém a identidade visual e corrige a origem da inconsistência.
2. Escurecer o fundo dos cartões e manter texto claro. Atenderia ao contraste,
   mas descaracterizaria o principal elemento de ação.
3. Criar um tema de alto contraste opcional. Aumentaria configuração e escopo
   sem necessidade para corrigir a paleta padrão.

## Design

### Cartões de momentos

O `MomentActionButton` resolverá background e foreground uma única vez por
estado e aplicará o mesmo foreground explicitamente a número, nome, faixa e
estado.

| Estado | Background | Foreground |
|---|---|---|
| Disponível e habilitado | `primary` | `onPrimary` |
| Momento atual | `primaryContainer` | `onPrimaryContainer` |
| Pendente, erro ou comando indisponível | `surfaceContainerHighest` | `onSurfaceVariant` |

Os estilos tipográficos existentes serão preservados com `copyWith(color: …)`.
Assim, nenhum `TextTheme` poderá substituir silenciosamente o foreground do
botão. A semântica continuará anunciando número, momento, faixa e estado.

### Controles de reprodução

Pausar, Parar e Narração usarão um foreground inativo derivado de
`onSurfaceVariant`, validado contra o fundo real do cartão. Ícone, texto e
borda do mesmo controle compartilharão esse token. O estado continuará
inativo por ausência de ação, semântica `enabled: false` e tratamento visual
uniforme; não dependerá apenas de baixa opacidade.

Controles habilitados e Narração ativa continuarão usando os tokens Material
atuais.

## Testes

O desenvolvimento seguirá TDD.

- Teste de widget reproduzirá primeiro a regressão: todos os textos de um
  cartão disponível devem resolver para `onPrimary`.
- Casos equivalentes cobrirão momento atual e estados indisponíveis.
- Um utilitário de teste calculará luminância relativa e exigirá pelo menos
  4,5:1 para foregrounds textuais e 3:1 para ícones/bordas.
- Testes dos controles confirmarão foreground uniforme e semântica inativa.
- A suíte completa, análise estática e formatação serão executadas.
- O APK debug será inspecionado no emulador Android 15, incluindo fonte a 200%,
  sem exigir teste físico nesta rodada.

## Documentação e compatibilidade

A correção será registrada em `[Unreleased]` no changelog. Não altera modelo
de dados, esquema JSON, persistência, reprodução, assinatura Android ou
identificador do aplicativo.
