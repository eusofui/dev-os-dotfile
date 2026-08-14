#Requires -Version 5.1
<#
    gerar-instalador.ps1
    ------------------------------------------------------------------
    Gera DevOS-Setup.exe LOCALMENTE, no seu Windows, sem depender do
    GitHub Actions. Rode isto uma vez (ou sempre que quiser atualizar o
    instalador) de dentro da pasta do repositorio:

        cd C:\SOUFUI
        .\gerar-instalador.ps1

    Pre-requisito: ter preenchido config.psd1 -> Identidade.RepoDotfiles
    com a URL do seu repositorio no GitHub (privado). E dali que este
    script descobre para onde o instalador deve apontar.

    O resultado e instalador\DevOS-Setup.exe — copie para um pendrive,
    mande para outra maquina, ou deixe no OneDrive/Drive: e um unico
    arquivo, sem instalar nada além do que ele mesmo baixa em tempo de
    execucao (nao embute os 15-20GB de programas dentro do .exe).
    ------------------------------------------------------------------
#>
param(
    # Sobrescreve a URL vinda do config.psd1, se quiser gerar para outro repo/branch.
    [string]$RepoUrlOverride = ''
)

$ErrorActionPreference = 'Stop'
$raizRepo = $PSScriptRoot

function Escrever($Mensagem, $Cor = 'Gray') {
    Write-Host $Mensagem -ForegroundColor $Cor
}

# ----------------------------------------------------------------------------
# 1) Descobrir a URL do repositorio e converter para URL de download do ZIP
# ----------------------------------------------------------------------------
$config = Import-PowerShellDataFile -Path (Join-Path $raizRepo 'config.psd1')

$repoUrlGit = $RepoUrlOverride
if (-not $repoUrlGit) {
    $repoUrlGit = $config.Identidade.RepoDotfiles
}

if (-not $repoUrlGit) {
    Escrever 'ERRO: config.psd1 -> Identidade.RepoDotfiles esta vazio.' 'Red'
    Escrever 'Preencha com a URL do seu repositorio (ex: git@github.com:seu-usuario/dev-os-dotfiles.git) e rode de novo,' 'Red'
    Escrever 'ou passe -RepoUrlOverride "https://github.com/seu-usuario/dev-os-dotfiles.git".' 'Red'
    exit 1
}

# Aceita tanto "git@github.com:usuario/repo.git" quanto "https://github.com/usuario/repo(.git)"
if ($repoUrlGit -match 'github\.com[:/]+(?<usuario>[^/]+)/(?<repo>[^/.]+)') {
    $usuarioGitHub = $Matches['usuario']
    $nomeRepo = $Matches['repo']
    $urlZip = "https://github.com/$usuarioGitHub/$nomeRepo/archive/refs/heads/main.zip"
}
else {
    Escrever "ERRO: nao consegui interpretar a URL '$repoUrlGit' como um repositorio do GitHub." 'Red'
    exit 1
}

Escrever "Repositorio detectado: $usuarioGitHub/$nomeRepo" 'Cyan'
Escrever "URL do instalador vai apontar para: $urlZip" 'Cyan'

# ----------------------------------------------------------------------------
# 2) Garantir o modulo PS2EXE (compilador .ps1 -> .exe, mantido pela comunidade,
#    usa o compilador C#/.NET que ja vem com o Windows — nao baixa nada exotico)
# ----------------------------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Escrever 'Instalando o modulo PS2EXE (unica vez)...' 'Yellow'
    Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
}
Import-Module ps2exe -Force

# ----------------------------------------------------------------------------
# 3) Injetar a URL no launcher (gera uma copia temporaria; o .ps1 original do
#    repositorio continua limpo, com o placeholder, para ficar seguro versionar)
# ----------------------------------------------------------------------------
$caminhoLauncherOriginal = Join-Path $raizRepo 'instalador\DevOS-Setup-Launcher.ps1'
$caminhoLauncherTemp = Join-Path $env:TEMP 'DevOS-Setup-Launcher.gerado.ps1'

(Get-Content $caminhoLauncherOriginal -Raw) -replace [Regex]::Escape('__REPO_ZIP_URL__'), $urlZip |
    Set-Content -Path $caminhoLauncherTemp -Encoding utf8

# ----------------------------------------------------------------------------
# 4) Compilar — .exe unico, com pedido de elevacao (UAC) e sem janela de console
#    "residual" (usa -noConsole=$false de proposito: queremos ver o progresso).
# ----------------------------------------------------------------------------
$pastaInstalador = Join-Path $raizRepo 'instalador'
$caminhoExeFinal = Join-Path $pastaInstalador 'DevOS-Setup.exe'

Escrever 'Compilando DevOS-Setup.exe...' 'Cyan'
Invoke-ps2exe -inputFile $caminhoLauncherTemp -outputFile $caminhoExeFinal `
    -title 'Development OS Setup' `
    -description 'Instalador automatico da Development OS (dev-os-dotfiles)' `
    -company $config.Identidade.NomeCompleto `
    -version '1.0.0.0' `
    -requireAdmin `
    -noConsole:$false

Remove-Item $caminhoLauncherTemp -Force -ErrorAction SilentlyContinue

Escrever "Pronto: $caminhoExeFinal" 'Green'
Escrever 'Copie esse arquivo para onde quiser (pendrive, outra maquina, nuvem) — ao dar duplo clique, ele baixa e instala tudo sozinho.' 'Green'
