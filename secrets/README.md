# Como as credenciais funcionam neste repositório

Esta pasta existe só para documentação — **nenhum segredo real deve ser
gravado dentro dela nem em qualquer outro lugar do repositório**. O
`.gitignore` da raiz já bloqueia os padrões mais comuns (`.env`, `*.key`,
`id_ed25519`, etc.) como uma segunda camada de proteção, mas a regra de
ouro é: se tem senha, chave ou token dentro, não é pra estar num arquivo
versionado.

## As três camadas de credenciais usadas pela Development OS

### 1. Login no GitHub — Git Credential Manager

O instalador do Git para Windows já inclui o **Git Credential Manager**
(GCM). O módulo `06-git-github-credentials.ps1` configura
`credential.helper = manager`, então na primeira vez que você fizer um
`git push`/`git pull` de um repositório privado, uma janela abre pedindo
login — depois disso, o GCM guarda o token no **Windows Credential
Manager** (Painel de Controle → Contas de Usuário → Gerenciador de
Credenciais) e reutiliza automaticamente. Nada fica em texto no disco.

Para o GitHub CLI (`gh`), rode manualmente uma vez:

```powershell
gh auth login --hostname github.com --git-protocol ssh --web
```

Esse comando é interativo de propósito — ele exige sua confirmação no
navegador, então não dá (nem deveria dar) para automatizar sem
intervenção humana.

### 2. Chave SSH

Gerada localmente pelo módulo 06 (`id_ed25519`), guardada em
`%USERPROFILE%\.ssh\`. A chave privada nunca sai da máquina. Cadastre a
chave **pública** (mostrada no final da execução do módulo, ou visível em
`id_ed25519.pub`) em <https://github.com/settings/keys>.

### 3. Segredos de aplicação (senha do QuestDB, tokens extras, etc.)

Usamos os módulos oficiais do PowerShell
`Microsoft.PowerShell.SecretManagement` + `Microsoft.PowerShell.SecretStore`,
que criam um cofre local criptografado (protegido pelo Windows + uma senha
mestre do cofre). Isso é instalado e inicializado automaticamente pelo
módulo 06.

**Gravar um segredo** (pede o valor de forma oculta, uma vez):

```powershell
Set-DevSecret -Nome 'QUESTDB_PASSWORD'
Set-DevSecret -Nome 'MOTHERDUCK_TOKEN'
```

**Ler um segredo dentro de um script/projeto seu:**

```powershell
$senha = Get-DevSecret -Nome 'QUESTDB_PASSWORD'
# use $senha em memória; nunca faça Write-Host $senha nem grave em arquivo
```

Essas duas funções vêm de `lib/Common.psm1` e já ficam disponíveis em
qualquer terminal novo, porque o perfil do PowerShell
(`dotfiles/powershell/Microsoft.PowerShell_profile.ps1`) importa o módulo
automaticamente.

## Docker remoto

Ainda não temos um host definido (ver `config.psd1` →
`DockerContextRemoto`). Quando você tiver um servidor, preencha esse
campo com algo como `ssh://usuario@ip-do-servidor` e rode
`.\install.ps1 -Somente BancoDeDados` de novo — o módulo
`03-databases.ps1` cria o `docker context` automaticamente. A autenticação
nesse caso é a mesma do SSH: sua chave `id_ed25519` (ou uma chave dedicada
que você registre no servidor).
