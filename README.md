# Diário de consumo consciente

App em Flutter para acompanhar gastos, hábitos de consumo e estimativas de
impacto ambiental. Os dados ficam armazenados localmente no dispositivo com
Hive CE, então o app pode ser usado offline.

## Pré-requisitos

- Flutter **3.47.5** (Dart **3.13.4** ou compatível com a restrição do projeto).
- Android Studio ou Android SDK configurado para compilar para Android.
- Java/JDK 17 ou superior.
- Um emulador Android ou dispositivo físico para executar o app.

No Windows, para compilar plugins Flutter que usam links simbólicos, habilite
o **Modo de Desenvolvedor** em Configurações do Windows.

## Configurar o Android SDK

Instale o Android SDK pelo Android Studio ou pelo Android command-line tools.
O projeto usa Android API 36 e NDK `28.2.13676358`. Se estiver instalando os
componentes manualmente, use o `sdkmanager` da instalação do SDK:

```powershell
$env:ANDROID_HOME = "C:\Users\<usuario>\AppData\Local\Android\Sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$sdkmanager = Join-Path $env:ANDROID_SDK_ROOT "cmdline-tools\latest\bin\sdkmanager.bat"

& $sdkmanager --sdk_root="$env:ANDROID_SDK_ROOT" `
  "platform-tools" `
  "platforms;android-36" `
  "build-tools;36.0.0" `
  "ndk;28.2.13676358" `
  "cmdline-tools;latest"

flutter config --android-sdk "$env:ANDROID_SDK_ROOT"
flutter doctor --android-licenses
flutter doctor
```

Aceite os termos apresentados pelo comando de licenças. No Android Studio,
também é possível instalar esses pacotes em **SDK Manager > SDK Platforms /
SDK Tools**. Não versione `android/local.properties`: ele contém caminhos
locais da instalação do Flutter e do Android SDK.

## Baixar dependências e executar

Na pasta raiz do repositório:

```powershell
flutter pub get
flutter devices
flutter run -d <device-id>
```

`flutter devices` lista os emuladores e dispositivos disponíveis. Para usar um
celular via USB, habilite as opções de desenvolvedor e a depuração USB no
aparelho e autorize a conexão quando solicitado. Também é possível iniciar o
app no dispositivo padrão com `flutter run`.

Para executar os testes e verificar o código:

```powershell
flutter test
flutter analyze
```

## Gerar APK para validação

```powershell
flutter build apk --release
```

O APK fica em:

```text
build/app/outputs/flutter-apk/app-release.apk
```

O build release deste projeto usa a assinatura de debug configurada no Gradle,
adequada para validação local em dispositivos físicos, mas não para publicar
na Google Play Store.
