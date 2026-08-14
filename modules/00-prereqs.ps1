#Requires -Version 5.1
<#
    00-prereqs.ps1
    ------------------------------------------------------------------
    Pre-requisitos de toda a "Development OS":
      - Confirma/instala winget
      - Instala Chocolatey como gerenciador de pacotes FALLBACK
        (usado apenas quando um pacote nao existe no winget)
      - Cria a estrutura de pastas de trabalho em C:\Dev
      - Habilita o "Modo Desenvolvedor" do Windows (necessario para
        criar symlinks de dotfiles sem precisar elevar cada comando)
    ------------------------------------------------------------------
#>
param(
    [Parameter(Mandatory = $true)]$Config,
    [Parameter(Mandatory = $true)][string]$RaizRepo
)

Import-Module (Join-Path $RaizRepo 'lib\Common.psm1') -Force
$resultados = @()

# winget --------------------------------------------------------------------
if (-not (Test-CommandExists 'winget')) {
    Write-Log 'winget nao encontrado. Instale o "App Installer" pela Microsoft Store e rode novamente:' -Nivel ERRO
    Write-Log 'https://apps.microsoft.com/detail/9nblggh4nns1' -Nivel ERRO
    throw 'winget e obrigatorio para este script.'
}
Write-Log 'winget disponivel.' -Nivel OK
winget source update | Out-Null

# Chocolatey (fallback) -------------------------------------------------------
if (-not (Test-CommandExists 'choco')) {
    Write-Log 'Instalando Chocolatey (usado apenas como fallback para pacotes ausentes no winget)...' -Nivel INFO
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $resultados += [PSCustomObject]@{ Nome = 'Chocolatey'; Status = 'Instalado'; Origem = 'https://chocolatey.org/' }
}
else {
    Write-Log 'Chocolatey ja instalado.' -Nivel OK
    $resultados += [PSCustomObject]@{ Nome = 'Chocolatey'; Status = 'Ja instalado'; Origem = 'https://chocolatey.org/' }
}

# Estrutura de pastas de trabalho ---------------------------------------------
$pastas = @(
    $Config.PastaDevHome,
    (Join-Path $Config.PastaDevHome 'projetos'),
    (Join-Path $Config.PastaDevHome 'sdks'),
    (Join-Path $Config.PastaDevHome 'sdks\jdbc-drivers'),
    (Join-Path $Config.PastaDevHome 'sdks\odbc-drivers'),
    (Join-Path $Config.PastaDevHome 'ferramentas')
)
foreach ($pasta in $pastas) {
    if (-not (Test-Path $pasta)) {
        New-Item -ItemType Directory -Path $pasta -Force | Out-Null
        Write-Log "Pasta criada: $pasta" -Nivel OK
    }
}

# Modo Desenvolvedor (permite criar symlinks sem admin em cada chamada) -------
$chaveModoDev = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
try {
    if (-not (Test-Path $chaveModoDev)) {
        New-Item -Path $chaveModoDev -Force | Out-Null
    }
    New-ItemProperty -Path $chaveModoDev -Name 'AllowDevelopmentWithoutDevLicense' -Value 1 -PropertyType DWORD -Force | Out-Null
    Write-Log 'Modo Desenvolvedor do Windows habilitado (necessario para symlinks de dotfiles).' -Nivel OK
}
catch {
    Write-Log 'Nao foi possivel habilitar o Modo Desenvolvedor automaticamente. Ative manualmente em Configuracoes > Privacidade e Seguranca > Para desenvolvedores.' -Nivel AVISO
}

return $resultados
