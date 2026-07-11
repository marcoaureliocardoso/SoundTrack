# Versionamento do SoundTrack

## Aplicativo

O SoundTrack usa versionamento semântico no formato `MAJOR.MINOR.PATCH`. Um
sufixo identifica candidatos ainda não promovidos à versão estável.

A versão atual é `1.0.0-rc.1+1`:

- `1.0.0-rc.1` é o nome público do primeiro release candidate;
- `+1` gera o `versionCode` Android.

O `versionCode` deve crescer em todo artefato distribuído. Uma reconstrução
destinada a usuários não pode reutilizar um número já publicado, mesmo quando
o nome público continuar igual.

## Esquema JSON

O `schemaVersion` das exportações é independente da versão do aplicativo. O RC
continua lendo e escrevendo `schemaVersion: 1`. Alterações no app não exigem
incremento do esquema enquanto o formato exportado permanecer compatível.

## Promoção e tags

Um candidato somente pode ser promovido para `1.0.0` depois dos gates
automatizados, validação do APK assinado e decisão explícita de release.

A tag `v1.0.0-rc.1` deve ser criada depois da geração e validação do artefato
assinado e deve apontar para o commit exato usado no build. Tags e GitHub
Releases não são usados para builds locais ou APKs assinados com chave debug.
