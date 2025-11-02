# Migration Guide: From Custom Gateway to Traefik

This guide helps you migrate from the original Node.js-based gateway to the new Traefik-based solution.

## Why Migrate?

The Traefik-based solution offers several advantages:

1. **No Manual Certificate Renewal**: Automatic renewal via Cloudflare DNS
2. **Better Performance**: Optimized reverse proxy built in Go
3. **More Features**: Load balancing, metrics, middleware, and more
4. **Active Development**: Traefik is actively maintained with regular updates
5. **Enterprise Ready**: Production-tested and widely used
6. **Built-in Monitoring**: Dashboard and Prometheus metrics included

## Migration Steps

### 1. Backup Current Setup

Before migrating, backup your current certificates and configuration:

```bash
# Backup Let's Encrypt certificates
sudo cp -r /etc/letsencrypt ~/letsencrypt-backup

# Note down your current containers
docker ps --format "{{.Names}}: {{.Ports}}"
```

### 2. Prepare Cloudflare

#### Set up Cloudflare DNS

1. Transfer your domain to Cloudflare (or add it if already there)
2. Ensure your domain's nameservers point to Cloudflare
3. Add an A record pointing to your server's IP:
   ```
   Type: A
   Name: @
   Content: your.server.ip
   Proxy: Enabled (orange cloud)
   ```
4. Add a wildcard A record:
   ```
   Type: A
   Name: *
   Content: your.server.ip
   Proxy: Enabled (orange cloud)
   ```

#### Create API Token

1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Click "Create Token"
3. Use the "Edit zone DNS" template
4. Configure:
   - Permissions: `Zone - DNS - Edit`
   - Zone Resources: `Include - Specific zone - your.domain`
5. Click "Continue to summary" then "Create Token"
6. **Save the token securely** - you won't see it again!

### 3. Install Prerequisites

Ensure you have Docker and Docker Compose:

```bash
# Check Docker
docker --version

# Check Docker Compose
docker-compose --version

# If not installed, install them:
# Ubuntu/Debian:
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 4. Set Up Traefik

```bash
# Navigate to your repository
cd /path/to/gateway-poc

# Create environment file
cp .env.example .env

# Edit .env with your settings
nano .env
```

Configure these variables in `.env`:
```bash
DOMAIN=your.domain
CF_API_EMAIL=your-email@example.com
CF_DNS_API_TOKEN=your-cloudflare-api-token
LETSENCRYPT_EMAIL=your-email@example.com
TRAEFIK_DASHBOARD_USERS=admin:$$apr1$$8EVjn/nj$$GiLUZqcbueTFeD23SuB6x0
```

Create required directories:
```bash
mkdir -p letsencrypt
chmod 600 letsencrypt
```

### 5. Stop Old Gateway

Stop the Node.js gateway:

```bash
# If running as a service
sudo systemctl stop gateway

# Or if running manually
pkill -f "node.*gateway"

# Free up port 443
sudo lsof -i :443
```

### 6. Start Traefik

```bash
docker-compose -f docker-compose.traefik.yml up -d
```

Watch the logs to ensure it starts correctly:
```bash
docker-compose -f docker-compose.traefik.yml logs -f traefik
```

You should see:
- Traefik starting up
- Cloudflare DNS challenge succeeding
- Certificates being issued

### 7. Migrate Your Containers

For each container you were exposing, add Traefik labels.

**Before (Original Gateway):**
```bash
docker run -d -p 8080:80 --name myapp myapp:latest
```

The gateway automatically discovered this via port 8080 and routed `myapp.your.domain` to it.

**After (Traefik):**

Option 1 - Using docker-compose:
```yaml
services:
  myapp:
    image: myapp:latest
    container_name: myapp
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.your.domain`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=cloudflare"
      - "traefik.http.services.myapp.loadbalancer.server.port=80"

networks:
  traefik-proxy:
    external: true
```

Option 2 - Using docker run:
```bash
docker run -d \
  --name myapp \
  --network traefik-proxy \
  --label "traefik.enable=true" \
  --label "traefik.http.routers.myapp.rule=Host(\`myapp.your.domain\`)" \
  --label "traefik.http.routers.myapp.entrypoints=websecure" \
  --label "traefik.http.routers.myapp.tls.certresolver=cloudflare" \
  --label "traefik.http.services.myapp.loadbalancer.server.port=80" \
  myapp:latest
```

### 8. Container Migration Script

Here's a helper script to migrate existing containers:

```bash
#!/bin/bash
# migrate-containers.sh

# List all running containers
for container in $(docker ps --format "{{.Names}}"); do
  # Skip Traefik itself
  if [ "$container" = "traefik-gateway" ]; then
    continue
  fi
  
  # Get container's port
  port=$(docker port "$container" | head -1 | cut -d: -f2)
  
  if [ -z "$port" ]; then
    echo "Skipping $container - no exposed ports"
    continue
  fi
  
  # Get image
  image=$(docker inspect "$container" --format '{{.Config.Image}}')
  
  echo "Migrating $container..."
  
  # Stop old container
  docker stop "$container"
  docker rm "$container"
  
  # Restart with Traefik labels
  docker run -d \
    --name "$container" \
    --network traefik-proxy \
    --label "traefik.enable=true" \
    --label "traefik.http.routers.$container.rule=Host(\`$container.$DOMAIN\`)" \
    --label "traefik.http.routers.$container.entrypoints=websecure" \
    --label "traefik.http.routers.$container.tls.certresolver=cloudflare" \
    --label "traefik.http.services.$container.loadbalancer.server.port=$port" \
    "$image"
done
```

### 9. Verify Migration

Check that everything is working:

```bash
# Check Traefik is running
docker ps | grep traefik

# Check logs
docker-compose -f docker-compose.traefik.yml logs traefik

# Access the dashboard
open https://traefik.your.domain

# Test a service
curl https://myapp.your.domain
```

### 10. Clean Up Old Setup

Once everything is working:

```bash
# Remove old Node.js gateway files (optional)
# Keep them for reference or remove:
# rm -rf src/
# rm package.json

# Remove old systemd service if you had one
sudo systemctl disable gateway
sudo rm /etc/systemd/system/gateway.service
sudo systemctl daemon-reload

# The original code is still in the repository for reference
```

## Rollback Procedure

If you need to rollback to the original gateway:

```bash
# Stop Traefik
docker-compose -f docker-compose.traefik.yml down

# Restore old certificates
sudo cp -r ~/letsencrypt-backup /etc/letsencrypt

# Start old gateway
KEYPATH=/etc/letsencrypt/live/your.domain node src/gateway.js
```

## Differences to Note

### Port Binding

**Old:** Containers had to expose ports on the host
```bash
docker run -p 8080:80 myapp
```

**New:** Containers only need to be on the Traefik network
```bash
docker run --network traefik-proxy myapp
```

### Discovery Method

**Old:** Automatic by container name and port scanning
**New:** Explicit via Docker labels

### Certificate Management

**Old:** Manual renewal every 90 days
**New:** Automatic renewal via Cloudflare DNS

### Headers

**Old:** No automatic header injection
**New:** Automatic `X-Forwarded-For`, `X-Real-IP`, etc.

## Troubleshooting

### Certificates not being issued

1. Verify Cloudflare API token has DNS edit permissions
2. Check DNS propagation: `dig @1.1.1.1 _acme-challenge.your.domain TXT`
3. Review logs: `docker-compose -f docker-compose.traefik.yml logs traefik`
4. Ensure ports 80 and 443 are accessible from the internet

### Container not accessible

1. Verify container is on `traefik-proxy` network:
   ```bash
   docker network inspect traefik-proxy
   ```
2. Check labels are correct:
   ```bash
   docker inspect myapp | grep -A 10 Labels
   ```
3. Check Traefik dashboard for router status

### Performance issues

1. Check resource usage:
   ```bash
   docker stats traefik-gateway
   ```
2. Review Traefik logs for errors
3. Consider adjusting rate limiting in `traefik-dynamic.yml`

## Next Steps

After migration:

1. **Set up monitoring**: Connect Prometheus to Traefik metrics endpoint
2. **Configure backups**: Backup `letsencrypt/acme.json` regularly
3. **Review security**: Adjust security headers and TLS settings as needed
4. **Add middleware**: Explore Traefik middleware for additional features
5. **Set up CI/CD**: Use the included GitHub Actions workflow

## Support

For issues:
- Check [README.traefik.md](README.traefik.md) for detailed documentation
- Review [Traefik documentation](https://doc.traefik.io/traefik/)
- Open an issue in the repository
