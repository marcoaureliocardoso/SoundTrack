# Correção de ciclo de vida da sessão ao vivo

## Objetivo

Corrigir os dois comentários abertos no PR #1 sem alterar a política de
continuidade de áudio: a sessão deve acompanhar o Modo Evento, enquanto o
comando Stop deve interromper somente a reprodução atual.

## Semântica aprovada

- Entrar no Dashboard ativa e persiste a sessão do evento.
- **Parar reprodução** interrompe a faixa atual, mas mantém a sessão ativa e o
  operador no Dashboard.
- Depois de Stop, iniciar outro momento reutiliza a mesma sessão persistida.
- **Sair do Modo Evento** interrompe a reprodução, encerra e remove a sessão
  persistida e retorna à biblioteca.
- Uma sessão persistida só é restaurável quando o snapshot ainda representa
  reprodução ativa ou pausada com um momento associado. Estados idle e stopped
  são tratados como obsoletos e limpos.

## Componentes

### LiveEventController

O controlador terá comandos distintos:

- confirmStop(): chama somente o Stop do motor de áudio;
- confirmExit(): chama o Stop e, após sucesso, limpa o
  ActiveLiveSessionStore.

Essa separação impede que um controle de transporte encerre silenciosamente o
Modo Evento. A limpeza continuará posterior ao Stop para preservar a sessão
quando o motor recusar o comando.

### LiveDashboardPage

A página aceitará um callback opcional de encerramento. Após confirmExit():

- quando foi empilhada pela preparação normal, continuará usando
  Navigator.pop;
- quando foi restaurada como raiz, chamará o callback fornecido pelo app.

O callback de raiz substituirá o Dashboard pela biblioteca sem criar uma rota
duplicada e sem depender de um pop impossível.

### SoundTrackApp

O futuro que seleciona a tela inicial passará a ser substituível. Ao receber o
encerramento do Dashboard restaurado, o app atualizará esse estado para
apresentar a biblioteca. A restauração também rejeitará snapshots idle,
stopped ou sem activeMomentId.

## Concorrência e erros

- Stop e saída continuam aguardando o motor de áudio antes de atualizar a
  persistência ou a navegação.
- Falha no Stop mantém o Dashboard e a sessão persistida, permitindo nova
  tentativa.
- O callback de saída só roda depois que Stop e limpeza terminarem.
- Nenhuma mudança será feita no tratamento de background, interrupções ou
  fades.

## Testes

1. confirmStop() interrompe o áudio e preserva o ID da sessão.
2. confirmExit() limpa o ID somente depois que o Stop termina.
3. Stop seguido de novo momento mantém a sessão restaurável.
4. O Dashboard restaurado, ao confirmar saída, mostra a biblioteca.
5. Snapshot stopped com ID persistido é limpo no startup.
6. Os testes existentes de saída empilhada, lifecycle e operação ao vivo
   continuam aprovados.

## Fora de escopo

- Alterar os controles visuais ou textos do Dashboard.
- Mudar a política de foco de áudio, chamadas, Bluetooth ou cabo.
- Executar a aceitação em aparelho físico nesta correção.
