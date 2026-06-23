# Complete Deployment Guide — Zero to Live on AWS EC2
# DevOps Demo Project — FastAPI + PostgreSQL + Redis + NGINX

This document walks you through every single step from creating an AWS account
to having the application live and auto-deploying via GitHub Actions.

Follow the steps IN ORDER. Do not skip any step.

---

## PHASE 0 — WHAT YOU NEED BEFORE STARTING

Before anything else, make sure you have:

- A computer with internet access
- A GitHub account (free) — https://github.com
- An AWS account (free tier) — https://aws.amazon.com
- Git installed on your computer
- A terminal / command prompt

That's it. Everything else gets installed during this guide.

---

## PHASE 1 — SET UP YOUR LOCAL PROJECT

### Step 1.1 — Download the Project

If you downloaded the ZIP file:
- Extract it to a folder on your computer
- Name the folder: devops-project
- Open your terminal and navigate into it:

```bash
cd path/to/devops-project
```

If you want to clone from GitHub instead (after Phase 2):
```bash
git clone https://github.com/YOUR_USERNAME/devops-project.git
cd devops-project
```

### Step 1.2 — Verify the Folder Structure

Run this command and confirm all these files exist:

```bash
ls -la
```

You should see:
```
.env.example
.gitignore
.github/
ARCHITECTURE.md
DEPLOYMENT.md
Dockerfile
README.md
app/
docker-compose.yml
nginx/
scripts/
```

If anything is missing, re-extract the ZIP file.

### Step 1.3 — Install Git (if not already installed)

Check if Git is installed:
```bash
git --version
```

If you see a version number, skip to Step 1.4.

If not installed:
- Windows: Download from https://git-scm.com/download/win
- Mac: Run `xcode-select --install`
- Ubuntu/Linux: Run `sudo apt install git -y`

### Step 1.4 — Configure Git (first time only)

```bash
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

---

## PHASE 2 — SET UP GITHUB REPOSITORY

### Step 2.1 — Create a New GitHub Repository

1. Go to https://github.com
2. Click the green "New" button (top left) or go to https://github.com/new
3. Fill in:
   - Repository name: `devops-project`
   - Description: `Production FastAPI deployment with Docker, NGINX, PostgreSQL, Redis on AWS EC2`
   - Visibility: **Public** (evaluators need to see it)
   - DO NOT check "Add a README file" (we already have one)
   - DO NOT add .gitignore (we already have one)
4. Click "Create repository"
5. Copy the repository URL — looks like:
   `https://github.com/YOUR_USERNAME/devops-project.git`

### Step 2.2 — Push Project to GitHub

In your terminal, inside the devops-project folder:

```bash
# Initialize git repository
git init

# Add all files
git add .

# Create first commit
git commit -m "init: production fastapi deployment setup"

# Connect to your GitHub repository (replace YOUR_USERNAME)
git remote add origin https://github.com/YOUR_USERNAME/devops-project.git

# Push to GitHub
git branch -M main
git push -u origin main
```

### Step 2.3 — Verify on GitHub

1. Go to https://github.com/YOUR_USERNAME/devops-project
2. You should see all your files listed
3. Click on ARCHITECTURE.md — you should see the Mermaid diagrams rendered
4. Click on README.md — you should see the formatted documentation

If everything looks good, move to Phase 3.

---

## PHASE 3 — SET UP AWS EC2 INSTANCE

### Step 3.1 — Log Into AWS Console

1. Go to https://console.aws.amazon.com
2. Log in with your AWS account
3. In the top right corner, select your region
   - Recommended: us-east-1 (N. Virginia) or ap-south-1 (Mumbai)
   - Pick the region closest to you

### Step 3.2 — Launch EC2 Instance

1. In the search bar at the top, type "EC2" and click it
2. Click the orange "Launch instance" button
3. Fill in the details:

**Name:**
```
devops-demo-server
```

**Application and OS Images (AMI):**
- Click "Ubuntu"
- Select: Ubuntu Server 22.04 LTS (HVM), SSD Volume Type
- Architecture: 64-bit (x86)

**Instance type:**
- Select: t2.micro (Free tier eligible)
- This gives you 1 vCPU and 1GB RAM — enough for this project

**Key pair (login):**
- Click "Create new key pair"
- Key pair name: `devops-demo-key`
- Key pair type: RSA
- Private key file format: .pem (for Mac/Linux) or .ppk (for Windows PuTTY)
  → Recommendation: choose .pem even on Windows if you'll use Git Bash
- Click "Create key pair"
- A file called `devops-demo-key.pem` will download automatically
- SAVE THIS FILE SAFELY — you cannot download it again

**Network settings:**
- Click "Edit" next to Network settings
- VPC: leave as default
- Subnet: leave as default (No preference)
- Auto-assign public IP: Enable
- Firewall (security groups): Select "Create security group"
- Security group name: `devops-demo-sg`
- Description: `Security group for devops demo project`

Add these inbound rules (click "Add security group rule" for each):

| Type | Port | Source | Description |
|---|---|---|---|
| SSH | 22 | My IP | SSH access (click "My IP" in dropdown) |
| HTTP | 80 | Anywhere (0.0.0.0/0) | Web traffic |
| HTTPS | 443 | Anywhere (0.0.0.0/0) | Secure web traffic |

**Configure storage:**
- Size: 20 GB (increase from default 8 GB — Docker images need space)
- Volume type: gp3

**Summary (right side):**
- Number of instances: 1

4. Click the orange "Launch instance" button
5. Click "View all instances"
6. Wait until "Instance state" shows "Running" and "Status check" shows "2/2 checks passed"
   (This takes about 2-3 minutes)

### Step 3.3 — Allocate an Elastic IP (Static IP)

Without this, your server's IP changes every time it restarts.

1. In the left sidebar under "Network & Security", click "Elastic IPs"
2. Click "Allocate Elastic IP address"
3. Leave everything as default
4. Click "Allocate"
5. You now have a static IP address — copy it and save it somewhere
6. Select the new Elastic IP (checkbox on the left)
7. Click "Actions" → "Associate Elastic IP address"
8. Instance: select your `devops-demo-server`
9. Click "Associate"

Your server now has a permanent IP address that never changes.

### Step 3.4 — Connect to Your Server via SSH

First, set correct permissions on your key file:

**Mac/Linux:**
```bash
chmod 400 ~/Downloads/devops-demo-key.pem
```

**Windows (Git Bash):**
```bash
chmod 400 /c/Users/YOUR_NAME/Downloads/devops-demo-key.pem
```

Now connect (replace YOUR_ELASTIC_IP with the IP from Step 3.3):

```bash
ssh -i ~/Downloads/devops-demo-key.pem ubuntu@YOUR_ELASTIC_IP
```

When asked "Are you sure you want to continue connecting?" — type `yes` and press Enter.

You should now see something like:
```
Welcome to Ubuntu 22.04.3 LTS (GNU/Linux 5.15.0-1047-aws x86_64)
ubuntu@ip-172-31-xx-xx:~$
```

You are now inside your EC2 server. Keep this terminal open.

---

## PHASE 4 — SET UP THE SERVER

All commands in this phase run INSIDE your EC2 server (the SSH terminal).

### Step 4.1 — Run the Server Setup Script

This script installs Docker, configures the firewall, sets up fail2ban, and more.

First, let's create the project directory and get the setup script:

```bash
# Create project directory
mkdir -p ~/devops-project

# Navigate into it
cd ~/devops-project
```

Now run each setup step manually (more reliable than running the script remotely):

**Update system packages:**
```bash
sudo apt-get update -y && sudo apt-get upgrade -y
```
This takes 2-5 minutes. Wait for it to complete.

**Install required packages:**
```bash
sudo apt-get install -y ca-certificates curl gnupg lsb-release git unzip
```

**Install Docker:**
```bash
# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add ubuntu user to docker group (no sudo needed)
sudo usermod -aG docker ubuntu

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker
```

Verify Docker installed:
```bash
sudo docker --version
```
You should see: `Docker version 24.x.x, build xxxxx`

**Configure UFW Firewall:**
```bash
sudo apt-get install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status
```

You should see:
```
Status: active
To                Action      From
22/tcp            ALLOW       Anywhere
80/tcp            ALLOW       Anywhere
443/tcp           ALLOW       Anywhere
```

**Install and configure fail2ban:**
```bash
sudo apt-get install -y fail2ban

sudo tee /etc/fail2ban/jail.local > /dev/null <<'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
EOF

sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

**Harden SSH (disable root login and password auth):**
```bash
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

**Create backup directory and set up cron:**
```bash
mkdir -p ~/backups/postgres
```

### Step 4.2 — Log Out and Back In

This is required for the Docker group change to take effect:

```bash
exit
```

Then reconnect:
```bash
ssh -i ~/Downloads/devops-demo-key.pem ubuntu@YOUR_ELASTIC_IP
```

Verify Docker works without sudo:
```bash
docker --version
docker ps
```

Both commands should work without any permission errors.

---

## PHASE 5 — DEPLOY THE APPLICATION

All commands in this phase run INSIDE your EC2 server.

### Step 5.1 — Clone Your Repository

```bash
cd ~
git clone https://github.com/YOUR_USERNAME/devops-project.git
cd devops-project
```

Verify files are there:
```bash
ls -la
```

### Step 5.2 — Create the Environment File

```bash
cp .env.example .env
nano .env
```

The nano editor will open. Fill in your values:

```
POSTGRES_USER=appuser
POSTGRES_PASSWORD=CHANGE_THIS_TO_A_STRONG_PASSWORD
POSTGRES_DB=appdb
REDIS_PASSWORD=CHANGE_THIS_TO_A_STRONG_REDIS_PASSWORD
SECRET_KEY=CHANGE_THIS_TO_A_64_CHAR_RANDOM_STRING
ENVIRONMENT=production
```

Rules for passwords:
- Minimum 16 characters
- Mix of uppercase, lowercase, numbers, symbols
- Example: `MyS3cur3P@ssw0rd!2024`

Generate a SECRET_KEY:
```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
```
Copy the output and paste it as your SECRET_KEY value.

Save and exit nano:
- Press Ctrl+X
- Press Y
- Press Enter

Verify the file looks correct:
```bash
cat .env
```

### Step 5.3 — Generate SSL Certificate

```bash
bash scripts/generate-ssl.sh
```

You should see:
```
✅ Self-signed certificate created in ./nginx/ssl/
```

Verify certs were created:
```bash
ls -la nginx/ssl/
```

You should see `selfsigned.crt` and `selfsigned.key`.

### Step 5.4 — Start All Containers

```bash
docker compose up -d
```

This will:
1. Pull PostgreSQL, Redis, NGINX images from Docker Hub
2. Build your FastAPI image
3. Start all 4 containers

This takes 3-5 minutes the first time. Watch the output for any errors.

### Step 5.5 — Verify All Containers Are Running

```bash
docker compose ps
```

You should see all 4 containers with status "healthy" or "running":

```
NAME                IMAGE               STATUS
devops_nginx        nginx:1.27-alpine   Up (healthy)
devops_api          devops-demo-api     Up (healthy)
devops_postgres     postgres:16-alpine  Up (healthy)
devops_redis        redis:7-alpine      Up (healthy)
```

If any container shows "Exit" or "Restarting", check its logs:
```bash
docker compose logs CONTAINER_NAME
# Example:
docker compose logs api
docker compose logs db
```

### Step 5.6 — Test the Application

Test from inside the server:
```bash
# Test HTTP health endpoint
curl http://localhost/health

# Test HTTPS (ignore self-signed cert warning with -k)
curl https://localhost/health -k
```

Expected response:
```json
{
  "status": "healthy",
  "uptime_seconds": 12.5,
  "components": {
    "api": "ok",
    "postgres": "ok",
    "redis": "ok"
  }
}
```

Test from your browser:
- Open: `http://YOUR_ELASTIC_IP/health`
- Open: `http://YOUR_ELASTIC_IP/docs` (Swagger UI)
- Open: `http://YOUR_ELASTIC_IP/` (root endpoint)

If you see responses, your application is live! 🎉

### Step 5.7 — Test the API Endpoints

```bash
# Create an item
curl -X POST http://YOUR_ELASTIC_IP/api/v1/items \
  -H "Content-Type: application/json" \
  -d '{"title": "My First Item", "description": "Testing the API"}'

# List all items
curl http://YOUR_ELASTIC_IP/api/v1/items

# Get item by ID (replace 1 with the id from the create response)
curl http://YOUR_ELASTIC_IP/api/v1/items/1
```

---

## PHASE 6 — SET UP GITHUB ACTIONS CI/CD

### Step 6.1 — Get Your SSH Key Content

On your LOCAL machine (not the server):

**Mac/Linux:**
```bash
cat ~/Downloads/devops-demo-key.pem
```

**Windows (Git Bash):**
```bash
cat /c/Users/YOUR_NAME/Downloads/devops-demo-key.pem
```

Copy the ENTIRE output including the header and footer:
```
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA...
...many lines...
-----END RSA PRIVATE KEY-----
```

### Step 6.2 — Add GitHub Secrets

1. Go to your GitHub repository: `https://github.com/YOUR_USERNAME/devops-project`
2. Click "Settings" tab (top of the repository page)
3. In the left sidebar, click "Secrets and variables"
4. Click "Actions"
5. Click "New repository secret"

Add each of these secrets one by one:

**Secret 1:**
- Name: `EC2_HOST`
- Value: Your Elastic IP address (example: `54.123.45.67`)
- Click "Add secret"

**Secret 2:**
- Name: `EC2_USER`
- Value: `ubuntu`
- Click "Add secret"

**Secret 3:**
- Name: `EC2_SSH_KEY`
- Value: Paste the ENTIRE content of your .pem file (from Step 6.1)
- Click "Add secret"

**Secret 4:**
- Name: `POSTGRES_USER`
- Value: Same value you put in .env (example: `appuser`)
- Click "Add secret"

**Secret 5:**
- Name: `POSTGRES_PASSWORD`
- Value: Same password you put in .env
- Click "Add secret"

**Secret 6:**
- Name: `POSTGRES_DB`
- Value: Same value you put in .env (example: `appdb`)
- Click "Add secret"

**Secret 7:**
- Name: `REDIS_PASSWORD`
- Value: Same Redis password you put in .env
- Click "Add secret"

**Secret 8:**
- Name: `SECRET_KEY`
- Value: Same SECRET_KEY you put in .env
- Click "Add secret"

After adding all 8 secrets, you should see them listed (values are hidden):
```
EC2_HOST          Updated X minutes ago
EC2_USER          Updated X minutes ago
EC2_SSH_KEY       Updated X minutes ago
POSTGRES_USER     Updated X minutes ago
POSTGRES_PASSWORD Updated X minutes ago
POSTGRES_DB       Updated X minutes ago
REDIS_PASSWORD    Updated X minutes ago
SECRET_KEY        Updated X minutes ago
```

### Step 6.3 — Test the CI/CD Pipeline

Make a small change to trigger the pipeline:

On your LOCAL machine, inside the devops-project folder:

```bash
# Make a small change (add a line to README)
echo "" >> README.md
echo "<!-- deployment test -->" >> README.md

# Commit and push
git add README.md
git commit -m "test: trigger CI/CD pipeline"
git push origin main
```

### Step 6.4 — Watch the Pipeline Run

1. Go to your GitHub repository
2. Click the "Actions" tab
3. You should see "CI/CD Pipeline" running (yellow circle = in progress)
4. Click on it to see the details
5. Click on "Build & Test" to watch that job
6. Wait for it to pass (green checkmark)
7. Click on "Deploy to EC2" to watch the deployment
8. It should complete in about 1-2 minutes

If both jobs show green ✓ — your CI/CD pipeline is working!

Every future push to main will now automatically deploy.

### Step 6.5 — Verify Deployment Worked

After the pipeline succeeds, test the application again:

```bash
curl http://YOUR_ELASTIC_IP/health
```

You should still get a healthy response.

---

## PHASE 7 — SET UP AUTOMATED BACKUPS

On your EC2 server:

### Step 7.1 — Load Environment Variables

```bash
cd ~/devops-project
export $(cat .env | grep -v '#' | xargs)
```

### Step 7.2 — Test the Backup Script

```bash
bash scripts/backup.sh
```

You should see:
```
[2024-xx-xx] Starting PostgreSQL backup...
[2024-xx-xx] Backup saved: /home/ubuntu/backups/postgres/backup_YYYYMMDD_HHMMSS.sql.gz (8.0K)
[2024-xx-xx] Backup complete ✅
```

Verify the backup file:
```bash
ls -lh ~/backups/postgres/
```

### Step 7.3 — Set Up Automated Daily Backups

```bash
crontab -e
```

If asked which editor to use, type `1` for nano and press Enter.

Add this line at the bottom of the file:
```
0 2 * * * cd /home/ubuntu/devops-project && export $(cat .env | grep -v '#' | xargs) && bash scripts/backup.sh >> /var/log/backup.log 2>&1
```

Save and exit (Ctrl+X, Y, Enter).

Verify the cron job was saved:
```bash
crontab -l
```

---

## PHASE 8 — FINAL VERIFICATION

Run through this complete checklist to confirm everything is working.

### Step 8.1 — Check All Containers

On your EC2 server:
```bash
docker compose ps
```
✓ All 4 containers should show as healthy

### Step 8.2 — Check All API Endpoints

From your browser, test these URLs (replace YOUR_ELASTIC_IP):

| URL | Expected Result |
|---|---|
| `http://YOUR_ELASTIC_IP/` | JSON with API info |
| `http://YOUR_ELASTIC_IP/health` | All components "ok" |
| `http://YOUR_ELASTIC_IP/health/live` | `{"status":"alive"}` |
| `http://YOUR_ELASTIC_IP/health/ready` | `{"status":"ready"}` |
| `http://YOUR_ELASTIC_IP/docs` | Swagger UI page |
| `http://YOUR_ELASTIC_IP/api/v1/items` | Empty array `[]` |

### Step 8.3 — Check Logs Are Working

```bash
# Check application logs
docker compose logs --tail=20 api

# Check NGINX access logs
docker compose logs --tail=20 nginx
```

You should see recent request logs.

### Step 8.4 — Check Security

```bash
# Verify firewall is active
sudo ufw status

# Verify fail2ban is running
sudo systemctl status fail2ban

# Verify non-root user in container
docker compose exec api whoami
# Should output: appuser (NOT root)
```

### Step 8.5 — Check CI/CD Is Working

Go to GitHub → Actions tab.
Your last workflow run should show two green checkmarks.

### Step 8.6 — Test Auto-Restart

Simulate a container crash:
```bash
docker restart devops_api
```

Wait 30 seconds, then check:
```bash
docker compose ps
curl http://localhost/health
```

Container should have restarted automatically and health should be OK.

---

## PHASE 9 — WHAT TO PUT IN YOUR SUBMISSION

### GitHub Repository

Your repository at `https://github.com/YOUR_USERNAME/devops-project` should contain:

```
✓ README.md          — Main documentation
✓ ARCHITECTURE.md    — Architecture diagrams and explanation
✓ DEPLOYMENT.md      — Deployment checklist and troubleshooting
✓ Dockerfile         — Multi-stage container build
✓ docker-compose.yml — All 4 services configured
✓ nginx/nginx.conf   — Production NGINX config
✓ app/               — FastAPI application code
✓ scripts/           — Backup, SSL, server setup scripts
✓ .github/workflows/ — CI/CD pipeline
✓ .env.example       — Environment template (NOT .env)
✓ .gitignore         — Excludes .env, certs, etc.
```

### Deliverables Checklist

| Requirement | Where It Is |
|---|---|
| GitHub repository | https://github.com/YOUR_USERNAME/devops-project |
| Deployment documentation | README.md + DEPLOYMENT.md |
| Docker Compose setup | docker-compose.yml |
| GitHub Actions workflow | .github/workflows/deploy.yml |
| Architecture diagram | ARCHITECTURE.md (Mermaid diagrams) |
| Deployment instructions | This document + README.md |
| Health check endpoint | GET /health, /health/live, /health/ready |
| Logging strategy | docker-compose.yml log driver config + app/main.py middleware |
| Backup/restart strategy | scripts/backup.sh + DEPLOYMENT.md |
| SSL setup | nginx/nginx.conf + scripts/generate-ssl.sh |
| Environment variables | .env.example |
| Basic security | UFW + fail2ban + non-root user + no exposed DB ports |

### Bonus Points Completed

| Bonus | Implementation |
|---|---|
| fail2ban | Installed in server-setup.sh, configured for SSH |
| Firewall setup | UFW with only ports 22, 80, 443 |
| Zero-downtime deploys | `docker compose up -d --no-deps api` in CI/CD |
| Automated backups | scripts/backup.sh + cron job |

---

## QUICK REFERENCE — DAILY COMMANDS

### Check everything is running
```bash
docker compose ps
```

### View live logs
```bash
docker compose logs -f
```

### Restart the app after a manual change
```bash
docker compose build --no-cache api && docker compose up -d --no-deps api
```

### Pull latest code manually (without CI/CD)
```bash
cd ~/devops-project
git pull origin main
docker compose build --no-cache api
docker compose up -d --no-deps api
```

### Check disk space
```bash
df -h
docker system df
```

### Emergency: restart everything
```bash
docker compose down && docker compose up -d
```

---

## TROUBLESHOOTING — MOST COMMON ISSUES

### "Connection refused" when visiting the IP

```bash
# Check if NGINX is running
docker compose ps nginx
docker compose logs nginx

# Check if port 80 is open
sudo ufw status
```

### "502 Bad Gateway"

```bash
# API container is down or not ready
docker compose logs api
docker compose restart api
# Wait 30 seconds then try again
```

### GitHub Actions failing

```bash
# SSH into server and check manually
docker compose logs api
docker compose ps
```

Check GitHub Secrets are correct — most common cause is a typo in EC2_HOST or wrong SSH key format.

### Containers keep restarting

```bash
# Check what error is causing restart
docker compose logs --tail=50 CONTAINER_NAME
```

Most common cause: wrong password in .env file.

---

## ESTIMATED TIME TO COMPLETE

| Phase | Estimated Time |
|---|---|
| Phase 1: Local setup | 5 minutes |
| Phase 2: GitHub setup | 10 minutes |
| Phase 3: AWS EC2 launch | 15 minutes |
| Phase 4: Server setup | 20 minutes |
| Phase 5: Deploy application | 15 minutes |
| Phase 6: GitHub Actions CI/CD | 15 minutes |
| Phase 7: Backups | 5 minutes |
| Phase 8: Verification | 10 minutes |
| **Total** | **~95 minutes** |

---

*This guide covers everything from zero to a fully deployed, auto-deploying, production-ready application on AWS EC2.*
