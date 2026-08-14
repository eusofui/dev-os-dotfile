#Requires -Version 5.1
<#
    07-misc-apps.ps1
    ------------------------------------------------------------------
    Programas diversos do dia a dia. Todos verificam se ja estao
    instalados antes de tentar instalar de novo (idempotente) —
    por isso e seguro incluir aqui o Chrome e o Claude mesmo ja
    estando instalados: eles so serao "redescobertos" e pulados,
    e ficam garantidos para a proxima maquina/formatacao.
    ------------------------------------------------------------------
#>
param(
    [Parameter(Mandatory = $true)]$Config,
    [Parameter(Mandatory = $true)][string]$RaizRepo
)

Import-Module (Join-Path $RaizRepo 'lib\Common.psm1') -Force
$resultados = @()

Write-Log 'Programas diversos' -Nivel PASSO

$resultados += Install-WingetApp -Id 'Google.Chrome' -Nome 'Google Chrome' -Origem 'https://www.google.com/chrome/'
$resultados += Install-WingetApp -Id 'Anthropic.Claude' -Nome 'Claude (app desktop)' -Origem 'https://claude.ai/download'
$resultados += Install-WingetApp -Id '7zip.7zip' -Nome '7-Zip' -Origem 'https://www.7-zip.org/'
$resultados += Install-WingetApp -Id 'AnyDesk.AnyDesk' -Nome 'AnyDesk' -Origem 'https://anydesk.com/'
$resultados += Install-WingetApp -Id 'CodecGuide.K-LiteCodecPack.Mega' -Nome 'K-Lite Codec Pack (Mega)' -Origem 'https://codecguide.com/download_kl.htm'
$resultados += Install-WingetApp -Id 'Zoom.Zoom' -Nome 'Zoom' -Origem 'https://zoom.us/'
$resultados += Install-WingetApp -Id 'Microsoft.VisualStudioCode' -Nome 'Visual Studio Code' -Origem 'https://code.visualstudio.com/'
$resultados += Install-WingetApp -Id 'Gyan.FFmpeg' -Nome 'ffmpeg' -Origem 'https://ffmpeg.org/'

# ============================================================================
# POWER BI DESKTOP — tratamento especial em cascata.
# O id "Microsoft.PowerBI" no winget tem um bug conhecido e recorrente
# ("Installer hash does not match" — ver issues no microsoft/winget-pkgs),
# que foi exatamente o problema relatado anteriormente. Por isso a ordem
# de tentativa aqui e:
#   1) Microsoft Store (mais confiavel, atualiza sozinho, sem problema de hash)
#   2) winget "Microsoft.PowerBI" (fonte winget tradicional)
#   3) Link oficial direto para download manual (ultimo recurso)
# ============================================================================
Write-Log 'Power BI Desktop (com fallback em 3 niveis)' -Nivel PASSO

$urlOficialPowerBi = 'https://www.microsoft.com/pt-br/download/details.aspx?id=58494'
$idPowerBiStore = '9NTXR16HNW1T'
$powerBiOk = $false

if (Test-WingetPackageInstalled -Id 'Microsoft.PowerBI') {
    Write-Log 'Power BI Desktop ja instalado.' -Nivel OK
    $resultados += [PSCustomObject]@{ Nome = 'Power BI Desktop'; Status = 'Ja instalado'; Origem = $urlOficialPowerBi }
    $powerBiOk = $true
}

if (-not $powerBiOk) {
    Write-Log 'Tentativa 1/3: instalando via Microsoft Store (winget --source msstore)...' -Nivel INFO
    $resultadoStore = Install-WingetApp -Id $idPowerBiStore -Nome 'Power BI Desktop' -Origem $urlOficialPowerBi -Source msstore
    if ($resultadoStore.Status -match 'Instalado|Ja instalado') {
        $resultados += $resultadoStore
        $powerBiOk = $true
    }
}

if (-not $powerBiOk) {
    Write-Log 'Tentativa 2/3: instalando via winget (fonte winget, id Microsoft.PowerBI)...' -Nivel INFO
    $resultadoWinget = Install-WingetApp -Id 'Microsoft.PowerBI' -Nome 'Power BI Desktop' -Origem $urlOficialPowerBi
    if ($resultadoWinget.Status -match 'Instalado|Ja instalado') {
        $resultados += $resultadoWinget
        $powerBiOk = $true
    }
}

if (-not $powerBiOk) {
    Write-Log 'Tentativa 3/3: as duas fontes automaticas falharam (problema conhecido de hash do instalador no winget).' -Nivel AVISO
    Write-Log "Baixe manualmente a versao oficial em: $urlOficialPowerBi" -Nivel AVISO
    Write-Log 'Alternativa: abra a Microsoft Store e busque "Power BI Desktop" manualmente (evita o bug de hash do winget).' -Nivel AVISO
    $resultados += [PSCustomObject]@{ Nome = 'Power BI Desktop'; Status = 'Falhou (baixar manualmente)'; Origem = $urlOficialPowerBi }
}

return $resultados
