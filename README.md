# dev-os-dotfiles

Sua "Development OS" completa, padronizada e automatizada para Windows —
tudo descrito como código, versionado num repositório Git privado
("Dotfiles / Setup as Code"). Existem dois jeitos de usar: baixar um único
**instalador `.exe`** e não fazer mais nada, ou rodar os scripts PowerShell
manualmente, passo a passo, se você preferir acompanhar/auditar cada
etapa. No final, você tem linguagens, IDEs, SDKs mobile/desktop, clientes
de banco de dados, ambiente de RPA, ferramentas de arquitetura, Git/GitHub
configurados, uma limpeza de bloatware do Windows e um relatório completo
do que foi instalado.

## Índice

1. [Filosofia e decisões de arquitetura](#1-filosofia-e-decisões-de-arquitetura)
2. [Pré-requisitos](#2-pré-requisitos)
3. [Instalador automático (.exe) — o caminho recomendado](#3-instalador-automático-exe--o-caminho-recomendado)
4. [Passo a passo manual (auditável)](#4-passo-a-passo-manual-auditável)
5. [Estrutura do repositório](#5-estrutura-do-repositório)
6. [O que cada módulo instala](#6-o-que-cada-módulo-instala)
7. [Limpeza de bloatware do Windows](#7-limpeza-de-bloatware-do-windows)
8. [Credenciais, senhas, chaves e tokens](#8-credenciais-senhas-chaves-e-tokens)
9. [Banco de dados: QuestDB e DuckDB remotos + Docker](#9-banco-de-dados-questdb-e-duckdb-remotos--docker)
10. [Mobile/Desktop: cobertura e limitações (iOS)](#10-mobiledesktop-cobertura-e-limitações-ios)
11. [Publicando no GitHub (repositório privado)](#11-publicando-no-github-repositório-privado)
12. [Uso do dia a dia](#12-uso-do-dia-a-dia)
13. [Relatório final (install_report.md)](#13-relatório-final-install_reportmd)
14. [Solução de problemas comuns](#14-solução-de-problemas-comuns)
15. [Como estender](#15-como-estender)

---

## 1. Filosofia e decisões de arquitetura

Este repositório segue quatro princípios:

**Idempotência** — rodar o script uma ou dez vezes produz o mesmo resultado.
Todo módulo verifica se algo já está instalado antes de instalar de novo.
Isso significa que você pode usar o mesmo repositório tanto para a
configuração inicial quanto para "consertar" uma máquina depois de meses.

**Nada fixo (hardcoded)** — nenhuma senha, chave SSH ou token aparece em
texto puro em nenhum arquivo versionado. Ver a seção
[8. Credenciais](#8-credenciais-senhas-chaves-e-tokens).

**Modular** — cada categoria de ferramenta é um arquivo próprio em
`modules/`. Ligar/desligar um módulo é uma linha no `config.psd1`, não uma
edição de código.

**Resiliente** — pacotes do `winget` mudam de ID, quebram ou saem do ar.
Cada instalação é isolada em `try/catch`; uma falha num programa não
derruba o resto da execução, e fica registrada tanto no log quanto no
`install_report.md` com uma URL para instalação manual.

### Decisões tomadas durante o planejamento

| Decisão | Escolha | Por quê |
|---|---|---|
| Gerenciador de pacotes | `winget` (nativo do Windows) + Chocolatey como fallback | Winget é mantido pela Microsoft e já vem no Windows 10/11 atualizados; Chocolatey cobre os poucos pacotes que o winget não tem |
| Credenciais | Windows Credential Manager + Git Credential Manager + PowerShell SecretStore | 100% nativo, sem depender de um serviço terceiro nem de assinatura paga |
| Acesso ao Docker | Só o Docker **CLI** local, apontando via `docker context` para um host remoto (endereço ainda não definido) | Você pediu explicitamente para não instalar o Docker Desktop/Engine nesta máquina |
| iOS | Não configurado agora | Sem Mac disponível; o ambiente já fica pronto para Android e para adicionar iOS depois via Expo EAS Build/Codemagic, sem precisar reinstalar nada |
| C++ / .NET / MAUI | Visual Studio Community 2022 completo | Necessário para o designer visual do .NET MAUI e para a melhor experiência de debug em C++ |
| Pasta do repositório | Fixa em `C:\SOUFUI` (não no perfil do usuário) | Pedido explícito — mesmo caminho em qualquer conta de usuário da máquina |
| Instalador | `.exe` único, gerado a partir dos mesmos scripts (não é um segundo código) | Zero interação além de 1 clique de UAC; ver seção 3 |
| Bloatware do Windows | Removido por padrão (nível "Leve") | Ver seção 7 — apps de consumo/jogos fora, nada essencial tocado |
| K-Lite Codec Pack | Edição **Mega** (mantida como pedido originalmente) | É a edição mais completa; cobre qualquer formato raro de vídeo/áudio |

---

## 2. Pré-requisitos

- Windows 10 (versão 1809+) ou Windows 11, com o **winget** disponível
  (`winget --version` no PowerShell). Se não tiver, o próprio instalador
  `.exe` abre a Microsoft Store no lugar certo automaticamente.
- Uma conta no GitHub, com um repositório **privado** vazio criado para
  guardar este conteúdo (ex: `dev-os-dotfiles`).
- PowerShell 5.1 (já vem no Windows) ou superior. PowerShell 7 funciona
  igual.
- Conexão à internet estável — o script baixa vários instaladores e SDKs
  (o total pode passar de 15-20 GB, principalmente por causa do Visual
  Studio e do Android Studio).
- Cerca de 1-2 horas na primeira execução completa, dependendo da
  internet. Isso vale tanto para o `.exe` quanto para o modo manual — o
  tempo é dos downloads em si, não de você ficar clicando em nada.

---

## 3. Instalador automático (.exe) — o caminho recomendado

Este é o "sem eu precisar fazer nada" que você pediu. O `DevOS-Setup.exe`
é gerado **a partir dos mesmos scripts** deste repositório (não existe um
segundo código de instalação por trás — ver `instalador/DevOS-Setup-Launcher.ps1`),
então tudo que está documentado nas seções seguintes também vale para ele.

### O que ele faz, sem perguntar nada

1. Pede elevação (UAC) — **este é o único clique que o Windows exige por
   segurança**; não é possível (nem seria desejável) remover esse prompt
   de um instalador que mexe no sistema.
2. Verifica o `winget`; se faltar, abre a Microsoft Store já na página
   certa.
3. Baixa este repositório (via ZIP, não precisa ter Git instalado ainda)
   e extrai em `C:\SOUFUI`.
4. Roda `install.ps1` com os padrões de `config.psd1` — todos os módulos
   habilitados, incluindo a limpeza de bloatware (seção 7) — sem exibir
   nenhuma caixa de diálogo.
5. Abre o `install_report.md` no final.

As únicas duas coisas que **não** ficam 100% automáticas, de propósito,
por segurança — e não bloqueiam o resto da instalação, só ficam pendentes
para você fazer depois, quando quiser:

- **Login no GitHub** (`gh auth login`) — exige confirmação no navegador;
  é assim que o OAuth funciona, não dá para simular isso com segurança.
- **Senhas de aplicação** (`Set-DevSecret`) — você decide quando quer
  digitá-las; não faria sentido o instalador "adivinhar" sua senha do
  QuestDB.

### Como conseguir o `.exe`

**Opção A — o robô gera para você (GitHub Actions, recomendado):**
depois que você subir este repositório para o GitHub (seção 11), o
workflow `.github/workflows/build-installer.yml` compila o instalador
sozinho a cada `git push` na branch `main`, rodando num servidor Windows
do próprio GitHub — você não roda nada localmente. O `.exe` fica sempre
disponível no mesmo link:

```
https://github.com/SEU_USUARIO/dev-os-dotfiles/releases/download/latest/DevOS-Setup.exe
```

(Ou pela aba **Releases** do repositório, ou em **Actions → última
execução → Artifacts**.)

**Opção B — gerar localmente, na hora, sem depender do GitHub:**

```powershell
cd C:\SOUFUI
.\gerar-instalador.ps1
```

Isso instala o módulo `ps2exe` (uma vez só) e compila
`instalador\DevOS-Setup.exe` em segundos. Útil se você quer testar antes
de subir para o GitHub, ou gerar um instalador "offline" para levar num
pendrive.

> Os dois métodos usam exatamente o mesmo script (`instalador/DevOS-Setup-Launcher.ps1`)
> — a única diferença é *onde* o `.exe` é compilado.

### Importante: o `.exe` é pequeno de propósito

Ele **não** embute os 15-20 GB de programas dentro de si — isso ficaria
gigante e desatualizado rapidamente. O `.exe` é só um "lançador" (poucos
KB) que baixa o repositório e deixa o `winget`/os downloads oficiais
fazerem o trabalho pesado em tempo real, sempre pegando a versão mais
recente de cada programa.

---

## 4. Passo a passo manual (auditável)

Prefere rodar comando por comando para ver exatamente o que acontece?
Este caminho é equivalente ao `.exe`, só que você conduz cada etapa.

### 4.1. Suba este repositório para o GitHub (privado)

No seu computador atual (onde este material foi gerado) ou depois de
extrair o `.zip` recebido:

```powershell
cd caminho\para\dev-os-dotfiles
git init
git add .
git commit -m "Setup inicial da Development OS"
git branch -M main
git remote add origin git@github.com:SEU_USUARIO/dev-os-dotfiles.git
git push -u origin main
```

> Crie o repositório como **privado** no GitHub antes do `git push`
> (Settings → New repository → Private). Como o `.gitignore` já bloqueia
> segredos, mesmo assim mantenha-o privado: o conteúdo revela quais
> ferramentas/servidores você usa.

### 4.2. Rode o bootstrap na máquina Windows nova

Abra o **PowerShell como Administrador** e rode:

```powershell
irm https://raw.githubusercontent.com/SEU_USUARIO/dev-os-dotfiles/main/bootstrap.ps1 | iex
```

Isso vai pedir a URL do repositório na primeira vez (ou edite a linha
abaixo com a URL direto):

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/SEU_USUARIO/dev-os-dotfiles/main/bootstrap.ps1))) -RepoUrl 'git@github.com:SEU_USUARIO/dev-os-dotfiles.git'
```

Ou, se preferir baixar manualmente antes (mais fácil de auditar o que vai
rodar — recomendado da primeira vez):

```powershell
git clone git@github.com:SEU_USUARIO/dev-os-dotfiles.git C:\SOUFUI
cd C:\SOUFUI
.\bootstrap.ps1
```

O `bootstrap.ps1` sempre usa `C:\SOUFUI` como destino por padrão (é a
pasta fixa decidida para este projeto — ver tabela da seção 1).

### 4.3. Antes de rodar de verdade: ajuste o `config.psd1`

Abra `config.psd1` e preencha ao menos:

```powershell
Identidade = @{
    NomeCompleto  = 'Seu Nome'
    Email         = 'voce@exemplo.com'
    UsuarioGitHub = 'seu-usuario'
    RepoDotfiles  = 'git@github.com:seu-usuario/dev-os-dotfiles.git'
}
```

Deixe os módulos que não quer rodar agora como `$false` em `Modulos`, e
ajuste `DebloatNivel` (`'Leve'` ou `'Forte'`) se quiser — ver seção 7.

### 4.4. Rode o instalador

```powershell
cd C:\SOUFUI
.\install.ps1
```

Acompanhe o progresso no terminal (colorido por nível: verde = ok,
amarelo = aviso, vermelho = erro). Ao final, o `install_report.md` é
gerado automaticamente — ver [seção 13](#13-relatório-final-install_reportmd).

**Depois que terminar, feche e abra um novo terminal** para garantir que
todas as variáveis de PATH/ambiente novas sejam carregadas.

---

## 5. Estrutura do repositório

```
dev-os-dotfiles/
├── bootstrap.ps1                 # ponto de entrada do modo manual (rodar 1x numa máquina nova)
├── install.ps1                   # orquestrador principal (idempotente)
├── gerar-instalador.ps1          # compila instalador/DevOS-Setup.exe localmente
├── config.psd1                   # liga/desliga módulos, identidade, workloads, nível de debloat
├── .gitignore                    # bloqueia segredos, builds, node_modules, o .exe compilado etc.
├── .env.example                  # modelo de variáveis (sem valores reais)
├── LICENSE
├── instalador/
│   └── DevOS-Setup-Launcher.ps1  # script-fonte do instalador .exe (autocontido)
├── .github/workflows/
│   ├── lint.yml                  # valida a sintaxe de todos os .ps1/.psm1/.psd1 a cada push
│   └── build-installer.yml       # compila e publica DevOS-Setup.exe a cada push em main
├── lib/
│   └── Common.psm1               # logging, instalação via winget/choco, cofre de segredos
├── modules/
│   ├── 00-prereqs.ps1            # winget, Chocolatey, pastas de trabalho, Modo Dev
│   ├── 09-debloat-windows.ps1    # remove bloatware do Windows (roda logo após 00-prereqs)
│   ├── 01-languages.ps1          # Python, R, Java, C#, Node, C/C++, Rust
│   ├── 02-mobile-desktop.ps1     # Visual Studio, Android Studio, Flutter, .NET MAUI
│   ├── 03-databases.ps1          # DuckDB, QuestDB (ODBC/JDBC), DBeaver, Docker context
│   ├── 04-rpa-automation.ps1     # PyAutoGUI, Tesseract OCR, AutoHotkey, Power Automate
│   ├── 05-architecture-tools.ps1 # draw.io, PlantUML/Graphviz, Postman, Insomnia
│   ├── 06-git-github-credentials.ps1  # Git, gh, SSH, cofre de segredos
│   ├── 07-misc-apps.ps1          # Chrome, Claude, 7-Zip, AnyDesk, K-Lite, Power BI, Zoom, VS Code, ffmpeg
│   ├── 08-dotfiles-apply.ps1     # symlinks do perfil PowerShell e VS Code + extensões
│   └── 99-report.ps1             # gera reports/install_report.md
├── dotfiles/
│   ├── powershell/Microsoft.PowerShell_profile.ps1
│   ├── git/.gitconfig-aliases
│   ├── vscode/{settings.json, keybindings.json, extensions.txt}
│   └── windows-terminal/settings.snippet.json
├── secrets/
│   └── README.md                 # explica o fluxo de credenciais (nenhum segredo aqui dentro)
└── reports/
    └── install_report.md         # gerado a cada execução (ignorado pelo git)
```

> Nota sobre a numeração de `modules/`: o arquivo `09-debloat-windows.ps1`
> roda logo depois de `00-prereqs.ps1` na prática — a ORDEM real de
> execução é definida pela lista `$definicaoModulos` dentro de
> `install.ps1`, não pelo número no nome do arquivo (o "09" ficou assim
> só para não precisar renumerar todos os módulos já existentes).

Toda a árvore acima fica dentro de `C:\SOUFUI` depois do primeiro clone.

---

## 6. O que cada módulo instala

### 6.1. `01-languages.ps1` — Linguagens e compiladores

| Linguagem | Gerenciador de versão | Observações |
|---|---|---|
| Python | [pyenv-win](https://github.com/pyenv-win/pyenv-win) | Instala Python 3.13 e define como global; `pipx` para CLIs isoladas |
| R | [rig](https://github.com/r-lib/rig) (mantido pela Posit) | Instala a versão "release" mais recente |
| Java | Eclipse Temurin (Adoptium) | Duas LTS lado a lado (21 e 17); troque com `Set-JavaVersion 17` no terminal |
| C# / .NET | .NET SDK oficial | Múltiplas versões convivem nativamente (side-by-side); use `dotnet new globaljson` por projeto |
| Node.js / JavaScript | [fnm](https://github.com/Schniz/fnm) | Instala a LTS mais recente; `corepack` habilita pnpm/yarn sob demanda |
| C/C++ | MSYS2 (GCC/Clang) + MSVC (via módulo 02) | + CMake, Ninja e vcpkg (gerenciador de pacotes C++ da Microsoft) |
| Rust | [rustup](https://rustup.rs/) | Toolchain `stable-msvc`; depende do MSVC Build Tools do módulo 02 |

**Por que gerenciadores de versão em vez de instalar direto?** Projetos
diferentes usam versões diferentes. `pyenv`, `rig`, `fnm` e `rustup`
deixam trocar de versão por projeto sem reinstalar nada — só o Java usa
uma abordagem mais simples (duas versões fixas lado a lado) porque no
Windows os gerenciadores de versão de Java mais populares (`jabba`, por
exemplo) têm histórico de manutenção instável; a função `Set-JavaVersion`
do perfil do PowerShell resolve isso de forma direta e sob seu controle.

### 6.2. `02-mobile-desktop.ps1` — Mobile e Desktop

- **Visual Studio Community 2022** completo, com os workloads: C++
  Desktop, .NET Desktop, .NET MAUI (multiplataforma) e UWP/WinUI.
- **Android Studio** + Android SDK (`platform-tools`, `build-tools`,
  emulador, imagem de sistema Android 14).
- **Flutter SDK**, já apontado para o Android SDK instalado.
- **React Native**: não instalamos um CLI global de propósito — a prática
  atual é `npx @react-native-community/cli init MeuApp`, que sempre usa a
  versão mais recente sem exigir atualização manual.
- **.NET MAUI**: workload instalado via `dotnet workload install maui`.

Cobertura de desktop multiplataforma: Windows nativamente (.NET/WPF/WinUI
ou Electron), Linux testável via WSL2 (sem precisar de Docker), macOS com
a mesma limitação do iOS (ver seção 10).

### 6.3. `03-databases.ps1` — Bancos de dados

Ver [seção 9](#9-banco-de-dados-questdb-e-duckdb-remotos--docker) —
seção dedicada, por ser o ponto mais técnico do pedido.

### 6.4. `04-rpa-automation.ps1` — Automação de GUI / RPA

- **PyAutoGUI** + Pillow + OpenCV (reconhecimento de imagem na tela) +
  pygetwindow + pyperclip + `keyboard`/`mouse` (hooks globais).
- **Tesseract OCR** (reconhecimento de texto na tela, via `pytesseract`).
- **AutoHotkey** (scripts `.ahk` leves e nativos do Windows).
- **Power Automate Desktop** (RPA visual, sem código, gratuito da
  Microsoft).

### 6.5. `05-architecture-tools.ps1` — Arquitetura e engenharia

- **draw.io Desktop** + extensão de VS Code que edita `.drawio` sem sair
  do editor.
- **Graphviz** + extensão PlantUML do VS Code (diagramas como código,
  versionáveis em texto).
- **Postman** e **Insomnia** (clientes de teste de API).

### 6.6. `06-git-github-credentials.ps1` — Git, GitHub e credenciais

Ver [seção 8](#8-credenciais-senhas-chaves-e-tokens).

### 6.7. `07-misc-apps.ps1` — Programas diversos

| Programa | Winget ID |
|---|---|
| Google Chrome | `Google.Chrome` |
| Claude (app desktop) | `Anthropic.Claude` |
| 7-Zip | `7zip.7zip` |
| AnyDesk | `AnyDesk.AnyDesk` |
| K-Lite Codec Pack (Mega) | `CodecGuide.K-LiteCodecPack.Mega` |
| Zoom | `Zoom.Zoom` |
| Visual Studio Code | `Microsoft.VisualStudioCode` |
| ffmpeg | `Gyan.FFmpeg` |
| Power BI Desktop | ver abaixo (tratamento especial) |

**Power BI Desktop tem um tratamento especial em cascata** porque o
pacote `Microsoft.PowerBI` no winget tem um bug conhecido e recorrente
("Installer hash does not match" — o mesmo problema que você relatou ter
enfrentado antes). O módulo tenta, em ordem: (1) Microsoft Store via
`winget --source msstore`, que não sofre desse bug; (2) o winget
tradicional; (3) se as duas falharem, o script avisa e mostra o link
oficial (<https://www.microsoft.com/pt-br/download/details.aspx?id=58494>)
para baixar manualmente.

### 6.8. `08-dotfiles-apply.ps1` — Aplicação de configurações

Cria links simbólicos (`New-Item -ItemType SymbolicLink`) entre os
arquivos versionados em `dotfiles/` e os locais reais que o Windows/VS
Code esperam. Depois disso, **editar a configuração no programa edita o
arquivo do repositório automaticamente** — é só rodar `git status` de
vez em quando para ver o que mudou e dar commit.

---

## 7. Limpeza de bloatware do Windows

Módulo `09-debloat-windows.ps1`, habilitado por padrão
(`config.psd1 → Modulos.DebloatWindows = $true`), com dois níveis
controlados por `config.psd1 → DebloatNivel`:

### Nível `'Leve'` (padrão)

Remove só pacotes **AppX de consumo/jogos** — baixo risco, não mexe em
serviços nem no registro:

Xbox App/Overlay/Identity Provider, Coleção Solitaire, Candy Crush,
Skype, Mixed Reality Portal, 3D Viewer, Cortana, Groove Music, Filmes e
TV, Feedback Hub, Bing News/Weather/Search, Clipchamp, Teams (versão
consumer), Office Hub, "Introdução", Obter Ajuda, People, To Do.

### Nível `'Forte'`

Tudo do nível Leve, **mais**:

- Desativa o serviço `DiagTrack` (telemetria).
- Desativa tarefas agendadas de coleta de dados/compatibilidade.
- Desativa Widgets, Copilot e as sugestões/anúncios do menu Iniciar e
  tela de bloqueio.

Para ativar: edite `config.psd1`:

```powershell
DebloatNivel = 'Forte'
```

e rode `.\install.ps1 -Somente DebloatWindows` de novo.

### O que NUNCA é removido, em nenhum nível

Terminal, Notepad, Calculadora, Paint, Snipping Tool (`ScreenSketch`),
Câmera, Fotos, Microsoft Store, Edge, .NET/VCLibs/UI.Xaml (dependências
de outros apps), e o **Power Automate Desktop** que o módulo 4 instala de
propósito (ele existe numa lista separada só para documentar, no código,
que não deve ser confundido com bloatware).

### Rede de segurança

Antes de qualquer remoção, o módulo cria um **Ponto de Restauração do
Sistema** (`Checkpoint-Computer`) — se algo parecer errado depois, use
"Restaurar Sistema" (pesquise por esse nome no menu Iniciar) para
reverter. Cada remoção roda isolada em `try/catch`: se um pacote não
existir nesta edição/versão do Windows, o script só pula para o próximo,
sem travar a instalação.

---

## 8. Credenciais, senhas, chaves e tokens

Resumo rápido (detalhes completos em [`secrets/README.md`](secrets/README.md)):

1. **Login do Git/GitHub** → Git Credential Manager (já vem com o Git
   para Windows), que guarda o token no **Windows Credential Manager**
   depois do primeiro `git push`/`gh auth login`.
2. **Chave SSH** → gerada localmente (`id_ed25519`), nunca versionada; só
   a chave pública é compartilhada (com o GitHub).
3. **Segredos de aplicação** (senha do QuestDB, tokens de API, etc.) →
   cofre local `Microsoft.PowerShell.SecretStore`, com duas funções
   prontas no seu perfil do PowerShell:

   ```powershell
   Set-DevSecret -Nome 'QUESTDB_PASSWORD'      # grava (pede o valor de forma oculta)
   $senha = Get-DevSecret -Nome 'QUESTDB_PASSWORD'   # lê, em memória, na hora de usar
   ```

Em nenhum momento uma senha, chave privada ou token aparece em texto
dentro de um arquivo versionado — o `.gitignore` bloqueia os padrões mais
comuns como uma segunda camada de proteção, mas a garantia real é
arquitetural: os scripts nunca escrevem segredo em disco fora do cofre
criptografado do Windows.

---

## 9. Banco de dados: QuestDB e DuckDB remotos + Docker

### QuestDB

QuestDB fala o **protocolo de rede do PostgreSQL** ("PGWire") na porta
`8812` — por isso não existe (nem é necessário) um driver JDBC/ODBC
exclusivo do QuestDB: usamos os drivers **oficiais do PostgreSQL**,
apontados para o host do QuestDB.

- Driver **JDBC**: `org.postgresql:postgresql` (baixado automaticamente
  para `C:\Dev\sdks\jdbc-drivers\`).
  Connection string: `jdbc:postgresql://<host>:8812/qdb` (usuário/senha
  padrão de fábrica: `admin`/`quest` — troque isso e guarde a senha real
  com `Set-DevSecret -Nome 'QUESTDB_PASSWORD'`).
- Driver **ODBC**: `psqlODBC` (instalado via winget), configurável em
  "Gerenciador de Fontes de Dados ODBC" (`odbcad32.exe`) com
  `Server=<host>`, `Port=8812`, `Database=qdb`.
- Console Web / REST, sem driver nenhum: `http://<host>:9000`.
- Cliente gráfico universal: **DBeaver** (já instalado), que fala JDBC
  nativamente — basta criar uma conexão PostgreSQL apontando pro host e
  porta 8812.

### DuckDB

- **CLI** oficial (`duckdb.exe`) instalado via winget.
- Driver **ODBC** oficial baixado automaticamente da última release em
  <https://github.com/duckdb/duckdb-odbc/releases> e registrado via
  `odbc_install.exe`. Cria um DSN padrão chamado "DuckDB".
- Driver **JDBC** oficial (`duckdb_jdbc-*.jar`) baixado automaticamente
  do Maven Central para `C:\Dev\sdks\jdbc-drivers\` — aponte o DBeaver ou
  sua IDE para esse `.jar`.

### Docker (sem instalar Docker Desktop/Engine nesta máquina)

Só o **Docker CLI** é instalado localmente. Ele conversa com um Docker
Engine remoto através de um `docker context`. Como você ainda não definiu
onde vai rodar esse host remoto, o script deixa tudo pronto e pausado:

1. Quando tiver o servidor (outra máquina, VM ou instância cloud), edite
   `config.psd1`:

   ```powershell
   DockerContextRemoto = 'ssh://usuario@ip-do-servidor'
   # ou, com TCP + TLS:
   # DockerContextRemoto = 'tcp://meu-servidor.exemplo.com:2376'
   ```

2. Rode de novo só o módulo de bancos de dados:

   ```powershell
   .\install.ps1 -Somente BancoDeDados
   ```

3. O módulo cria o contexto (`docker context create servidor-remoto ...`)
   e já troca para ele. A partir daí, `docker ps`, `docker run` etc.
   funcionam normalmente, só que tudo roda **no servidor remoto**, não
   nesta máquina.

Se a opção `ssh://` for usada, a autenticação é a mesma chave SSH já
configurada no módulo 06 (ou uma chave dedicada, se preferir isolar).

---

## 10. Mobile/Desktop: cobertura e limitações (iOS)

O Windows **não compila nem empacota apps iOS** — isso é uma restrição da
própria Apple (exige Xcode rodando em macOS), não uma limitação deste
script. Como você indicou não ter um Mac disponível agora, o iOS foi
deliberadamente deixado de fora desta rodada.

O ambiente Flutter/React Native instalado já cobre 100% do fluxo Android
(código, testes, build, emulador). Quando fizer sentido adicionar iOS,
duas opções — nenhuma delas exige reinstalar nada aqui:

- **Expo EAS Build** (para projetos React Native/Expo): builda o `.ipa`
  na nuvem, sem precisar de Mac.
- **Codemagic** (para Flutter ou React Native puro): CI/CD com runners
  macOS na nuvem, builda e até publica na App Store.

Se no futuro você conseguir acesso a um Mac (físico, VM ou serviço como
MacStadium), me avise — dá pra adicionar um módulo que configura o VS
Code Remote-SSH apontando para ele.

---

## 11. Publicando no GitHub (repositório privado)

Já coberto no [passo 4.1](#41-suba-este-repositório-para-o-github-privado).
Resumo dos comandos essenciais depois da primeira vez:

```powershell
git add .
git commit -m "Descreva o que mudou"
git push
```

Assim que o `push` chegar no GitHub, o workflow `build-installer.yml` já
recompila o `DevOS-Setup.exe` sozinho (ver seção 3).

Para trazer as configurações mais recentes para outra máquina (ou depois
de reinstalar o Windows), o jeito mais simples é baixar o `.exe` mais
recente em Releases e dar duplo clique — ou, no modo manual:

```powershell
irm https://raw.githubusercontent.com/SEU_USUARIO/dev-os-dotfiles/main/bootstrap.ps1 | iex
```

---

## 12. Uso do dia a dia

```powershell
# Rodar tudo de novo (idempotente — só instala o que falta)
.\install.ps1

# Rodar só um módulo específico
.\install.ps1 -Somente Linguagens
.\install.ps1 -Somente BancoDeDados,ProgramasDiversos

# Pular um ou mais módulos
.\install.ps1 -Pular AutomacaoGui,DebloatWindows

# Simular sem alterar nada (dry run)
.\install.ps1 -SimulacaoSemAlterar
```

Aliases úteis já disponíveis em qualquer terminal (definidos no perfil do
PowerShell, `dotfiles/powershell/Microsoft.PowerShell_profile.ps1`):

| Comando | Ação |
|---|---|
| `devhome` | vai para `C:\Dev` |
| `gs`, `ga`, `gc`, `gp`, `gl`, `gco` | atalhos de Git (status, add, commit, push, log, checkout) |
| `ghpr` | abre um Pull Request preenchido automaticamente (`gh pr create --fill`) |
| `Set-JavaVersion 17` | troca a versão ativa do Java |
| `Set-DevSecret -Nome X` / `Get-DevSecret -Nome X` | grava/lê um segredo no cofre local |

---

## 13. Relatório final (`install_report.md`)

Toda execução do `install.ps1` (com o módulo `RelatorioFinal` habilitado,
que é o padrão) gera `reports/install_report.md` — e uma cópia em
`%USERPROFILE%\install_report.md` para acesso rápido — contendo:

- Todos os programas processados naquela execução;
- A **versão instalada** de cada um (consultada automaticamente via
  `winget list`, ou via `--version`/`-v` para o que foi instalado por
  fora do winget, como `pyenv`, `rig`, `fnm`);
- A **categoria** (a qual módulo pertence);
- O **status** (instalado, já instalado, ou falhou — com log detalhado
  em `reports/install-<data>.log`);
- A **URL oficial** de download/repositório de cada ferramenta.

Itens marcados `N/D` na coluna de versão são aqueles sem um comando de
versão padronizado (ex: uma chave SSH gerada, ou um contexto Docker
configurado) — não é um erro, apenas não há "versão" para reportar.

---

## 14. Solução de problemas comuns

**"Não é possível carregar o arquivo ... porque a execução de scripts foi
desabilitada"** — o `bootstrap.ps1` já ajusta a política de execução para
`RemoteSigned` no escopo do usuário atual, mas se você rodar um módulo
avulso e ver esse erro, rode primeiro:
`Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`.

**Power BI Desktop falha com "Installer hash does not match"** — o
módulo 07 já tenta contornar isso automaticamente via Microsoft Store;
se mesmo assim falhar, baixe manualmente em
<https://www.microsoft.com/pt-br/download/details.aspx?id=58494> ou pela
Microsoft Store diretamente.

**Um `winget install` falha com "No package found matching input criteria"**
— os IDs de pacote do winget mudam de tempos em tempos. Rode
`winget search "<nome do programa>"` para achar o ID atualizado e ajuste
o módulo correspondente (uma linha `Install-WingetApp -Id '...'`).

**`code`, `git`, `python` etc. "não reconhecido como comando"
logo após instalar** — normal: o PATH só é recarregado em um terminal
novo. Feche e abra o PowerShell (ou reinicie) e rode `.\install.ps1` de
novo se precisar completar alguma etapa que dependia daquele comando.

**Criar o symlink dos dotfiles falha com "Você não tem privilégio
suficiente"** — o módulo `00-prereqs.ps1` habilita o "Modo Desenvolvedor"
do Windows para liberar `New-Item -ItemType SymbolicLink` sem precisar de
admin a cada chamada; se ainda assim falhar, ative manualmente em
Configurações → Privacidade e segurança → Para desenvolvedores, e rode o
módulo 08 de novo.

**Algo pareceu quebrar depois da limpeza de bloatware (seção 7)** —
pesquise "Restaurar Sistema" no menu Iniciar e volte para o ponto de
restauração criado automaticamente antes do módulo `09-debloat-windows.ps1`
rodar. Depois, rode `.\install.ps1 -Pular DebloatWindows` para pular essa
etapa nas próximas execuções.

**`gerar-instalador.ps1` falha ao instalar o módulo `ps2exe`** —
normalmente é falta de acesso ao PowerShell Gallery (rede corporativa
restrita, por exemplo). Nesse caso, use a Opção A da seção 3 (GitHub
Actions gera o `.exe` para você, sem precisar do PowerShell Gallery
nesta máquina).

---

## 15. Como estender

Para adicionar um novo programa a um módulo existente, adicione uma linha
assim dentro do arquivo em `modules/`:

```powershell
$resultados += Install-WingetApp -Id 'Publicador.Programa' -Nome 'Nome Amigável' -Origem 'https://site-oficial.com/'
```

Para adicionar um **módulo novo inteiro** (ex: um dia adicionar suporte a
iOS com Mac remoto):

1. Crie `modules/NN-nome-do-modulo.ps1` seguindo o mesmo formato dos
   demais (`param($Config, $RaizRepo)`, importar `Common.psm1`, retornar
   `$resultados`).
2. Adicione uma chave nova em `config.psd1` → `Modulos`.
3. Adicione uma linha em `install.ps1` → `$definicaoModulos`, na posição
   em que ele deve rodar.

O `99-report.ps1` já pega automaticamente qualquer resultado retornado
por um módulo novo, sem precisar editar nada nele. Se o módulo novo
mexer em `instalador/` ou nos scripts principais, o `build-installer.yml`
já recompila o `.exe` sozinho no próximo push (ver os `paths:` no início
daquele workflow, ajuste se necessário).
