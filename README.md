# DevOps Demo — Production FastAPI Deployment on AWS EC2

A production-ready deployment of a FastAPI application with PostgreSQL, Redis, NGINX, Docker Compose, and GitHub Actions CI/CD — deployed on AWS EC2.

---

## Architecture Overview

```
Internet
   │
   ▼
AWS Security Group (ports 80, 443, 22 only)
   │
   ▼
AWS EC2 (Ubuntu 22.04) ── Elastic IP
   │
   ├── UFW Firewall
   ├── fail2ban (SSH protection)
   │
   └── Docker Compose Stack
         ├── NGINX  :443/:80  (SSL termination, reverse proxy, rate limiting)
         │       │
         │       ▼
         ├── FastAPI :8000   (2 uvicorn workers, non-root user)
         │       │        │
         │       ▼        ▼
         ├── PostgreSQL  Redis
         │   :5432        :6379
         │   (internal)   (internal)
         │
         └── (volumes: postgres_data, redis_data)
```

---

## Stack

| Layer | Technology |
|---|---|
| API Framework | FastAPI 0.115 + Python 3.12 |
| Database | PostgreSQL 16 |
| Cache | Redis 7 |
| Reverse Proxy | NGINX 1.27 |
| Containerization | Docker + Docker Compose v2 |
| CI/CD | GitHub Actions |
| Cloud | AWS EC2 (t2.micro / t3.small) |
| SSL | Self-signed (dev) / Let's Encrypt (prod) |
| Security | UFW, fail2ban, non-root Docker user |

---

## Local Development

### Prerequisites
- Docker Desktop installed
- Git

### Quickstart

```bash
# 1. Clone
git clone https://github.com/yourusername/devops-project.git
cd devops-project

# 2. Create environment file
cp .env.example .env
# Edit .env with your values

# 3. Generate self-signed SSL cert
bash scripts/generate-ssl.sh

# 4. Start all services
docker compose up -d

# 5. Verify
curl http://localhost/health
curl https://localhost/health -k
```

### API Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/` | Root info |
| GET | `/health` | Full health check (API + DB + Redis) |
| GET | `/health/live` | Liveness probe |
| GET | `/health/ready` | Readiness probe |
| GET | `/docs` | Swagger UI |
| GET | `/api/v1/items` | List items |
| POST | `/api/v1/items` | Create item |
| GET | `/api/v1/items/{id}` | Get item (Redis cached) |
| PATCH | `/api/v1/items/{id}` | Update item |
| DELETE | `/api/v1/items/{id}` | Soft-delete item |

---

## AWS EC2 Deployment

### Step 1 — Launch EC2 Instance

1. Go to AWS Console → EC2 → Launch Instance
2. Choose **Ubuntu Server 22.04 LTS**
3. Instance type: **t2.micro** (free tier) or t3.small for production
4. Create a key pair (download the `.pem` file)
5. Configure Security Group:
   - Port 22 (SSH) — your IP only
   - Port 80 (HTTP) — 0.0.0.0/0
   - Port 443 (HTTPS) — 0.0.0.0/0
6. Assign an **Elastic IP** to the instance

### Step 2 — Run Server Setup Script

```bash
# SSH into your instance
chmod 400 your-key.pem
ssh -i your-key.pem ubuntu@YOUR_ELASTIC_IP

# Run setup script
curl -fsSL https://raw.githubusercontent.com/yourusername/devops-project/main/scripts/server-setup.sh | bash

# Log out and back in for Docker group to take effect
exit
ssh -i your-key.pem ubuntu@YOUR_ELASTIC_IP
```

### Step 3 — Deploy the Application

```bash
# Clone the repository
git clone https://github.com/yourusername/devops-project.git ~/devops-project
cd ~/devops-project

# Configure environment
cp .env.example .env
nano .env   # Fill in strong passwords and secret key

# Generate SSL certificate
bash scripts/generate-ssl.sh

# Start everything
docker compose up -d

# Verify
docker compose ps
curl https://localhost/health -k
```

### Step 4 — Configure GitHub Actions

Add the following **Secrets** in GitHub → Settings → Secrets → Actions:

| Secret Name | Value |
|---|---|
| `EC2_HOST` | Your Elastic IP address |
| `EC2_USER` | `ubuntu` |
| `EC2_SSH_KEY` | Contents of your `.pem` file |
| `POSTGRES_USER` | Your DB username |
| `POSTGRES_PASSWORD` | Strong DB password |
| `POSTGRES_DB` | Database name |
| `REDIS_PASSWORD` | Strong Redis password |
| `SECRET_KEY` | 64-char random string |

After setting secrets, every push to `main` will automatically deploy.

---

## SSL Configuration

### Option A — Self-Signed (No Domain)
```bash
bash scripts/generate-ssl.sh
```
Browsers will show a warning. Use `-k` with curl. Documents the production approach.

### Option B — Let's Encrypt (With Domain)
```bash
# Point your domain DNS A record to your Elastic IP first, then:
sudo apt install certbot
sudo certbot certonly --standalone -d yourdomain.com

# Update nginx/nginx.conf:
# ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
# ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

# Auto-renew (cron)
echo "0 12 * * * certbot renew --quiet" | sudo crontab -
```

---

## Security Measures

| Measure | Implementation |
|---|---|
| Firewall | UFW — only ports 22, 80, 443 open |
| Brute force protection | fail2ban on SSH |
| Non-root containers | `appuser` (UID 1001) in Docker |
| Secrets management | `.env` file, never committed to git |
| SSH hardening | Root login disabled, password auth disabled |
| DB not exposed | PostgreSQL only reachable inside Docker network |
| Redis not exposed | Redis only reachable inside Docker network |
| Security headers | HSTS, X-Frame-Options, CSP via NGINX |
| Rate limiting | 30 req/min per IP via NGINX |
| TLS | TLS 1.2/1.3 only, strong cipher suite |

---

## Logging Strategy

- **Application logs**: JSON format, stdout → Docker log driver
- **NGINX logs**: Access + error logs, JSON format
- **Log rotation**: `max-size: 10m`, `max-file: 5` (via Docker log options)
- **Viewing logs**:

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f api
docker compose logs -f nginx

# Since last hour
docker compose logs --since 1h api
```

---

## Backup & Recovery

### Automated Backups
```bash
# Backup cron runs daily at 2 AM (set up by server-setup.sh)
# Manual backup:
bash scripts/backup.sh

# List backups
ls -lh ~/backups/postgres/
```

### Restore from Backup
```bash
# Decompress and restore
gunzip -c ~/backups/postgres/backup_YYYYMMDD_HHMMSS.sql.gz | \
  docker exec -i devops_postgres psql -U $POSTGRES_USER $POSTGRES_DB
```

### Restart Strategy
All containers have `restart: always` — they auto-restart on crash or reboot.

---

## Monitoring (Bonus)

### Uptime Kuma (Self-hosted monitoring)

```bash
docker run -d \
  --name uptime-kuma \
  --restart always \
  -p 3001:3001 \
  -v uptime-kuma:/app/data \
  louislam/uptime-kuma:1
```

Access at `http://YOUR_IP:3001` and add monitors for:
- `https://YOUR_IP/health` (HTTP)
- `https://YOUR_IP/health/ready` (HTTP)

---

## Zero-Downtime Deployments

The CI/CD pipeline achieves near-zero downtime by:
1. Building the new API image
2. Restarting only the `api` container (`--no-deps`)
3. NGINX continues serving the old container until the new one passes health checks
4. Only then does traffic route to the new container

---

## Troubleshooting

```bash
# Check container status
docker compose ps

# View recent logs
docker compose logs --tail=50 api

# Restart a single service
docker compose restart api

# Rebuild and restart
docker compose build api && docker compose up -d --no-deps api

# Shell into running container
docker compose exec api bash

# Check disk usage
df -h
docker system df

# Check if DB is accepting connections
docker compose exec db pg_isready -U $POSTGRES_USER
```

---

## Project Structure

```
devops-project/
├── app/
│   ├── main.py              # FastAPI app + middleware
│   ├── database.py          # PostgreSQL async connection
│   ├── cache.py             # Redis connection
│   ├── requirements.txt
│   ├── models/
│   │   └── item.py          # SQLAlchemy model
│   ├── schemas/
│   │   └── item.py          # Pydantic schemas
│   └── routers/
│       ├── health.py        # /health endpoints
│       └── items.py         # CRUD endpoints with Redis caching
├── nginx/
│   ├── nginx.conf           # Rate limiting, SSL, security headers
│   └── ssl/                 # Certs (gitignored)
├── scripts/
│   ├── backup.sh            # PostgreSQL backup + S3 upload
│   ├── generate-ssl.sh      # Self-signed cert generator
│   └── server-setup.sh      # One-time EC2 provisioning
├── .github/
│   └── workflows/
│       └── deploy.yml       # CI/CD pipeline
├── docker-compose.yml
├── Dockerfile               # Multi-stage, non-root user
├── .env.example
├── .gitignore
└── README.md
```

<!-- deployment test -->
