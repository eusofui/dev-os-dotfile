#Requires -Version 5.1
<#
    DevOS-Setup-Launcher.ps1
    ------------------------------------------------------------------
    Este arquivo vira o "DevOS-Setup.exe" (via PS2EXE — ver
    ../gerar-instalador.ps1 e ../.github/workflows/build-installer.yml).

    E AUTOCONTIDO DE PROPOSITO: nao depende de nenhum outro arquivo do
    repositorio, porque a funcao dele e justamente TRAZER o repositorio
    para esta maquina. Fluxo, do clique duplo ao fim, sem nenhuma
    pergunta ao usuario:

      1. Pede elevacao (UAC) — o .exe compilado ja e marcado como
         "requireAdmin", entao o Windows mostra isso automaticamente.
      2. Garante TLS 1.2 e verifica/orienta a instalar o winget.
      3. Baixa o ZIP do repositorio (sem depender de Git) e extrai em
         C:\SOUFUI.
      4. Roda install.ps1 de dentro de C:\SOUFUI, com os padroes do
         config.psd1 do repositorio — 100% desatendido.
      5. Abre o install_report.md ao final.

    A UNICA coisa que nao da (nem deve) para automatizar sem interacao:
    o prompt de UAC (Windows exige isso por seguranca) e o login do
    GitHub CLI / SecretStore, que ficam para depois (ver README).
    ------------------------------------------------------------------
#>

# ============================================================================
# CONFIGURACAO — preenchido automaticamente por gerar-instalador.ps1 (local)
# ou pelo workflow build-installer.yml (GitHub Actions) antes de compilar.
# Se voce estiver lendo isto sem ter rodado por la, edite a linha abaixo
# manualmente antes de compilar com PS2EXE.
# ============================================================================
$UrlRepoZip = '__REPO_ZIP_URL__'          # ex: https://github.com/usuario/dev-os-dotfiles/archive/refs/heads/main.zip
$PastaDestino = 'C:\SOUFUI'

function Escrever($Mensagem, $Cor = 'Gray') {
    Write-Host "[DevOS-Setup] $Mensagem" -ForegroundColor $Cor
}

# ----------------------------------------------------------------------------
# 1) Elevacao — redundante ao "requireAdmin" do PS2EXE, mas seguro ter os dois.
# ----------------------------------------------------------------------------
$principalAtual = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principalAtual.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Escrever 'Solicitando elevacao (Administrador)...' 'Yellow'
    $caminhoAtual = if ($PSCommandPath) { $PSCommandPath } else { [System.Diagnostics.Process]::GetCurrentProcess().Path }
    Start-Process -FilePath $caminhoAtual -Verb RunAs
    exit
}

# O .exe compilado (PS2EXE) roda sem passar pela Execution Policy do Windows —
# mas ele proprio chama install.ps1 mais abaixo, que E um .ps1 de verdade, e
# esse fica sujeito a Execution Policy normalmente. Na maioria das maquinas
# (principalmente as novas/domesticas) o padrao e "Restricted", que bloqueia
# QUALQUER script. Isto aqui libera SOMENTE para este processo — nao muda
# nenhuma configuracao permanente do Windows nem precisa de nada alem do que
# este .exe ja tem (nao depende de politica de grupo).
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop
}
catch {
    Escrever "Aviso: nao foi possivel ajustar a Execution Policy do processo ($($_.Exception.Message))." 'Yellow'
}

# IMPORTANTE: esta checagem NAO compara com o texto literal do marcador usado
# la em cima (duplo underscore antes/depois de REPO ZIP URL). Se comparasse,
# a troca automatica feita pelo gerar-instalador.ps1 / build-installer.yml
# substituiria as DUAS ocorrencias (a de cima E esta aqui) pela mesma URL —
# e a checagem passaria a comparar a URL com ela mesma, disparando "erro"
# mesmo quando tudo deu certo. Por isso valida a FORMA da URL, nao o texto
# exato do marcador.
if ([string]::IsNullOrWhiteSpace($UrlRepoZip) -or $UrlRepoZip -notmatch '^https://github\.com/') {
    Escrever 'ERRO: este instalador foi compilado sem a URL do repositorio configurada corretamente.' 'Red'
    Escrever "Valor atual: '$UrlRepoZip'" 'Red'
    Escrever 'Preencha config.psd1 -> Identidade.RepoDotfiles no repositorio e gere o instalador de novo (gerar-instalador.ps1).' 'Red'
    Read-Host 'Pressione ENTER para sair'
    exit 1
}

Escrever 'Development OS — instalacao automatica iniciada.' 'Cyan'
Escrever "Repositorio: $UrlRepoZip"
Escrever "Destino: $PastaDestino"

# ----------------------------------------------------------------------------
# 2) TLS 1.2 + verificacao do winget
# ----------------------------------------------------------------------------
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Escrever 'winget nao encontrado. Abrindo a Microsoft Store para instalar o "App Installer"...' 'Yellow'
    Start-Process 'ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1'
    Escrever 'Instale o App Installer na janela que abriu e rode este instalador de novo.' 'Yellow'
    Read-Host 'Pressione ENTER para sair'
    exit 1
}
Escrever 'winget disponivel.' 'Green'

# ----------------------------------------------------------------------------
# 3) Baixar e extrair o repositorio (via ZIP — nao depende de Git instalado)
# ----------------------------------------------------------------------------
try {
    $zipTemp = Join-Path $env:TEMP 'dev-os-dotfiles.zip'
    $pastaExtracaoTemp = Join-Path $env:TEMP 'dev-os-dotfiles-extract'

    Escrever 'Baixando o repositorio...' 'Cyan'
    # O endpoint .../archive/refs/heads/main.zip do GitHub aponta sempre para
    # "o main atual", mas o CDN dele (codeload.github.com) pode servir por
    # alguns minutos uma copia em cache de ANTES do ultimo commit — o que
    # faria baixar uma versao desatualizada do repositorio logo apos uma
    # correcao. Isto forca sempre buscar a versao mais nova.
    $urlSemCache = "$UrlRepoZip`?cachebust=$([guid]::NewGuid().ToString('N'))"
    $headersSemCache = @{ 'Cache-Control' = 'no-cache, no-store'; 'Pragma' = 'no-cache' }
    Invoke-WebRequest -Uri $urlSemCache -OutFile $zipTemp -UseBasicParsing -Headers $headersSemCache

    if (Test-Path $pastaExtracaoTemp) { Remove-Item $pastaExtracaoTemp -Recurse -Force }
    Expand-Archive -Path $zipTemp -DestinationPath $pastaExtracaoTemp -Force

    # O GitHub extrai dentro de uma subpasta tipo "dev-os-dotfiles-main" — normaliza.
    $subpasta = Get-ChildItem $pastaExtracaoTemp -Directory | Select-Object -First 1

    if (Test-Path $PastaDestino) {
        Escrever "Pasta $PastaDestino ja existe — atualizando arquivos (mantendo o que ja estava configurado)..." 'Yellow'
        Copy-Item "$($subpasta.FullName)\*" $PastaDestino -Recurse -Force
    }
    else {
        New-Item -ItemType Directory -Path (Split-Path $PastaDestino -Parent) -Force -ErrorAction SilentlyContinue | Out-Null
        Move-Item $subpasta.FullName $PastaDestino -Force
    }

    Escrever "Repositorio pronto em $PastaDestino." 'Green'
}
catch {
    Escrever "ERRO ao baixar/extrair o repositorio: $($_.Exception.Message)" 'Red'
    Read-Host 'Pressione ENTER para sair'
    exit 1
}

# ----------------------------------------------------------------------------
# 4) Rodar install.ps1 — 100% desatendido, usa os padroes de config.psd1
# ----------------------------------------------------------------------------
Escrever 'Iniciando install.ps1 (isso pode levar de 1 a 3 horas, dependendo da internet)...' 'Cyan'
Set-Location $PastaDestino
try {
    & (Join-Path $PastaDestino 'install.ps1')
}
catch {
    Escrever "install.ps1 terminou com um erro: $($_.Exception.Message)" 'Red'
    Escrever 'Revise reports\install-*.log dentro de C:\SOUFUI para detalhes.' 'Yellow'
}

# ----------------------------------------------------------------------------
# 5) Abrir o relatorio final
# ----------------------------------------------------------------------------
$caminhoRelatorio = Join-Path $PastaDestino 'reports\install_report.md'
if (Test-Path $caminhoRelatorio) {
    Escrever 'Abrindo o relatorio final...' 'Green'
    Start-Process $caminhoRelatorio
}

Escrever 'Concluido. Abra um novo terminal para carregar todas as variaveis de PATH.' 'Cyan'
Read-Host 'Pressione ENTER para fechar'
