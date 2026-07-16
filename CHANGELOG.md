# Changelog

Todas as mudanças relevantes deste projeto serão documentadas neste arquivo.

## [Unreleased]

### Changed

- A Biblioteca agora usa linhas editoriais, quatro ordenações e abre o contexto
  do evento antes da edição ou preparação ao vivo.
- Os fluxos de Evento, Editar estrutura, Editar momento e Verificação adotam o
  vocabulário unificado (`Salvar`, `Selecionar`, `Áudios pendentes` e
  `Voltar ao evento`) e hierarquia visual consistente.
- “Tocando agora” permanece fixo no topo do Dashboard, com faixa lateral,
  progresso e ticker; o dock segmentado de Pausar/Retomar, Parar e Narração
  permanece fixo no rodapé.
- O toggle persistente de Volumes de emergência abre uma cortina por trás do
  dock, sem deslocar as regiões fixas nem perder a posição dos Momentos.
- Nomes longos da faixa atual percorrem uma única linha após uma pausa inicial,
  retornam ao começo por transição suave e permanecem estáticos quando o
  sistema solicita redução de animações.
- Em telas compactas, “Tocando agora” e alertas mostram um resumo e permitem
  abrir o conteúdo completo; o botão Voltar fecha a cortina de volumes antes
  de solicitar a saída do evento.

### Fixed

- Momentos ao vivo agora são linhas editoriais de toque integral, com faixa em
  uma linha, estado textual e destaque semântico/visual para o momento atual.
- Controles inativos de transporte e Narração permanecem visualmente inativos,
  mas legíveis no Dashboard escuro.
- Dashboard permanece sem recorte ou sobreposição com fontes de 100% a 200%,
  em viewports pequenos de retrato e paisagem, inclusive quando há alerta.
- O painel compacto de “Tocando agora” preserva momento, faixa com ticker,
  estado, tempo e progresso; em paisagem curta, a saída de áudio migra para o
  cabeçalho e o dock mantém alvos de 48 dp.
- Ao concluir a religação dos áudios de um evento importado, `Voltar ao evento`
  abre o contexto correto em vez de retornar à Biblioteca.
- Papéis Material do tema agora usam integralmente a paleta verde-petróleo; o
  editor usa `Disponibilizar Narração` e a Verificação mostra o horário relativo
  de sua última execução concluída.

### Validation

- 429 testes Flutter, formatação e análise estática aprovados.
- Biblioteca, contexto, editores, religação, Verificação e Dashboard cobertos
  por testes de widget de 100% a 200%, em retrato e paisagem.
- Fluxos instrumentados de autoria/importação e Modo Evento aprovados no
  emulador Android 15/API 35; buffer de crashes permaneceu vazio.

## [1.0.1] - 2026-07-14

### Changed

- Versão Android atualizada para `1.0.1+3`, preservando o crescimento do
  `versionCode` após os artefatos já distribuídos.

### Fixed

- Layouts de Dashboard, editores e religamento agora respeitam fontes Android
  ampliadas até 200% sem sobreposição ou overflow.
- “Tocando agora” e “Momentos” usam fluxo vertical com separação mínima de
  16 px e rolagem única no Modo Evento.
- Nomes extensos de arquivos de áudio são abreviados visualmente nos botões e
  cartões de momentos, preservando o nome completo para leitores de tela.

### Validation

- 388 testes Flutter e análise estática aprovados.
- APK assinado instalado e iniciado no emulador Android 15/API 35; versão
  `1.0.1 (3)`, tela “Meus Eventos” e buffer de crashes vazio confirmados.

## [1.0.0] - 2026-07-12

### Changed

- Promovido o release candidate aprovado para a primeira versão estável, sem
  mudanças funcionais.
- Versão Android atualizada para `1.0.0+2`, preservando o crescimento do
  `versionCode` após a distribuição do RC.

### Validation

- APK assinado do RC validado no emulador e em moto g54 5G com Android 15.
- Instalação, inicialização, retorno após alternância de aplicativo e ausência
  de crashes confirmados no aparelho físico.

### Known limitations

- Normalização automática de volume permanece fora do MVP.
- Testes manuais de Bluetooth, cabo, ligação, WhatsApp e sessão prolongada
  continuam adiados.

## [1.0.0-rc.1] - 2026-07-11

### Added

- Catálogo, editor e persistência local de eventos e momentos.
- Reprodução por momentos com fade, crossfade, loop e Modo Narração.
- Dashboard ao vivo com volumes de emergência e continuidade em segundo plano.
- Exportação e importação JSON com religamento manual de áudios.
- Restauração segura da sessão ativa e saída explícita para a biblioteca.

### Changed

- Identidade Android definida como `br.com.marcocardoso.soundtrack`.
- Stop interrompe a reprodução sem encerrar o Modo Evento; Sair encerra a
  sessão.

### Known limitations

- Normalização automática de volume permanece fora do MVP.
- Testes manuais de Bluetooth, cabo, ligação, WhatsApp e sessão prolongada
  estão adiados.
- O APK oficial depende da configuração do keystore privado.
