# Deployment Guide — VPS Security Dashboard

This guide walks through deploying the security dashboard on your Oracle Cloud free tier VPS using Docker Compose and Caddy for automatic HTTPS.

---

## Prerequisites

Before deploying, ensure the following are installed on your VPS:

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose plugin (v2)
sudo apt-get install -y docker-compose-plugin

# Verify
docker --version          # Docker 24+
docker compose version    # Docker Compose v2.x
```

---

## Architecture

```
Internet
    │
    ▼
Caddy :443 (HTTPS + IP restriction)
    │
    ▼
App :3000 (Express + React)
    │
    ├── SQLite (file: /app/data/security-dashboard.db)
    │
    └── Host system (via volume mounts + sudoers)
         ├── /var/log (read-only)
         ├── fail2ban-client (via sudo)
         └── ufw (via sudo)
```

The database is a single SQLite file persisted in the `app_data` Docker volume. There is no separate database container or network port — this is intentional to minimise the attack surface and resource usage on the Oracle Cloud free tier.

---

## Step 1 — Clone the Repository

```bash
git clone https://github.com/andrzj/oracle-vps-security-suite.git
cd oracle-vps-security-suite/vps-security-dashboard
```

---

## Step 2 — Configure Environment Variables

```bash
cd docker
cp env.template .env
nano .env   # Fill in all values
chmod 600 .env
```

**Required values:**

| Variable | Description | How to obtain |
|----------|-------------|---------------|
| `DOMAIN` | Your dashboard domain | e.g. `security.yourdomain.com` |
| `JWT_SECRET` | Session signing key | `openssl rand -hex 32` |
| `TRUSTED_IP` | Your home/office IP | `curl -s ifconfig.me` |
| `SQLITE_DB_PATH` | SQLite file path inside container | Default: `/app/data/security-dashboard.db` |
| `NODE_ENV` | Runtime mode | Set to `production` |

> `SQLITE_DB_PATH` has a sensible default and only needs to be changed if you want to store the database file in a custom location.

> **No external accounts required.** The dashboard uses self-contained username/password authentication stored in SQLite. On first visit, you will be prompted to create your admin account directly in the browser.

---

## Step 3 — Configure Caddy

Edit `docker/caddy/Caddyfile` and replace the placeholders:

```bash
nano docker/caddy/Caddyfile
```

Replace:
- `YOUR_DOMAIN` → your actual domain (e.g., `security.yourdomain.com`)
- `YOUR_HOME_IP` → your home/office IP address

**Find your current IP:**
```bash
curl -s ifconfig.me
```

> **Security Note:** The IP restriction in Caddy is the single most effective security measure in the entire stack. It prevents the login page from being exposed to the internet entirely — the dashboard is completely invisible to any IP that is not yours. Do not skip this step.

---

## Step 4 — Configure DNS

Point your domain to your VPS public IP:

```
A    security.yourdomain.com    →    YOUR_VPS_PUBLIC_IP
```

Verify DNS propagation:
```bash
dig security.yourdomain.com +short
```

---

## Step 5 — Configure Sudoers (Critical)

The dashboard app needs limited sudo access to read logs and control Fail2Ban/UFW:

```bash
# Copy sudoers config
sudo cp docker/sudoers-dashboard.conf /etc/sudoers.d/dashboard
sudo chmod 440 /etc/sudoers.d/dashboard

# Validate syntax (IMPORTANT — never skip this)
sudo visudo -c
```

If `visudo -c` reports errors, fix them before proceeding. A broken sudoers file can lock you out of the system.

---

## Step 6 — Open Oracle Cloud Security List

In Oracle Cloud Console:

1. Navigate to **Networking → Virtual Cloud Networks → Your VCN → Security Lists**
2. Add **Ingress Rules**:

| Source CIDR | Protocol | Port | Description |
|-------------|----------|------|-------------|
| `0.0.0.0/0` | TCP | 80 | HTTP (Caddy ACME challenge + redirect) |
| `0.0.0.0/0` | TCP | 443 | HTTPS |

> HTTP port 80 is required only for the initial Let's Encrypt ACME challenge and for redirecting plain HTTP requests to HTTPS. Caddy handles both automatically.

---

## Step 7 — Deploy

```bash
cd docker

# Start the stack
docker compose up -d

# Watch startup logs
docker compose logs -f

# Verify all containers are healthy
docker compose ps
```

Expected output:
```
NAME                    STATUS
vps-security-caddy      Up (healthy)
vps-security-app        Up (healthy)
```

---

## Step 8 — Verify

```bash
# Test HTTPS (replace with your domain)
curl -I https://security.yourdomain.com

# Expected: HTTP/2 200 (from your IP) or connection refused (from other IPs)
```

Open `https://security.yourdomain.com` in your browser. On first visit, you will see a **First-run setup** screen — create your admin username and password (minimum 12 characters). This account is stored in the local SQLite database. No external account or platform is required.

---

## Management Commands

```bash
# View logs
docker compose logs -f app
docker compose logs -f caddy

# Restart a service
docker compose restart app

# Update to latest version
git pull
docker compose build app
docker compose up -d app

# Stop everything
docker compose down

# Stop and remove volumes (destructive — deletes SQLite database)
docker compose down -v
```

---

## Updating Your IP Address

If your home IP changes (dynamic IP), update the Caddyfile:

```bash
nano docker/caddy/Caddyfile
# Update the remote_ip line with your new IP

docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

---

## Backup

All stateful data lives in two places:

| Data | Location | Backup method |
|------|----------|---------------|
| SQLite database | `app_data` Docker volume | See commands below |
| Caddy TLS certificates | `caddy_data` Docker volume | See commands below |

```bash
# Backup the SQLite database
docker run --rm \
  -v vps-security-dashboard_app_data:/data \
  -v $(pwd):/backup \
  alpine \
  cp /data/security-dashboard.db /backup/security-dashboard-$(date +%F).db

# Backup Caddy certificates
docker run --rm \
  -v vps-security-dashboard_caddy_data:/data \
  -v $(pwd):/backup \
  alpine \
  tar czf /backup/caddy_data_backup-$(date +%F).tar.gz /data
```

**Restore the SQLite database:**
```bash
docker run --rm \
  -v vps-security-dashboard_app_data:/data \
  -v $(pwd):/backup \
  alpine \
  cp /backup/security-dashboard-YYYY-MM-DD.db /data/security-dashboard.db

docker compose restart app
```

> **Tip:** Add a daily cron job on your VPS to automate database backups and keep the last 7 copies:
> ```bash
> 0 3 * * * cd /path/to/docker && docker run --rm -v vps-security-dashboard_app_data:/data -v $(pwd)/backups:/backup alpine cp /data/security-dashboard.db /backup/security-dashboard-$(date +\%F).db && ls -t /path/to/docker/backups/*.db | tail -n +8 | xargs rm -f
> ```

---

## Troubleshooting

### Dashboard shows "No data" for system metrics
The app container cannot reach host system commands. Verify:
1. The sudoers file is correctly installed: `sudo visudo -c`
2. The `dashboard` user exists on the host: `id dashboard`
3. Log volumes are mounted: `docker compose exec app ls /var/log/auth.log`

### Caddy cannot obtain TLS certificate
- Verify DNS is pointing to your VPS IP
- Check port 80 is open in Oracle Cloud Security List
- Check Caddy logs: `docker compose logs caddy`
- Test with staging CA first (uncomment `acme_ca` line in Caddyfile)

### 403 Forbidden on the dashboard
Your IP is not in the allowed list. Update `remote_ip` in the Caddyfile with your current IP and reload Caddy.

### Login fails with "Invalid username or password"
1. Verify you are using the credentials created during first-run setup.
2. If you have forgotten your password, reset it by running:
   ```bash
   docker compose exec app node -e "
     const bcrypt = require('bcryptjs');
     const db = require('better-sqlite3')(process.env.SQLITE_DB_PATH);
     const hash = bcrypt.hashSync('NewPassword123!', 12);
     db.prepare(\"UPDATE admins SET passwordHash = ? WHERE username = 'admin'\").run(hash);
     console.log('Password reset.');
   "
   ```
3. If no admin account exists at all, the first-run setup screen will appear automatically on next visit.

### SQLite database locked error
This occurs if the app crashed mid-write. Restart the app container:
```bash
docker compose restart app
```
If the error persists, restore from the most recent backup.

---

## Security Checklist

Before going live, verify:

- [ ] `YOUR_HOME_IP` is set correctly in Caddyfile
- [ ] `YOUR_DOMAIN` is set correctly in Caddyfile
- [ ] `JWT_SECRET` is a strong random value (`openssl rand -hex 64`)
- [ ] `.env` file has restricted permissions: `chmod 600 .env`
- [ ] Sudoers file validated with `visudo -c`
- [ ] Oracle Cloud Security List only opens ports 80 and 443
- [ ] SSH port is NOT exposed in the Security List (use VCN-level access)
- [ ] Dashboard is accessible only from your trusted IP
- [ ] SQLite backup cron job is configured
