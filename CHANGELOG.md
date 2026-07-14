# Changelog

Todas as mudanças relevantes deste projeto serão documentadas neste arquivo.

## [Unreleased]

### Changed

- Metadados da próxima correção preparados como `1.0.1+3`; `v1.0.0` permanece
  a última versão publicada.

### Fixed

- Layouts de Dashboard, editores e religamento agora respeitam fontes Android
  ampliadas até 200% sem sobreposição ou overflow.
- “Tocando agora” e “Momentos” usam fluxo vertical com separação mínima de
  16 px e rolagem única no Modo Evento.
- Nomes extensos de arquivos de áudio são abreviados visualmente nos botões e
  cartões de momentos, preservando o nome completo para leitores de tela.

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
