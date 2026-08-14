#Requires -Version 5.1
<#
    bootstrap.ps1
    ------------------------------------------------------------------
    PONTO DE ENTRADA UNICO do dev-os-dotfiles.

    Este e o UNICO arquivo que voce precisa baixar manualmente (ou colar)
    numa maquina Windows nova. Ele:
      1) Garante que esta rodando como Administrador (relanca elevado se nao estiver)
      2) Habilita TLS 1.2 (necessario para downloads em algumas maquinas novas)
      3) Verifica/instala o winget (App Installer)
      4) Verifica/instala o Git
      5) Clona (ou atualiza, se ja existir) o repositorio de dotfiles
      6) Chama install.ps1 dentro do repositorio clonado

    USO RECOMENDADO (uma linha, PowerShell como Administrador):
        irm https://raw.githubusercontent.com/<SEU_USUARIO>/dev-os-dotfiles/main/bootstrap.ps1 | iex

    USO LOCAL (se voce ja tem os arquivos em uma pasta/pendrive):
        cd C:\SOUFUI
        .\bootstrap.ps1

    O repositorio sempre vive em C:\SOUFUI nesta maquina (pasta fixa, fora
    do perfil do usuario) — ver parametro -PastaDestino abaixo.
    ------------------------------------------------------------------
#>

param(
    # URL do repositorio Git privado de dotfiles. Se vazio, tenta usar o repo local atual.
    [string]$RepoUrl = '',

    # Pasta onde o repositorio sera clonado/atualizado (fixa por decisao do projeto)
    [string]$PastaDestino = 'C:\SOUFUI'
)

$ErrorActionPreference = 'Stop'

function Write-Etapa($texto) {
    Write-Host "`n=== $texto ===" -ForegroundColor Cyan
}

# 1) Garantir execucao elevada -------------------------------------------------
$principalAtual = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principalAtual.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Relançando o PowerShell como Administrador...' -ForegroundColor Yellow
    $argumentosOriginais = $MyInvocation.UnboundArguments -join ' '
    if ($MyInvocation.MyCommand.Path) {
        Start-Process powershell.exe -Verb RunAs -ArgumentList @(
            '-NoExit', '-ExecutionPolicy', 'Bypass', '-File', "`"$($MyInvocation.MyCommand.Path)`"", $argumentosOriginais
        )
    }
    else {
        Write-Host 'Rode este comando novamente dentro de um PowerShell aberto como Administrador.' -ForegroundColor Red
    }
    exit
}

# 2) TLS 1.2 para downloads confiaveis -----------------------------------------
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# 3) Politica de execucao (somente para o usuario atual, nao a maquina toda) --
Write-Etapa 'Ajustando politica de execucao do PowerShell (escopo: usuario atual)'
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# 4) winget --------------------------------------------------------------------
Write-Etapa 'Verificando winget (Windows Package Manager)'
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host 'winget nao encontrado. Instale o "App Installer" pela Microsoft Store:' -ForegroundColor Yellow
    Write-Host '  https://apps.microsoft.com/detail/9nblggh4nns1' -ForegroundColor Yellow
    Write-Host 'Depois rode este script novamente.' -ForegroundColor Yellow
    throw 'winget ausente.'
}
else {
    Write-Host 'winget encontrado.' -ForegroundColor Green
}

# 5) Git -------------------------------------------------------------------------
Write-Etapa 'Verificando Git'
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host 'Git nao encontrado. Instalando via winget...' -ForegroundColor Yellow
    winget install --id Git.Git --exact --source winget --accept-package-agreements --accept-source-agreements --silent
    # Atualiza o PATH da sessao atual sem precisar reabrir o PowerShell
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
}
else {
    Write-Host 'Git encontrado.' -ForegroundColor Green
}

# 6) Clonar ou atualizar o repositorio de dotfiles -------------------------------
Write-Etapa 'Preparando o repositorio dev-os-dotfiles'

if ($RepoUrl) {
    if (Test-Path (Join-Path $PastaDestino '.git')) {
        Write-Host "Repositorio ja existe em $PastaDestino. Atualizando (git pull)..." -ForegroundColor Yellow
        Push-Location $PastaDestino
        git pull --ff-only
        Pop-Location
    }
    else {
        Write-Host "Clonando $RepoUrl em $PastaDestino..." -ForegroundColor Yellow
        git clone $RepoUrl $PastaDestino
    }
}
elseif (Test-Path (Join-Path $PSScriptRoot 'install.ps1')) {
    # Rodando localmente a partir de uma copia ja existente (pendrive, zip extraido, etc.)
    $PastaDestino = $PSScriptRoot
    Write-Host "Usando copia local em $PastaDestino (parametro -RepoUrl nao informado)." -ForegroundColor Yellow
}
else {
    throw 'Nem -RepoUrl foi informado, nem existe um install.ps1 na pasta atual. Informe -RepoUrl "git@github.com:usuario/dev-os-dotfiles.git".'
}

# 7) Executar o orquestrador principal -------------------------------------------
Write-Etapa 'Iniciando install.ps1'
Set-Location $PastaDestino
& (Join-Path $PastaDestino 'install.ps1')
