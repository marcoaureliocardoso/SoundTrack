# Assinatura Android

O SoundTrack exige uma chave privada para qualquer build release. Builds debug
continuam usando as credenciais de desenvolvimento gerenciadas pelo Android.

## Arquivos privados

Crie `android/key.properties` somente no ambiente de build. O arquivo deve
definir estas quatro propriedades com os valores privados reais:

- `storeFile`: caminho do keystore, resolvido a partir do diretório `android`;
- `storePassword`: senha do keystore;
- `keyAlias`: alias da chave de assinatura;
- `keyPassword`: senha da chave.

`android/key.properties`, arquivos `.jks` e arquivos `.keystore` estão
ignorados pelo Git. Não remova essas regras e nunca registre senhas, chaves ou
caminhos pessoais em commits, logs, issues ou Pull Requests.

## Custódia

Mantenha o keystore fora do repositório e faça backup criptografado em local
controlado. Guarde senhas em um gerenciador de segredos separado do arquivo. A
perda da chave impede publicar atualizações compatíveis para o mesmo
`applicationId`.

## Builds

Sem configuração completa, tasks release falham com uma mensagem indicando as
quatro propriedades exigidas. O comportamento é intencional e impede fallback
para a chave debug.

Depois de configurar e auditar a chave:

```powershell
flutter build apk --release
flutter build appbundle --release
```

Valide o artefato assinado que será distribuído antes de criar a tag e o
GitHub Release. Não publique um APK diferente daquele efetivamente testado.
