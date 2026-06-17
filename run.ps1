#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Script moderno de gerenciamento de containers Docker para desenvolvimento
.DESCRIPTION
    Facilita o gerenciamento do ambiente com Docker Compose, incluindo validacoes
    automaticas, mensagens uteis e diagnostico para problemas comuns no Windows/WSL2
.PARAMETER Command
    Comando a executar
.EXAMPLE
    .\run.ps1 up -d
    .\run.ps1 diagnostic
#>

param(
    [Parameter(Position = 0)]
    [string]$Command,
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$CommandArgs
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# ============================================================================
# FUNCOES DE OUTPUT
# ============================================================================

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK]   $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERR]  $Message" -ForegroundColor Red
}

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host $Text -ForegroundColor Cyan
    Write-Host ("=" * $Text.Length) -ForegroundColor Gray
}

# ============================================================================
# VALIDACOES
# ============================================================================

function Test-DockerInstalled {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    return $null -ne $docker
}

function Test-DockerRunning {
    try {
        docker ps 2>&1 | Out-Null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Test-DockerVersion {
    try {
        $version = docker --version 2>&1
        Write-Success "Docker: $version"
        return $true
    }
    catch {
        return $false
    }
}

function Test-ComposeInstalled {
    # Testa docker-compose standalone
    $compose = Get-Command docker-compose -ErrorAction SilentlyContinue
    if ($null -ne $compose) {
        return 'standalone'
    }

    # Testa docker compose integrado
    try {
        docker compose version 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            return 'integrated'
        }
    }
    catch {}

    return $null
}

function Test-EnvFile {
    if (-not (Test-Path -LiteralPath '.env')) {
        Write-Warning ".env nao encontrado"
        if (Test-Path -LiteralPath '.env.example') {
            Write-Info "Criando .env baseado em .env.example..."
            Copy-Item '.env.example' '.env'
            Write-Success ".env criado com sucesso"
            return $true
        }
        Write-Error-Custom "Arquivo .env eh necessario"
        return $false
    }
    return $true
}

function Show-Docker-Diagnostics {
    Write-Header "Diagnostico do Docker"

    # Docker instalado?
    if (Test-DockerInstalled) {
        Write-Success "Docker esta instalado"
    }
    else {
        Write-Error-Custom "Docker NAO esta instalado"
        Write-Host ""
        Write-Host "SOLUCAO:"
        Write-Host "  1. Baixe Docker Desktop: https://www.docker.com/products/docker-desktop"
        Write-Host "  2. Inicie Docker Desktop apos instalacao"
        Write-Host ""
        return $false
    }

    # Docker rodando?
    if (Test-DockerRunning) {
        Write-Success "Docker esta rodando"
    }
    else {
        Write-Error-Custom "Docker NAO esta rodando"
        Write-Host ""
        Write-Host "SOLUCAO:"
        Write-Host "  1. Inicie Docker Desktop (Windows)"
        Write-Host "  2. Aguarde alguns segundos"
        Write-Host "  3. Tente: docker ps"
        Write-Host "  4. Verifique WSL2: wsl --list"
        Write-Host ""
        return $false
    }

    # Versao Docker
    if (-not (Test-DockerVersion)) {
        Write-Error-Custom "Nao foi possivel obter versao do Docker"
        return $false
    }

    # Docker Compose
    $composeType = Test-ComposeInstalled
    if ($composeType -eq 'standalone') {
        Write-Success "Docker Compose (standalone) esta instalado"
    }
    elseif ($composeType -eq 'integrated') {
        Write-Success "Docker Compose (integrado) esta disponivel"
    }
    else {
        Write-Error-Custom "Docker Compose NAO esta disponivel"
        Write-Host ""
        Write-Host "SOLUCAO:"
        Write-Host "  Instale Docker Compose ou use Docker Desktop"
        Write-Host ""
        return $false
    }

    Write-Success "Tudo pronto para usar Docker!"
    return $true
}

# ============================================================================
# CONFIGURACAO
# ============================================================================

function Import-DotEnv {
    param([string]$Path = '.env')

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    Get-Content -LiteralPath $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { return }

        $sep = $line.IndexOf('=')
        if ($sep -lt 1) { return }

        $name = $line.Substring(0, $sep).Trim()
        $value = $line.Substring($sep + 1).Trim()

        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        [Environment]::SetEnvironmentVariable($name, $value, 'Process')
    }
}

function Assert-NativeSuccess {
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

function Invoke-DockerCompose {
    $composeType = Test-ComposeInstalled

    if ($composeType -eq 'standalone') {
        docker-compose @args
        Assert-NativeSuccess
    }
    elseif ($composeType -eq 'integrated') {
        docker compose @args
        Assert-NativeSuccess
    }
    else {
        Write-Error-Custom "Docker Compose nao disponivel"
        exit 1
    }
}

# ============================================================================
# HELP
# ============================================================================

function Show-Usage {
    Write-Header "Comandos Disponveis"

    Write-Host ""
    Write-Host "DOCKER:"
    Write-Host "  up [args]           - Inicia containers"
    Write-Host "  down [args]         - Para containers"
    Write-Host "  ps                  - Lista containers"
    Write-Host ""
    Write-Host "DESENVOLVIMENTO:"
    Write-Host "  composer [args]     - Executa Composer"
    Write-Host "  php:console         - Console PHP interativo"
    Write-Host ""
    Write-Host "TESTES:"
    Write-Host "  test [path]         - PHPUnit"
    Write-Host "  codecept [args]     - Codeception"
    Write-Host "  test:browser [path] - Testes com navegador"
    Write-Host ""
    Write-Host "CODIGO:"
    Write-Host "  phpcs [path]        - Verificar estilo"
    Write-Host "  phpcbf [path]       - Corrigir estilo"
    Write-Host "  phpstan [args]      - Analise estatica"
    Write-Host ""
    Write-Host "NGINX:"
    Write-Host "  nginx:check         - Verificar config"
    Write-Host "  nginx:status        - Status"
    Write-Host "  nginx:reload        - Recarregar"
    Write-Host ""
    Write-Host "BANCO DE DADOS:"
    Write-Host "  db:console          - Console MySQL"
    Write-Host "  db:reset            - Resetar banco"
    Write-Host "  db:populate         - Popular banco"
    Write-Host ""
    Write-Host "UTILITARIOS:"
    Write-Host "  git:clean:branchs   - Limpar branches"
    Write-Host "  diagnostic          - Diagnostico"
    Write-Host "  help                - Ajuda estendida"
    Write-Host ""
}

function Show-Extended-Help {
    Write-Header "Guia Completo"

    Write-Host ""
    Write-Host "PRIMEIROS PASSOS:"
    Write-Host "  1. .\run.ps1 diagnostic         # Verifica pre-requisitos"
    Write-Host "  2. .\run.ps1 up -d              # Inicia containers"
    Write-Host "  3. .\run.ps1 db:populate        # Popular banco"
    Write-Host "  4. .\run.ps1 test               # Executar testes"
    Write-Host ""
    Write-Host "DESENVOLVIMENTO:"
    Write-Host "  .\run.ps1 up                    # Containers com logs"
    Write-Host "  .\run.ps1 composer install      # Instalar dependencias"
    Write-Host "  .\run.ps1 phpcs app/            # Verificar estilo"
    Write-Host ""
    Write-Host "TESTES:"
    Write-Host "  .\run.ps1 test                  # PHPUnit tudo"
    Write-Host "  .\run.ps1 codecept run          # Codeception"
    Write-Host ""
    Write-Host "BANCO DE DADOS:"
    Write-Host "  .\run.ps1 db:console            # Acessar MySQL"
    Write-Host "  .\run.ps1 db:reset              # Resetar schema"
    Write-Host ""
}

# ============================================================================
# MAIN
# ============================================================================

Import-DotEnv

if ([string]::IsNullOrWhiteSpace($Command)) {
    Show-Usage
    exit 0
}

$elapsed = [System.Diagnostics.Stopwatch]::StartNew()

try {
    switch ($Command) {
        # ====== DOCKER COMPOSE ======
        'ps' {
            Invoke-DockerCompose ps
        }

        'up' {
            if (-not (Show-Docker-Diagnostics)) {
                exit 1
            }
            if (-not (Test-EnvFile)) {
                exit 1
            }
            Write-Success "Iniciando containers..."
            Write-Host ""
            Invoke-DockerCompose up @CommandArgs
        }

        'down' {
            Write-Info "Parando containers..."
            Invoke-DockerCompose down @CommandArgs
        }

        # ====== COMPOSER ======
        'composer' {
            if (-not (Show-Docker-Diagnostics)) {
                exit 1
            }
            Write-Info "Executando Composer..."
            docker run --rm --interactive -e COMPOSER_CACHE_DIR='/app/.cache/composer' -v "${PWD}:/app" -w /app composer:2.7.2 composer @CommandArgs
            Assert-NativeSuccess
        }

        # ====== NGINX ======
        'nginx:check' {
            Write-Info "Verificando Nginx..."
            Invoke-DockerCompose exec web nginx -t
        }

        'nginx:status' {
            Write-Info "Status do Nginx..."
            Invoke-DockerCompose exec web service nginx status
        }

        'nginx:reload' {
            Write-Info "Recarregando Nginx..."
            Invoke-DockerCompose exec web nginx -s reload
        }

        # ====== PHP ======
        'php:console' {
            Write-Info "Console PHP interativo..."
            Invoke-DockerCompose exec php php -a
        }

        # ====== TESTES ======
        'test' {
            $testPath = if ($CommandArgs.Count -gt 0) { $CommandArgs } else { @('tests') }
            Write-Info "Executando PHPUnit..."
            Invoke-DockerCompose run --rm php_test ./vendor/bin/phpunit --color=always --testdox @testPath
        }

        'codecept' {
            Write-Info "Executando Codeception..."
            Invoke-DockerCompose run --rm php_test ./vendor/bin/codecept @CommandArgs
        }

        'test:browser' {
            $testPath = if ($CommandArgs.Count -gt 0) { $CommandArgs } else { @('tests/Acceptance') }
            Write-Info "Testes com navegador..."
            Invoke-DockerCompose run --rm php_test ./vendor/bin/codecept run acceptance @testPath
        }

        # ====== CODE QUALITY ======
        'phpcs' {
            $testPath = if ($CommandArgs.Count -gt 0) { $CommandArgs } else { @('.') }
            Write-Info "Verificando estilo..."
            Invoke-DockerCompose run --rm php ./vendor/bin/phpcs @testPath
        }

        'phpcbf' {
            $testPath = if ($CommandArgs.Count -gt 0) { $CommandArgs } else { @('.') }
            Write-Warning "Corrigindo estilo..."
            Invoke-DockerCompose run --rm php ./vendor/bin/phpcbf @testPath
        }

        'phpstan' {
            Write-Info "Analise estatica (PHPStan)..."
            Invoke-DockerCompose run --rm php ./vendor/bin/codecept build
            Invoke-DockerCompose run --rm php ./vendor/bin/phpstan analyse --memory-limit 1G @CommandArgs
        }

        # ====== GIT ======
        'git:clean:branchs' {
            Write-Warning "Removendo branches locais..."
            git branch | Where-Object { $_ -notmatch '^\*|master|main|develop|production' } | ForEach-Object {
                $branch = $_.Trim()
                git branch -D $branch
                Write-Success "Removido: $branch"
            }
        }

        # ====== DATABASE ======
        'db:console' {
            Write-Info "Console MySQL..."
            Invoke-DockerCompose exec db sh -c "mysql -u root -p`"$env:DB_PASSWORD`" $env:DB_DATABASE --default-character-set utf8mb4"
        }

        'db:reset' {
            Write-Warning "Resetando banco..."
            Invoke-DockerCompose cp database/schema.sql db:/tmp/
            Invoke-DockerCompose exec db sh -c "mysql -u root -p`"$env:DB_PASSWORD`" $env:DB_DATABASE < /tmp/schema.sql"
            Write-Success "Banco resetado"
        }

        'db:populate' {
            Write-Info "Populando banco..."
            Invoke-DockerCompose exec php php database/Populate/populate.php
            Write-Success "Banco populado"
        }

        # ====== HELP ======
        'help' {
            Show-Extended-Help
        }

        'diagnostic' {
            Show-Docker-Diagnostics | Out-Null
        }

        default {
            Write-Error-Custom "Comando desconhecido: $Command"
            Write-Host ""
            Show-Usage
            exit 1
        }
    }
}
catch {
    Write-Error-Custom "Erro: $_"
    exit 1
}
finally {
    $elapsed.Stop()
    Write-Host ""
    $totalSeconds = [int]$elapsed.Elapsed.TotalSeconds
    Write-Host "Concluido em ${totalSeconds}s" -ForegroundColor Gray
}
