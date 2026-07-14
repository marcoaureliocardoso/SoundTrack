# Acessibilidade de escala de texto — Design

## Objetivo

O SoundTrack deve permanecer legível, operável e visualmente separado quando
o tamanho da fonte do Android for ampliado até 200%. A aplicação deve respeitar
a preferência do usuário, sem limitar globalmente a escala, reduzir texto de
forma automática ou usar texto em movimento.

O requisito vale para todas as telas de produção em modo retrato e paisagem.
O menor viewport de referência automatizada será 320 × 480 pixels lógicos em
retrato e 480 × 320 em paisagem.

## Critérios globais

- Nenhum `RenderFlex overflow`, texto cortado de forma não intencional ou
  interseção entre elementos em escalas de 100%, 150% e 200%.
- Nenhum elemento de interface pode se sobrepor ou invadir a área de outro.
- Conteúdo que não couber deve reorganizar-se em múltiplas linhas ou ficar
  acessível por rolagem vertical.
- Controles interativos preservam área de toque mínima de 48 dp.
- Rótulos de botões podem ocupar até duas linhas e os botões crescem
  verticalmente para acomodá-los.
- Grupos horizontais de ações usam quebra responsiva quando não houver largura.
- Não haverá letreiro, marquee ou rolagem automática de texto em botões.
- Reticências são permitidas somente em conteúdo secundário cuja forma completa
  permaneça disponível no contexto adequado ou para tecnologia assistiva.
- Diálogos, formulários e painéis inferiores devem permitir rolagem quando o
  teclado, a orientação ou a escala de texto reduzirem a área disponível.

## Dashboard do Modo Evento

O Dashboard adotará um fluxo vertical único nesta ordem:

1. alertas;
2. painel “Tocando agora”;
3. separação visual mínima de 16 px;
4. título da seção “Momentos”;
5. botões dos momentos;
6. controles de reprodução;
7. volumes de emergência.

O painel “Tocando agora” terá altura definida pelo conteúdo. Limites de altura
fixos não poderão comprimir seus textos quando a fonte estiver ampliada. A
seção “Momentos” começará somente depois do limite inferior real desse painel e
da separação mínima de 16 px.

Quando o conjunto não couber no viewport, o Dashboard inteiro terá rolagem
vertical. Isso evita reservar uma área insuficiente para os momentos e mantém
todos os controles alcançáveis sem sobreposição. O estado “Tocando agora” deve
continuar visualmente distinto dos botões dos momentos.

O modo expandido dos volumes seguirá a mesma regra: cabeçalho, estado atual,
controles e ajustes usam alturas naturais e rolagem vertical, sem painéis
textuais presos a limites menores que o conteúdo.

## Botões e cartões de momentos

O nome do momento é a informação principal e pode ocupar até duas linhas. O
nome do arquivo de áudio é secundário e será mostrado em uma única linha com
reticências no Dashboard e na lista de momentos do editor.

O nome completo do arquivo continuará:

- incluído no rótulo semântico do botão ou cartão para leitores de tela;
- visível na edição do momento, onde pode quebrar linha;
- visível nas telas de importação e religamento em até duas linhas, pois nessas
  telas o usuário precisa diferenciar arquivos semelhantes.

Número, nome, arquivo e estado do momento devem permanecer em fluxo vertical
ou em colunas flexíveis. Nenhum deles pode ocupar espaço reservado ao outro.

## Demais telas

Biblioteca, editor de evento, editor de momento, verificação pré-evento,
importação, religamento e diálogos serão auditados com as mesmas regras.
Linhas rígidas que misturem texto e controles deverão mudar para `Wrap`,
`Column`, `Expanded` ou composição equivalente conforme a finalidade.

Alturas fixas serão mantidas apenas para elementos sem texto quando forem
necessárias. Elementos que contêm texto usam restrições mínimas, nunca uma
altura máxima menor que o conteúdo ampliado.

A barra superior pode truncar apenas o nome variável do evento ou da rota de
áudio. Ações da barra devem manter ícone, semântica completa e alvo de toque
válido. Informações que não couberem com segurança na barra podem migrar para o
fluxo rolável da página em escala ampliada.

## Testes automatizados

Uma infraestrutura comum de testes aplicará `TextScaler` de 1,0, 1,5 e 2,0 em
viewports pequenos de retrato e paisagem. Os testes de cada fluxo crítico
devem verificar:

- ausência de exceções de layout;
- presença de uma área rolável quando o conteúdo exceder o viewport;
- acesso e acionamento de ações essenciais após rolagem;
- altura mínima de 48 dp para controles interativos;
- inexistência de interseções geométricas entre widgets adjacentes;
- distância mínima de 16 px entre “Tocando agora” e “Momentos”;
- nome de arquivo truncado visualmente nos cartões e preservado por inteiro na
  semântica;
- nome completo disponível no editor e no religamento;
- funcionamento dos controles de reprodução e volumes após o reflow.

Os testes existentes de lógica, ciclo de vida e reprodução continuam fazendo
parte do gate para impedir regressões não visuais.

## Validação no emulador

Depois dos testes de widget, o APK será instalado no emulador Android 15/API
35. A escala de fonte do sistema será configurada para 200% e as telas
principais serão inspecionadas em retrato e paisagem. Serão capturadas
screenshots e o log de crashes.

A rodada verificará especialmente:

- separação entre “Tocando agora” e “Momentos”;
- legibilidade e toque dos botões de momentos;
- acesso aos controles de reprodução e volumes;
- formulários e diálogos com teclado aberto;
- retorno à escala padrão sem alteração persistente do layout.

## Fora de escopo

- Redesenho visual não relacionado à escala de texto.
- Mudança de cores, tipografia ou identidade da aplicação.
- Suporte garantido acima de 200% nesta rodada.
- Normalização de áudio ou mudanças no motor de reprodução.
- Texto em movimento ou redução global da preferência de acessibilidade.

## Aceitação

O requisito será aceito quando todos os testes automatizados passarem nas três
escalas e duas orientações, o emulador não apresentar sobreposição ou crash a
200%, e as ações essenciais permanecerem alcançáveis e operáveis por rolagem.
