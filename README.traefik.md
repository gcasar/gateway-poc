# Traefik Gateway with Cloudflare Integration

This is an improved version of the gateway-poc using **Traefik** and **Cloudflare** for automatic SSL certificate management and reverse proxy functionality.

## 🌟 Features

- **Automatic SSL Certificates**: Uses Let's Encrypt with Cloudflare DNS-01 challenge (no manual certificate renewal!)
- **Docker Auto-Discovery**: Automatically discovers and routes to Docker containers
- **Wildcard Certificates**: Supports `*.your.domain` with automatic renewal
- **Security Headers**: Built-in security headers and middleware
- **Real IP Support**: Properly handles `X-Forwarded-For` and `X-Real-IP` headers
- **Prometheus Metrics**: Built-in metrics endpoint for monitoring
- **Dashboard**: Web UI for monitoring and configuration
- **CI/CD Pipeline**: GitHub Actions workflow for validation and testing

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- A domain registered with Cloudflare
- Cloudflare API token with DNS edit permissions

### Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd gateway-poc
   ```

2. **Create environment file**
   ```bash
   cp .env.example .env
   ```

3. **Configure environment variables**
   
   Edit `.env` and set:
   - `DOMAIN`: Your domain name (e.g., `example.com`)
   - `CF_API_EMAIL`: Your Cloudflare account email
   - `CF_DNS_API_TOKEN`: Your Cloudflare API token (see below)
   - `LETSENCRYPT_EMAIL`: Email for Let's Encrypt notifications
   - `TRAEFIK_DASHBOARD_USERS`: Dashboard authentication (see below)

4. **Create Cloudflare API Token**
   
   Go to https://dash.cloudflare.com/profile/api-tokens and create a token with:
   - Permissions: `Zone - DNS - Edit`
   - Zone Resources: `Include - Specific Zone - your.domain`

5. **Generate Dashboard Password** (optional)
   ```bash
   echo $(htpasswd -nb admin yourpassword) | sed -e s/\\$/\\$\\$/g
   ```
   
   Copy the output to `TRAEFIK_DASHBOARD_USERS` in `.env`

6. **Create required directories**
   ```bash
   mkdir -p letsencrypt
   chmod 600 letsencrypt
   ```

7. **Start the stack**
   ```bash
   docker-compose -f docker-compose.traefik.yml up -d
   ```

8. **Verify it's working**
   ```bash
   docker-compose -f docker-compose.traefik.yml logs -f traefik
   ```

## 📦 Adding Services

To expose a Docker container through the gateway, add these labels:

```yaml
services:
  myapp:
    image: myapp:latest
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.${DOMAIN}`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=cloudflare"
      - "traefik.http.services.myapp.loadbalancer.server.port=80"

networks:
  traefik-proxy:
    external: true
```

Or for a standalone container:

```bash
docker run -d \
  --name myapp \
  --network traefik-proxy \
  --label "traefik.enable=true" \
  --label "traefik.http.routers.myapp.rule=Host(\`myapp.example.com\`)" \
  --label "traefik.http.routers.myapp.entrypoints=websecure" \
  --label "traefik.http.routers.myapp.tls.certresolver=cloudflare" \
  --label "traefik.http.services.myapp.loadbalancer.server.port=80" \
  myapp:latest
```

## 🔍 Monitoring

### Traefik Dashboard

Access the dashboard at: `https://traefik.your.domain`

Default credentials: `admin:admin` (change this!)

### Prometheus Metrics

Metrics are available at: `http://localhost:8082/metrics`

Example metrics:
- `traefik_entrypoint_requests_total`
- `traefik_entrypoint_request_duration_seconds`
- `traefik_router_requests_total`

### Logs

View logs:
```bash
docker-compose -f docker-compose.traefik.yml logs -f traefik
```

## 🔒 Security Features

### Automatic HTTPS

All HTTP traffic is automatically redirected to HTTPS.

### Security Headers

The following headers are automatically added:
- `X-Frame-Options: DENY`
- `X-Content-Type-Options: nosniff`
- `X-XSS-Protection: 1; mode=block`
- `Strict-Transport-Security: max-age=31536000`

### Cloudflare IP Validation

Traffic is validated against Cloudflare IP ranges to ensure it comes through Cloudflare.

### TLS Configuration

- Minimum TLS version: 1.2
- Modern cipher suites only
- Perfect Forward Secrecy enabled

## 🔧 Configuration

### Traefik Static Configuration

Edit `traefik.yml` for static configuration:
- Entry points (ports)
- Certificate resolvers
- Provider settings
- Logging configuration

### Traefik Dynamic Configuration

Edit `traefik-dynamic.yml` for dynamic configuration:
- Middlewares
- TLS options
- Router rules
- Service definitions

### Environment Variables

All environment-specific settings are in `.env`:
- Domain configuration
- API credentials
- Email addresses
- Authentication settings

## 🧪 Testing

The CI/CD pipeline automatically tests:
- Configuration validation
- YAML linting
- Security scanning
- Integration testing

Run tests locally:
```bash
# Validate configuration
docker-compose -f docker-compose.traefik.yml config

# Validate Traefik config
docker run --rm \
  -v $(pwd)/traefik.yml:/traefik.yml:ro \
  -v $(pwd)/traefik-dynamic.yml:/traefik-dynamic.yml:ro \
  -e DOMAIN=example.com \
  -e LETSENCRYPT_EMAIL=test@example.com \
  traefik:v2.10 \
  traefik --configFile=/traefik.yml --dry-run
```

## 🆚 Comparison with Original Implementation

| Feature | Original (Node.js) | New (Traefik + Cloudflare) |
|---------|-------------------|----------------------------|
| SSL Certificates | Manual renewal every 90 days | Automatic renewal |
| DNS Challenge | Not supported | Cloudflare DNS-01 |
| Container Discovery | Custom Docker API | Built-in Docker provider |
| Headers | Not supported | X-Forwarded-For, X-Real-IP |
| Metrics | Not supported | Prometheus metrics |
| Dashboard | Not available | Web UI included |
| Load Balancing | Not supported | Built-in |
| Rate Limiting | Not supported | Configurable middleware |
| Security Headers | Not supported | Built-in |
| CI/CD | Not included | GitHub Actions |

## 🛠️ Troubleshooting

### Certificate Issues

If certificates aren't being issued:

1. Check Cloudflare API token permissions
2. Verify DNS records are propagated
3. Check logs: `docker-compose -f docker-compose.traefik.yml logs traefik`
4. Ensure `letsencrypt/acme.json` has correct permissions (600)

### Container Not Accessible

1. Verify the container is on the `traefik-proxy` network
2. Check labels are correct
3. Ensure `traefik.enable=true` is set
4. Check Traefik dashboard for router status

### Dashboard Not Accessible

1. Verify `DOMAIN` in `.env` is correct
2. Check DNS points to your server
3. Verify Cloudflare proxy (orange cloud) is enabled
4. Check authentication credentials

## 🔧 Maintenance

### Updating Cloudflare IP Ranges

The Cloudflare IP whitelist in `traefik-dynamic.yml` should be updated periodically:

1. Check current ranges: https://www.cloudflare.com/ips/
2. Update the `cloudflare-ip` middleware in `traefik-dynamic.yml`
3. Reload Traefik: `docker compose -f docker-compose.traefik.yml restart traefik`

**Recommended:** Check for updates quarterly or when Cloudflare announces changes.

### Updating Traefik

To update to a newer Traefik version:

```bash
# Pull latest image
docker pull traefik:v2.10

# Restart stack
docker compose -f docker-compose.traefik.yml down
docker compose -f docker-compose.traefik.yml up -d
```

## 📚 Additional Resources

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Cloudflare API Tokens](https://developers.cloudflare.com/api/tokens/)
- [Let's Encrypt DNS-01 Challenge](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge)
- [Docker Labels Reference](https://doc.traefik.io/traefik/routing/providers/docker/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: GitHub Actions will validate on PR
5. Submit a pull request

## 📝 License

ISC License - see LICENSE file for details

## 🙏 Acknowledgments

- Original gateway-poc implementation
- Traefik community
- Cloudflare for DNS services
