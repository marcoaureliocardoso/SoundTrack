# Changelog

Todas as mudanças relevantes deste projeto serão documentadas neste arquivo.

## [Unreleased]

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
