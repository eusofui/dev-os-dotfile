#Requires -Version 5.1
<#
    06-git-github-credentials.ps1
    ------------------------------------------------------------------
    Git, GitHub CLI, chave SSH e cofre de credenciais — SEM NADA fixo
    (hardcoded) em nenhum arquivo do repositorio.

    Estrategia de credenciais (decidida no planejamento):
      - Git Credential Manager (ja embutido no instalador oficial do Git
        para Windows) usa o Windows Credential Manager por baixo para
        guardar o token/senha do GitHub depois do primeiro login.
      - Chave SSH gerada localmente; a CHAVE PRIVADA nunca sai da maquina
        nem entra no repositorio (o .gitignore do repo bloqueia isso).
      - Segredos "de aplicacao" (senha do QuestDB, tokens extras, etc.)
        ficam no cofre local Microsoft.PowerShell.SecretStore, acessados
        em runtime via Get-DevSecret — nunca gravados em texto puro.
    ------------------------------------------------------------------
#>
param(
    [Parameter(Mandatory = $true)]$Config,
    [Parameter(Mandatory = $true)][string]$RaizRepo
)

Import-Module (Join-Path $RaizRepo 'lib\Common.psm1') -Force
$resultados = @()

# ============================================================================
# GIT (o instalador oficial ja inclui o Git Credential Manager)
# ============================================================================
Write-Log 'Git + Git Credential Manager' -Nivel PASSO
$resultados += Install-WingetApp -Id 'Git.Git' -Nome 'Git for Windows (inclui Git Credential Manager)' -Origem 'https://git-scm.com/'

if (Test-CommandExists 'git') {
    git config --global credential.helper manager
    git config --global init.defaultBranch main
    git config --global core.autocrlf true
    git config --global pull.rebase false

    if ($Config.Identidade.NomeCompleto) {
        git config --global user.name $Config.Identidade.NomeCompleto
    }
    if ($Config.Identidade.Email) {
        git config --global user.email $Config.Identidade.Email
    }
    Write-Log 'Git configurado (credential.helper=manager -> usa o Windows Credential Manager).' -Nivel OK
}

# Symlink do .gitconfig versionado (mantem includes/aliases customizados sincronizados)
New-DotfileSymlink -OrigemNoRepo (Join-Path $RaizRepo 'dotfiles\git\.gitconfig-aliases') -DestinoReal "$env:USERPROFILE\.gitconfig-aliases"
if (Test-CommandExists 'git') {
    git config --global include.path "$env:USERPROFILE\.gitconfig-aliases"
}

# ============================================================================
# GITHUB CLI (gh)
# ============================================================================
Write-Log 'GitHub CLI (gh)' -Nivel PASSO
$resultados += Install-WingetApp -Id 'GitHub.cli' -Nome 'GitHub CLI' -Origem 'https://cli.github.com/'

if (Test-CommandExists 'gh') {
    $statusGh = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log 'GitHub CLI instalado, mas ainda sem login. Rode manualmente (interativo, abre o navegador):' -Nivel AVISO
        Write-Log '    gh auth login --hostname github.com --git-protocol ssh --web' -Nivel AVISO
        Write-Log 'Isso NAO pode ser automatizado com seguranca (exige confirmacao humana no navegador/GitHub) — de proposito, para nao expor token nenhum em script.' -Nivel INFO
    }
    else {
        Write-Log 'GitHub CLI ja autenticado nesta maquina.' -Nivel OK
    }
}

# ============================================================================
# CHAVE SSH — gerada localmente, nunca versionada
# ============================================================================
Write-Log 'Chave SSH' -Nivel PASSO

$pastaSsh = "$env:USERPROFILE\.ssh"
$chavePrivada = Join-Path $pastaSsh 'id_ed25519'
$chavePublica = "$chavePrivada.pub"

if (-not (Test-Path $pastaSsh)) {
    New-Item -ItemType Directory -Path $pastaSsh -Force | Out-Null
}

if (-not (Test-Path $chavePrivada)) {
    $emailParaChave = if ($Config.Identidade.Email) { $Config.Identidade.Email } else { "$env:USERNAME@$env:COMPUTERNAME" }
    Write-Log "Gerando novo par de chaves SSH (ed25519) para $emailParaChave..." -Nivel INFO
    ssh-keygen -t ed25519 -C $emailParaChave -f $chavePrivada -N '""'
    $resultados += [PSCustomObject]@{ Nome = 'Chave SSH (ed25519)'; Status = 'Gerada'; Origem = 'local (nunca versionada)' }
}
else {
    Write-Log 'Chave SSH ja existe, mantendo a atual.' -Nivel OK
    $resultados += [PSCustomObject]@{ Nome = 'Chave SSH (ed25519)'; Status = 'Ja existia'; Origem = 'local (nunca versionada)' }
}

# Habilita e inicia o servico OpenSSH Authentication Agent, e adiciona a chave
try {
    Get-Service ssh-agent | Set-Service -StartupType Automatic
    Start-Service ssh-agent -ErrorAction SilentlyContinue
    ssh-add $chavePrivada 2>$null | Out-Null
    Write-Log 'ssh-agent iniciado e chave adicionada.' -Nivel OK
}
catch {
    Write-Log 'Nao foi possivel iniciar o ssh-agent automaticamente. Rode como Administrador: Set-Service ssh-agent -StartupType Automatic; Start-Service ssh-agent' -Nivel AVISO
}

if (Test-Path $chavePublica) {
    Write-Log 'Sua chave PUBLICA (pode compartilhar) — cadastre em https://github.com/settings/keys :' -Nivel INFO
    Write-Log (Get-Content $chavePublica -Raw) -Nivel INFO
}

# ============================================================================
# COFRE DE SEGREDOS LOCAL — Microsoft.PowerShell.SecretManagement + SecretStore
# Usado para senhas do QuestDB, tokens extras, etc. Tudo protegido pelo
# Windows (DPAPI) + uma senha mestre do cofre. NUNCA fica em texto no repo.
# ============================================================================
Write-Log 'Cofre de segredos local (SecretManagement + SecretStore)' -Nivel PASSO
try {
    Initialize-DevSecretStore
    $resultados += [PSCustomObject]@{ Nome = 'Cofre de segredos (SecretStore)'; Status = 'Configurado'; Origem = 'https://learn.microsoft.com/powershell/utility-modules/secretmanagement/overview' }
    Write-Log 'Para guardar uma senha/token: Set-DevSecret -Nome "QUESTDB_PASSWORD" (pede o valor de forma oculta e segura).' -Nivel INFO
    Write-Log 'Para usar em um script:      $senha = Get-DevSecret -Nome "QUESTDB_PASSWORD"' -Nivel INFO
}
catch {
    Write-Log "Nao foi possivel preparar o cofre de segredos agora: $($_.Exception.Message). Rode Initialize-DevSecretStore manualmente depois de abrir um novo terminal." -Nivel AVISO
}

Write-Log 'Nenhuma senha, chave ou token e gravado em texto puro em nenhum arquivo deste repositorio (ver secrets/README.md e .gitignore).' -Nivel OK

return $resultados
