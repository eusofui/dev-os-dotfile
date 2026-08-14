#Requires -Version 5.1
<#
    04-rpa-automation.ps1
    ------------------------------------------------------------------
    Ambiente de automacao de GUI / RPA (cliques, teclado, reconhecimento
    de imagem/texto na tela):
      - PyAutoGUI + libs de apoio (Pillow, OpenCV, pygetwindow, pyperclip)
      - Tesseract OCR (reconhecimento de texto na tela, usado via pytesseract)
      - AutoHotkey (automacao nativa de teclado/mouse via scripts .ahk)
      - Power Automate Desktop (ferramenta de RPA nativa e gratuita da Microsoft)
    ------------------------------------------------------------------
#>
param(
    [Parameter(Mandatory = $true)]$Config,
    [Parameter(Mandatory = $true)][string]$RaizRepo
)

Import-Module (Join-Path $RaizRepo 'lib\Common.psm1') -Force
$resultados = @()

# ============================================================================
# PYAUTOGUI e bibliotecas Python de apoio para RPA
# ============================================================================
Write-Log 'PyAutoGUI e bibliotecas Python de automacao' -Nivel PASSO

if (Test-CommandExists 'pip') {
    $pacotesPython = @(
        'pyautogui',      # controle de mouse/teclado + localizacao de imagem na tela
        'pillow',         # manipulacao de imagens (dependencia do PyAutoGUI)
        'opencv-python',  # reconhecimento de imagem mais preciso (usado pelo PyAutoGUI internamente)
        'pygetwindow',    # localizar/mover/focar janelas abertas
        'pyperclip',      # acesso a area de transferencia
        'pytesseract',    # OCR (le texto de imagens/telas) -- precisa do Tesseract instalado (abaixo)
        'keyboard',       # hooks globais de teclado
        'mouse'           # hooks globais de mouse
    )
    Write-Log "Instalando via pip: $($pacotesPython -join ', ')" -Nivel INFO
    python -m pip install --upgrade $pacotesPython | Out-Null
    $resultados += [PSCustomObject]@{ Nome = 'PyAutoGUI + libs de RPA (pip)'; Status = 'Instalado'; Origem = 'https://pyautogui.readthedocs.io/' }
}
else {
    Write-Log 'pip nao encontrado nesta sessao — rode o modulo 01-languages.ps1 primeiro (Python/pyenv-win).' -Nivel AVISO
}

# ============================================================================
# TESSERACT OCR — reconhecimento de texto na tela (usado com pytesseract)
# ============================================================================
Write-Log 'Tesseract OCR' -Nivel PASSO
$resultados += Install-WingetApp -Id 'UB-Mannheim.TesseractOCR' -Nome 'Tesseract OCR' -Origem 'https://github.com/UB-Mannheim/tesseract/wiki'

$pastaTesseract = "$env:ProgramFiles\Tesseract-OCR"
if (Test-Path $pastaTesseract) {
    Add-UserPathEntry -Pasta $pastaTesseract
    Write-Log 'No Python, aponte o pytesseract para o executavel: pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"' -Nivel INFO
}

# ============================================================================
# AUTOHOTKEY — automacao nativa via scripts .ahk (cliques, teclado, janelas)
# ============================================================================
Write-Log 'AutoHotkey' -Nivel PASSO
$resultados += Install-WingetApp -Id 'AutoHotkey.AutoHotkey' -Nome 'AutoHotkey' -Origem 'https://www.autohotkey.com/'

# ============================================================================
# POWER AUTOMATE DESKTOP — RPA visual/nativo da Microsoft (gratuito p/ Windows)
# ============================================================================
Write-Log 'Power Automate Desktop' -Nivel PASSO
$resultados += Install-WingetApp -Id 'Microsoft.PowerAutomateDesktop' -Nome 'Power Automate Desktop' `
    -Origem 'https://www.microsoft.com/pt-br/power-platform/products/power-automate' `
    -UrlManualFallback 'https://www.microsoft.com/pt-br/power-platform/products/power-automate'

Write-Log 'Resumo do ambiente de RPA: PyAutoGUI (scripts Python programaticos) + AutoHotkey (scripts leves .ahk) + Power Automate Desktop (fluxos visuais, sem codigo).' -Nivel INFO

return $resultados
