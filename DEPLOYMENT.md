Deployment Notes
Went through the whole setup end to end, noting down what I checked and how I fixed things when they broke.
Before starting (local machine)

Made sure Docker Desktop was running, Git was installed, and I had an AWS account ready. Downloaded the .pem key and locked it down with chmod 400.
Setting up AWS

Launched an EC2 instance — Ubuntu 22.04, t3.micro works fine for this. Locked the security group down to just ports 22, 80 and 443. Grabbed an Elastic IP and attached it so the address doesn't change on restart. Tested SSH access before moving on.
Server side

Ran the server-setup.sh script. Had to log out and back in for the Docker group permissions to actually kick in — easy to forget this step. After that, docker --version worked fine without sudo. Checked UFW was active with the right rules, and fail2ban was running too.
Getting the app running

Cloned the repo into ~/devops-project, then copied .env.example to .env and filled in the real values. Used strong passwords everywhere (16+ characters, mixed). For SECRET_KEY I generated a 64-character random hex string. Ran the SSL script (bash scripts/generate-ssl.sh) to get certs in place.
Then docker compose up -d — came up clean with no errors. docker compose ps showed all 4 containers healthy. Hit the health endpoint and got back {"status":"healthy"}, same thing worked over HTTPS too.
CI/CD

Added all 8 secrets in GitHub. Pushed a test commit to main to trigger the pipeline — both the Test and Deploy jobs came back green. Double-checked the deployment actually worked by hitting the health endpoint again after the run.
Backups

Ran the backup script manually first to make sure it worked — file showed up in ~/backups/postgres/ as expected. Then set up the cron job and confirmed it with crontab -l.

Issues I ran into and how I fixed them
Container wouldn't start — First thing I do is check logs (docker compose logs api, etc). Usually it's one of: wrong password in .env, a port already taken (check with sudo lsof -i :80), or missing SSL certs.
502 Bad Gateway — This means NGINX is fine but can't talk to the API. Usually the API just needs a few more seconds to boot, or it crashed because the DB wasn't ready yet. Check the API container's health and logs first.
Database wouldn't connect — Happened once after I changed the password in .env post-setup — the DB was still using the old one. Had to wipe and recreate:
docker compose down -v
docker compose up -d
(Heads up — this nukes existing data, so be careful with it on a real environment.)
Redis auth failing — Same idea, password mismatch between .env and what Redis actually started with. Fixed with:
docker compose restart redis
docker compose restart api
SSL errors — Just check the certs folder actually has files in it, regenerate if not, and restart nginx.
GitHub Actions deploy failing — A few usual suspects: SSH refusing (wrong EC2_HOST or port 22 not open), permission denied (fix ownership with sudo chown -R ubuntu:ubuntu ~/devops-project), or the health check failing after deploy (SSH in and check the API logs directly).
Disk filling up — df -h to see how bad it is, then docker system prune -a clears out old images and containers that aren't being used.

Commands I use most
docker compose ps
docker compose logs -f
docker compose restart api
docker compose down && docker compose up -d
Health checks
curl http://52.63.66.236/health
curl http://52.63.66.236/health/live
curl http://52.63.66.236/health/ready
Database
docker compose exec db psql -U $POSTGRES_USER -d $POSTGRES_DB
bash scripts/backup.sh
Redis
docker compose exec redis redis-cli -a $REDIS_PASSWORD

.env values
VariableWhat it's forPOSTGRES_USERDB usernamePOSTGRES_PASSWORDDB password (strong)POSTGRES_DBDB nameREDIS_PASSWORDRedis authSECRET_KEY64-char hex, signing key
Generate the key with:
python3 -c "import secrets; print(secrets.token_hex(32))"
GitHub Secrets needed
SecretWhere fromEC2_HOSTAWS console → Elastic IPsEC2_USERalways "ubuntu"EC2_SSH_KEYfull .pem contentPOSTGRES_USER/PASSWORD/DBsame as .envREDIS_PASSWORDsame as .envSECRET_KEYsame as .env