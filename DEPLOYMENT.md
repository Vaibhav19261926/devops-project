# Deployment Checklist & Troubleshooting Guide

## Pre-Deployment Checklist

### Local Machine
- [ ] Docker Desktop installed and running
- [ ] Git installed
- [ ] AWS account created
- [ ] `.pem` key file downloaded and `chmod 400` applied

### AWS Setup
- [ ] EC2 instance launched (Ubuntu 22.04, t2.micro or larger)
- [ ] Security Group configured (ports 22, 80, 443 only)
- [ ] Elastic IP allocated and associated with instance
- [ ] EC2 instance is reachable via SSH

### Server Setup
- [ ] `server-setup.sh` run successfully
- [ ] Logged out and back in (for Docker group membership)
- [ ] `docker --version` works without sudo
- [ ] UFW status shows active with correct rules
- [ ] fail2ban status shows active

### Application Setup
- [ ] Repository cloned to `~/devops-project`
- [ ] `.env` created from `.env.example` with real values
- [ ] All passwords are strong (16+ chars, mixed characters)
- [ ] `SECRET_KEY` is a 64-char random hex string
- [ ] SSL certificates generated (`bash scripts/generate-ssl.sh`)
- [ ] `docker compose up -d` completed without errors
- [ ] `docker compose ps` shows all 4 containers as healthy
- [ ] `curl http://localhost/health` returns `{"status":"healthy",...}`
- [ ] `curl https://localhost/health -k` returns same response

### CI/CD Setup
- [ ] All 8 GitHub Secrets added
- [ ] Test push to main triggered the workflow
- [ ] Both jobs (Test and Deploy) showed green ✓
- [ ] Deployment verified via health endpoint after CI/CD run

### Backup Setup
- [ ] `scripts/backup.sh` runs without error manually
- [ ] Backup file appears in `~/backups/postgres/`
- [ ] Cron job set (`crontab -l` shows the backup entry)

---

## Common Issues & Fixes

### Container won't start

**Symptom:** `docker compose ps` shows container as `Exit 1` or `Restarting`

```bash
# Check the logs
docker compose logs api
docker compose logs db
docker compose logs nginx
docker compose logs redis
```

Common causes:
- Wrong password in `.env` → fix `.env`, run `docker compose up -d`
- Port already in use → `sudo lsof -i :80` to find what's using it
- Missing SSL certs → run `bash scripts/generate-ssl.sh`

---

### 502 Bad Gateway from NGINX

**Symptom:** Browser shows 502 error

Means NGINX is running but can't reach FastAPI.

```bash
# Check if API is healthy
docker compose ps api

# Check API logs
docker compose logs api

# Check if API is listening
docker compose exec nginx curl http://api:8000/health/live
```

Common causes:
- API container still starting up (wait 30s after `docker compose up`)
- API crashed due to DB connection error (check DB is healthy first)
- `depends_on` health check not yet passed

---

### Database connection error

**Symptom:** API logs show `asyncpg.exceptions.InvalidPasswordError` or `Connection refused`

```bash
# Check DB is running
docker compose ps db

# Check DB health specifically
docker compose exec db pg_isready -U $POSTGRES_USER

# Check credentials match between .env and what DB was created with
docker compose exec db psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT 1"
```

If you changed `.env` passwords after first run, the DB was already created with the old password. Fix:
```bash
docker compose down -v   # WARNING: deletes all data
docker compose up -d
```

---

### Redis authentication error

**Symptom:** API logs show `WRONGPASS invalid username-password pair`

```bash
# Test Redis connection manually
docker compose exec redis redis-cli -a $REDIS_PASSWORD ping
# Should return: PONG
```

Check that `REDIS_PASSWORD` in `.env` matches what Redis was started with. If changed after first run:
```bash
docker compose restart redis
docker compose restart api
```

---

### SSL certificate errors

**Symptom:** NGINX won't start, logs show `cannot load certificate`

```bash
# Check certs exist
ls -la nginx/ssl/

# Regenerate if missing
bash scripts/generate-ssl.sh

# Restart NGINX
docker compose restart nginx
```

---

### GitHub Actions deployment fails

**Symptom:** Deploy job shows red ✗

```bash
# Check which step failed in the GitHub Actions log
# Common issues:

# 1. SSH connection refused
# → Check EC2_HOST secret is correct Elastic IP
# → Check port 22 is open in Security Group
# → Check EC2_SSH_KEY is the full .pem content including header/footer

# 2. Permission denied
# → ubuntu user must own ~/devops-project
# → Run: sudo chown -R ubuntu:ubuntu ~/devops-project

# 3. Health check failed after deploy
# → SSH into server and check: docker compose logs api
```

---

### Disk space full

**Symptom:** `No space left on device` errors

```bash
# Check disk usage
df -h

# Docker cleanup
docker system prune -a    # removes unused images, containers, networks
docker volume prune       # WARNING: removes unused volumes (not your named ones)

# Check what's taking space
du -sh ~/backups/postgres/*
```

---

## Useful Commands Reference

### Daily Operations

```bash
# Check everything is running
docker compose ps

# View live logs (all services)
docker compose logs -f

# View logs for one service
docker compose logs -f api
docker compose logs -f nginx

# Restart one service
docker compose restart api

# Full restart
docker compose down && docker compose up -d
```

### Health Checks

```bash
# Full health check
curl http://localhost/health

# Liveness probe
curl http://localhost/health/live

# Readiness probe
curl http://localhost/health/ready

# Test HTTPS (ignore self-signed cert warning)
curl https://localhost/health -k
```

### Database Operations

```bash
# Connect to PostgreSQL
docker compose exec db psql -U $POSTGRES_USER -d $POSTGRES_DB

# Run a query
docker compose exec db psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT COUNT(*) FROM items;"

# Manual backup
bash scripts/backup.sh

# List backups
ls -lh ~/backups/postgres/
```

### Redis Operations

```bash
# Connect to Redis CLI
docker compose exec redis redis-cli -a $REDIS_PASSWORD

# Check memory usage
docker compose exec redis redis-cli -a $REDIS_PASSWORD info memory

# Flush cache (careful in production)
docker compose exec redis redis-cli -a $REDIS_PASSWORD FLUSHDB
```

### Docker Operations

```bash
# Check resource usage
docker stats

# Check disk usage
docker system df

# View all images
docker images

# Clean up unused images
docker image prune -f

# Rebuild and restart one service
docker compose build --no-cache api && docker compose up -d --no-deps api
```

---

## Environment Variables Reference

| Variable | Example Value | Description |
|---|---|---|
| `POSTGRES_USER` | `appuser` | PostgreSQL username |
| `POSTGRES_PASSWORD` | `Str0ng!Pass#2024` | PostgreSQL password (strong) |
| `POSTGRES_DB` | `appdb` | Database name |
| `REDIS_PASSWORD` | `R3d!sPa$$w0rd` | Redis auth password |
| `SECRET_KEY` | `a3f8...` (64 hex chars) | App secret key for signing |
| `ENVIRONMENT` | `production` | Environment name |

Generate a strong SECRET_KEY:
```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
```

---

## GitHub Secrets Reference

| Secret Name | Where to get it |
|---|---|
| `EC2_HOST` | AWS Console → EC2 → Elastic IPs |
| `EC2_USER` | Always `ubuntu` for Ubuntu instances |
| `EC2_SSH_KEY` | Contents of your downloaded `.pem` file |
| `POSTGRES_USER` | Same as your `.env` POSTGRES_USER |
| `POSTGRES_PASSWORD` | Same as your `.env` POSTGRES_PASSWORD |
| `POSTGRES_DB` | Same as your `.env` POSTGRES_DB |
| `REDIS_PASSWORD` | Same as your `.env` REDIS_PASSWORD |
| `SECRET_KEY` | Same as your `.env` SECRET_KEY |
