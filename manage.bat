@echo off
setlocal enabledelayedexpansion

REM n8n Docker Compose Management Script for Windows
REM This script provides easy management of the n8n Docker Compose setup

set "COMPOSE_FILE=docker-compose.yml"
set "ENV_FILE=.env"
set "ENV_EXAMPLE=.env.example"

REM Color codes for Windows
set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "NC=[0m"

REM Helper functions
:log_info
echo %BLUE%[INFO]%NC% %~1
goto :eof

:log_success
echo %GREEN%[SUCCESS]%NC% %~1
goto :eof

:log_warning
echo %YELLOW%[WARNING]%NC% %~1
goto :eof

:log_error
echo %RED%[ERROR]%NC% %~1
goto :eof

:check_requirements
call :log_info "Checking requirements..."

REM Check Docker
docker --version >nul 2>&1
if errorlevel 1 (
    call :log_error "Docker is not installed or not in PATH"
    exit /b 1
)

REM Check Docker Compose
docker compose version >nul 2>&1
if errorlevel 1 (
    call :log_error "Docker Compose is not installed or not in PATH"
    exit /b 1
)

REM Check if compose file exists
if not exist "%COMPOSE_FILE%" (
    call :log_error "Docker Compose file (%COMPOSE_FILE%) not found"
    exit /b 1
)

call :log_success "Requirements check passed"
goto :eof

:check_env_file
if not exist "%ENV_FILE%" (
    call :log_warning "Environment file (.env) not found"
    if exist "%ENV_EXAMPLE%" (
        call :log_info "Copying .env.example to .env"
        copy "%ENV_EXAMPLE%" "%ENV_FILE%" >nul
        call :log_warning "Please edit .env file with your configuration before starting services"
        exit /b 1
    ) else (
        call :log_error "Neither .env nor .env.example found"
        exit /b 1
    )
)
exit /b 0

:check_ssl_certificates
call :log_info "Checking SSL certificates..."

set "cert_dir=files"
set "missing_files="

if not exist "%cert_dir%" (
    call :log_error "Certificate directory (%cert_dir%) not found"
    exit /b 1
)

if not exist "%cert_dir%\cert.pem" set "missing_files=!missing_files! cert.pem"
if not exist "%cert_dir%\key.pem" set "missing_files=!missing_files! key.pem"
if not exist "%cert_dir%\mbma-chain.pem" set "missing_files=!missing_files! mbma-chain.pem"

if not "!missing_files!"=="" (
    call :log_error "Missing SSL certificate files:!missing_files!"
    call :log_info "Please place the required SSL certificates in the %cert_dir% directory"
    exit /b 1
)

call :log_success "SSL certificates found"
exit /b 0

:generate_secrets
call :log_info "Generating secure secrets..."

echo # Generated secrets - %date% %time%
echo N8N_ENCRYPTION_KEY=%RANDOM%%RANDOM%%RANDOM%%RANDOM%
echo N8N_JWT_SECRET=%RANDOM%%RANDOM%%RANDOM%%RANDOM%
echo POSTGRES_PASSWORD=%RANDOM%%RANDOM%
echo REDIS_PASSWORD=%RANDOM%%RANDOM%
echo N8N_BASIC_AUTH_PASSWORD=%RANDOM%%RANDOM%

call :log_success "Secrets generated. Copy these to your .env file"
call :log_warning "Note: For production, use stronger secrets with openssl or similar tools"
goto :eof

:start_services
call :log_info "Starting n8n services..."

call :check_requirements
if errorlevel 1 exit /b 1

call :check_env_file
if errorlevel 1 (
    call :log_error "Please configure .env file before starting services"
    exit /b 1
)

call :check_ssl_certificates
if errorlevel 1 (
    call :log_warning "SSL certificates not found. Services may not start properly"
)

docker compose up -d
if errorlevel 1 (
    call :log_error "Failed to start services"
    exit /b 1
)

call :log_success "Services started successfully"
call :log_info "n8n will be available at: https://localhost:5678"
call :log_info "Use 'manage.bat status' to check service health"
goto :eof

:stop_services
call :log_info "Stopping n8n services..."
docker compose down
call :log_success "Services stopped"
goto :eof

:restart_services
call :log_info "Restarting n8n services..."
docker compose restart
call :log_success "Services restarted"
goto :eof

:show_status
call :log_info "Service status:"
docker compose ps

echo.
call :log_info "Service health:"

REM Check n8n health
curl -k -s https://localhost:5678/healthz >nul 2>&1
if errorlevel 1 (
    call :log_error "n8n: Unhealthy or not responding"
) else (
    call :log_success "n8n: Healthy"
)

REM Check Nginx health
curl -s http://localhost/health >nul 2>&1
if errorlevel 1 (
    call :log_error "Nginx: Unhealthy or not responding"
) else (
    call :log_success "Nginx: Healthy"
)
goto :eof

:show_logs
set "service=%~1"
set "follow=%~2"

if "%service%"=="" (
    call :log_info "Showing logs for all services..."
    if "%follow%"=="-f" (
        docker compose logs -f
    ) else (
        docker compose logs --tail=100
    )
) else (
    call :log_info "Showing logs for service: %service%"
    if "%follow%"=="-f" (
        docker compose logs -f "%service%"
    ) else (
        docker compose logs --tail=100 "%service%"
    )
)
goto :eof

:backup_data
set "backup_dir=backups"
set "timestamp=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "timestamp=%timestamp: =0%"

call :log_info "Creating backup..."

if not exist "%backup_dir%" mkdir "%backup_dir%"

REM Backup PostgreSQL
call :log_info "Backing up PostgreSQL database..."
docker compose exec -T postgres pg_dump -U n8n n8n > "%backup_dir%\postgres_backup_%timestamp%.sql"

REM Backup n8n data
call :log_info "Backing up n8n data..."
docker compose exec -T n8n tar -czf - /home/node/.n8n > "%backup_dir%\n8n_data_backup_%timestamp%.tar.gz"

call :log_success "Backup completed: %backup_dir%\"
dir "%backup_dir%\*%timestamp%*"
goto :eof

:update_services
call :log_info "Updating services..."

REM Pull latest images
call :log_info "Pulling latest images..."
docker compose pull

REM Restart services with new images
call :log_info "Restarting services with updated images..."
docker compose up -d

REM Clean up old images
call :log_info "Cleaning up old images..."
docker image prune -f

call :log_success "Services updated successfully"
goto :eof

:scale_workers
set "replicas=%~1"

if "%replicas%"=="" (
    call :log_error "Please specify number of worker replicas"
    call :log_info "Usage: manage.bat scale <number>"
    exit /b 1
)

REM Check if replicas is a number (basic check)
echo %replicas%| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    call :log_error "Replicas must be a number"
    exit /b 1
)

call :log_info "Scaling n8n workers to %replicas% replicas..."
docker compose up -d --scale n8n-worker=%replicas%

call :log_success "Workers scaled to %replicas% replicas"
docker compose ps n8n-worker
goto :eof

:show_help
echo n8n Docker Compose Management Script for Windows
echo.
echo Usage: %~nx0 ^<command^> [options]
echo.
echo Commands:
echo   start           Start all services
echo   stop            Stop all services
echo   restart         Restart all services
echo   status          Show service status and health
echo   logs [service]  Show logs (optionally for specific service)
echo   logs -f [service] Follow logs (optionally for specific service)
echo   backup          Create backup of database and n8n data
echo   update          Update services to latest versions
echo   scale ^<number^>  Scale worker nodes to specified number
echo   secrets         Generate secure secrets for .env file
echo   check           Check requirements and configuration
echo   help            Show this help message
echo.
echo Examples:
echo   %~nx0 start                 # Start all services
echo   %~nx0 logs n8n              # Show n8n logs
echo   %~nx0 logs -f               # Follow all logs
echo   %~nx0 scale 3               # Scale to 3 worker nodes
echo   %~nx0 backup                # Create backup
echo.
goto :eof

REM Main script logic
if "%~1"=="" (
    call :log_error "No command specified"
    call :show_help
    exit /b 1
)

if /i "%~1"=="start" (
    call :start_services
) else if /i "%~1"=="stop" (
    call :stop_services
) else if /i "%~1"=="restart" (
    call :restart_services
) else if /i "%~1"=="status" (
    call :show_status
) else if /i "%~1"=="logs" (
    if /i "%~2"=="-f" (
        call :show_logs "%~3" "-f"
    ) else (
        call :show_logs "%~2" "%~3"
    )
) else if /i "%~1"=="backup" (
    call :backup_data
) else if /i "%~1"=="update" (
    call :update_services
) else if /i "%~1"=="scale" (
    call :scale_workers "%~2"
) else if /i "%~1"=="secrets" (
    call :generate_secrets
) else if /i "%~1"=="check" (
    call :check_requirements
    call :check_env_file
    call :check_ssl_certificates
    call :log_success "All checks passed"
) else if /i "%~1"=="help" (
    call :show_help
) else if /i "%~1"=="--help" (
    call :show_help
) else if /i "%~1"=="-h" (
    call :show_help
) else (
    call :log_error "Unknown command: %~1"
    call :show_help
    exit /b 1
)

endlocal