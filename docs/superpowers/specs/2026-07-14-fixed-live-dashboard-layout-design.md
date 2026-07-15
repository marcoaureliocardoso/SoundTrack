# Dashboard ao vivo com cabeçalho e controles fixos

## Objetivo

Reorganizar o Dashboard do Modo Evento para manter o estado da reprodução e as
ações críticas sempre acessíveis. O painel **Tocando agora** ficará fixo no topo,
a barra de reprodução ficará fixa no rodapé e somente a região central será
rolável.

Esta especificação substitui, apenas para o Dashboard normal, a decisão anterior
de usar um único fluxo vertical rolável. As garantias de acessibilidade para
fontes Android de até 200%, ausência de sobreposição e alturas naturais continuam
obrigatórias.

## Estrutura da tela

O corpo do Dashboard será dividido verticalmente em quatro regiões:

1. painel **Tocando agora**, fixo;
2. banner de alerta, fixo enquanto existir;
3. região central flexível, que exibe Momentos ou Volumes de emergência;
4. barra fixa com Pausar/Continuar, Parar, Narração e Volumes.

A `AppBar`, com nome do evento e rota de saída, permanece acima dessas regiões.
O cabeçalho e o rodapé não participam da rolagem dos Momentos.

O layout deve usar regiões normais do fluxo, com uma área central `Expanded`, e
não sobreposições de coordenadas absolutas. Essa composição evita que conteúdo
fique escondido atrás dos controles e permite medir o espaço restante em cada
viewport.

## Tocando agora

O painel continua visualmente distinto dos botões e apresenta momento, faixa,
estado e tempo. Em viewports normais ele usa sua altura natural e permanece
fixo no topo.

Em telas muito baixas, especialmente na orientação horizontal com fonte
ampliada, o painel passa automaticamente para um resumo compacto com momento,
estado e tempo. Tocar no painel abre um diálogo com o nome completo da faixa.
Essa adaptação deve preservar uma área central utilizável; ela não pode comprimir
ou recortar texto.

### Nome longo da faixa

No painel normal, o nome da faixa ocupa uma única linha. Se o conteúdo exceder a
largura disponível, o ciclo visual será:

1. mostrar imediatamente o início do nome;
2. aguardar aproximadamente 2 segundos;
3. rolar suavemente uma vez até o final;
4. aguardar aproximadamente 1 segundo;
5. retornar diretamente ao início com uma transição cruzada curta, sem percorrer
   o texto no sentido inverso;
6. manter o início visível por aproximadamente 3 segundos antes de repetir.

Nomes que cabem não serão animados. Com redução de animações ativada no sistema,
o texto usará reticências e permanecerá parado. A semântica exporá sempre o nome
completo uma única vez, sem anunciar cada etapa da animação.

Esse comportamento é uma exceção deliberada à regra anterior contra letreiros e
vale somente para o nome da faixa em **Tocando agora**. Nomes em botões de Momentos
continuam usando uma linha com reticências.

## Região central e Momentos

No estado padrão, a região central contém o título
**MOMENTOS — TOQUE PARA INICIAR** e a lista vertical de cartões. Essa é a única
área rolável do Dashboard normal.

A posição da lista será preservada quando o operador abrir e fechar os Volumes de
emergência. Alterações no estado de reprodução não devem recriar a lista nem
reposicioná-la desnecessariamente.

O painel superior, o eventual alerta e a barra inferior devem permanecer imóveis
durante a rolagem. Nenhuma dessas regiões poderá se sobrepor à lista.

## Barra inferior fixa

A barra fixa conterá quatro ações:

- Pausar ou Continuar;
- Parar;
- Narração;
- Volumes.

O botão Volumes será compacto e indicará visualmente quando a cortina estiver
aberta. Pausar, Parar e Narração conservarão os estados habilitado e desabilitado
atuais. Volumes continuará disponível durante a sessão.

Cada ação terá alvo mínimo de 48 x 48 dp. Quando os quatro rótulos não couberem
horizontalmente com fonte ampliada, a interface priorizará ícones alinhados e
rótulos visuais curtos, mantendo descrições completas para leitores de tela e
dicas de acessibilidade.

## Cortina de Volumes de emergência

Ao acionar Volumes, uma cortina subirá de baixo para cima, visualmente por detrás
da barra fixa, e substituirá o conteúdo da região central. Os Momentos ficarão
ocultos enquanto a cortina estiver aberta. **Tocando agora**, o alerta e a barra
inferior permanecerão visíveis.

A cortina não será arrastável, evitando conflito entre gestos verticais e os
sliders. Ela abrirá e fechará pelo botão Volumes. O botão Voltar também a fechará.
Com redução de animações ativada, a troca ocorrerá sem movimento.

O `EmergencyVolumePanel` continuará responsável por Master, Música, Narração e
restauração da predefinição. A mudança será somente de composição visual; os
valores, callbacks e regras de reprodução não mudarão.

## Alertas

Um alerta de reprodução será exibido em um banner fixo entre **Tocando agora** e a
região central. Em telas muito baixas, o banner mostrará um resumo de uma linha.
Tocar no resumo abrirá um diálogo com a mensagem completa, preservando a ação
explícita de dispensar.

O alerta nunca poderá ficar escondido pela lista ou pela cortina. A abertura de
detalhes não altera nem interrompe a reprodução.

## Navegação pelo botão Voltar

O botão Voltar obedecerá à seguinte prioridade:

1. fechar a cortina de Volumes, se estiver aberta;
2. fechar detalhes de alerta ou faixa, se estiverem abertos;
3. solicitar confirmação para sair do Modo Evento.

O comportamento já existente de confirmação e encerramento da sessão será
preservado.

## Componentes e estado

A mudança ficará restrita à camada de apresentação:

- `LiveDashboardPage` compõe as regiões fixas e a área central flexível;
- `NowPlayingPanel` oferece variantes normal e compacta;
- um componente isolado controla a exibição e animação do nome da faixa;
- `PlaybackControls` incorpora a ação compacta de Volumes;
- `EmergencyVolumePanel` mantém sliders e callbacks atuais;
- `controlsExpanded` continua sendo a fonte de verdade para alternar Momentos e
  Volumes.

O Dashboard continuará sendo uma projeção de `LiveEventState`. Nenhum estado de
animação poderá iniciar, parar, pausar ou alterar volume diretamente. Falhas de
layout ou animação não podem afetar a continuidade do áudio.

## Estados expandidos e telas extremas

O layout expandido dos Volumes usará as mesmas quatro regiões. A cortina central
terá rolagem vertical própria quando seus controles não couberem.

Se cabeçalho, alerta e rodapé consumirem a maior parte de um viewport muito
baixo, as variantes compactas deverão reduzir conteúdo secundário sem violar
alvos de toque ou recortar texto primário. A região central deve conservar altura
positiva e permanecer alcançável. Não haverá rolagem aninhada dentro da lista de
Momentos.

## Testes automatizados

Testes de widget e geometria cobrirão:

- fontes em 100%, 150% e 200%;
- retrato, horizontal e viewports baixos;
- cabeçalho e rodapé imóveis enquanto a lista rola;
- região central delimitada e sem sobreposição;
- lista de Momentos como única rolagem no estado padrão;
- preservação da posição da lista ao abrir e fechar Volumes;
- animação, seleção e fechamento da cortina;
- prioridade do botão Voltar;
- nomes de faixa curtos e longos;
- comportamento com redução de animações;
- banner normal, banner compacto e detalhes do alerta;
- semântica completa e alvos mínimos de 48 x 48 dp;
- ausência de regressão nos comandos de reprodução e volumes.

Testes do componente animado usarão tempo controlado para verificar pausa inicial,
deslocamento, pausa final e retorno, sem depender do relógio real.

## Validação Android

O fluxo será validado no emulador Android, sem utilizar o aparelho físico:

1. abrir evento com vários Momentos e uma faixa de nome longo;
2. verificar o Dashboard em 100% e 200% de fonte;
3. rolar a lista e confirmar que topo e rodapé permanecem imóveis;
4. abrir e fechar Volumes e confirmar a posição preservada da lista;
5. testar alerta, detalhes, botão Voltar e redução de animações;
6. repetir em retrato e horizontal;
7. capturar árvore de acessibilidade, telas e buffer de crashes;
8. restaurar escala e orientação originais do emulador.

## Fora de escopo

- alterações no motor de áudio ou nas regras de fade;
- novos controles de volume ou novas predefinições;
- gestos de arraste para abrir ou fechar a cortina;
- mudanças nos cartões de Momentos além do necessário para o novo contêiner;
- rolagem automática de nomes fora de **Tocando agora**;
- testes no aparelho físico nesta etapa.

## Critérios de aceite

A mudança estará aceita quando:

- **Tocando agora** e a barra de reprodução permanecerem acessíveis durante toda
  a rolagem dos Momentos;
- somente a região central alternar entre Momentos e Volumes;
- nenhum elemento ficar recortado, escondido ou sobreposto até 200% de fonte;
- a faixa longa priorizar o início do nome e respeitar redução de animações;
- alertas permanecerem visíveis e acessíveis;
- a posição da lista for preservada após usar os Volumes;
- ações e semântica continuarem corretas;
- a reprodução não sofrer interrupção causada por navegação ou animação da UI.
