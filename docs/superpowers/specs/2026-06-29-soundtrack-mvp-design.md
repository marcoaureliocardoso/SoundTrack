# SoundTrack — Design do MVP

**Data:** 29 de junho de 2026  
**Plataforma inicial:** Android  
**Base técnica:** Flutter/Dart, com integrações Android isoladas quando necessárias  
**Estado:** aprovado para planejamento

## 1. Visão do produto

SoundTrack é uma mesa de trilha sonora para eventos, desenhada primeiro para pessoas sem experiência profissional em áudio. O usuário prepara uma linha do tempo com os momentos do evento, associa uma música local a cada momento e, durante o evento, inicia qualquer momento tocando em um botão grande.

O produto também atende profissionais de som que eventualmente assumam a operação. Essa flexibilidade não pode tornar a experiência básica mais complexa ou arriscada.

O princípio central é **continuidade primeiro**: durante o evento, o aplicativo deve evitar silêncio inesperado, preservar a faixa atual quando uma troca falhar e não interromper voluntariamente a reprodução por eventos externos.

## 2. Objetivos do MVP

- Criar e manter vários eventos no próprio dispositivo.
- Montar uma linha do tempo ordenada de momentos.
- Associar a cada momento uma música disponível no armazenamento do Android.
- Operar o evento em um Dashboard protegido, com todos os momentos acessíveis.
- Fazer fade-out e fade-in coordenados ao trocar de momento.
- Permitir repetição ou parada ao fim de cada música, com repetição como padrão.
- Oferecer modo Narração opcional por momento.
- Disponibilizar controles de Master, Música e Narração nas configurações e no Dashboard.
- Funcionar integralmente offline.
- Verificar arquivos e condições básicas antes de entrar no Modo Evento.
- Manter a música atual quando a próxima faixa não puder ser preparada.
- Permitir alternar livremente para outros aplicativos sem encerrar o Modo Evento ou interromper voluntariamente o áudio.
- Exportar a configuração de um evento como arquivo JSON legível e versionado.

## 3. Fora do escopo inicial

- iOS.
- Normalização automática de loudness.
- Integração com serviços de streaming.
- Contas, sincronização em nuvem ou colaboração remota.
- Controle remoto por outro dispositivo.
- Gravação de narração ou áudio do evento.
- Edição destrutiva dos arquivos de música.
- Automação da linha do tempo por horário ou duração.
- Importação de eventos exportados.
- Exportação em XML ou formatos adicionais.

A normalização permanece como evolução futura. O MVP oferece ajuste manual de ganho por momento.

## 4. Estrutura da experiência

### 4.1 Meus Eventos

Tela inicial com ações para:

- criar evento;
- abrir evento;
- duplicar evento;
- renomear evento;
- exportar evento;
- excluir evento mediante confirmação.

Cada evento exibe nome, quantidade de momentos, estado da última verificação e data de alteração.

### 4.2 Preparação

O editor permite:

- definir nome do evento;
- adicionar, remover e reordenar momentos;
- nomear cada momento;
- selecionar uma música local;
- ouvir um teste da música;
- escolher entre repetir ou parar ao fim;
- habilitar ou não Narração;
- ajustar ganho manual;
- herdar os fades globais ou definir uma exceção;
- configurar volumes e fades globais.

As músicas não são copiadas para o armazenamento interno. O app guarda a referência persistente fornecida pelo Android. Se o arquivo for movido, removido ou perder permissão, o momento será marcado como indisponível.

### 4.3 Verificação pré-evento

Antes do Modo Evento, o app verifica:

- acesso a todas as músicas;
- capacidade de preparar cada faixa;
- rota de saída atualmente selecionada;
- volume de mídia do Android;
- bateria disponível.

O app recomenda ativar “Não perturbe”, conectar o carregador e confirmar a saída de áudio. Problemas são listados por momento. O usuário pode entrar no Modo Evento com avisos, mas a interface deixa claro quais nós não estão prontos.

### 4.4 Modo Evento

O Modo Evento bloqueia alterações estruturais e mantém a tela ativa enquanto o SoundTrack estiver visível. Sair exige confirmação.

O Dashboard usa uma linha do tempo vertical com botões largos. A ordem e o número do momento permanecem visíveis. O nó atual tem indicação textual e visual; cor nunca é o único indicador.

O painel **Tocando agora** é informativo e visualmente distinto dos botões:

- superfície própria;
- rótulo explícito;
- música e momento atuais;
- posição e duração;
- estado de repetição;
- nenhum comportamento de toque que possa ser confundido com iniciar um momento.

Os botões dos momentos usam ícone de reprodução, borda e texto que indicam ação. Tocar no nó já ativo não reinicia a faixa.

Os comandos de Pausar, Parar e Narração ficam separados da linha do tempo. Parar exige confirmação ou gesto protegido; Pausar é imediatamente reversível.

Os três controles de volume — Master, Música e Narração — ficam disponíveis numa área de emergência expansível. Alterações feitas ali valem para a sessão atual e não sobrescrevem as predefinições sem uma ação explícita de salvar. Uma ação restaura os valores predefinidos.

### 4.5 Alternância entre aplicativos

O Modo Evento não usa modo quiosque, não bloqueia os comandos de navegação do Android e não impede o usuário de abrir WhatsApp, câmera ou qualquer outro aplicativo.

Ao colocar o SoundTrack em segundo plano:

- a reprodução e as transições já iniciadas continuam;
- o Modo Evento permanece ativo;
- momento, posição, volumes temporários e Narração são preservados;
- uma notificação persistente informa que o evento continua em execução e oferece uma ação para retornar ao Dashboard;
- ao voltar, o Dashboard reaparece no mesmo estado, sem reiniciar a música.

Se o Android encerrar o processo por falta de recursos, o app não pode garantir reprodução contínua. O serviço de áudio em primeiro plano reduz essa possibilidade, e a interface deve explicar claramente uma eventual recuperação.

### 4.6 Exportação do evento

Fora do Modo Evento, o usuário pode exportar um evento para um arquivo UTF-8 com extensão `.soundtrack.json`.

O arquivo contém:

- identificador do formato e versão do esquema;
- data da exportação;
- nome e configurações globais do evento;
- ordem e configuração de todos os momentos;
- metadados exibidos das músicas;
- referências locais do Android, explicitamente marcadas como dependentes do dispositivo.

O arquivo não contém os bytes das músicas e não é um pacote portátil de áudio. Uma referência pode deixar de funcionar após mover o arquivo, revogar a permissão, reinstalar o app ou usar outro dispositivo. A exportação serve para inspeção, integração futura e preservação da configuração; a importação e o religamento assistido das músicas ficam fora do MVP.

O esquema usa JSON por ser simples, amplamente suportado e fácil de versionar. XML e formatos adicionais não serão oferecidos no primeiro lançamento.

## 5. Modelo de dados

### Event

- identificador;
- nome;
- data de criação e alteração;
- configurações globais de áudio;
- lista ordenada de momentos.

### EventAudioSettings

- volume Master;
- volume de Música;
- volume de Narração;
- duração global de fade-in;
- duração global de fade-out.

Valores iniciais:

- Master: 80%;
- Música: 100%;
- Narração: 25%;
- fade-in: 2 segundos;
- fade-out: 2 segundos.

Todos são ajustáveis pelo usuário.

### Moment

- identificador;
- posição na linha do tempo;
- nome;
- referência persistente do Android para o arquivo;
- metadados exibidos da música;
- comportamento ao terminar: repetir ou parar;
- Narração habilitada;
- ajuste manual de ganho;
- fade-in opcional;
- fade-out opcional.

Quando um fade específico não existe, o momento herda o valor global. O fade-in pertence ao momento que entra; o fade-out pertence ao momento que sai.

### SessionState

Estado transitório do Modo Evento:

- momento atual;
- estado de reprodução;
- posição;
- Narração ativa;
- volumes temporários;
- rota de áudio observada;
- transição em andamento;
- alertas não bloqueantes.

O estado da sessão não altera as predefinições do evento automaticamente.

### EventExport

Envelope textual do arquivo exportado:

- `format`: valor fixo `soundtrack-event`;
- `schemaVersion`: inteiro iniciado em `1`;
- `exportedAt`: data e hora em ISO 8601;
- `event`: configuração serializada do evento;
- `audioSources`: referências locais e metadados, cada uma marcada com `portable: false`.

Campos futuros devem ser opcionais ou acompanhados por incremento de `schemaVersion`. Dados transitórios de `SessionState` não são exportados.

## 6. Regras de áudio

O volume efetivo é composto por:

`volume de mídia do Android × Master × Música ou Narração × ganho do momento`

O app controla apenas seus próprios fatores. O volume de mídia do Android é observado e exibido na verificação, sem ser confundido com o Master do app.

### 6.1 Iniciar o primeiro momento

1. Validar acesso ao arquivo.
2. Preparar a faixa.
3. Iniciar em volume zero.
4. Aplicar fade-in até o volume efetivo.
5. Confirmar o momento como atual.

Se a preparação falhar, nenhum estado atual é descartado e o usuário recebe um alerta.

### 6.2 Trocar de momento

1. Validar e preparar a próxima faixa sem interromper a atual.
2. Iniciar a próxima faixa em volume zero.
3. Executar simultaneamente o fade-out da faixa atual e o fade-in da próxima.
4. Encerrar e descarregar a faixa anterior.
5. Confirmar o novo momento.

Dois players coordenados permitem o crossfade. O controlador de transição é a única unidade autorizada a trocar o momento atual.

Se o destino falhar antes de estar pronto, a faixa atual continua sem alteração. Toques rápidos não criam uma fila: o pedido válido mais recente substitui a transição pendente, partindo dos volumes efetivos daquele instante.

### 6.3 Fim da faixa

- **Repetir:** reinicia a mesma faixa de modo contínuo; é o padrão.
- **Parar:** executa o fade-out configurado e fica em silêncio, mantendo o momento selecionado.

### 6.4 Narração

O botão aparece apenas quando o momento atual permite Narração.

- Um toque ativa e outro desativa.
- Ao ativar, o volume converge suavemente do nível Música para o nível Narração.
- Ao desativar, retorna suavemente ao nível Música.
- Trocar de momento desativa Narração antes da nova faixa.
- O estado ativo é destacado por texto, ícone e cor.

### 6.5 Pausar e parar

- **Pausar:** reduz rapidamente o volume e pausa preservando a posição.
- **Retomar:** continua da mesma posição com entrada suave.
- **Parar:** faz fade-out, limpa o momento atual e exige proteção contra toque acidental.

## 7. Política de continuidade

Somente Pausar, Parar ou sair do Modo Evento interrompem voluntariamente a reprodução.

- Ao desconectar Bluetooth ou cabo, o app não pausa por conta própria. A reprodução continua na rota escolhida pelo Android e um alerta visual informa a mudança.
- Em ligação ou perda de foco de áudio, o app tenta manter a reprodução. Quando o Android impuser uma interrupção, o app preserva posição e estado e retoma automaticamente assim que o sistema permitir.
- Alertas de rota ou foco não bloqueiam os controles do evento.
- O app usa execução apropriada para áudio em primeiro plano e mantém o estado da sessão durante sobreposições breves.
- Alternar para outro aplicativo não é tratado como pausa, saída ou encerramento do Modo Evento.

O Android pode impor interrupções que o aplicativo não consegue evitar. O requisito é minimizar o intervalo, preservar o contexto e retomar sem ação manual.

## 8. Arquitetura

### Presentation

- Meus Eventos;
- Editor;
- Verificação;
- Dashboard;
- componentes reutilizáveis de volume, momento e estado de reprodução.

A interface envia intenções e renderiza um estado imutável. Ela não controla players diretamente.

### Application

- `EventEditorController`: edição e validação do evento;
- `PreflightController`: verificação de arquivos, saída e condições;
- `LiveEventController`: estado e comandos da sessão;
- `PlaybackCoordinator`: serialização de comandos e transições;
- `VolumeController`: composição de Master, modo e ganho;
- `TransitionEngine`: curvas de fade e cancelamento seguro.

### Domain

- Event;
- Moment;
- EventAudioSettings;
- SessionState;
- regras puras de volume, herança, repetição e Narração.

### Infrastructure

- repositório local de eventos;
- acesso a documentos do Android e permissões persistentes;
- adaptação dos dois players;
- observação de foco e rota de áudio;
- integração para tela ativa e execução em primeiro plano.
- serialização versionada e compartilhamento do arquivo JSON exportado.

As interfaces entre essas unidades permitem substituir armazenamento ou biblioteca de áudio sem alterar as regras do produto.

## 9. Tratamento de falhas

- Arquivo inacessível no editor: marcar o momento e oferecer nova seleção.
- Arquivo inacessível no pré-evento: listar erro específico.
- Arquivo inacessível durante a troca: manter a faixa atual.
- Falha no primeiro momento: permanecer em silêncio e exibir ação de tentar novamente.
- Falha durante crossfade antes da confirmação: cancelar a faixa nova e estabilizar a atual.
- Mudança de rota: continuar e alertar.
- Interrupção imposta pelo Android: preservar posição e retomar automaticamente.
- App enviado ao segundo plano: manter serviço, reprodução e estado; restaurar o mesmo Dashboard ao retornar.
- Falha ao criar ou compartilhar exportação: não alterar o evento e informar o destino ou a permissão que falhou.
- Estado persistente corrompido: isolar o evento afetado e manter os demais acessíveis.
- Encerramento inesperado: salvar alterações do editor de forma atômica; a sessão ao vivo não promete retomar áudio após o processo ser morto.

Mensagens de erro devem dizer o que ocorreu, qual momento foi afetado e qual ação pode resolver o problema.

## 10. Estratégia de testes

### Unitários

- composição de volumes;
- limites e ganho por momento;
- herança de fades;
- máquina de estados da reprodução;
- Narração e cancelamento ao trocar de momento;
- repetição e parada;
- comando mais recente durante transição;
- preservação da faixa atual em falhas.

### Persistência

- criar, editar, duplicar e excluir eventos;
- manter ordem dos momentos;
- salvar configurações globais e exceções;
- recuperação após escrita interrompida;
- referências de arquivo válidas e inválidas.

### Interface

- distinção entre painel informativo e botões;
- proteção de ações destrutivas;
- volumes temporários e restauração;
- estados ativo, pausado, Narração e erro;
- tamanhos mínimos de toque e acessibilidade.
- alternância para outro app e retorno ao mesmo estado visual.

### Integração Android

- seleção e permissão persistente de arquivos;
- preparação de formatos suportados;
- crossfade com dois players;
- mudança entre alto-falante, cabo e Bluetooth;
- perda e retorno de foco de áudio;
- tela ativa e execução prolongada.
- reprodução e transições com o app em segundo plano;
- encerramento e recriação da interface sem reiniciar a sessão mantida pelo serviço.

### Exportação

- JSON válido em UTF-8;
- esquema e versão presentes;
- ordem e configurações preservadas;
- referências de áudio marcadas como não portáveis;
- ausência dos bytes das músicas;
- falha de escrita ou compartilhamento sem modificar o evento;
- compatibilidade de leitura estrutural por ferramentas JSON comuns.

### Validação física

- testes prolongados em aparelho real;
- saída cabeada e Bluetooth;
- eventos com muitas trocas;
- arquivos longos e de formatos diferentes;
- toques rápidos durante fades;
- bateria baixa, tela bloqueada e sobreposições;
- medição auditiva de transições, loops e Narração.

## 11. Critérios de sucesso do MVP

- Um usuário leigo consegue preparar e executar um evento sem treinamento técnico.
- Qualquer momento válido pode ser iniciado com um toque.
- Trocas válidas não produzem corte seco nem intervalo perceptível indevido.
- Falha ao abrir a próxima música não interrompe a atual.
- Narração altera o nível de forma previsível e nunca permanece ativa após troca de momento.
- O Dashboard diferencia inequivocamente informação de ação.
- O app funciona sem rede.
- Interrupções externas não provocam pausa voluntária e a retomada automática ocorre quando o Android a torna necessária.
- Alternar para outro aplicativo não interrompe voluntariamente o áudio, e retornar preserva o estado do Dashboard.
- Um evento pode ser exportado como JSON versionado sem incorporar os arquivos de música.
- Uma sessão prolongada em aparelho físico não apresenta vazamentos progressivos, perda de comandos ou degradação das transições.
