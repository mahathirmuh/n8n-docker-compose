# n8n Docker Compose Setup

A production-ready Docker Compose configuration for n8n workflow automation platform with PostgreSQL, Redis, and Nginx reverse proxy.

## 🏗️ Architecture

This setup includes:

- **n8n**: Main workflow automation application with built-in task runners
- **PostgreSQL**: Primary database for workflow and execution data
- **Redis**: Queue management and caching
- **Nginx**: Reverse proxy with SSL termination and security headers

## 🚀 Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- SSL certificates (cert.pem, key.pem, mbma-chain.pem) in the `files/` directory

### 1. Environment Setup

```bash
# Copy the environment template
cp .env.example .env

# Edit the environment variables
nano .env
```

### 2. Generate Secure Keys

```bash
# Generate encryption key (32+ characters)
openssl rand -base64 32

# Generate JWT secret (32+ characters)
openssl rand -base64 32

# Generate secure passwords
openssl rand -base64 16
```

### 3. SSL Certificate Setup

Ensure your SSL certificates are in the `files/` directory:
```
files/
├── cert.pem          # SSL certificate
├── key.pem           # Private key
└── mbma-chain.pem    # Certificate chain
```

### 4. Start Services

```bash
# Start all services
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f n8n
```

### 5. Access n8n

- **HTTPS**: https://localhost:5678
- **HTTP**: http://localhost (redirects to HTTPS)

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `POSTGRES_PASSWORD` | PostgreSQL password | `n8n_secure_password` |
| `REDIS_PASSWORD` | Redis password | `redis_secure_password` |
| `N8N_ENCRYPTION_KEY` | n8n encryption key | Required |
| `N8N_JWT_SECRET` | JWT secret for user management | Required |
| `N8N_BASIC_AUTH_USER` | Basic auth username | `admin` |
| `N8N_BASIC_AUTH_PASSWORD` | Basic auth password | `admin_password` |
| `N8N_HOST` | Application host | `localhost` |
| `N8N_PROTOCOL` | Protocol (http/https) | `https` |
| `WEBHOOK_URL` | Webhook base URL | `https://localhost:5678` |

### Service Configuration

#### n8n Main Application
- **Port**: 5678
- **Database**: PostgreSQL
- **Queue**: Redis (Bull)
- **Task Runners**: Built-in (enabled via N8N_RUNNERS_ENABLED)
- **Execution Mode**: Queue-based with internal scaling
- **SSL**: Enabled with custom certificates
- **User Management**: Enabled
- **Basic Auth**: Optional (configurable)

#### PostgreSQL Database
- **Version**: 15-alpine
- **Database**: n8n
- **User**: n8n
- **Extensions**: uuid-ossp, pgcrypto
- **Health Check**: Enabled

#### Redis Cache/Queue
- **Version**: 7-alpine
- **Password Protected**: Yes
- **Persistence**: Enabled
- **Health Check**: Enabled

#### Nginx Reverse Proxy
- **HTTP**: Port 80 (redirects to HTTPS)
- **HTTPS**: Port 443
- **SSL/TLS**: v1.2, v1.3
- **Security Headers**: Enabled
- **Rate Limiting**: Configured
- **Gzip Compression**: Enabled

## 🔒 Security Features

### SSL/TLS Configuration
- TLS 1.2 and 1.3 support
- Strong cipher suites
- HSTS headers
- Certificate chain validation

### Security Headers
- `X-Frame-Options: DENY`
- `X-Content-Type-Options: nosniff`
- `X-XSS-Protection: 1; mode=block`
- `Content-Security-Policy`
- `Referrer-Policy`

### Rate Limiting
- API endpoints: 10 requests/second
- Login endpoints: 1 request/second
- Burst protection enabled

### Container Security
- Non-root user execution
- No new privileges
- Read-only certificate mounts
- Network isolation

## 📊 Monitoring & Health Checks

### Health Check Endpoints

```bash
# Check n8n health
curl -k https://localhost:5678/healthz

# Check Nginx health
curl http://localhost/health

# Check all services
docker-compose ps
```

### Logs

```bash
# View all logs
docker-compose logs

# Follow specific service logs
docker-compose logs -f n8n
docker-compose logs -f postgres
docker-compose logs -f redis
docker-compose logs -f nginx

# View n8n application logs
docker-compose exec n8n ls -la /home/node/.n8n/logs/
```

## 🔄 Scaling & Performance

### Built-in Task Runners

This configuration uses n8n's modern built-in task runner system:

- **Automatic Scaling**: Task runners scale automatically based on workload
- **Queue Management**: Executions are queued and processed efficiently
- **Resource Optimization**: Better resource utilization than separate containers
- **Simplified Management**: No need to manage separate worker containers

```bash
# Check task runner status in logs
docker-compose logs n8n | grep -i "task\|runner"

# Monitor execution queue
docker-compose logs n8n | grep -i "queue"
```

### Performance Tuning

1. **Execution Mode**: Set to `queue` with `N8N_RUNNERS_ENABLED=true`
2. **Task Runner Configuration**: Automatically managed by n8n
3. **Database**: Consider connection pooling for high load
4. **Redis**: Configure memory limits and persistence
5. **Memory Allocation**: Adjust container memory limits based on workflow complexity

## 🛠️ Maintenance

### Backup

```bash
# Backup PostgreSQL
docker-compose exec postgres pg_dump -U n8n n8n > backup_$(date +%Y%m%d_%H%M%S).sql

# Backup n8n data
docker-compose exec n8n tar -czf /tmp/n8n_backup.tar.gz /home/node/.n8n
docker cp $(docker-compose ps -q n8n):/tmp/n8n_backup.tar.gz ./n8n_backup_$(date +%Y%m%d_%H%M%S).tar.gz
```

### Updates

```bash
# Pull latest images
docker-compose pull

# Restart with new images
docker-compose up -d

# Clean up old images
docker image prune
```

### Certificate Renewal

```bash
# Replace certificates in files/ directory
# Restart nginx to load new certificates
docker-compose restart nginx
```

## 🐛 Troubleshooting

### Common Issues

1. **SSL Certificate Errors**
   - Verify certificate files exist in `files/` directory
   - Check certificate validity: `openssl x509 -in files/cert.pem -text -noout`

2. **Database Connection Issues**
   - Check PostgreSQL health: `docker-compose exec postgres pg_isready -U n8n`
   - Verify environment variables in .env file

3. **Redis Connection Issues**
   - Test Redis: `docker-compose exec redis redis-cli ping`
   - Check Redis password configuration

4. **Permission Issues**
   - Ensure proper file permissions: `chmod 600 files/*.pem`
   - Check container user permissions

### Debug Commands

```bash
# Check service health
docker-compose ps

# View detailed logs
docker-compose logs --tail=100 n8n

# Execute commands in containers
docker-compose exec n8n /bin/sh
docker-compose exec postgres psql -U n8n -d n8n
docker-compose exec redis redis-cli

# Check network connectivity
docker-compose exec n8n ping postgres
docker-compose exec n8n ping redis
```

## 📋 Production Checklist

- [ ] Generate strong encryption keys and passwords
- [ ] Configure proper SSL certificates
- [ ] Set up regular database backups
- [ ] Configure log rotation
- [ ] Set up monitoring and alerting
- [ ] Review and adjust rate limiting
- [ ] Configure firewall rules
- [ ] Set up automated certificate renewal
- [ ] Test disaster recovery procedures
- [ ] Review security headers and CSP

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This configuration is provided as-is for educational and production use.

---

**Note**: Always review and customize the configuration according to your specific security and performance requirements before deploying to production.