#Requires -Version 5.1
<#
    09-debloat-windows.ps1
    ------------------------------------------------------------------
    Remove o "bloatware" que vem de fabrica no Windows (jogos, apps de
    consumo, atalhos de propaganda) para deixar a maquina focada em
    desenvolvimento. Dois niveis, controlados por config.psd1 -> DebloatNivel:

      'Leve' (padrao) — so remove pacotes AppX de consumo/jogos. Baixo
                         risco, nao mexe em servicos nem no registro.
      'Forte'          — alem do nivel Leve, desativa telemetria
                         (DiagTrack), tarefas agendadas de coleta de dados,
                         Widgets, Copilot e sugestoes/anuncios do menu Iniciar.

    SEGURANCA: cada remocao roda isolada em try/catch — se um pacote nao
    existir nesta edicao/versao do Windows (ou ja tiver sido removido),
    o script simplesmente pula para o proximo, sem interromper a
    instalacao. Nada aqui desinstala Edge, Store, .NET/VCLibs/UI.Xaml
    (dependencias de outros apps) ou ferramentas uteis para dev
    (Terminal, Notepad, Calculadora, Snipping Tool, Camera).

    Um Ponto de Restauracao do Sistema e criado ANTES de qualquer remocao,
    para que seja possivel reverter por "Restaurar Sistema" caso algo
    pareca errado depois.
    ------------------------------------------------------------------
#>
param(
    [Parameter(Mandatory = $true)]$Config,
    [Parameter(Mandatory = $true)][string]$RaizRepo
)

Import-Module (Join-Path $RaizRepo 'lib\Common.psm1') -Force
$resultados = @()
$nivel = if ($Config.DebloatNivel) { $Config.DebloatNivel } else { 'Leve' }

Write-Log "Debloat do Windows — nivel: $nivel" -Nivel PASSO

# ============================================================================
# PONTO DE RESTAURACAO — rede de seguranca antes de mexer no sistema
# ============================================================================
try {
    Enable-ComputerRestore -Drive 'C:\' -ErrorAction SilentlyContinue
    Checkpoint-Computer -Description 'Antes do dev-os-dotfiles debloat' -RestorePointType 'MODIFY_SETTINGS'
    Write-Log 'Ponto de restauracao do sistema criado (Painel de Controle > Recuperacao > Abrir Restauracao do Sistema, se precisar reverter).' -Nivel OK
    $resultados += [PSCustomObject]@{ Nome = 'Ponto de restauracao do sistema'; Status = 'Criado'; Origem = 'nativo do Windows' }
}
catch {
    Write-Log "Nao foi possivel criar o ponto de restauracao automaticamente ($($_.Exception.Message)). Recomendo criar um manualmente antes de continuar." -Nivel AVISO
}

# ============================================================================
# NIVEL LEVE — pacotes AppX de consumo/jogos (baixo risco)
# Lista curada: nada aqui e dependencia de outro app nem essencial ao Windows.
# ============================================================================
$pacotesConsumo = @(
    # Jogos / Xbox (mantém apenas o necessário caso você jogue algo via Steam/Epic — isso não depende do Xbox App)
    'Microsoft.XboxApp',
    'Microsoft.GamingApp',
    'Microsoft.XboxGamingOverlay',
    'Microsoft.XboxIdentityProvider',
    'Microsoft.XboxSpeechToTextOverlay',
    'Microsoft.Xbox.TCUI',
    'Microsoft.MicrosoftSolitaireCollection',
    'king.com.CandyCrushSaga',
    'king.com.CandyCrushSodaSaga',
    'king.com.*',

    # Comunicacao/social que nao usamos neste setup (GitHub/Slack/Teams corporativo continuam por fora)
    'Microsoft.SkypeApp',
    'Microsoft.YourPhone',
    'Microsoft.People',

    # Realidade mista / 3D — nao se aplica a um setup de dev backend/mobile/desktop tradicional
    'Microsoft.MixedReality.Portal',
    'Microsoft.Microsoft3DViewer',

    # Atalhos de propaganda / apps redundantes
    'Microsoft.MicrosoftOfficeHub',
    'Microsoft.GetHelp',
    'Microsoft.Getstarted',
    'Microsoft.WindowsFeedbackHub',
    'Microsoft.BingNews',
    'Microsoft.BingWeather',
    'Microsoft.BingSearch',
    'Microsoft.549981C3F5F10',    # Cortana
    'Microsoft.ZuneMusic',        # "Musica do Groove"
    'Microsoft.ZuneVideo',        # "Filmes e TV"
    'Clipchamp.Clipchamp',
    'MicrosoftTeams',             # versao consumer embutida (nao afeta o Teams corporativo instalado por fora)
    'Microsoft.Todos',
    'Microsoft.PowerAutomateDesktop.WinGet' # placeholder nunca usado; o Power Automate Desktop REAL e instalado de proposito no modulo 04, nao entra aqui
)
# Remove o item "placeholder" acima da lista de forma segura — existe só para
# deixar documentado, no código, que o Power Automate Desktop é intencional
# e NÃO deve ser removido por engano por este módulo.
$pacotesConsumo = $pacotesConsumo | Where-Object { $_ -ne 'Microsoft.PowerAutomateDesktop.WinGet' }

$totalRemovidos = 0
foreach ($pacote in $pacotesConsumo) {
    try {
        $instalado = Get-AppxPackage -Name $pacote -AllUsers -ErrorAction SilentlyContinue
        if ($instalado) {
            $instalado | Remove-AppxPackage -AllUsers -ErrorAction Stop
            $totalRemovidos++
            Write-Log "Removido: $pacote" -Nivel OK
        }

        # Remove tambem do "template" do sistema, para nao reaparecer em novos usuarios/perfis
        $provisionado = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like $pacote }
        if ($provisionado) {
            $provisionado | Remove-AppxProvisionedPackage -Online -ErrorAction Stop | Out-Null
        }
    }
    catch {
        Write-Log "Nao foi possivel remover '$pacote' (pode nao existir nesta edicao do Windows): $($_.Exception.Message)" -Nivel AVISO
    }
}
$resultados += [PSCustomObject]@{ Nome = "Apps de consumo/jogos removidos ($totalRemovidos de $($pacotesConsumo.Count) tentados)"; Status = 'Concluido'; Origem = 'nativo do Windows (Remove-AppxPackage)' }

Write-Log 'Mantidos de proposito (uteis para dev ou essenciais ao sistema): Terminal, Notepad, Calculadora, Paint, Snipping Tool (ScreenSketch), Camera, Fotos, Microsoft Store, Edge, .NET/VCLibs/UI.Xaml.' -Nivel INFO

# ============================================================================
# NIVEL FORTE — telemetria, tarefas agendadas, Widgets, Copilot, sugestoes
# ============================================================================
if ($nivel -eq 'Forte') {
    Write-Log 'Nivel Forte: reduzindo telemetria e itens de "engajamento" do Windows...' -Nivel PASSO

    # --- Servico de telemetria (Connected User Experiences and Telemetry) ---
    try {
        Get-Service -Name 'DiagTrack' -ErrorAction Stop | Stop-Service -Force -ErrorAction SilentlyContinue
        Set-Service -Name 'DiagTrack' -StartupType Disabled
        Write-Log 'Servico DiagTrack (telemetria) desativado.' -Nivel OK
        $resultados += [PSCustomObject]@{ Nome = 'Servico DiagTrack (telemetria)'; Status = 'Desativado'; Origem = 'nativo do Windows' }
    }
    catch {
        Write-Log "Nao foi possivel desativar o DiagTrack: $($_.Exception.Message)" -Nivel AVISO
    }

    # --- Tarefas agendadas de coleta de dados/compatibilidade ---
    $tarefasParaDesativar = @(
        '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
        '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
        '\Microsoft\Windows\Autochk\Proxy',
        '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
        '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask',
        '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
        '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
        '\Microsoft\Windows\Feedback\Siuf\DmClient',
        '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload'
    )
    $totalTarefas = 0
    foreach ($tarefa in $tarefasParaDesativar) {
        try {
            Disable-ScheduledTask -TaskPath (Split-Path $tarefa -Parent) -TaskName (Split-Path $tarefa -Leaf) -ErrorAction Stop | Out-Null
            $totalTarefas++
        }
        catch {
            # Tarefa pode nao existir nesta versao do Windows — segue sem erro fatal
        }
    }
    Write-Log "Tarefas agendadas de telemetria/compatibilidade desativadas: $totalTarefas de $($tarefasParaDesativar.Count)." -Nivel OK
    $resultados += [PSCustomObject]@{ Nome = "Tarefas agendadas de telemetria ($totalTarefas desativadas)"; Status = 'Concluido'; Origem = 'nativo do Windows (Task Scheduler)' }

    # --- Copilot (politica de registro oficial da Microsoft para desativar) ---
    try {
        $chaveCopilot = 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'
        if (-not (Test-Path $chaveCopilot)) { New-Item -Path $chaveCopilot -Force | Out-Null }
        New-ItemProperty -Path $chaveCopilot -Name 'TurnOffWindowsCopilot' -Value 1 -PropertyType DWORD -Force | Out-Null
        Write-Log 'Windows Copilot desativado via politica local.' -Nivel OK
        $resultados += [PSCustomObject]@{ Nome = 'Windows Copilot'; Status = 'Desativado'; Origem = 'nativo do Windows (politica de registro)' }
    }
    catch {
        Write-Log "Nao foi possivel desativar o Copilot: $($_.Exception.Message)" -Nivel AVISO
    }

    # --- Widgets ---
    try {
        Get-AppxPackage -Name 'MicrosoftWindows.Client.WebExperience' -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' -Name 'AllowNewsAndInterests' -Value 0 -PropertyType DWORD -Force -ErrorAction SilentlyContinue | Out-Null
        Write-Log 'Widgets removidos/desativados.' -Nivel OK
        $resultados += [PSCustomObject]@{ Nome = 'Widgets'; Status = 'Desativado'; Origem = 'nativo do Windows' }
    }
    catch {
        Write-Log "Nao foi possivel desativar os Widgets: $($_.Exception.Message)" -Nivel AVISO
    }

    # --- Sugestoes/anuncios no menu Iniciar e na tela de bloqueio ---
    try {
        $chaveConteudo = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        $propriedades = @(
            'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled',
            'SubscribedContent-353698Enabled', 'SystemPaneSuggestionsEnabled',
            'SilentInstalledAppsEnabled', 'PreInstalledAppsEnabled', 'OemPreInstalledAppsEnabled'
        )
        foreach ($prop in $propriedades) {
            New-ItemProperty -Path $chaveConteudo -Name $prop -Value 0 -PropertyType DWORD -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Write-Log 'Sugestoes/anuncios do menu Iniciar e da tela de bloqueio desativados.' -Nivel OK
        $resultados += [PSCustomObject]@{ Nome = 'Sugestoes e anuncios do Windows'; Status = 'Desativado'; Origem = 'nativo do Windows (registro do usuario)' }
    }
    catch {
        Write-Log "Nao foi possivel desativar as sugestoes do menu Iniciar: $($_.Exception.Message)" -Nivel AVISO
    }

    Write-Log 'Nivel Forte concluido. Nada aqui e irreversivel: use o Ponto de Restauracao criado no inicio deste modulo se precisar desfazer.' -Nivel INFO
}
else {
    Write-Log 'Nivel Leve concluido (padrao). Para reduzir tambem telemetria/Widgets/Copilot/sugestoes, mude DebloatNivel para "Forte" em config.psd1 e rode ".\install.ps1 -Somente DebloatWindows" de novo.' -Nivel INFO
}

return $resultados
