# Refinamento visual amplo do SoundTrack

- **Data:** 15 de julho de 2026
- **Status:** implementado e validado; documento em manutenção contínua
- **Escopo:** fluxo principal do aplicativo Android, exceto o laboratório técnico de áudio
- **Natureza:** documento canônico e permanente do sistema visual; deve ser atualizado quando a interface aprovada mudar

Este arquivo é a fonte de verdade para linguagem visual, navegação, vocabulário,
acessibilidade, estados e critérios de aceitação da interface do SoundTrack.
Registros datados em `docs/superpowers/` e mockups exploratórios não o substituem.

## 1. Objetivo

Reformular visualmente o SoundTrack como uma ferramenta operacional premium: sóbria, legível, rápida de interpretar e segura durante eventos. A mudança deve unificar a biblioteca, a preparação, a edição e o Dashboard ao vivo sem alterar a finalidade central do produto.

O refinamento deve:

- manter o tema escuro em todo o aplicativo;
- preservar o verde-petróleo como identidade principal;
- reduzir cartões, cápsulas e grandes áreas preenchidas;
- evitar CTAs largos e preenchidos nas telas do fluxo principal; ações operacionais usam linhas editoriais e ações de edição usam texto no cabeçalho;
- privilegiar listas editoriais, divisores, tipografia e pequenos acentos;
- tornar o evento, o momento e o estado atual mais importantes que ações secundárias;
- funcionar sem recortes ou sobreposição com escala de texto de até 200%;
- preservar a continuidade de reprodução quando o usuário alternar para outro aplicativo;
- manter alvos de toque seguros e estados visuais claros.

## 2. Fora de escopo

- Audio Engine Lab e rota de depuração `/debug/audio-engine`;
- mudança do motor de reprodução, da política de interrupções ou do serviço em segundo plano;
- normalização automática de loudness;
- inclusão dos arquivos de áudio nos arquivos exportados;
- tema claro;
- novos formatos de importação ou exportação;
- persistência da preferência de ordenação entre reinicializações do aplicativo;
- alteração da regra de que entrar no Modo Evento não inicia uma faixa automaticamente.

## 3. Direção visual

### 3.1 Personalidade

A interface deve transmitir precisão, estabilidade e controle. O aplicativo não deve parecer um player de consumo nem uma página promocional. A expressão visual vem de contraste, ritmo, tipografia e estados — não de ilustrações ou grandes botões coloridos.

### 3.2 Paleta de referência

Os valores abaixo orientam o tema e podem receber pequenos ajustes técnicos durante a implementação, desde que os contrastes mínimos sejam preservados.

| Papel | Cor de referência | Contraste relevante |
|---|---:|---:|
| Fundo principal | `#091315` | — |
| Superfície | `#111F21` | — |
| Superfície elevada | `#182B2C` | — |
| Divisor/borda | `#263638` | — |
| Texto principal | `#EDF7F5` | 17,23:1 sobre o fundo |
| Texto secundário | `#8FA19F` | 6,96:1 sobre o fundo |
| Acento verde-petróleo | `#73D2C7` | 10,55:1 sobre o fundo |
| Texto sobre o acento | `#092426` | 9,11:1 sobre o acento |
| Aviso | `#D0B66F` | 9,50:1 sobre o fundo |
| Erro/destrutivo | `#CC9DA4` | 8,00:1 sobre o fundo |

Texto normal deve atingir pelo menos WCAG AA. Estados não podem depender somente de cor; devem combinar texto, ícone e, quando pertinente, borda ou forma.

### 3.3 Tipografia e espaçamento

- Nomes de eventos são os maiores títulos de conteúdo.
- Nomes de momentos têm destaque intermediário.
- Cabeçalhos de seção usam tamanho menor, maior espaçamento entre letras e peso forte.
- Rótulos de campo não devem competir com cabeçalhos de seção.
- Um cabeçalho de seção só existe quando agrupa vários elementos. Não usar, por exemplo, “Identificação” acima do único campo “Nome do evento”.
- Linhas e painéis têm altura natural. Nenhum conteúdo textual relevante deve ser mascarado por altura fixa.
- Alvos interativos devem ter pelo menos 48 dp no eixo tocável.

### 3.4 Primitivos de interface

A implementação deve centralizar os padrões abaixo em componentes pequenos, sem criar um framework paralelo ao Material 3:

- `EditorialSectionHeader`: título da seção e ação textual opcional;
- `EditorialRow`: número/ícone, conteúdo flexível, metadados e indicador de navegação;
- `OperationalActionRow`: ação crítica de fluxo com ícone funcional, título, explicação e seta;
- `StatusIndicator`: ícone, rótulo e severidade com semântica completa;
- `AdaptiveTrackLine`: nome de faixa em uma linha, com elipse ou ticker conforme o contexto;
- `LabeledVolumeControl`: rótulo, explicação, valor e slider;
- `DestructiveTextAction`: ação destrutiva discreta com alvo amplo;
- `AdaptiveTopActions`: ações do cabeçalho que não se sobrepõem em fonte ampliada.

Os componentes devem aceitar conteúdo flexível e não presumir uma única linha, salvo o nome rolante de faixa onde isso for explicitamente requerido.

## 4. Vocabulário do produto

| Termo | Uso obrigatório |
|---|---|
| `Salvar` | Confirma edições de evento, estrutura ou momento. Substitui `Concluir` em editores. |
| `Adicionar` | Cria um item dentro de uma estrutura existente. |
| `Novo` | Cria um evento a partir da biblioteca. |
| `Excluir` | Remove definitivamente e sempre exige confirmação. |
| `Volume` | Termo visível ao usuário. Percentual nos níveis gerais e dB na correção individual da faixa. |
| `Preparar Modo Evento` | Abre a verificação; ainda não entra no Dashboard. |
| `Entrar no Modo Evento` | Abre o Dashboard após a verificação; não inicia uma faixa. |
| `Reverificar` | Executa novamente a verificação pré-evento. |
| `Faixa` | Música atribuída a um momento. |
| `Áudio` | Arquivo, disponibilidade, preparação ou saída técnica. |

`Ganho` deve ser apresentado como `Volume da faixa`, mantendo dB como unidade e explicando que se trata de uma correção individual.

## 5. Navegação do fluxo principal

```text
Biblioteca
  ├─ Novo evento
  ├─ Importar evento
  └─ Evento
       ├─ Preparar Modo Evento → Verificação → Dashboard
       ├─ Editar estrutura
       │    └─ Editar momento
       └─ Menu contextual
            ├─ Exportar
            ├─ Duplicar
            ├─ Renomear
            └─ Excluir
```

O toque na linha de um evento abre uma tela contextual de evento. Não abre diretamente um formulário nem um menu flutuante. A tela contextual substitui a edição direta como destino principal, sem adicionar outra etapa antes do Modo Evento.

## 6. Telas aprovadas

### 6.1 Biblioteca de eventos

- Cabeçalho `Eventos` sem subtítulo redundante.
- Ação `Novo` integrada ao cabeçalho; não usar FAB estendido nem CTA preenchido.
- Menu `⋮` contém `Importar evento` e demais ações globais pouco frequentes.
- Resumo discreto pode informar quantidade de eventos, eventos prontos e momentos.
- Lista editorial numerada, com nome, quantidade de momentos, atualização e estado de prontidão.
- Toda a linha abre o contexto do evento; a seta comunica navegação.
- Ordenação disponível ao lado de `Seus eventos`:
  - Mais recentes, padrão;
  - Mais antigos;
  - Nome: A–Z;
  - Nome: Z–A.
- A ordenação por data usa `updatedAt`. A alfabética compara `name.trim().toLowerCase()`; empates são resolvidos por `updatedAt` decrescente e depois por `id`. A comparação não remove diacríticos.
- A preferência dura enquanto a instância da biblioteca estiver ativa. Ao reiniciar o aplicativo, o padrão volta a ser `Mais recentes`.

### 6.2 Contexto do evento

- Cabeçalho contém somente voltar e menu `⋮`.
- O nome do evento é o título dominante; não repetir a palavra `Evento`.
- Metadados mostram quantidade de momentos e última atualização.
- Estado `Pronto para iniciar` é discreto e não compete com o nome.
- `Editar estrutura` permanece como ação textual visível.
- `Exportar`, `Duplicar`, `Renomear` e `Excluir` ficam no menu contextual.
- A seção `Operação` contém a linha `Preparar Modo Evento`, com explicação de que será feita a verificação.
- A lista mostra todos os momentos na mesma rolagem. Não usar `Ver todos`.
- A seção de áudio resume os volumes e oferece `Ajustar`.
- `Ajustar` abre a mesma tela `Editar estrutura`, posicionada na seção `Áudio do evento`; não existe um segundo editor de áudio.
- A tela inteira usa uma única rolagem vertical.

### 6.3 Editar estrutura

- Tela cheia com cabeçalho `Editar estrutura`, voltar e ação `Salvar`.
- Alterações não salvas devem ser indicadas sem bloquear leitura.
- Começar diretamente pelo campo `Nome do evento`; não usar seção `Identificação`.
- Seção `Momentos` oferece `Adicionar` e lista editorial numerada.
- A linha inteira abre o editor do momento.
- Um puxador visível permite reordenar. A exclusão sai da lista e fica dentro do editor do momento.
- Seção `Áudio do evento` contém:
  - Master, em percentual;
  - Música, em percentual;
  - Música durante a narração, em percentual;
  - Fade-in;
  - Fade-out.
- O terceiro rótulo deve deixar claro que controla a música durante a fala, não um microfone.
- Fade-in e fade-out oferecem 0, 1, 2, 3 e 5 segundos.
- O salvamento continua explícito. Sair com alterações pendentes exige confirmação para descartar.

### 6.4 Editar momento

- Substituir a folha inferior atual por uma tela cheia rolável.
- Cabeçalho `Editar momento`, voltar e `Salvar`.
- Começar diretamente por `Nome do momento`; não usar seção `Conteúdo`.
- Faixa selecionada aparece como linha editorial com nome flexível e ação `Trocar` com largura reservada.
- Em fonte ampliada, `Trocar` pode ir para uma linha inferior; nunca pode sair da tela.
- `Ao terminar a faixa` é uma seleção exclusiva com duas opções:
  - ícone `loop` + `Repetir em loop`;
  - ícone `stop` + `Parar`.
- Não mostrar radios visuais dentro dessas opções. Seleção usa ícone, texto, borda, superfície e rótulo de estado.
- `Disponibilizar Narração` explica que apenas mostra o botão no Dashboard daquele momento.
- `Volume da faixa` usa intervalo de −12 dB a +6 dB e explica que corrige a faixa individualmente.
- Fade-in e fade-out aceitam `Herdado`, `Sem fade`, 1, 2, 3 ou 5 segundos.
- `Excluir este momento` usa vermelho discreto, alvo de pelo menos 48 dp e confirmação explícita.

### 6.5 Verificação antes do evento

- Cabeçalho `Verificação`, voltar e `Reverificar` como ação secundária.
- Nome do evento em destaque e horário relativo da verificação.
- Síntese concreta: áudios prontos/total, avisos e erros.
- Grupos editoriais: `Áudios`, `Avisos`, `Erros` e `Informações`; grupos vazios podem ser omitidos.
- Quando todos os áudios estiverem prontos, mostrar uma única linha de sucesso derivada de `readyMomentIds` e da quantidade de momentos.
- A saída de áudio aparece em `Informações`.
- Avisos não bloqueiam a entrada.
- Sem erros, a linha operacional final usa `Entrar no Modo Evento` e explica que nenhuma faixa será iniciada.
- Com erros, o texto muda para `Entrar mesmo assim`, recebe tratamento destrutivo discreto e abre confirmação que explica o risco de momentos sem áudio.
- Falha da própria verificação apresenta mensagem e `Tentar novamente` no mesmo padrão editorial.

### 6.6 Dashboard ao vivo

O layout aprovado anteriormente permanece como base e recebe a nova linguagem sem regressão funcional.

- Cabeçalho e painel `Tocando agora` ficam fixos no topo.
- `Tocando agora` usa painel de comando com acento lateral, nome do momento, faixa, estado, tempo e progresso.
- O painel tem altura natural; não usar limites que recortem conteúdo em 200%.
- O nome da faixa permanece em uma linha e usa ticker unidirecional:
  - pausa inicial;
  - deslocamento visual do conteúdo para a esquerda, revelando progressivamente o final do nome;
  - reinício no começo, sem movimento de vai e volta;
  - reinício ao trocar de faixa.
- `Momentos` usa lista editorial; toda a linha é tocável.
- A lista é a única região rolável entre o painel superior e a barra inferior.
- O momento atual combina acento, superfície e texto; não depende só de cor.
- A barra fixa inferior usa dock segmentado com alvos grandes e posições estáveis:
  - Pausar/Retomar;
  - Parar;
  - Narração.
- Narração recebe mais largura quando disponível; Parar permanece visualmente destrutivo sem dominar.
- A cortina `Volumes de emergência` surge por detrás do dock e não empurra nem sobrepõe a lista de momentos de forma imprevisível.
- Alertas usam altura natural e permanecem integralmente visíveis em fonte ampliada.

### 6.7 Estados auxiliares

#### Biblioteca vazia

- Manter `Novo` somente no cabeçalho.
- Estado vazio orienta o usuário sem repetir um grande CTA.

#### Importação e áudios pendentes

- Título `Áudios pendentes`.
- Explicar que os arquivos não acompanham o evento exportado.
- Cada linha associa nome esperado do arquivo ao momento e oferece `Selecionar`.
- `Resolver depois` permite voltar mantendo as referências pendentes.
- Quando tudo estiver resolvido, usar `Voltar ao evento` em vez de `Concluir`.

#### Confirmações destrutivas

- Informar o nome do item e a consequência.
- Ações `Cancelar` e `Excluir`.
- O vermelho identifica a ação destrutiva, mas não preenche todo o diálogo.
- Exclusão de momento esclarece que não remove o arquivo do dispositivo.

#### Carregamento e falha

- Listas usam esqueletos que preservam a geometria da tela.
- Operações pontuais podem usar progresso no próprio alvo.
- Falhas recuperáveis mostram causa em linguagem simples e `Tentar novamente`.
- Conteúdo anterior válido deve permanecer visível sempre que a operação permitir.

## 7. Fluxo de dados e limites de responsabilidade

### 7.1 Biblioteca

`EventLibraryController` continua responsável por carregar e alterar eventos. A ordenação é uma transformação de apresentação sobre uma cópia imutável da lista; não muda a ordem no repositório nem o arquivo exportado.

### 7.2 Contexto e edição

- Uma nova página contextual recebe o snapshot do evento e callbacks para preparar, editar e executar ações do menu.
- `EventEditorController` continua sendo a autoridade do rascunho e do salvamento de estrutura.
- O editor de momento modifica um rascunho local e só o devolve ao editor de estrutura ao tocar em `Salvar`.
- Sair sem salvar não altera o evento persistido.

### 7.3 Verificação

`PreflightService` continua realizando as sondagens. A apresentação deriva contagens de `PreflightResult.items`, `readyMomentIds` e `event.moments`. Não repetir sondagens dentro dos widgets.

### 7.4 Dashboard

`LiveEventController` e o coordenador de reprodução continuam sendo as fontes de verdade. Os novos componentes apenas representam estado e encaminham comandos existentes.

## 8. Acessibilidade e adaptação

- Testar escalas de texto 1,0 e 2,0 em largura compacta de telefone.
- Nenhuma tela pode apresentar overflow, recorte, sobreposição ou alvo inacessível em 200%.
- Telas de edição e verificação usam uma única rolagem vertical.
- Linhas editoriais crescem naturalmente e mantêm pelo menos 48 dp de alvo.
- Ações do cabeçalho podem quebrar para uma segunda linha, reduzir para ícone com tooltip/semântica ou migrar para o menu, conforme a prioridade; nunca devem se sobrepor.
- Controles lado a lado passam para uma coluna quando não houver largura:
  - Loop/Parar;
  - fade-in/fade-out;
  - métricas da verificação, se necessário.
- Nome de arquivo em editores usa elipse e acesso ao nome completo por semântica e detalhe; no Dashboard usa ticker.
- Todo ícone interativo possui rótulo semântico e tooltip quando aplicável.
- Ordem de foco segue a ordem visual.
- Estados de seleção, erro, aviso e sucesso não dependem apenas de cor.
- Respeitar áreas seguras, teclado e barras do sistema.

## 9. Tratamento de erros

- Falha ao carregar biblioteca: manter mensagem central, ação `Tentar novamente` e nenhum CTA concorrente.
- Falha ao importar ou exportar: mensagem específica, sem descartar o estado atual.
- Falha ao selecionar/revincular áudio: manter a linha pendente e permitir nova seleção.
- Falha ao salvar: manter o rascunho e o indicador de alterações não salvas.
- Falha na verificação: não permitir entrada sem resultado válido; oferecer nova tentativa.
- Erros de pré-evento não impedem entrada absoluta, mas exigem confirmação explícita.
- Ações destrutivas não podem ser executadas por toque único na listagem.

## 10. Estratégia de testes

### 10.1 Unidade

- comparadores das quatro ordenações;
- derivação das contagens da verificação;
- vocabulário e mapeamento de severidade onde houver funções puras;
- preservação do rascunho ao falhar o salvamento.

### 10.2 Widgets

- biblioteca com eventos, vazia, carregando e com falha;
- ordenação e navegação para o contexto;
- menu global com importação e menu contextual do evento;
- contexto do evento e destinos das ações;
- editor de estrutura, reordenação e salvamento explícito;
- editor de momento, seleção Loop/Parar, Narração, volume, fades e exclusão;
- revinculação de áudios pendentes;
- verificação em sucesso, aviso, erro, falha e progresso;
- Dashboard com painel, lista, dock, cortina e alertas.

Cada tela principal deve ter teste geométrico em 1,0 e 2,0 que confirme:

- ausência de exceções de layout;
- visibilidade integral de textos e ações essenciais;
- separação entre regiões fixas e roláveis;
- alvos mínimos de 48 dp;
- capacidade de alcançar o último elemento por rolagem.

### 10.3 Integração no emulador

- criar evento;
- editar estrutura e momento;
- selecionar áudio;
- preparar e entrar no Modo Evento;
- iniciar e trocar momentos;
- pausar, parar e alternar Narração;
- abrir e fechar volumes de emergência;
- alternar para outro aplicativo e retornar sem interrupção indevida;
- importar evento e revincular áudios;
- repetir o fluxo com fonte do sistema ampliada.

## 11. Critérios de aceitação

O refinamento estará concluído quando:

1. todas as telas aprovadas estiverem implementadas no tema escuro verde-petróleo;
2. a biblioteca oferecer as quatro ordenações e abrir o contexto do evento;
3. os editores usarem `Salvar`, vocabulário uniforme e rolagem segura;
4. a verificação mostrar contagens concretas e estados de severidade;
5. o Dashboard preservar todas as funções já entregues e adotar painel de comando, lista editorial e dock segmentado;
6. importação, revinculação, vazios, falhas e confirmações seguirem o mesmo sistema;
7. análise estática e testes automatizados passarem;
8. testes de widget em 200% não apresentarem overflow, recorte ou sobreposição;
9. o fluxo principal for validado no emulador Android;
10. o laboratório técnico permanecer fora das alterações de produto.

## 12. Sequência recomendada de implementação

1. Tokens de tema e primitivos editoriais.
2. Biblioteca, ordenação e contexto do evento.
3. Editar estrutura e editor de momento em tela cheia.
4. Verificação e estados auxiliares.
5. Aplicação do sistema visual ao Dashboard existente.
6. Testes de acessibilidade, integração no emulador e documentação.

Essa ordem reduz risco porque estabiliza primeiro os componentes reutilizados e deixa o Dashboard — a tela mais sensível operacionalmente — para depois de os padrões estarem testados.

## 13. Registro da implementação

O sistema visual foi implementado no fluxo principal Android em 15 de julho de
2026. A entrega inclui os tokens verde-petróleo aplicados aos papéis Material 3,
componentes editoriais, telas de Biblioteca e Evento, editores, Verificação e
Dashboard ao vivo. O laboratório técnico permaneceu fora do refinamento.

A revisão final confirmou também:

- `Tocando agora` preserva momento, faixa, estado, tempo e progresso em 100%,
  150% e 200%, inclusive em paisagem compacta;
- concluir a religação de todos os áudios importados retorna ao contexto do
  evento correspondente;
- `Disponibilizar Narração`, horário relativo da Verificação e papéis do tema
  seguem o vocabulário e a paleta deste documento;
- formatação, análise estática e 429 testes Flutter foram aprovados;
- os fluxos instrumentados de autoria/importação e Modo Evento foram aprovados
  no emulador Android 15/API 35.
