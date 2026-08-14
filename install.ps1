#Requires -Version 5.1
<#
    install.ps1
    ------------------------------------------------------------------
    Orquestrador principal do dev-os-dotfiles.
    Le config.psd1, importa lib/Common.psm1 e executa cada modulo em
    modules/ na ordem correta, registrando tudo em log e, ao final,
    gerando reports/install_report.md.

    E IDEMPOTENTE: pode ser executado varias vezes; cada modulo verifica
    o que ja esta instalado antes de tentar instalar de novo.

    PARAMETROS UTEIS:
        .\install.ps1                       # roda todos os modulos habilitados no config.psd1
        .\install.ps1 -Somente Linguagens    # roda so um modulo especifico
        .\install.ps1 -Pular ProgramasDiversos,AutomacaoGui
        .\install.ps1 -SimulacaoSemAlterar   # (dry run) so mostra o que faria
    ------------------------------------------------------------------
#>

[CmdletBinding()]
param(
    [string[]]$Somente = @(),
    [string[]]$Pular = @(),
    [switch]$SimulacaoSemAlterar
)

$ErrorActionPreference = 'Stop'
$RaizRepo = $PSScriptRoot

Import-Module (Join-Path $RaizRepo 'lib\Common.psm1') -Force

$arquivoLog = Join-Path $RaizRepo "reports\install-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Initialize-DevOsLog -Path $arquivoLog

Write-Log 'dev-os-dotfiles :: inicio da instalacao' -Nivel PASSO
Write-Log "Maquina: $env:COMPUTERNAME | Usuario: $env:USERNAME | Repo: $RaizRepo"

if (-not (Test-IsAdmin)) {
    Write-Log 'Rode este script em um PowerShell aberto como Administrador (clique direito > Executar como administrador).' -Nivel ERRO
    throw 'Privilegios de administrador ausentes.'
}

# Carrega configuracao central -------------------------------------------------
$config = Import-PowerShellDataFile -Path (Join-Path $RaizRepo 'config.psd1')

if (-not (Test-Path $config.PastaDevHome)) {
    New-Item -ItemType Directory -Path $config.PastaDevHome -Force | Out-Null
    Write-Log "Pasta de trabalho criada: $($config.PastaDevHome)" -Nivel OK
}
Set-UserEnvironmentVariable -Nome 'DEV_HOME' -Valor $config.PastaDevHome

# Lista ordenada de modulos: (chave do config.psd1, arquivo, nome amigavel) ---
$definicaoModulos = @(
    @{ Chave = 'Prereqs';              Arquivo = '00-prereqs.ps1';                Nome = 'Pre-requisitos (winget/choco)' }
    @{ Chave = 'DebloatWindows';       Arquivo = '09-debloat-windows.ps1';        Nome = 'Limpeza de bloatware do Windows' }
    @{ Chave = 'Linguagens';           Arquivo = '01-languages.ps1';              Nome = 'Linguagens e compiladores' }
    @{ Chave = 'MobileDesktop';        Arquivo = '02-mobile-desktop.ps1';         Nome = 'Mobile e Desktop' }
    @{ Chave = 'BancoDeDados';         Arquivo = '03-databases.ps1';              Nome = 'Bancos de dados (QuestDB/DuckDB)' }
    @{ Chave = 'AutomacaoGui';         Arquivo = '04-rpa-automation.ps1';         Nome = 'Automacao de GUI / RPA' }
    @{ Chave = 'Arquitetura';          Arquivo = '05-architecture-tools.ps1';     Nome = 'Arquitetura e engenharia de software' }
    @{ Chave = 'GitGithubCredenciais'; Arquivo = '06-git-github-credentials.ps1'; Nome = 'Git, GitHub e credenciais' }
    @{ Chave = 'ProgramasDiversos';    Arquivo = '07-misc-apps.ps1';              Nome = 'Programas diversos' }
    @{ Chave = 'AplicarDotfiles';      Arquivo = '08-dotfiles-apply.ps1';         Nome = 'Aplicacao de dotfiles (perfil, VS Code)' }
)

$RelatorioResultados = New-Object System.Collections.Generic.List[object]

foreach ($modulo in $definicaoModulos) {
    $habilitado = $config.Modulos[$modulo.Chave]
    $foiPedidoSomente = $Somente.Count -gt 0
    $devePular = $Pular -contains $modulo.Chave
    $deveRodar = $habilitado -and -not $devePular -and (-not $foiPedidoSomente -or $Somente -contains $modulo.Chave)

    if (-not $deveRodar) {
        Write-Log "Modulo '$($modulo.Nome)' desabilitado ou pulado — ignorando." -Nivel AVISO
        continue
    }

    Write-Log $modulo.Nome -Nivel PASSO
    $caminhoModulo = Join-Path $RaizRepo "modules\$($modulo.Arquivo)"

    if (-not (Test-Path $caminhoModulo)) {
        Write-Log "Arquivo de modulo nao encontrado: $caminhoModulo" -Nivel ERRO
        continue
    }

    if ($SimulacaoSemAlterar) {
        Write-Log "[SIMULACAO] Executaria: $caminhoModulo" -Nivel INFO
        continue
    }

    try {
        $resultadosModulo = & $caminhoModulo -Config $config -RaizRepo $RaizRepo
        if ($resultadosModulo) {
            $resultadosModulo | ForEach-Object {
                $_ | Add-Member -MemberType NoteProperty -Name 'Categoria' -Value $modulo.Nome -Force
                $RelatorioResultados.Add($_)
            }
        }
    }
    catch {
        Write-Log "Erro no modulo '$($modulo.Nome)': $($_.Exception.Message)" -Nivel ERRO
        Write-Log "O script continua para os proximos modulos. Revise o log em $arquivoLog" -Nivel AVISO
    }
}

# Relatorio final ---------------------------------------------------------------
if ($config.Modulos.RelatorioFinal -and -not $SimulacaoSemAlterar) {
    Write-Log 'Relatorio final de instalacao' -Nivel PASSO
    $caminhoRelatorio = Join-Path $RaizRepo 'modules\99-report.ps1'
    & $caminhoRelatorio -Config $config -RaizRepo $RaizRepo -Resultados $RelatorioResultados
}

Write-Log 'dev-os-dotfiles :: instalacao concluida' -Nivel PASSO
Write-Log "Log completo salvo em: $arquivoLog" -Nivel OK
Write-Log 'Abra um NOVO terminal (ou reinicie) para garantir que todas as variaveis de PATH sejam recarregadas.' -Nivel AVISO
