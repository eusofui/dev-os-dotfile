#Requires -Version 5.1
<#
    02-mobile-desktop.ps1
    ------------------------------------------------------------------
    Desenvolvimento Mobile (Android/iOS) e Desktop (Windows/Linux/Mac):
      - Visual Studio Community 2022 completo, com workloads de C++,
        .NET desktop, .NET MAUI (mobile + desktop) e UWP/WinUI
      - Android Studio + Android SDK (platform-tools, build-tools, emulator)
      - Flutter SDK
      - React Native (via Node.js, ja instalado no modulo 01)
      - react-native-windows (desktop Windows nativo em React Native)

    OBS. IMPORTANTE SOBRE iOS:
      O Windows NAO compila nem empacota apps iOS nativamente — a Apple exige
      Xcode/macOS para o build final. Por decisao deste projeto (sem Mac
      disponivel no momento), o iOS NAO e configurado agora. O ambiente fica
      100% pronto para Android e, quando fizer sentido, adicionar iOS via um
      servico de build em nuvem (Expo EAS Build ou Codemagic), sem precisar
      reinstalar nada aqui.
    ------------------------------------------------------------------
#>
param(
    [Parameter(Mandatory = $true)]$Config,
    [Parameter(Mandatory = $true)][string]$RaizRepo
)

Import-Module (Join-Path $RaizRepo 'lib\Common.psm1') -Force
$resultados = @()

# ============================================================================
# VISUAL STUDIO COMMUNITY 2022 — IDE completa para C++/.NET/MAUI
# ============================================================================
Write-Log 'Visual Studio Community 2022 + workloads' -Nivel PASSO

$listaWorkloads = @()
foreach ($workload in $Config.VisualStudioWorkloads) {
    $listaWorkloads += '--add'
    $listaWorkloads += $workload
}
$argumentosVs = @('--override', "`"$($listaWorkloads -join ' ') --quiet --norestart`"")

$resultados += Install-WingetApp -Id 'Microsoft.VisualStudio.2022.Community' -Nome 'Visual Studio Community 2022' `
    -Origem 'https://visualstudio.microsoft.com/pt-br/vs/community/' -ArgumentosExtras $argumentosVs `
    -UrlManualFallback 'https://visualstudio.microsoft.com/pt-br/downloads/'

Write-Log 'Workloads instalados: C++ Desktop, .NET Desktop, .NET MAUI (multiplataforma), UWP/WinUI.' -Nivel INFO
Write-Log 'Para adicionar/remover workloads depois, abra o "Visual Studio Installer" (ja instalado junto).' -Nivel INFO

# ============================================================================
# ANDROID — Android Studio + SDK
# ============================================================================
Write-Log 'Android Studio + Android SDK' -Nivel PASSO

$resultados += Install-WingetApp -Id 'Google.AndroidStudio' -Nome 'Android Studio' -Origem 'https://developer.android.com/studio'

$pastaAndroidSdk = "$env:LOCALAPPDATA\Android\Sdk"
Set-UserEnvironmentVariable -Nome 'ANDROID_HOME' -Valor $pastaAndroidSdk
Set-UserEnvironmentVariable -Nome 'ANDROID_SDK_ROOT' -Valor $pastaAndroidSdk
Add-UserPathEntry -Pasta "$pastaAndroidSdk\platform-tools"
Add-UserPathEntry -Pasta "$pastaAndroidSdk\cmdline-tools\latest\bin"
Add-UserPathEntry -Pasta "$pastaAndroidSdk\emulator"

$sdkManager = "$pastaAndroidSdk\cmdline-tools\latest\bin\sdkmanager.bat"
if (Test-Path $sdkManager) {
    Write-Log 'Instalando componentes do Android SDK via sdkmanager (platform-tools, build-tools, plataforma mais recente, emulador)...' -Nivel INFO
    $componentesAndroid = @(
        'platform-tools',
        'platforms;android-34',
        'build-tools;34.0.0',
        'emulator',
        'system-images;android-34;google_apis;x86_64'
    )
    foreach ($componente in $componentesAndroid) {
        & $sdkManager --install $componente --sdk_root=$pastaAndroidSdk | Out-Null
    }
    $resultados += [PSCustomObject]@{ Nome = 'Android SDK (platform-tools, build-tools 34, emulator)'; Status = 'Instalado'; Origem = 'https://developer.android.com/studio' }
}
else {
    Write-Log 'sdkmanager ainda nao encontrado (o Android Studio pode precisar abrir uma vez para finalizar a instalacao do SDK). Rode o modulo novamente depois de abrir o Android Studio ao menos uma vez.' -Nivel AVISO
}

# ============================================================================
# FLUTTER
# ============================================================================
Write-Log 'Flutter SDK' -Nivel PASSO
$resultados += Install-WingetApp -Id 'Google.Flutter' -Nome 'Flutter SDK' -Origem 'https://flutter.dev/'

if (Test-CommandExists 'flutter') {
    flutter config --android-sdk $pastaAndroidSdk | Out-Null
    flutter config --no-enable-ios | Out-Null
    Write-Log 'Rodando "flutter doctor" para diagnostico (revise a saida no log)...' -Nivel INFO
    flutter doctor | ForEach-Object { Write-Log $_ }
}

# ============================================================================
# REACT NATIVE — usa o Node.js do modulo 01 (fnm). Sem instalacao global de CLI:
# a pratica atual e rodar "npx react-native ..." por projeto, sempre com a
# versao mais recente do CLI, sem precisar manter nada global atualizado.
# ============================================================================
Write-Log 'React Native (via npx, usando o Node.js ja instalado)' -Nivel PASSO
Write-Log 'Nao instalamos um CLI global do React Native de proposito: crie projetos com "npx @react-native-community/cli init MeuApp".' -Nivel INFO
$resultados += [PSCustomObject]@{ Nome = 'React Native CLI (via npx, sob demanda)'; Status = 'Pronto para uso'; Origem = 'https://reactnative.dev/' }

# react-native-windows habilita apps desktop nativos Windows a partir de React Native
Write-Log 'Dica: dentro de um projeto React Native, rode "npx react-native-windows-init" para adicionar suporte a Desktop Windows.' -Nivel INFO

# ============================================================================
# .NET MAUI — workload via dotnet CLI (requer .NET SDK do modulo 01)
# ============================================================================
Write-Log '.NET MAUI workload' -Nivel PASSO
if (Test-CommandExists 'dotnet') {
    dotnet workload install maui --skip-manifest-update | Out-Null
    $resultados += [PSCustomObject]@{ Nome = '.NET MAUI workload'; Status = 'Instalado'; Origem = 'https://dotnet.microsoft.com/apps/maui' }
}
else {
    Write-Log 'dotnet CLI nao encontrado nesta sessao — rode "dotnet workload install maui" manualmente depois de abrir um novo terminal.' -Nivel AVISO
}

# ============================================================================
# DESKTOP MULTIPLATAFORMA — resumo do que cobre Windows / Linux / Mac
# ============================================================================
Write-Log 'Resumo de cobertura Desktop multiplataforma:' -Nivel INFO
Write-Log '  Windows -> WPF/WinForms/WinUI (.NET, via Visual Studio) e Electron (Node.js)' -Nivel INFO
Write-Log '  Linux   -> .NET e Electron rodam nativamente; para testar em ambiente Linux real, use WSL2 (wsl --install), sem precisar de Docker' -Nivel INFO
Write-Log '  macOS   -> mesma limitacao do iOS: build final precisa de um Mac ou CI cloud (nao configurado agora)' -Nivel INFO

return $resultados
