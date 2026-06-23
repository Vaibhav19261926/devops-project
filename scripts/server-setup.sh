#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# server-setup.sh — Run once on a fresh Ubuntu 22.04 EC2 instance
# Usage: bash server-setup.sh
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail
echo "=== DevOps Demo — EC2 Server Setup ==="

# ── 1. System updates ─────────────────────────────────────────────────────────
echo "[1/7] Updating system packages..."
sudo apt-get update -y && sudo apt-get upgrade -y

# ── 2. Install Docker ─────────────────────────────────────────────────────────
echo "[2/7] Installing Docker..."
sudo apt-get install -y ca-certificates curl gnupg lsb-release git

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add current user to docker group (no sudo needed)
sudo usermod -aG docker "$USER"
sudo systemctl enable docker
sudo systemctl start docker
echo "Docker installed ✅"

# ── 3. UFW Firewall ───────────────────────────────────────────────────────────
echo "[3/7] Configuring UFW firewall..."
sudo apt-get install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp    comment 'SSH'
sudo ufw allow 80/tcp    comment 'HTTP'
sudo ufw allow 443/tcp   comment 'HTTPS'
sudo ufw --force enable
sudo ufw status verbose
echo "UFW configured ✅"

# ── 4. fail2ban ───────────────────────────────────────────────────────────────
echo "[4/7] Installing fail2ban..."
sudo apt-get install -y fail2ban

sudo tee /etc/fail2ban/jail.local > /dev/null <<'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

[sshd]
enabled  = true
port     = ssh
logpath  = %(sshd_log)s
backend  = %(sshd_backend)s
EOF

sudo systemctl enable fail2ban
sudo systemctl restart fail2ban
echo "fail2ban configured ✅"

# ── 5. SSH hardening ──────────────────────────────────────────────────────────
echo "[5/7] Hardening SSH..."
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
echo "SSH hardened ✅"

# ── 6. Automatic security updates ────────────────────────────────────────────
echo "[6/7] Enabling unattended upgrades..."
sudo apt-get install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades || true
echo "Auto-updates enabled ✅"

# ── 7. Clone repo & setup backup cron ────────────────────────────────────────
echo "[7/7] Final setup..."
mkdir -p ~/backups/postgres

# Set up backup cron (runs at 2 AM daily)
(crontab -l 2>/dev/null; echo "0 2 * * * /home/$USER/devops-project/scripts/backup.sh >> /var/log/backup.log 2>&1") | crontab -
echo "Backup cron set ✅"

echo ""
echo "════════════════════════════════════════"
echo "  Server setup complete! ✅"
echo "  Next steps:"
echo "  1. Log out and back in (for docker group)"
echo "  2. git clone your repo into ~/devops-project"
echo "  3. cp .env.example .env && nano .env"
echo "  4. bash scripts/generate-ssl.sh"
echo "  5. docker compose up -d"
echo "════════════════════════════════════════"
