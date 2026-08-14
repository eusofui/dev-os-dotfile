#Requires -Version 5.1
<#
    01-languages.ps1
    ------------------------------------------------------------------
    Linguagens, compiladores e gerenciadores de versao:
      - Python  -> pyenv-win
      - R       -> rig (R Installation Manager, oficial da Posit)
      - Java    -> Eclipse Temurin (LTS 21 + 17 lado a lado) + Maven/Gradle
      - C#      -> .NET SDK (multiplas versoes convivem nativamente)
      - Node.js -> fnm (Fast Node Manager)
      - C/C++   -> MSVC Build Tools (via modulo 02, dentro do Visual Studio),
                   MSYS2 (GCC/Clang estilo Unix), CMake, Ninja, vcpkg
      - Rust    -> rustup
    ------------------------------------------------------------------
#>
param(
    [Parameter(Mandatory = $true)]$Config,
    [Parameter(Mandatory = $true)][string]$RaizRepo
)

Import-Module (Join-Path $RaizRepo 'lib\Common.psm1') -Force
$resultados = @()
$pastaSdks = Join-Path $Config.PastaDevHome 'sdks'

# ============================================================================
# PYTHON — pyenv-win
# ============================================================================
Write-Log 'Python + pyenv-win' -Nivel PASSO

$pastaPyenv = "$env:USERPROFILE\.pyenv"
if (-not (Test-Path $pastaPyenv)) {
    Write-Log 'Instalando pyenv-win (metodo oficial via script do projeto)...' -Nivel INFO
    Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/pyenv-win/pyenv-win/master/pyenv-win/install-pyenv-win.ps1' -OutFile "$env:TEMP\install-pyenv-win.ps1"
    & "$env:TEMP\install-pyenv-win.ps1"
    $resultados += [PSCustomObject]@{ Nome = 'pyenv-win'; Status = 'Instalado'; Origem = 'https://github.com/pyenv-win/pyenv-win' }
}
else {
    Write-Log 'pyenv-win ja instalado.' -Nivel OK
    $resultados += [PSCustomObject]@{ Nome = 'pyenv-win'; Status = 'Ja instalado'; Origem = 'https://github.com/pyenv-win/pyenv-win' }
}

# Variaveis exigidas pelo pyenv-win + PATH (sessao atual e persistente)
Set-UserEnvironmentVariable -Nome 'PYENV' -Valor "$pastaPyenv\pyenv-win\"
Set-UserEnvironmentVariable -Nome 'PYENV_ROOT' -Valor "$pastaPyenv\pyenv-win\"
Add-UserPathEntry -Pasta "$pastaPyenv\pyenv-win\bin"
Add-UserPathEntry -Pasta "$pastaPyenv\pyenv-win\shims"

if (Test-CommandExists 'pyenv') {
    $versaoPython = '3.13.0'
    Write-Log "Instalando Python $versaoPython via pyenv..." -Nivel INFO
    pyenv install $versaoPython -s
    pyenv global $versaoPython
    pyenv rehash
    $resultados += [PSCustomObject]@{ Nome = "Python $versaoPython"; Status = 'Instalado'; Origem = 'https://www.python.org/' }

    python -m pip install --upgrade pip pipx | Out-Null
    python -m pipx ensurepath | Out-Null
    $resultados += [PSCustomObject]@{ Nome = 'pipx'; Status = 'Instalado'; Origem = 'https://pipx.pypa.io/' }
}
else {
    Write-Log 'pyenv ainda nao esta no PATH desta sessao. Abra um novo terminal e rode o modulo novamente se necessario.' -Nivel AVISO
}

# ============================================================================
# R — rig (R Installation Manager, mantido pela Posit)
# ============================================================================
Write-Log 'R + rig' -Nivel PASSO
$resultados += Install-WingetApp -Id 'Posit.rig' -Nome 'rig (R Installation Manager)' -Origem 'https://github.com/r-lib/rig'

if (Test-CommandExists 'rig') {
    Write-Log 'Instalando a ultima versao "release" do R via rig...' -Nivel INFO
    rig add release
    rig default release
    $resultados += [PSCustomObject]@{ Nome = 'R (release)'; Status = 'Instalado'; Origem = 'https://cran.r-project.org/' }
}

# ============================================================================
# JAVA — Eclipse Temurin (duas LTS lado a lado) + Maven + Gradle
# ============================================================================
Write-Log 'Java (Eclipse Temurin)' -Nivel PASSO

foreach ($versaoJava in $Config.VersoesJava) {
    $idTemurin = "EclipseAdoptium.Temurin.$versaoJava.JDK"
    $resultados += Install-WingetApp -Id $idTemurin -Nome "Eclipse Temurin JDK $versaoJava" -Origem 'https://adoptium.net/'
}

# JAVA_HOME aponta para a primeira versao da lista (a mais nova); a troca entre
# versoes e feita pela funcao Set-JavaVersion definida no perfil do PowerShell
# (ver dotfiles/powershell/Microsoft.PowerShell_profile.ps1).
$versaoJavaPadrao = $Config.VersoesJava[0]
$pastaTemurin = "C:\Program Files\Eclipse Adoptium"
if (Test-Path $pastaTemurin) {
    $jdkPadrao = Get-ChildItem $pastaTemurin -Directory | Where-Object { $_.Name -like "jdk-$versaoJavaPadrao*" } | Select-Object -First 1
    if ($jdkPadrao) {
        Set-UserEnvironmentVariable -Nome 'JAVA_HOME' -Valor $jdkPadrao.FullName
        Add-UserPathEntry -Pasta (Join-Path $jdkPadrao.FullName 'bin')
    }
}

$resultados += Install-WingetApp -Id 'Apache.Maven' -Nome 'Apache Maven' -Origem 'https://maven.apache.org/'
$resultados += Install-WingetApp -Id 'Gradle.Gradle' -Nome 'Gradle' -Origem 'https://gradle.org/'

# ============================================================================
# C# / .NET — SDK oficial (multiplas versoes convivem nativamente, sem version manager)
# ============================================================================
Write-Log 'C# / .NET SDK' -Nivel PASSO

$idsDotnetParaTentar = @('Microsoft.DotNet.SDK.10', 'Microsoft.DotNet.SDK.8')
$dotnetInstalado = $false
foreach ($idDotnet in $idsDotnetParaTentar) {
    if ($dotnetInstalado) { break }
    $resultado = Install-WingetApp -Id $idDotnet -Nome ".NET SDK ($idDotnet)" -Origem 'https://dotnet.microsoft.com/'
    $resultados += $resultado
    if ($resultado.Status -match 'Instalado|Ja instalado') { $dotnetInstalado = $true }
}
if (-not $dotnetInstalado) {
    Write-Log 'Nenhum id de .NET SDK testado funcionou. Verifique a versao LTS atual em https://dotnet.microsoft.com/download e ajuste config.psd1 / este modulo.' -Nivel AVISO
}
Write-Log 'Dica: use "dotnet new globaljson --sdk-version X.Y.Z" dentro de cada projeto para fixar a versao do .NET usada nele.' -Nivel INFO

# ============================================================================
# JAVASCRIPT / NODE.JS — fnm (Fast Node Manager)
# ============================================================================
Write-Log 'Node.js + fnm' -Nivel PASSO
$resultados += Install-WingetApp -Id 'Schniz.fnm' -Nome 'fnm (Fast Node Manager)' -Origem 'https://github.com/Schniz/fnm'

if (Test-CommandExists 'fnm') {
    fnm install --lts
    fnm default lts-latest
    $resultados += [PSCustomObject]@{ Nome = 'Node.js (LTS via fnm)'; Status = 'Instalado'; Origem = 'https://nodejs.org/' }

    # fnm precisa de um "hook" no perfil do PowerShell — ja incluido em
    # dotfiles/powershell/Microsoft.PowerShell_profile.ps1 (linha 'fnm env | ...').
    $env:PATH = "$env:USERPROFILE\.fnm;$env:PATH"
}
else {
    Write-Log 'fnm ainda nao esta no PATH desta sessao. Abra um novo terminal para o hook do fnm carregar o Node.' -Nivel AVISO
}

# Ferramentas Node globais uteis (corepack ja vem embutido no Node >= 16.9)
if (Test-CommandExists 'corepack') {
    corepack enable
    Write-Log 'corepack habilitado (gerencia pnpm/yarn automaticamente por projeto).' -Nivel OK
}
if (Test-CommandExists 'npm') {
    npm install -g typescript | Out-Null
    $resultados += [PSCustomObject]@{ Nome = 'TypeScript (global)'; Status = 'Instalado'; Origem = 'https://www.typescriptlang.org/' }
}

# ============================================================================
# C / C++ — MSYS2 (GCC/Clang), CMake, Ninja, vcpkg
# (O compilador MSVC + Windows SDK e instalado no modulo 02 junto ao Visual Studio)
# ============================================================================
Write-Log 'C/C++ — MSYS2, CMake, Ninja, vcpkg' -Nivel PASSO

$resultados += Install-WingetApp -Id 'MSYS2.MSYS2' -Nome 'MSYS2 (GCC/Clang/Make estilo Unix)' -Origem 'https://www.msys2.org/'
$resultados += Install-WingetApp -Id 'Kitware.CMake' -Nome 'CMake' -Origem 'https://cmake.org/'
$resultados += Install-WingetApp -Id 'Ninja-build.Ninja' -Nome 'Ninja' -Origem 'https://ninja-build.org/'

if (Test-Path 'C:\msys64\usr\bin\bash.exe') {
    Write-Log 'Instalando toolchain GCC/Clang dentro do MSYS2 (mingw-w64)...' -Nivel INFO
    & 'C:\msys64\usr\bin\bash.exe' -lc 'pacman -Syu --noconfirm' | Out-Null
    & 'C:\msys64\usr\bin\bash.exe' -lc 'pacman -S --noconfirm mingw-w64-x86_64-toolchain mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja' | Out-Null
    Add-UserPathEntry -Pasta 'C:\msys64\mingw64\bin'
    $resultados += [PSCustomObject]@{ Nome = 'mingw-w64-toolchain (GCC/Clang via MSYS2)'; Status = 'Instalado'; Origem = 'https://www.msys2.org/' }
}

# vcpkg — gerenciador de pacotes C/C++ oficial (Microsoft), integra com MSVC e VS Code
$pastaVcpkg = Join-Path $pastaSdks 'vcpkg'
if (-not (Test-Path $pastaVcpkg)) {
    Write-Log 'Clonando e inicializando vcpkg...' -Nivel INFO
    git clone https://github.com/microsoft/vcpkg.git $pastaVcpkg
    & "$pastaVcpkg\bootstrap-vcpkg.bat" -disableMetrics
    & "$pastaVcpkg\vcpkg.exe" integrate install
    Add-UserPathEntry -Pasta $pastaVcpkg
    $resultados += [PSCustomObject]@{ Nome = 'vcpkg'; Status = 'Instalado'; Origem = 'https://github.com/microsoft/vcpkg' }
}
else {
    Write-Log 'vcpkg ja instalado.' -Nivel OK
    $resultados += [PSCustomObject]@{ Nome = 'vcpkg'; Status = 'Ja instalado'; Origem = 'https://github.com/microsoft/vcpkg' }
}

# ============================================================================
# RUST — rustup
# (rustup, no Windows, usa o linker do MSVC Build Tools instalado no modulo 02;
#  como alternativa 100% autocontida, o target GNU via MSYS2 tambem funciona)
# ============================================================================
Write-Log 'Rust — rustup' -Nivel PASSO
$resultados += Install-WingetApp -Id 'Rustlang.Rustup' -Nome 'rustup' -Origem 'https://www.rust-lang.org/'

if (Test-CommandExists 'rustup') {
    rustup default stable-x86_64-pc-windows-msvc
    $resultados += [PSCustomObject]@{ Nome = 'Rust toolchain (stable-msvc)'; Status = 'Instalado'; Origem = 'https://www.rust-lang.org/' }
}
Write-Log 'Importante: o Rust no Windows precisa do MSVC Build Tools (workload "Desenvolvimento para desktop com C++"), instalado no modulo 02-mobile-desktop.ps1.' -Nivel INFO

return $resultados
