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
    ├── MySQL/TiDB (Manus platform DB)
    │
    └── Host system (via volume mounts + sudoers)
         ├── /var/log (read-only)
         ├── fail2ban-client (via sudo)
         └── ufw (via sudo)
```

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
```

**Required values:**

| Variable | Description | Where to find |
|----------|-------------|---------------|
| `DATABASE_URL` | MySQL connection string | Manus project → Database panel |
| `JWT_SECRET` | Session signing key | `openssl rand -hex 64` |
| `VITE_APP_ID` | Manus OAuth app ID | Manus project → Settings |
| `OWNER_OPEN_ID` | Your Manus OpenID | Manus account settings |
| `BUILT_IN_FORGE_API_KEY` | Manus API key | Manus project → Secrets |

---

## Step 3 — Configure Caddy

Edit `docker/caddy/Caddyfile` and replace the placeholders:

```bash
nano docker/caddy/Caddyfile
```

Replace:
- `YOUR_DOMAIN` → your actual domain (e.g., `security.yourdomain.com`)
- `YOUR_HOME_IP` → your home/office IP address

**Find your IP:**
```bash
curl -s ifconfig.me
```

> **Security Note:** The IP restriction in Caddy is the single most effective security measure. It prevents the login page from being exposed to the internet entirely. Do not skip this step.

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

If `visudo -c` reports errors, fix them before proceeding. A broken sudoers file can lock you out.

---

## Step 6 — Open Oracle Cloud Security List

In Oracle Cloud Console:

1. Navigate to **Networking → Virtual Cloud Networks → Your VCN → Security Lists**
2. Add **Ingress Rules**:

| Source CIDR | Protocol | Port | Description |
|-------------|----------|------|-------------|
| `0.0.0.0/0` | TCP | 80 | HTTP (Caddy redirect) |
| `0.0.0.0/0` | TCP | 443 | HTTPS |

> HTTP port 80 is needed only for the initial ACME challenge and for redirecting to HTTPS. Caddy handles the redirect automatically.

---

## Step 7 — Deploy

```bash
cd docker

# Start the stack
docker compose up -d

# Watch startup logs
docker compose logs -f

# Verify both containers are healthy
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

# Expected: HTTP/2 200 (from your IP) or HTTP/2 403 (from other IPs)
```

Open `https://security.yourdomain.com` in your browser and sign in with your Manus account.

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

# Stop and remove volumes (destructive)
docker compose down -v
```

---

## Updating Your IP Address

If your home IP changes (dynamic IP), update the Caddyfile:

```bash
nano docker/caddy/Caddyfile
# Update the remote_ip line

docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

---

## Backup

The only stateful data is in the MySQL database (managed by Manus platform). Caddy certificates are stored in the `caddy_data` Docker volume.

```bash
# Backup Caddy certificates
docker run --rm -v vps-security-dashboard_caddy_data:/data \
    -v $(pwd):/backup alpine \
    tar czf /backup/caddy_data_backup.tar.gz /data
```

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
- Test with staging CA first (uncomment in Caddyfile)

### 403 Forbidden on the dashboard
Your IP is not in the allowed list. Update `remote_ip` in the Caddyfile with your current IP.

### Authentication fails after login
Verify `VITE_APP_ID`, `OAUTH_SERVER_URL`, and `VITE_OAUTH_PORTAL_URL` are correctly set in `.env`.

---

## Security Checklist

Before going live, verify:

- [ ] `YOUR_HOME_IP` is set correctly in Caddyfile
- [ ] `YOUR_DOMAIN` is set correctly in Caddyfile
- [ ] `JWT_SECRET` is a strong random value (64+ hex chars)
- [ ] `.env` file has `chmod 600` permissions: `chmod 600 .env`
- [ ] Sudoers file validated with `visudo -c`
- [ ] Oracle Cloud Security List only opens ports 80 and 443
- [ ] SSH port is NOT exposed in the Security List (use VCN-level access)
- [ ] Dashboard is accessible only from your IP
