# Examples Directory

This directory contains example configurations for common use cases with Traefik.

## Available Examples

### 1. WordPress (`wordpress.yml`)
Complete WordPress setup with MySQL database and Traefik integration.

**Usage:**
```bash
# Set your domain and passwords in .env
export DOMAIN=example.com
export WORDPRESS_DB_PASSWORD=secure_password
export WORDPRESS_DB_ROOT_PASSWORD=secure_root_password

# Start WordPress
docker-compose -f examples/wordpress.yml up -d
```

Access at: `https://blog.example.com`

### 2. Node.js Application (`nodejs-app.yml`)
Example Node.js application with health checks and rate limiting.

**Features:**
- Health check endpoint
- Rate limiting (100 req/s average, 50 burst)
- Compression
- Security headers

**Usage:**
```bash
# Build and start your Node.js app
docker-compose -f examples/nodejs-app.yml up -d
```

Access at: `https://app.example.com`

### 3. Multi-Service Setup (`multi-service.yml`)
Example of running multiple services with different routing strategies.

**Features:**
- Path-based routing (`/` for frontend, `/api` for backend)
- Subdomain routing (`admin.domain.com`)
- CORS configuration
- IP whitelisting for admin
- Path prefix stripping

**Usage:**
```bash
docker-compose -f examples/multi-service.yml up -d
```

Access:
- Frontend: `https://example.com/`
- API: `https://example.com/api`
- Admin: `https://admin.example.com`

## General Usage

All examples assume:
1. Traefik is already running (via `docker-compose.traefik.yml`)
2. The `traefik-proxy` network exists
3. Environment variables are set in `.env`

## Customization

Each example can be customized by:
- Modifying labels for different routing rules
- Adding middleware for additional features
- Changing service configurations
- Adjusting network settings

## Common Middleware

Here are common middleware you can use:

### Rate Limiting
```yaml
- "traefik.http.middlewares.my-ratelimit.ratelimit.average=100"
- "traefik.http.middlewares.my-ratelimit.ratelimit.burst=50"
```

### Basic Auth
```yaml
# Generate: htpasswd -nb user password
- "traefik.http.middlewares.my-auth.basicauth.users=user:$$apr1$$..."
```

### IP Whitelist
```yaml
- "traefik.http.middlewares.my-ipwhitelist.ipwhitelist.sourcerange=192.168.1.0/24"
```

### CORS Headers
```yaml
- "traefik.http.middlewares.my-cors.headers.accesscontrolallowmethods=GET,POST"
- "traefik.http.middlewares.my-cors.headers.accesscontrolalloworiginlist=https://example.com"
```

### Compression
```yaml
- "traefik.http.middlewares.my-compress.compress=true"
```

### Redirect Regex
```yaml
- "traefik.http.middlewares.my-redirect.redirectregex.regex=^https://www.example.com/(.*)"
- "traefik.http.middlewares.my-redirect.redirectregex.replacement=https://example.com/$${1}"
```

### Strip Prefix
```yaml
- "traefik.http.middlewares.my-strip.stripprefix.prefixes=/api,/v1"
```

## Tips

1. **Priority**: Use `priority` to control route matching order (higher number = higher priority)
2. **Networks**: Always use the `traefik-proxy` network for services that need to be exposed
3. **Health Checks**: Add health checks for better reliability
4. **Middleware Chain**: Chain multiple middleware with commas: `middleware1,middleware2,middleware3`

## Testing

Test your configuration before deploying:

```bash
# Validate docker-compose file
docker-compose -f examples/your-example.yml config

# Start in foreground to see logs
docker-compose -f examples/your-example.yml up

# Check if service is accessible
curl -I https://your-service.example.com
```

## More Information

See [README.traefik.md](../README.traefik.md) for complete documentation.
