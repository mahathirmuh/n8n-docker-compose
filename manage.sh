#!/bin/bash

# n8n Docker Compose Management Script
# This script provides easy management of the n8n Docker Compose setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"
ENV_EXAMPLE=".env.example"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    log_info "Checking requirements..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    # Check if compose file exists
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "Docker Compose file ($COMPOSE_FILE) not found"
        exit 1
    fi
    
    log_success "Requirements check passed"
}

check_env_file() {
    if [ ! -f "$ENV_FILE" ]; then
        log_warning "Environment file (.env) not found"
        if [ -f "$ENV_EXAMPLE" ]; then
            log_info "Copying .env.example to .env"
            cp "$ENV_EXAMPLE" "$ENV_FILE"
            log_warning "Please edit .env file with your configuration before starting services"
            return 1
        else
            log_error "Neither .env nor .env.example found"
            exit 1
        fi
    fi
    return 0
}

check_ssl_certificates() {
    log_info "Checking SSL certificates..."
    
    local cert_dir="files"
    local required_files=("cert.pem" "key.pem" "mbma-chain.pem")
    local missing_files=()
    
    if [ ! -d "$cert_dir" ]; then
        log_error "Certificate directory ($cert_dir) not found"
        return 1
    fi
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$cert_dir/$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        log_error "Missing SSL certificate files: ${missing_files[*]}"
        log_info "Please place the required SSL certificates in the $cert_dir directory"
        return 1
    fi
    
    log_success "SSL certificates found"
    return 0
}

generate_secrets() {
    log_info "Generating secure secrets..."
    
    echo "# Generated secrets - $(date)"
    echo "N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)"
    echo "N8N_JWT_SECRET=$(openssl rand -base64 32)"
    echo "POSTGRES_PASSWORD=$(openssl rand -base64 16)"
    echo "REDIS_PASSWORD=$(openssl rand -base64 16)"
    echo "N8N_BASIC_AUTH_PASSWORD=$(openssl rand -base64 12)"
    
    log_success "Secrets generated. Copy these to your .env file"
}

start_services() {
    log_info "Starting n8n services..."
    
    check_requirements
    if ! check_env_file; then
        log_error "Please configure .env file before starting services"
        exit 1
    fi
    
    if ! check_ssl_certificates; then
        log_warning "SSL certificates not found. Services may not start properly"
    fi
    
    docker compose up -d
    
    log_success "Services started successfully"
    log_info "n8n will be available at: https://localhost:5678"
    log_info "Use 'manage.sh status' to check service health"
}

stop_services() {
    log_info "Stopping n8n services..."
    docker compose down
    log_success "Services stopped"
}

restart_services() {
    log_info "Restarting n8n services..."
    docker compose restart
    log_success "Services restarted"
}

show_status() {
    log_info "Service status:"
    docker compose ps
    
    echo ""
    log_info "Service health:"
    
    # Check n8n health
    if curl -k -s https://localhost:5678/healthz > /dev/null 2>&1; then
        log_success "n8n: Healthy"
    else
        log_error "n8n: Unhealthy or not responding"
    fi
    
    # Check Nginx health
    if curl -s http://localhost/health > /dev/null 2>&1; then
        log_success "Nginx: Healthy"
    else
        log_error "Nginx: Unhealthy or not responding"
    fi
}

show_logs() {
    local service="$1"
    local follow="$2"
    
    if [ -z "$service" ]; then
        log_info "Showing logs for all services..."
        if [ "$follow" = "-f" ]; then
            docker compose logs -f
        else
            docker compose logs --tail=100
        fi
    else
        log_info "Showing logs for service: $service"
        if [ "$follow" = "-f" ]; then
            docker compose logs -f "$service"
        else
            docker compose logs --tail=100 "$service"
        fi
    fi
}

backup_data() {
    local backup_dir="backups"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    
    log_info "Creating backup..."
    
    mkdir -p "$backup_dir"
    
    # Backup PostgreSQL
    log_info "Backing up PostgreSQL database..."
    docker compose exec -T postgres pg_dump -U n8n n8n > "$backup_dir/postgres_backup_$timestamp.sql"
    
    # Backup n8n data
    log_info "Backing up n8n data..."
    docker compose exec -T n8n tar -czf - /home/node/.n8n > "$backup_dir/n8n_data_backup_$timestamp.tar.gz"
    
    log_success "Backup completed: $backup_dir/"
    ls -la "$backup_dir/"*"$timestamp"*
}

update_services() {
    log_info "Updating services..."
    
    # Pull latest images
    log_info "Pulling latest images..."
    docker compose pull
    
    # Restart services with new images
    log_info "Restarting services with updated images..."
    docker compose up -d
    
    # Clean up old images
    log_info "Cleaning up old images..."
    docker image prune -f
    
    log_success "Services updated successfully"
}

scale_workers() {
    local replicas="$1"
    
    if [ -z "$replicas" ]; then
        log_error "Please specify number of worker replicas"
        log_info "Usage: manage.sh scale <number>"
        exit 1
    fi
    
    if ! [[ "$replicas" =~ ^[0-9]+$ ]]; then
        log_error "Replicas must be a number"
        exit 1
    fi
    
    log_info "Scaling n8n workers to $replicas replicas..."
    docker compose up -d --scale n8n-worker="$replicas"
    
    log_success "Workers scaled to $replicas replicas"
    docker compose ps n8n-worker
}

show_help() {
    echo "n8n Docker Compose Management Script"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start           Start all services"
    echo "  stop            Stop all services"
    echo "  restart         Restart all services"
    echo "  status          Show service status and health"
    echo "  logs [service]  Show logs (optionally for specific service)"
    echo "  logs -f [service] Follow logs (optionally for specific service)"
    echo "  backup          Create backup of database and n8n data"
    echo "  update          Update services to latest versions"
    echo "  scale <number>  Scale worker nodes to specified number"
    echo "  secrets         Generate secure secrets for .env file"
    echo "  check           Check requirements and configuration"
    echo "  help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start                 # Start all services"
    echo "  $0 logs n8n              # Show n8n logs"
    echo "  $0 logs -f               # Follow all logs"
    echo "  $0 scale 3               # Scale to 3 worker nodes"
    echo "  $0 backup                # Create backup"
    echo ""
}

# Main script logic
case "$1" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        show_status
        ;;
    logs)
        if [ "$2" = "-f" ]; then
            show_logs "$3" "-f"
        else
            show_logs "$2" "$3"
        fi
        ;;
    backup)
        backup_data
        ;;
    update)
        update_services
        ;;
    scale)
        scale_workers "$2"
        ;;
    secrets)
        generate_secrets
        ;;
    check)
        check_requirements
        check_env_file
        check_ssl_certificates
        log_success "All checks passed"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        log_error "No command specified"
        show_help
        exit 1
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac