#Requires -Version 5.1
<#
    05-architecture-tools.ps1
    ------------------------------------------------------------------
    Ferramentas de arquitetura e engenharia de software:
      - draw.io Desktop (diagramas de arquitetura, fluxos, BPMN)
      - Extensao "Draw.io Integration" para editar .drawio direto no VS Code
      - Graphviz + extensao PlantUML para VS Code (diagramas as code)
      - Postman e Insomnia (clientes de teste de API)
    ------------------------------------------------------------------
#>
param(
    [Parameter(Mandatory = $true)]$Config,
    [Parameter(Mandatory = $true)][string]$RaizRepo
)

Import-Module (Join-Path $RaizRepo 'lib\Common.psm1') -Force
$resultados = @()

# ============================================================================
# DRAW.IO DESKTOP — diagramas de arquitetura, BPMN, fluxogramas
# ============================================================================
Write-Log 'draw.io Desktop' -Nivel PASSO
$resultados += Install-WingetApp -Id 'JGraph.Draw' -Nome 'draw.io Desktop' -Origem 'https://www.drawio.com/'

# ============================================================================
# PLANTUML — diagramas "as code" (precisa de Java, ja instalado no modulo 01, + Graphviz)
# ============================================================================
Write-Log 'PlantUML + Graphviz' -Nivel PASSO
$resultados += Install-WingetApp -Id 'Graphviz.Graphviz' -Nome 'Graphviz (motor de renderizacao do PlantUML)' -Origem 'https://graphviz.org/'

$pastaGraphviz = Get-ChildItem 'C:\Program Files\Graphviz*' -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
if ($pastaGraphviz) {
    Add-UserPathEntry -Pasta (Join-Path $pastaGraphviz.FullName 'bin')
}

Write-Log 'Extensoes de VS Code para diagramas (instaladas junto no modulo de VS Code / dotfiles): jebbs.plantuml e hediet.vscode-drawio.' -Nivel INFO

# ============================================================================
# CLIENTES DE TESTE DE API — Postman e Insomnia
# ============================================================================
Write-Log 'Postman e Insomnia (clientes de API)' -Nivel PASSO
$resultados += Install-WingetApp -Id 'Postman.Postman' -Nome 'Postman' -Origem 'https://www.postman.com/'
$resultados += Install-WingetApp -Id 'Insomnia.Insomnia' -Nome 'Insomnia' -Origem 'https://insomnia.rest/'

Write-Log 'Mapeamento de processos/requisitos: use draw.io (BPMN) para fluxos visuais e PlantUML (Markdown) para diagramas versionados como texto no proprio repositorio.' -Nivel INFO

return $resultados
