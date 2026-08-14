#Requires -Version 5.1
<#
    99-report.ps1
    ------------------------------------------------------------------
    Gera reports/install_report.md com: nome do programa, versao
    instalada, categoria e URL oficial de cada item processado pelos
    modulos anteriores. Tambem copia o relatorio para a raiz do perfil
    do usuario, para acesso rapido.
    ------------------------------------------------------------------
#>
param(
    [Parameter(Mandatory = $true)]$Config,
    [Parameter(Mandatory = $true)][string]$RaizRepo,
    [Parameter(Mandatory = $true)]$Resultados
)

Import-Module (Join-Path $RaizRepo 'lib\Common.psm1') -Force

# Mapeamento "melhor esforco" de comando de versao para itens que nao vieram
# de um id winget (ex: instalados via pyenv/rig/fnm/pip/git clone).
$mapaComandosVersao = @(
    @{ Padrao = 'Python *';                     Comando = 'python';   Argumento = '--version' }
    @{ Padrao = 'pipx';                          Comando = 'pipx';     Argumento = '--version' }
    @{ Padrao = 'R (release)';                   Comando = 'Rscript';  Argumento = '--version' }
    @{ Padrao = 'Eclipse Temurin JDK*';          Comando = 'java';     Argumento = '-version' }
    @{ Padrao = '.NET SDK*';                     Comando = 'dotnet';   Argumento = '--version' }
    @{ Padrao = '.NET MAUI*';                    Comando = 'dotnet';   Argumento = '--version' }
    @{ Padrao = 'Node.js*';                      Comando = 'node';     Argumento = '--version' }
    @{ Padrao = 'TypeScript*';                   Comando = 'tsc';      Argumento = '--version' }
    @{ Padrao = 'Rust toolchain*';                Comando = 'rustc';    Argumento = '--version' }
    @{ Padrao = 'vcpkg';                         Comando = 'vcpkg';    Argumento = 'version' }
    @{ Padrao = 'mingw-w64*';                    Comando = 'gcc';      Argumento = '--version' }
    @{ Padrao = 'Flutter SDK';                    Comando = 'flutter';  Argumento = '--version' }
    @{ Padrao = 'Docker CLI';                     Comando = 'docker';   Argumento = '--version' }
    @{ Padrao = 'pyenv-win';                      Comando = 'pyenv';    Argumento = '--version' }
    @{ Padrao = 'fnm*';                          Comando = 'fnm';      Argumento = '--version' }
    @{ Padrao = 'rig*';                          Comando = 'rig';      Argumento = '--version' }
    @{ Padrao = 'Chocolatey';                     Comando = 'choco';    Argumento = '--version' }
)

function Resolve-VersaoInstalada {
    param($ItemResultado)

    # 1) Prioridade: se veio de winget, pergunta ao proprio winget (fonte mais confiavel)
    if ($ItemResultado.PSObject.Properties.Name -contains 'WingetId' -and $ItemResultado.WingetId) {
        $versaoWinget = Get-WingetInstalledVersion -Id $ItemResultado.WingetId
        if ($versaoWinget) { return $versaoWinget }
    }

    # 2) Fallback: mapa de comandos conhecidos
    foreach ($mapa in $mapaComandosVersao) {
        if ($ItemResultado.Nome -like $mapa.Padrao) {
            $versao = Get-AppVersion -Comando $mapa.Comando -Argumento $mapa.Argumento
            if ($versao) { return $versao }
        }
    }

    # 3) Nao foi possivel determinar automaticamente
    return 'N/D'
}

$linhasTabela = New-Object System.Collections.Generic.List[string]
$linhasTabela.Add('| Programa | Versao instalada | Categoria | Status | URL oficial |')
$linhasTabela.Add('|---|---|---|---|---|')

$totalOk = 0
$totalFalhas = 0

foreach ($item in $Resultados) {
    $versao = Resolve-VersaoInstalada -ItemResultado $item
    $categoria = if ($item.PSObject.Properties.Name -contains 'Categoria') { $item.Categoria } else { 'Geral' }
    $linhasTabela.Add("| $($item.Nome) | $versao | $categoria | $($item.Status) | $($item.Origem) |")

    if ($item.Status -match 'Falhou') { $totalFalhas++ } else { $totalOk++ }
}

$dataGeracao = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'

$conteudoRelatorio = @"
# Relatorio de Instalacao — Development OS

- **Data/hora:** $dataGeracao
- **Maquina:** $env:COMPUTERNAME
- **Usuario:** $env:USERNAME
- **Itens processados:** $($Resultados.Count) ($totalOk com sucesso / $totalFalhas com falha ou pendencia)

## Programas instalados

$($linhasTabela -join "`n")

## Observacoes

- Itens marcados como **N/D** na coluna de versao nao possuem um comando de
  versao padronizado (ex: chaves SSH, configuracoes de contexto Docker) ou
  a ferramenta ainda nao esta disponivel no PATH desta sessao — abra um novo
  terminal e rode ``.\install.ps1`` novamente para o script tentar de novo
  (ele e idempotente: pula tudo que ja esta instalado).
- Itens com status **"Falhou"** tem uma URL oficial na tabela acima para
  instalacao manual; os detalhes do erro estao no log da execucao, dentro
  de ``reports/install-<data>.log``.
- Este arquivo e gerado automaticamente a cada execucao do ``install.ps1``
  e sobrescrito na pasta ``reports/``; uma copia tambem fica em
  ``%USERPROFILE%\install_report.md`` para acesso rapido.

---
Gerado automaticamente por ``modules/99-report.ps1`` (repositorio dev-os-dotfiles).
"@

$caminhoRelatorio = Join-Path $RaizRepo 'reports\install_report.md'
$conteudoRelatorio | Out-File -FilePath $caminhoRelatorio -Encoding utf8 -Force
Copy-Item $caminhoRelatorio "$env:USERPROFILE\install_report.md" -Force

Write-Log "Relatorio gerado em: $caminhoRelatorio" -Nivel OK
Write-Log "Copia rapida em: $env:USERPROFILE\install_report.md" -Nivel OK
Write-Log "Resumo: $totalOk item(ns) OK, $totalFalhas com falha/pendencia de $($Resultados.Count) total." -Nivel INFO
