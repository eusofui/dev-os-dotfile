#Requires -Version 5.1
<#
    03-databases.ps1
    ------------------------------------------------------------------
    Acesso a bancos de dados QuestDB e DuckDB (REMOTAMENTE), mais um
    cliente universal (DBeaver) e o CLI do Docker configurado para
    apontar para um host remoto — SEM instalar Docker Desktop/Engine
    nesta maquina.

    QuestDB fala o protocolo de rede do PostgreSQL ("PGWire") na porta
    8812 — por isso os drivers usados sao o PostgreSQL JDBC e o psqlODBC
    oficiais, apontando para o host/porta do QuestDB.

    DuckDB tem driver ODBC e JDBC proprios, baixados diretamente dos
    releases oficiais no GitHub.
    ------------------------------------------------------------------
#>
param(
    [Parameter(Mandatory = $true)]$Config,
    [Parameter(Mandatory = $true)][string]$RaizRepo
)

Import-Module (Join-Path $RaizRepo 'lib\Common.psm1') -Force
$resultados = @()
$pastaJdbc = Join-Path $Config.PastaDevHome 'sdks\jdbc-drivers'
$pastaOdbc = Join-Path $Config.PastaDevHome 'sdks\odbc-drivers'

# ============================================================================
# CLIENTE UNIVERSAL — DBeaver Community (JDBC: QuestDB via PGWire + DuckDB)
# ============================================================================
Write-Log 'DBeaver Community (cliente universal SQL)' -Nivel PASSO
$resultados += Install-WingetApp -Id 'dbeaver.dbeaver' -Nome 'DBeaver Community' -Origem 'https://dbeaver.io/'

# ============================================================================
# DUCKDB — CLI + driver ODBC + driver JDBC (oficiais)
# ============================================================================
Write-Log 'DuckDB — CLI, ODBC e JDBC' -Nivel PASSO
$resultados += Install-WingetApp -Id 'DuckDB.cli' -Nome 'DuckDB CLI' -Origem 'https://duckdb.org/'

# --- Driver ODBC oficial (baixado do GitHub Releases, instalado silenciosamente) ---
try {
    Write-Log 'Baixando o driver ODBC oficial do DuckDB...' -Nivel INFO
    $releaseInfo = Invoke-RestMethod -Uri 'https://api.github.com/repos/duckdb/duckdb-odbc/releases/latest'
    $asset = $releaseInfo.assets | Where-Object { $_.name -like '*windows-amd64.zip' } | Select-Object -First 1

    if ($asset) {
        $zipDestino = Join-Path $env:TEMP 'duckdb_odbc.zip'
        $pastaExtracao = Join-Path $pastaOdbc 'duckdb'
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipDestino -UseBasicParsing
        Expand-Archive -Path $zipDestino -DestinationPath $pastaExtracao -Force
        Start-Process -FilePath (Join-Path $pastaExtracao 'odbc_install.exe') -Wait -NoNewWindow
        $resultados += [PSCustomObject]@{ Nome = "DuckDB ODBC Driver ($($releaseInfo.tag_name))"; Status = 'Instalado'; Origem = 'https://github.com/duckdb/duckdb-odbc' }
        Write-Log 'Driver ODBC do DuckDB instalado e registrado (DSN padrao "DuckDB" criado).' -Nivel OK
    }
    else {
        Write-Log 'Nao encontrei o asset "windows-amd64.zip" na ultima release do duckdb-odbc. Baixe manualmente em https://github.com/duckdb/duckdb-odbc/releases' -Nivel AVISO
    }
}
catch {
    Write-Log "Falha ao instalar o driver ODBC do DuckDB: $($_.Exception.Message)" -Nivel AVISO
}

# --- Driver JDBC oficial (jar baixado do Maven Central) ---
try {
    Write-Log 'Baixando o driver JDBC oficial do DuckDB (Maven Central)...' -Nivel INFO
    $metadadosMaven = Invoke-RestMethod -Uri 'https://search.maven.org/solrsearch/select?q=g:org.duckdb+AND+a:duckdb_jdbc&rows=1&wt=json'
    $versaoJdbc = $metadadosMaven.response.docs[0].latestVersion
    $urlJar = "https://repo1.maven.org/maven2/org/duckdb/duckdb_jdbc/$versaoJdbc/duckdb_jdbc-$versaoJdbc.jar"
    $destinoJar = Join-Path $pastaJdbc "duckdb_jdbc-$versaoJdbc.jar"
    Invoke-WebRequest -Uri $urlJar -OutFile $destinoJar -UseBasicParsing
    $resultados += [PSCustomObject]@{ Nome = "DuckDB JDBC Driver ($versaoJdbc)"; Status = 'Instalado'; Origem = 'https://mvnrepository.com/artifact/org.duckdb/duckdb_jdbc' }
    Write-Log "Driver JDBC do DuckDB salvo em: $destinoJar (aponte o DBeaver/sua IDE para este .jar)" -Nivel OK
}
catch {
    Write-Log "Falha ao baixar o driver JDBC do DuckDB: $($_.Exception.Message)" -Nivel AVISO
}

# ============================================================================
# QUESTDB — acesso remoto via protocolo PostgreSQL (PGWire, porta 8812)
# ============================================================================
Write-Log 'QuestDB — drivers de acesso remoto (PGWire)' -Nivel PASSO

# --- Driver JDBC: PostgreSQL JDBC oficial (pgJDBC) — QuestDB fala PGWire ---
try {
    Write-Log 'Baixando o driver JDBC do PostgreSQL (usado para falar com o QuestDB via PGWire, porta 8812)...' -Nivel INFO
    $metadadosPg = Invoke-RestMethod -Uri 'https://search.maven.org/solrsearch/select?q=g:org.postgresql+AND+a:postgresql&rows=1&wt=json'
    $versaoPg = $metadadosPg.response.docs[0].latestVersion
    $urlJarPg = "https://repo1.maven.org/maven2/org/postgresql/postgresql/$versaoPg/postgresql-$versaoPg.jar"
    $destinoJarPg = Join-Path $pastaJdbc "postgresql-$versaoPg.jar"
    Invoke-WebRequest -Uri $urlJarPg -OutFile $destinoJarPg -UseBasicParsing
    $resultados += [PSCustomObject]@{ Nome = "PostgreSQL JDBC Driver ($versaoPg) — usado para QuestDB"; Status = 'Instalado'; Origem = 'https://jdbc.postgresql.org/' }
    Write-Log "Driver JDBC salvo em: $destinoJarPg" -Nivel OK
    Write-Log 'String de conexao QuestDB (padrao de fabrica): jdbc:postgresql://<host>:8812/qdb  |  usuario: admin  |  senha: guarde no cofre local (ver modulo 06)' -Nivel INFO
}
catch {
    Write-Log "Falha ao baixar o driver JDBC do PostgreSQL: $($_.Exception.Message)" -Nivel AVISO
}

# --- Driver ODBC: psqlODBC oficial (mesma logica: PGWire) ---
$resultados += Install-WingetApp -Id 'PostgreSQL.psqlODBC' -Nome 'psqlODBC (usado para QuestDB via PGWire)' `
    -Origem 'https://odbc.postgresql.org/' -UrlManualFallback 'https://www.postgresql.org/ftp/odbc/versions/msi/'

Write-Log 'Apos instalar o psqlODBC, crie um DSN em "Gerenciador de Fontes de Dados ODBC" (odbcad32.exe) apontando Server=<host>, Port=8812, Database=qdb.' -Nivel INFO
Write-Log 'Console Web / API REST do QuestDB (sem driver nenhum, direto do navegador): http://<host>:9000' -Nivel INFO

# ============================================================================
# DOCKER — SOMENTE o CLI local, apontando para um host remoto (sem Docker
# Desktop/Engine instalado aqui). O host remoto ainda nao foi definido
# (config.psd1 -> DockerContextRemoto), entao o contexto fica pronto como
# template para voce preencher assim que tiver o servidor.
# ============================================================================
Write-Log 'Docker CLI (cliente apenas — sem instalar o Docker Desktop/Engine)' -Nivel PASSO
$resultados += Install-WingetApp -Id 'Docker.DockerCLI' -Nome 'Docker CLI' -Origem 'https://docs.docker.com/engine/reference/commandline/cli/'

if (Test-CommandExists 'docker') {
    if ($Config.DockerContextRemoto) {
        Write-Log "Criando 'docker context' apontando para $($Config.DockerContextRemoto)..." -Nivel INFO
        docker context create servidor-remoto --docker "host=$($Config.DockerContextRemoto)" 2>$null
        docker context use servidor-remoto
        $resultados += [PSCustomObject]@{ Nome = 'Docker context "servidor-remoto"'; Status = 'Configurado'; Origem = 'https://docs.docker.com/engine/context/working-with-contexts/' }
    }
    else {
        Write-Log 'DockerContextRemoto ainda nao foi definido em config.psd1. O Docker CLI foi instalado, mas sem host configurado ainda.' -Nivel AVISO
        Write-Log 'Quando tiver o servidor, rode (exemplo via SSH): docker context create servidor-remoto --docker "host=ssh://usuario@ip-do-servidor"' -Nivel INFO
        Write-Log 'Ou via TCP com TLS: docker context create servidor-remoto --docker "host=tcp://meu-servidor:2376,ca=...,cert=...,key=..."' -Nivel INFO
        $resultados += [PSCustomObject]@{ Nome = 'Docker context remoto'; Status = 'Pendente (definir host em config.psd1)'; Origem = 'https://docs.docker.com/engine/context/working-with-contexts/' }
    }
}

return $resultados
