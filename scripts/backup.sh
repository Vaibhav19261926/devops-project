#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# backup.sh — PostgreSQL backup to local + optional S3 upload
# Cron: 0 2 * * * /home/ubuntu/devops-project/scripts/backup.sh >> /var/log/backup.log 2>&1
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Config (edit these) ───────────────────────────────────────────────────────
BACKUP_DIR="/home/ubuntu/backups/postgres"
CONTAINER="devops_postgres"
DB_NAME="${POSTGRES_DB:-appdb}"
DB_USER="${POSTGRES_USER:-appuser}"
RETENTION_DAYS=7
S3_BUCKET="${S3_BUCKET:-}"           # set to your bucket name to enable S3
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/backup_${TIMESTAMP}.sql.gz"

# ── Setup ─────────────────────────────────────────────────────────────────────
mkdir -p "$BACKUP_DIR"
echo "[$(date)] Starting PostgreSQL backup..."

# ── Dump + compress ───────────────────────────────────────────────────────────
docker exec "$CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_FILE"
echo "[$(date)] Backup saved: $BACKUP_FILE ($(du -sh "$BACKUP_FILE" | cut -f1))"

# ── Upload to S3 (optional) ───────────────────────────────────────────────────
if [[ -n "$S3_BUCKET" ]]; then
    aws s3 cp "$BACKUP_FILE" "s3://${S3_BUCKET}/postgres/$(basename "$BACKUP_FILE")"
    echo "[$(date)] Uploaded to s3://${S3_BUCKET}/postgres/"
fi

# ── Prune old local backups ───────────────────────────────────────────────────
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +${RETENTION_DAYS} -delete
echo "[$(date)] Cleaned up backups older than ${RETENTION_DAYS} days"

echo "[$(date)] Backup complete ✅"
