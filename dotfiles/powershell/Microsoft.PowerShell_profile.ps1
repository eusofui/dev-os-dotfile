# ============================================================================
# Microsoft.PowerShell_profile.ps1
# Perfil pessoal do PowerShell — versionado no repositorio dev-os-dotfiles.
# Este arquivo e "linkado" (symlink) para o local real do perfil
# ($PROFILE, algo como Documents\PowerShell\Microsoft.PowerShell_profile.ps1)
# pelo modulo 08-dotfiles-apply.ps1. Editar aqui OU no local real e a mesma
# coisa fisicamente no disco.
# ============================================================================

# ----------------------------------------------------------------------------
# Hooks de gerenciadores de versao (precisam rodar a cada novo terminal)
# ----------------------------------------------------------------------------
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd | Out-String | Invoke-Expression
}

if ($env:PYENV) {
    $env:Path = "$env:PYENV\bin;$env:PYENV\shims;$env:Path"
}

# ----------------------------------------------------------------------------
# Aliases de produtividade
# ----------------------------------------------------------------------------
function ll { Get-ChildItem -Force @args }
function la { Get-ChildItem -Force -Hidden @args }
function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function devhome { Set-Location $env:DEV_HOME }

# Git
function gs { git status @args }
function ga { git add @args }
function gc { git commit @args }
function gp { git push @args }
function gl { git log --oneline --graph --decorate -n 20 @args }
function gco { git checkout @args }

# GitHub CLI
function ghpr { gh pr create --fill @args }

# ----------------------------------------------------------------------------
# Alternar versao ativa do Java (as versoes ficam lado a lado, instaladas
# pelo modulo 01-languages.ps1 via Eclipse Temurin)
# Uso:  Set-JavaVersion 17
# ----------------------------------------------------------------------------
function Set-JavaVersion {
    param([Parameter(Mandatory = $true)][string]$Versao)

    $pastaBase = 'C:\Program Files\Eclipse Adoptium'
    $jdkEscolhido = Get-ChildItem $pastaBase -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "jdk-$Versao*" } | Select-Object -First 1

    if (-not $jdkEscolhido) {
        Write-Warning "Nenhum JDK $Versao encontrado em $pastaBase. Versoes disponiveis:"
        Get-ChildItem $pastaBase -Directory -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  $($_.Name)" }
        return
    }

    $env:JAVA_HOME = $jdkEscolhido.FullName
    $env:Path = "$($jdkEscolhido.FullName)\bin;" + ($env:Path -split ';' | Where-Object { $_ -notlike '*Eclipse Adoptium*' } -join ';')
    Write-Host "JAVA_HOME agora aponta para: $env:JAVA_HOME" -ForegroundColor Green
    java -version
}

# ----------------------------------------------------------------------------
# Cofre de segredos (Set-DevSecret / Get-DevSecret) — carregado sob demanda
# a partir do Common.psm1 do repositorio de dotfiles, se ele existir nesta
# maquina. Evita erro em maquinas onde o repo ainda nao foi clonado.
# ----------------------------------------------------------------------------
$caminhoCommonModule = 'C:\SOUFUI\lib\Common.psm1'
if (Test-Path $caminhoCommonModule) {
    Import-Module $caminhoCommonModule -Force -DisableNameChecking
}

# ----------------------------------------------------------------------------
# Prompt simples com o nome da branch git atual (sem dependencias externas)
# ----------------------------------------------------------------------------
function prompt {
    $pastaAtual = (Get-Location).Path
    $branchGit = git rev-parse --abbrev-ref HEAD 2>$null
    if ($branchGit) {
        Write-Host "$pastaAtual " -NoNewline -ForegroundColor Cyan
        Write-Host "($branchGit)" -NoNewline -ForegroundColor DarkYellow
    }
    else {
        Write-Host $pastaAtual -NoNewline -ForegroundColor Cyan
    }
    return "`nPS> "
}

Write-Host "dev-os-dotfiles carregado. Digite 'devhome' para ir para $env:DEV_HOME." -ForegroundColor DarkGray
