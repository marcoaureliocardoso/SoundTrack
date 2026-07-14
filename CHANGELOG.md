# Changelog

Todas as mudanças relevantes deste projeto serão documentadas neste arquivo.

## [Unreleased]

### Changed

- “Tocando agora” permanece fixo no topo do Dashboard e a barra com Pausar ou
  Retomar, Parar, Narração e Volumes permanece fixa no rodapé; somente a lista
  de momentos rola entre essas regiões.
- Volumes de emergência agora surgem como uma cortina no espaço central e
  preservam a posição da lista de momentos ao fechar.
- Nomes longos da faixa atual percorrem uma única linha após uma pausa inicial,
  retornam ao começo por transição suave e permanecem estáticos quando o
  sistema solicita redução de animações.
- Em telas compactas, “Tocando agora” e alertas mostram um resumo e permitem
  abrir o conteúdo completo; o botão Voltar fecha a cortina de volumes antes
  de solicitar a saída do evento.

### Fixed

- Cartões de momentos agora usam foreground uniforme e contraste WCAG AA em
  número, nome, faixa e estado.
- Controles inativos de transporte e Narração permanecem visualmente inativos,
  mas legíveis no Dashboard escuro.
- Dashboard permanece sem recorte ou sobreposição com fontes de 100% a 200%,
  em viewports pequenos de retrato e paisagem, inclusive quando há alerta.

### Validation

- 405 testes Flutter, formatação e análise estática aprovados; APK debug
  compilado com sucesso.
- APK de QA instalado no emulador Android 15/API 35 com o certificado oficial;
  Dashboard exercitado com oito momentos em 100% e 200%, retrato e paisagem.
- Limites de “Tocando agora” e das quatro ações permaneceram idênticos antes e
  depois da rolagem; cortina, Voltar, posição preservada, processo ativo e
  buffer de crashes vazio foram confirmados.

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
