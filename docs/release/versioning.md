# Versionamento do SoundTrack

## Aplicativo

O SoundTrack usa versionamento semântico no formato `MAJOR.MINOR.PATCH`. Um
sufixo identifica candidatos ainda não promovidos à versão estável.

A versão de desenvolvimento é `1.0.1+3`:

- `1.0.1` é uma correção compatível da primeira versão estável;
- `+3` gera o próximo `versionCode` Android, superior aos artefatos já
  distribuídos;
- essa versão permanece não publicada enquanto suas mudanças estiverem em
  `[Unreleased]` no changelog.

A última versão publicada é `1.0.0+2`, identificada pela tag `v1.0.0`. A
versão de desenvolvimento não deve ser confundida com um artefato oficial.

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
Uma tag ou GitHub Release `v1.0.1` somente será criada após nova validação e
decisão explícita de publicação.

As tags `v1.0.0-rc.1` e `v1.0.0` devem apontar para os commits exatos usados
nos respectivos builds. Tags e GitHub Releases não são usados para builds
locais ou APKs assinados com chave debug.
