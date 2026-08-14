#Requires -Version 5.1
<#
    08-dotfiles-apply.ps1
    ------------------------------------------------------------------
    Aplica os dotfiles versionados neste repositorio nos locais reais
    que o Windows/VS Code/PowerShell esperam, via LINK SIMBOLICO — ou
    seja, o arquivo real do programa passa a ser o mesmo arquivo do
    repositorio git. Editar em um lugar edita no outro.

    Cobre:
      - Perfil do PowerShell ($PROFILE)
      - settings.json e keybindings.json do VS Code
      - Instalacao das extensoes do VS Code listadas em extensions.txt
    ------------------------------------------------------------------
#>
param(
    [Parameter(Mandatory = $true)]$Config,
    [Parameter(Mandatory = $true)][string]$RaizRepo
)

Import-Module (Join-Path $RaizRepo 'lib\Common.psm1') -Force
$resultados = @()

# ============================================================================
# PERFIL DO POWERSHELL
# ============================================================================
Write-Log 'Symlink do perfil do PowerShell' -Nivel PASSO

$origemPerfil = Join-Path $RaizRepo 'dotfiles\powershell\Microsoft.PowerShell_profile.ps1'
New-DotfileSymlink -OrigemNoRepo $origemPerfil -DestinoReal $PROFILE
$resultados += [PSCustomObject]@{ Nome = 'Perfil do PowerShell (symlink)'; Status = 'Configurado'; Origem = 'dotfiles/powershell/' }

# ============================================================================
# VS CODE — settings.json, keybindings.json e extensoes
# ============================================================================
Write-Log 'Dotfiles do VS Code' -Nivel PASSO

$pastaConfigVsCode = "$env:APPDATA\Code\User"
New-DotfileSymlink -OrigemNoRepo (Join-Path $RaizRepo 'dotfiles\vscode\settings.json') -DestinoReal (Join-Path $pastaConfigVsCode 'settings.json')
New-DotfileSymlink -OrigemNoRepo (Join-Path $RaizRepo 'dotfiles\vscode\keybindings.json') -DestinoReal (Join-Path $pastaConfigVsCode 'keybindings.json')
$resultados += [PSCustomObject]@{ Nome = 'settings.json / keybindings.json do VS Code (symlink)'; Status = 'Configurado'; Origem = 'dotfiles/vscode/' }

if (Test-CommandExists 'code') {
    $arquivoExtensoes = Join-Path $RaizRepo 'dotfiles\vscode\extensions.txt'
    $listaExtensoes = Get-Content $arquivoExtensoes | Where-Object { $_ -and $_ -notmatch '^\s*#' }
    $extensoesJaInstaladas = code --list-extensions

    Write-Log "Instalando extensoes do VS Code ($($listaExtensoes.Count) no total)..." -Nivel INFO
    foreach ($extensao in $listaExtensoes) {
        $extensao = $extensao.Trim()
        if ($extensoesJaInstaladas -contains $extensao) {
            continue
        }
        code --install-extension $extensao --force | Out-Null
    }
    $resultados += [PSCustomObject]@{ Nome = 'Extensoes do VS Code (extensions.txt)'; Status = 'Instalado'; Origem = 'dotfiles/vscode/extensions.txt' }
    Write-Log 'Extensoes do VS Code sincronizadas.' -Nivel OK
}
else {
    Write-Log 'Comando "code" ainda nao esta no PATH desta sessao (normal logo apos instalar o VS Code). Abra um novo terminal e rode este modulo novamente para instalar as extensoes.' -Nivel AVISO
}

# ============================================================================
# WINDOWS TERMINAL — apenas orienta (nao faz symlink, ver motivo no arquivo)
# ============================================================================
Write-Log 'Windows Terminal: aparencia/fonte disponivel em dotfiles/windows-terminal/settings.snippet.json (aplicacao manual, ver README).' -Nivel INFO

return $resultados
