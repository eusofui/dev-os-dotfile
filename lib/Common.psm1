#Requires -Version 5.1
<#
    Common.psm1
    ------------------------------------------------------------------
    Modulo de funcoes utilitarias compartilhadas por todos os modulos
    de instalacao do repositorio "dev-os-dotfiles".

    Objetivo: centralizar logging, verificacoes de idempotencia,
    instalacao via winget/choco com fallback e helpers de PATH/segredos,
    para que os modulos em /modules apenas descrevam "o que" instalar,
    nao "como" instalar.
    ------------------------------------------------------------------
#>

$Script:LogFile = $null

function Initialize-DevOsLog {
    <#
        .SYNOPSIS
        Define o arquivo de log usado por Write-Log nesta sessao.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )
    $pastaLog = Split-Path -Parent $Path
    if (-not (Test-Path $pastaLog)) {
        New-Item -ItemType Directory -Path $pastaLog -Force | Out-Null
    }
    $Script:LogFile = $Path
    "" | Out-File -FilePath $Script:LogFile -Encoding utf8 -Append
}

function Write-Log {
    <#
        .SYNOPSIS
        Escreve uma mensagem no console (colorida) e no arquivo de log.
        .PARAMETER Nivel
        INFO, OK, AVISO, ERRO ou PASSO.
    #>
    param(
        [Parameter(Mandatory = $true, Position = 0)][string]$Mensagem,
        [ValidateSet('INFO', 'OK', 'AVISO', 'ERRO', 'PASSO')][string]$Nivel = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $linha = "[$timestamp] [$Nivel] $Mensagem"

    switch ($Nivel) {
        'OK'    { Write-Host $linha -ForegroundColor Green }
        'AVISO' { Write-Host $linha -ForegroundColor Yellow }
        'ERRO'  { Write-Host $linha -ForegroundColor Red }
        'PASSO' { Write-Host "`n=== $Mensagem ===" -ForegroundColor Cyan }
        default { Write-Host $linha -ForegroundColor Gray }
    }

    if ($Script:LogFile) {
        $linha | Out-File -FilePath $Script:LogFile -Encoding utf8 -Append
    }
}

function Test-IsAdmin {
    <#
        .SYNOPSIS
        Retorna $true se o PowerShell atual esta rodando elevado (Administrador).
    #>
    $identidadeAtual = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identidadeAtual)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-DevOsAdmin {
    <#
        .SYNOPSIS
        Encerra a execucao com uma mensagem clara caso o script nao esteja elevado.
    #>
    if (-not (Test-IsAdmin)) {
        Write-Log 'Este script precisa ser executado como Administrador. Abra o PowerShell com "Executar como administrador" e rode novamente.' -Nivel ERRO
        throw 'Privilegios de administrador ausentes.'
    }
}

function Test-CommandExists {
    <#
        .SYNOPSIS
        Verifica se um comando/executavel esta disponivel no PATH atual.
    #>
    param([Parameter(Mandatory = $true)][string]$Nome)
    return [bool](Get-Command $Nome -ErrorAction SilentlyContinue)
}

function Test-WingetPackageInstalled {
    <#
        .SYNOPSIS
        Verifica (via winget list) se um pacote ja esta instalado, para manter
        o script idempotente (rodar de novo nao reinstala tudo do zero).
    #>
    param([Parameter(Mandatory = $true)][string]$Id)
    $resultado = winget list --id $Id --exact --accept-source-agreements 2>$null
    return ($LASTEXITCODE -eq 0 -and $resultado -match [Regex]::Escape($Id))
}

function Install-WingetApp {
    <#
        .SYNOPSIS
        Instala (ou atualiza) um pacote via winget de forma idempotente e resiliente.

        .PARAMETER Id
        Id exato do pacote no winget (ex: "Git.Git").

        .PARAMETER Nome
        Nome amigavel usado apenas nos logs e no relatorio final.

        .PARAMETER Origem
        Site oficial / repositorio do programa, usado no relatorio final.

        .PARAMETER Source
        Fonte do winget a usar (winget | msstore). Padrao: winget.

        .PARAMETER ArgumentosExtras
        Argumentos adicionais repassados ao instalador (ex: workloads do Visual Studio).

        .PARAMETER UrlManualFallback
        URL para download manual, mostrada caso o winget falhe (ex: bug de hash conhecido).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Nome,
        [Parameter(Mandatory = $true)][string]$Origem,
        [ValidateSet('winget', 'msstore')][string]$Source = 'winget',
        [string[]]$ArgumentosExtras = @(),
        [string]$UrlManualFallback = ''
    )

    if (-not (Test-CommandExists 'winget')) {
        Write-Log "winget nao encontrado no PATH. Instale o 'App Installer' pela Microsoft Store e rode o script novamente." -Nivel ERRO
        return [PSCustomObject]@{ Nome = $Nome; Status = 'Falhou (winget ausente)'; Origem = $Origem }
    }

    if (Test-WingetPackageInstalled -Id $Id) {
        Write-Log "$Nome ja esta instalado (id: $Id). Pulando." -Nivel OK
        return [PSCustomObject]@{ Nome = $Nome; Status = 'Ja instalado'; Origem = $Origem; WingetId = $Id }
    }

    Write-Log "Instalando $Nome (winget id: $Id)..." -Nivel INFO
    $argumentos = @(
        'install', '--id', $Id, '--exact',
        '--source', $Source,
        '--accept-package-agreements', '--accept-source-agreements',
        '--silent'
    ) + $ArgumentosExtras

    try {
        $processo = Start-Process -FilePath 'winget' -ArgumentList $argumentos -NoNewWindow -Wait -PassThru
        if ($processo.ExitCode -eq 0) {
            Write-Log "$Nome instalado com sucesso." -Nivel OK
            return [PSCustomObject]@{ Nome = $Nome; Status = 'Instalado'; Origem = $Origem; WingetId = $Id }
        }
        else {
            throw "winget retornou codigo de saida $($processo.ExitCode)"
        }
    }
    catch {
        Write-Log "Falha ao instalar $Nome via winget: $($_.Exception.Message)" -Nivel AVISO
        if ($UrlManualFallback) {
            Write-Log "Baixe manualmente em: $UrlManualFallback" -Nivel AVISO
        }
        return [PSCustomObject]@{ Nome = $Nome; Status = 'Falhou (ver log)'; Origem = $Origem; WingetId = $Id }
    }
}

function Install-ChocoApp {
    <#
        .SYNOPSIS
        Fallback via Chocolatey para pacotes que nao existem (ou estao quebrados) no winget.
        So e usado se o Chocolatey estiver instalado (modulo 00-prereqs.ps1 pergunta antes).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Nome,
        [Parameter(Mandatory = $true)][string]$Origem
    )

    if (-not (Test-CommandExists 'choco')) {
        Write-Log "Chocolatey nao instalado; nao foi possivel instalar $Nome via fallback." -Nivel AVISO
        return [PSCustomObject]@{ Nome = $Nome; Status = 'Falhou (choco ausente)'; Origem = $Origem }
    }

    Write-Log "Instalando $Nome via Chocolatey (id: $Id)..." -Nivel INFO
    choco install $Id -y --no-progress | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Log "$Nome instalado via Chocolatey." -Nivel OK
        return [PSCustomObject]@{ Nome = $Nome; Status = 'Instalado (choco)'; Origem = $Origem }
    }
    Write-Log "Falha ao instalar $Nome via Chocolatey." -Nivel ERRO
    return [PSCustomObject]@{ Nome = $Nome; Status = 'Falhou'; Origem = $Origem }
}

function Add-UserPathEntry {
    <#
        .SYNOPSIS
        Adiciona uma pasta ao PATH do usuario (persistente), sem duplicar entradas.
    #>
    param([Parameter(Mandatory = $true)][string]$Pasta)

    $pathAtual = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entradas = $pathAtual -split ';' | Where-Object { $_ -ne '' }

    if ($entradas -contains $Pasta) {
        return
    }

    $novoPath = ($entradas + $Pasta) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $novoPath, 'User')
    $env:Path = "$env:Path;$Pasta"
    Write-Log "Adicionado ao PATH do usuario: $Pasta" -Nivel INFO
}

function Set-UserEnvironmentVariable {
    <#
        .SYNOPSIS
        Define uma variavel de ambiente persistente de usuario (nao processo).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Nome,
        [Parameter(Mandatory = $true)][string]$Valor
    )
    [Environment]::SetEnvironmentVariable($Nome, $Valor, 'User')
    Set-Item -Path "env:$Nome" -Value $Valor
    Write-Log "Variavel de ambiente definida: $Nome=$Valor" -Nivel INFO
}

function Get-WingetInstalledVersion {
    <#
        .SYNOPSIS
        Consulta "winget list --id X" e retorna a versao instalada relatada
        pelo proprio winget. Funciona mesmo para apps sem CLI de versao
        (ex: AnyDesk, Zoom, K-Lite Codec Pack, draw.io).
    #>
    param([Parameter(Mandatory = $true)][string]$Id)
    try {
        $saida = winget list --id $Id --exact --accept-source-agreements 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $saida) { return $null }
        # A saida do winget e tabular; a versao e a penultima "coluna" da linha de dados.
        $linhaDados = $saida | Where-Object { $_ -match [Regex]::Escape($Id) }
        if (-not $linhaDados) { return $null }
        $colunas = ($linhaDados -split '\s{2,}') | Where-Object { $_ -ne '' }
        if ($colunas.Count -ge 3) {
            return $colunas[-2].Trim()
        }
        return $null
    }
    catch {
        return $null
    }
}

function Get-AppVersion {
    <#
        .SYNOPSIS
        Tenta obter a versao instalada de um programa executando o comando
        e o argumento informado, retornando a primeira linha da saida.
        Usado pelo gerador de install_report.md.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Comando,
        [string]$Argumento = '--version'
    )
    if (-not (Test-CommandExists $Comando)) {
        return $null
    }
    try {
        $saida = & $Comando $Argumento 2>&1 | Select-Object -First 1
        return "$saida".Trim()
    }
    catch {
        return $null
    }
}

function New-DotfileSymlink {
    <#
        .SYNOPSIS
        Cria (ou substitui) um link simbolico apontando do destino real (ex: pasta
        de configuracao do VS Code) para o arquivo versionado dentro do repositorio.
        Assim, editar o programa edita o arquivo do repo Git automaticamente.

        .PARAMETER OrigemNoRepo
        Caminho do arquivo dentro de dev-os-dotfiles/dotfiles/...

        .PARAMETER DestinoReal
        Caminho onde o programa espera encontrar o arquivo de configuracao.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$OrigemNoRepo,
        [Parameter(Mandatory = $true)][string]$DestinoReal
    )

    if (-not (Test-Path $OrigemNoRepo)) {
        Write-Log "Arquivo de origem nao encontrado, symlink ignorado: $OrigemNoRepo" -Nivel AVISO
        return
    }

    $pastaDestino = Split-Path -Parent $DestinoReal
    if (-not (Test-Path $pastaDestino)) {
        New-Item -ItemType Directory -Path $pastaDestino -Force | Out-Null
    }

    if (Test-Path $DestinoReal) {
        $item = Get-Item $DestinoReal -Force
        if ($item.LinkType -eq 'SymbolicLink') {
            Remove-Item $DestinoReal -Force
        }
        else {
            $backup = "$DestinoReal.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Write-Log "Arquivo existente sem ser symlink; guardando backup em $backup" -Nivel AVISO
            Move-Item $DestinoReal $backup -Force
        }
    }

    New-Item -ItemType SymbolicLink -Path $DestinoReal -Target $OrigemNoRepo -Force | Out-Null
    Write-Log "Symlink criado: $DestinoReal -> $OrigemNoRepo" -Nivel OK
}

function Initialize-DevSecretStore {
    <#
        .SYNOPSIS
        Prepara o cofre local de segredos usando os modulos oficiais do PowerShell
        Microsoft.PowerShell.SecretManagement + Microsoft.PowerShell.SecretStore.
        Os segredos ficam criptografados no perfil do usuario do Windows
        (protegidos por DPAPI + senha do cofre), NUNCA dentro do repositorio git.
    #>
    $modulosNecessarios = 'Microsoft.PowerShell.SecretManagement', 'Microsoft.PowerShell.SecretStore'
    foreach ($modulo in $modulosNecessarios) {
        if (-not (Get-Module -ListAvailable -Name $modulo)) {
            Write-Log "Instalando modulo PowerShell: $modulo" -Nivel INFO
            Install-Module -Name $modulo -Scope CurrentUser -Force -AllowClobber
        }
    }

    if (-not (Get-SecretVault -Name 'DevOsVault' -ErrorAction SilentlyContinue)) {
        Register-SecretVault -Name 'DevOsVault' -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
        Write-Log "Cofre de segredos 'DevOsVault' registrado (Microsoft.PowerShell.SecretStore)." -Nivel OK
    }
}

function Set-DevSecret {
    <#
        .SYNOPSIS
        Grava um segredo (senha, token, chave) no cofre local. Nunca aparece em texto
        puro em nenhum arquivo do repositorio.
        .EXAMPLE
        Set-DevSecret -Nome 'QUESTDB_PASSWORD'
    #>
    param([Parameter(Mandatory = $true)][string]$Nome)
    $valorSeguro = Read-Host -Prompt "Digite o valor de '$Nome'" -AsSecureString
    Set-Secret -Name $Nome -SecureStringSecret $valorSeguro -Vault DevOsVault
    Write-Log "Segredo '$Nome' salvo no cofre local." -Nivel OK
}

function Get-DevSecret {
    <#
        .SYNOPSIS
        Le um segredo do cofre local e retorna como texto puro em memoria (uso em runtime,
        nunca deve ser impresso em log nem salvo em disco).
        .EXAMPLE
        $senha = Get-DevSecret -Nome 'QUESTDB_PASSWORD'
    #>
    param([Parameter(Mandatory = $true)][string]$Nome)
    $segredo = Get-Secret -Name $Nome -Vault DevOsVault -ErrorAction SilentlyContinue
    if (-not $segredo) {
        Write-Log "Segredo '$Nome' nao encontrado no cofre. Use Set-DevSecret -Nome '$Nome' primeiro." -Nivel AVISO
        return $null
    }
    return [System.Net.NetworkCredential]::new('', $segredo).Password
}

Export-ModuleMember -Function *
