@{
    # ------------------------------------------------------------------
    # config.psd1
    # Arquivo central de configuracao do dev-os-dotfiles.
    # Ligue/desligue modulos e ajuste parametros sem tocar no codigo dos scripts.
    # ------------------------------------------------------------------

    # Dados usados no Git e nos commits (ajuste antes de rodar o install.ps1)
    Identidade = @{
        NomeCompleto   = 'Gilberto'
        Email          = 'contato@sofui.com.br'
        UsuarioGitHub  = ''   # ex: 'gilberto-dev' -- preencha com seu usuario do GitHub
        RepoDotfiles   = ''   # ex: 'git@github.com:gilberto-dev/dev-os-dotfiles.git' (privado)
    }

    # Pasta FIXA onde este repositorio vive no disco (decisao do projeto: C:\SOUFUI,
    # nao dentro do perfil do usuario). bootstrap.ps1 e o instalador .exe (instalador/)
    # ja usam este caminho por padrao — mantido aqui apenas como referencia central.
    PastaLocalRepo = 'C:\SOUFUI'

    # Liga (1) ou desliga (0) cada modulo de instalacao
    Modulos = @{
        Prereqs             = $true   # winget, Chocolatey (fallback), pastas base
        DebloatWindows      = $true   # remove apps de consumo/jogos (ver DebloatNivel abaixo)
        Linguagens          = $true   # Python, R, Java, C#, Node, C/C++, Rust
        MobileDesktop       = $true   # Android Studio, Flutter, .NET MAUI, Visual Studio
        BancoDeDados        = $true   # DuckDB, QuestDB (drivers), DBeaver, contexto Docker remoto
        AutomacaoGui        = $true   # PyAutoGUI e ferramentas de RPA
        Arquitetura         = $true   # draw.io, PlantUML, Postman/Insomnia
        GitGithubCredenciais = $true  # Git, gh, SSH, cofre de segredos
        ProgramasDiversos   = $true   # Chrome, Claude, 7z, AnyDesk, K-Lite, Power BI, Zoom, VSCode, ffmpeg
        AplicarDotfiles     = $true   # perfil PowerShell, settings/extensoes do VS Code, symlinks
        RelatorioFinal      = $true   # gera reports/install_report.md (sempre recomendado)
    }

    # Escolhas feitas durante o planejamento (documentadas aqui para referencia futura)
    Decisoes = @{
        GerenciadorDePacotes   = 'winget (nativo do Windows) com Chocolatey como fallback opcional'
        GerenciadorCredenciais = 'Windows Credential Manager + Git Credential Manager + PowerShell SecretStore'
        AcessoDocker           = 'Somente Docker CLI local; conecta em host remoto via "docker context" (endereco a definir)'
        DesenvolvimentoIOS     = 'Nao configurado agora (sem Mac disponivel). Estrutura cross-platform pronta para adicionar depois via Expo EAS/Codemagic.'
        IdeCppDotnet           = 'Visual Studio Community 2022 completo'
    }

    # Endereco do host Docker remoto (preencha quando tiver um servidor definido).
    # Exemplos validos:
    #   'ssh://usuario@192.168.1.50'
    #   'tcp://meu-servidor.exemplo.com:2376'
    DockerContextRemoto = ''

    # Workloads do Visual Studio 2022 Community a instalar (ver modules/02-mobile-desktop.ps1)
    VisualStudioWorkloads = @(
        'Microsoft.VisualStudio.Workload.NativeDesktop'      # C++ desktop
        'Microsoft.VisualStudio.Workload.ManagedDesktop'      # .NET desktop (WinForms/WPF)
        'Microsoft.VisualStudio.Workload.NetCrossPlat'        # .NET MAUI / multiplataforma
        'Microsoft.VisualStudio.Workload.Universal'           # UWP/WinUI
    )

    # Versoes de JDK instaladas lado a lado (Eclipse Temurin)
    VersoesJava = @('21', '17')

    # Pasta raiz de trabalho para projetos e SDKs
    PastaDevHome = 'C:\Dev'

    # Nivel de limpeza do Windows aplicado pelo modulo 09-debloat-windows.ps1:
    #   'Leve'  -> so remove apps de consumo/jogos (Xbox extra, Candy Crush, Skype,
    #              Bing News/Weather, Cortana, etc.). Baixo risco.
    #   'Forte' -> alem do Leve, desativa telemetria (DiagTrack), tarefas agendadas
    #              de coleta de dados, Widgets, Copilot e sugestoes/anuncios do
    #              menu Iniciar. Um Ponto de Restauracao e criado antes de tudo.
    DebloatNivel = 'Leve'
}
