#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# generate-ssl.sh — Generate a self-signed SSL certificate for dev/no-domain
# For production with a real domain, use Certbot instead:
#   sudo certbot certonly --standalone -d yourdomain.com
# ─────────────────────────────────────────────────────────────────────────────

set -e
OUTPUT_DIR="./nginx/ssl"
mkdir -p "$OUTPUT_DIR"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "${OUTPUT_DIR}/selfsigned.key" \
    -out    "${OUTPUT_DIR}/selfsigned.crt" \
    -subj "/C=US/ST=State/L=City/O=DevOps Demo/CN=localhost" \
    -addext "subjectAltName=IP:127.0.0.1,DNS:localhost"

chmod 600 "${OUTPUT_DIR}/selfsigned.key"
chmod 644 "${OUTPUT_DIR}/selfsigned.crt"

echo ""
echo "✅ Self-signed certificate created in ${OUTPUT_DIR}/"
echo ""
echo "NOTE: For production with a real domain, replace these with Let's Encrypt certs:"
echo "  sudo apt install certbot"
echo "  sudo certbot certonly --standalone -d yourdomain.com"
echo "  Then update nginx.conf to point to /etc/letsencrypt/live/yourdomain.com/"
