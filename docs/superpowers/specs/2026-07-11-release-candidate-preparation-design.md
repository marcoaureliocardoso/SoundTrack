# SoundTrack — preparação do release candidate

Data: 11 de julho de 2026.

## Objetivo

Preparar o repositório para o primeiro release candidate Android sem publicar
um instalador não assinado ou assinado com chave de desenvolvimento.

## Decisões aprovadas

- A versão do aplicativo será `1.0.0-rc.1+1`.
- O `applicationId`, o namespace Android e os pacotes Kotlin serão
  `br.com.marcocardoso.soundtrack`.
- O nome exibido pelo Android será `SoundTrack`.
- O APK oficial, a tag `v1.0.0-rc.1` e o GitHub Release serão criados somente
  depois da configuração e custódia do keystore privado.
- Esta rodada termina em uma branch e uma Pull Request de preparação do RC.
- Os testes físicos manuais de Bluetooth, cabo, ligação, WhatsApp e sessão
  prolongada permanecem adiados e não serão registrados como aprovados.

## Versionamento

O projeto seguirá SemVer para o nome da versão Flutter/Android:

- `1.0.0-rc.1` identifica o primeiro candidato à versão estável 1.0.0;
- `+1` é o primeiro `versionCode` Android e deve crescer a cada artefato
  distribuído, inclusive entre candidatos que reutilizem o mesmo nome;
- a versão do esquema JSON exportado permanece independente, em
  `schemaVersion: 1`.

Não haverá tag ou GitHub Release antes de o APK release assinado ser gerado e
validado. A tag deverá apontar para o commit exato usado no artefato publicado.

## Identidade Android

A migração de `com.soundtrack.soundtrack` para
`br.com.marcocardoso.soundtrack` abrangerá:

- `namespace` e `applicationId` do Gradle;
- declarações de pacote, diretórios e testes Kotlin;
- atividade principal declarada no manifesto;
- nomes dos MethodChannels e do canal de notificação pertencentes ao app.

O nome técnico do pacote Dart continuará `soundtrack`; essa identidade é
interna ao código Flutter e não precisa acompanhar o identificador Android.

## Assinatura

O Gradle carregará a configuração privada de `android/key.properties`. O
arquivo indicará caminho do keystore, alias e senhas, e continuará ignorado
pelo Git junto com arquivos de chave.

Comportamento esperado:

- builds debug continuam funcionando sem credenciais;
- build ou bundle release sem configuração falha com mensagem explícita;
- com uma configuração completa, o build release usa exclusivamente a chave
  informada;
- nenhuma senha, chave ou caminho pessoal será versionado.

A documentação explicará a estrutura esperada, a geração fora do repositório,
o backup e os comandos de build, sem criar credenciais nesta rodada.

## Documentação

O `README.md` passará a descrever o produto entregue, funcionalidades do MVP,
ambiente validado, execução, testes, limitações e estado de RC.

Será criado um `CHANGELOG.md` com `Unreleased` e `1.0.0-rc.1`, seguindo uma
estrutura compatível com Keep a Changelog. Documentos específicos registrarão
a política de versionamento e a assinatura Android.

O checklist de aceitação será corrigido para:

- diferenciar **Parar reprodução** de **Sair do Modo Evento**;
- registrar 344 testes automatizados;
- registrar a execução dos três fluxos integrados no moto g54 5G, Android 15;
- manter os cenários físicos manuais explicitamente adiados.

Os planos em `docs/superpowers/plans` serão identificados como registros
históricos de implementação. Especificações aprovadas e documentação de
release prevalecem quando um plano antigo descrever comportamento superado.

## Verificação

A Pull Request somente estará pronta após:

1. formatação sem mudanças;
2. `flutter analyze` sem problemas;
3. 344 testes Flutter aprovados;
4. build APK debug aprovado;
5. tentativa de build release sem keystore falhando com a mensagem prevista;
6. busca sem referências técnicas remanescentes a
   `com.soundtrack.soundtrack`;
7. links Markdown locais válidos;
8. `git diff --check` sem erros.

Os fluxos integrados já aprovados no moto g54 não serão repetidos nesta rodada,
pois a mudança não altera comportamento funcional; o APK debug será instalado
novamente apenas se a migração de identidade revelar falha de inicialização.

## Fora de escopo

- criar, armazenar ou transferir o keystore privado;
- publicar APK, tag ou GitHub Release;
- promover o RC para `1.0.0`;
- executar os testes físicos manuais adiados;
- alterar o esquema JSON exportado;
- adicionar novas funcionalidades ao produto.
