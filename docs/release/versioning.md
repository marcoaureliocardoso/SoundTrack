# Versionamento do SoundTrack

## Aplicativo

O SoundTrack usa versionamento semântico no formato `MAJOR.MINOR.PATCH`. Um
sufixo identifica candidatos ainda não promovidos à versão estável.

A versão atual publicada é `1.0.1+3`:

- `1.0.1` é uma correção compatível da primeira versão estável;
- `+3` é o `versionCode` Android, superior aos artefatos distribuídos;
- a tag correspondente é `v1.0.1`.

O `versionCode` deve crescer em todo artefato distribuído. Uma reconstrução
destinada a usuários não pode reutilizar um número já publicado, mesmo quando
o nome público continuar igual.

## Esquema JSON

O `schemaVersion` das exportações é independente da versão do aplicativo. O RC
continua lendo e escrevendo `schemaVersion: 1`. Alterações no app não exigem
incremento do esquema enquanto o formato exportado permanecer compatível.

## Promoção e tags

O candidato `1.0.0-rc.1` foi promovido para `1.0.0` depois dos gates
automatizados, da validação do APK assinado e da decisão explícita de release.
Depois dos mesmos gates, as correções de acessibilidade foram publicadas como
`v1.0.1`.

As tags `v1.0.0-rc.1`, `v1.0.0` e `v1.0.1` devem apontar para os commits exatos
usados nos respectivos builds. Tags e GitHub Releases não são usados para
builds locais ou APKs assinados com chave debug.
