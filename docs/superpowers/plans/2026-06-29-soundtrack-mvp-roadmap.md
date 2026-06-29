# SoundTrack MVP Implementation Roadmap

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement these plans task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o MVP Android do SoundTrack em três incrementos executáveis, cada um com testes e um produto demonstrável.

**Architecture:** O app usa Flutter/Dart para interface, domínio e orquestração. Integrações de documentos usam Storage Access Framework por canal de plataforma, e reprodução usa dois players `just_audio` coordenados por um `AudioHandler` do `audio_service`.

**Tech Stack:** Flutter 3.44.2, Dart 3.12.2, Kotlin/Android, `path_provider`, `uuid`, `just_audio`, `audio_service`, `audio_session`, Flutter Test e Integration Test.

---

## Sequência obrigatória

1. [Foundation, Event Editing, Import and Export Plan](2026-06-29-soundtrack-foundation-plan.md)
2. [Audio Engine and Background Playback Plan](2026-06-29-soundtrack-audio-engine-plan.md)
3. [Live Event Dashboard and Acceptance Plan](2026-06-29-soundtrack-live-event-plan.md)

Cada plano parte do commit final do plano anterior. Não execute tarefas de dois planos ao mesmo tempo: os contratos de domínio e áudio são deliberadamente estabilizados em sequência.

## Limites preservados da especificação

Os planos não adicionam normalização automática, iOS, streaming, contas, nuvem, controle remoto, gravação ou automação por horário. Nenhuma funcionalidade do MVP depende de rede em tempo de execução. XML também permanece fora do primeiro lançamento; o único formato de transferência é JSON versionado.

## Matriz de cobertura

| Seção da especificação | Tarefas |
|---|---|
| Meus Eventos e Preparação | Foundation 4–6 |
| Seleção e persistência de músicas | Foundation 7–8 |
| Exportação, importação e religamento | Foundation 8–9 |
| Modelo de dados e validação | Foundation 2–5 |
| Volumes, fades, repetição e Narração | Audio Engine 1–4 |
| Segundo plano, foco e mudança de rota | Audio Engine 5–7 |
| Verificação pré-evento | Live Event 1–4 |
| Dashboard e controles protegidos | Live Event 3–6 |
| Alternância entre aplicativos | Audio Engine 5–7 e Live Event 6 |
| Erros e continuidade primeiro | Audio Engine 3 e 6; Live Event 1, 3 e 6 |
| Testes automatizados e físicos | Checkpoint final de cada plano |
| Critérios de sucesso do MVP | Live Event 7 |

## Entrega 1 — Catálogo e preparação

Ao fim do primeiro plano, o usuário consegue:

- criar, duplicar, editar, reordenar e excluir eventos;
- selecionar músicas por `ACTION_OPEN_DOCUMENT`;
- persistir referências concedidas pelo Android;
- exportar `.soundtrack.json`;
- importar eventos e religar áudios pendentes;
- reabrir o app e encontrar os dados preservados.

Não há reprodução ao vivo nessa entrega; o botão Modo Evento permanece desabilitado com explicação.

## Entrega 2 — Motor de áudio

Ao fim do segundo plano, uma tela técnica permite:

- iniciar músicas locais;
- trocar faixas com crossfade;
- repetir ou parar no fim;
- ajustar Master, Música, Narração e ganho do momento;
- continuar em segundo plano;
- retomar automaticamente após interrupção imposta pelo Android;
- manter a faixa atual quando a próxima falha.

Essa entrega estabiliza `LivePlaybackPort`, usado pela interface final.

## Entrega 3 — Operação ao vivo

Ao fim do terceiro plano, o produto completo inclui:

- verificação pré-evento;
- Dashboard protegido;
- painel Tocando agora distinto dos botões;
- linha do tempo vertical;
- controles de emergência;
- alertas não bloqueantes;
- restauração após alternar entre aplicativos;
- testes de integração e roteiro de validação física.

## Referências técnicas confirmadas

- O Storage Access Framework fornece `ACTION_OPEN_DOCUMENT`, `ACTION_CREATE_DOCUMENT` e permissões persistentes, mas a permissão deixa de funcionar se o documento for movido ou excluído: [Android shared documents](https://developer.android.com/training/data-storage/shared/documents-files).
- Reprodução de mídia em segundo plano exige serviço do tipo `mediaPlayback` nas versões Android atuais: [Foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types).
- `audio_service` expõe `AudioHandler`, notificação e estado compartilhado com a interface: [audio_service](https://pub.dev/packages/audio_service).
- `just_audio` suporta múltiplos players, volume, loop, streams de estado e erros: [just_audio](https://pub.dev/packages/just_audio).
- `audio_session` expõe interrupções e mudanças de rota; o app desabilitará o tratamento automático do player para aplicar a política de continuidade: [audio_session](https://pub.dev/packages/audio_session).
- Android 12+ pode impor fade/mute por foco ou chamada; o app preserva o estado e retoma quando permitido: [Android audio focus](https://developer.android.com/media/optimize/audio-focus).
