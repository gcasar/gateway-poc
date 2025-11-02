#!/bin/bash

# Traefik Gateway Setup Script
# This script helps you set up the Traefik gateway with Cloudflare integration

set -e

echo "=================================="
echo "Traefik Gateway Setup"
echo "=================================="
echo

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_info() {
    echo -e "${GREEN}ℹ${NC} $1"
}

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    echo "Visit: https://docs.docker.com/get-docker/"
    exit 1
fi
print_success "Docker is installed"

if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    echo "Visit: https://docs.docker.com/compose/install/"
    exit 1
fi
print_success "Docker Compose is installed"

echo

# Check if .env exists
if [ -f .env ]; then
    print_warning ".env file already exists"
    read -p "Do you want to overwrite it? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Keeping existing .env file"
        ENV_EXISTS=true
    fi
fi

if [ "$ENV_EXISTS" != "true" ]; then
    echo "Setting up environment variables..."
    
    # Domain
    read -p "Enter your domain name (e.g., example.com): " DOMAIN
    while [ -z "$DOMAIN" ]; do
        print_error "Domain cannot be empty"
        read -p "Enter your domain name: " DOMAIN
    done
    
    # Cloudflare email
    read -p "Enter your Cloudflare email: " CF_EMAIL
    while [ -z "$CF_EMAIL" ]; do
        print_error "Email cannot be empty"
        read -p "Enter your Cloudflare email: " CF_EMAIL
    done
    
    # Cloudflare API token
    echo
    print_info "You need a Cloudflare API token with DNS edit permissions"
    print_info "Create one at: https://dash.cloudflare.com/profile/api-tokens"
    print_info "Use the 'Edit zone DNS' template"
    echo
    read -p "Enter your Cloudflare API token: " CF_TOKEN
    while [ -z "$CF_TOKEN" ]; do
        print_error "API token cannot be empty"
        read -p "Enter your Cloudflare API token: " CF_TOKEN
    done
    
    # Let's Encrypt email
    read -p "Enter email for Let's Encrypt notifications [$CF_EMAIL]: " LE_EMAIL
    LE_EMAIL=${LE_EMAIL:-$CF_EMAIL}
    
    # Dashboard password
    echo
    print_info "Setting up Traefik dashboard authentication"
    read -p "Enter username for dashboard [admin]: " DASH_USER
    DASH_USER=${DASH_USER:-admin}
    read -s -p "Enter password for dashboard: " DASH_PASS
    echo
    
    if command -v htpasswd &> /dev/null; then
        DASH_HASH=$(htpasswd -nb "$DASH_USER" "$DASH_PASS" | sed -e s/\\$/\\$\\$/g)
    else
        print_warning "htpasswd not found, using default password hash"
        print_warning "Install apache2-utils to set custom password"
        DASH_HASH="admin:\$\$apr1\$\$8EVjn/nj\$\$GiLUZqcbueTFeD23SuB6x0"
    fi
    
    # Create .env file
    cat > .env << EOF
# Traefik Gateway Configuration
# Generated on $(date)

# Domain configuration
DOMAIN=$DOMAIN

# Cloudflare API credentials
CF_API_EMAIL=$CF_EMAIL
CF_DNS_API_TOKEN=$CF_TOKEN

# Let's Encrypt configuration
LETSENCRYPT_EMAIL=$LE_EMAIL

# Traefik dashboard authentication
TRAEFIK_DASHBOARD_USERS=$DASH_HASH
EOF
    
    print_success "Created .env file"
fi

echo

# Create required directories
echo "Creating required directories..."
mkdir -p letsencrypt
chmod 600 letsencrypt
print_success "Created letsencrypt directory"

echo

# Create Traefik network if it doesn't exist
if ! docker network inspect traefik-proxy &> /dev/null; then
    echo "Creating traefik-proxy network..."
    docker network create traefik-proxy
    print_success "Created traefik-proxy network"
else
    print_success "traefik-proxy network already exists"
fi

echo

# Ask if user wants to start Traefik now
read -p "Do you want to start Traefik now? (Y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "Starting Traefik..."
    docker-compose -f docker-compose.traefik.yml up -d
    
    echo
    print_success "Traefik is starting up!"
    echo
    
    # Wait a bit and check status
    sleep 3
    if docker ps | grep -q traefik-gateway; then
        print_success "Traefik is running"
        echo
        echo "You can access:"
        echo "  - Dashboard: https://traefik.$DOMAIN"
        echo "  - Example service: https://whoami.$DOMAIN"
        echo
        echo "View logs with: docker-compose -f docker-compose.traefik.yml logs -f traefik"
    else
        print_error "Traefik failed to start. Check logs with:"
        echo "docker-compose -f docker-compose.traefik.yml logs traefik"
    fi
else
    echo
    print_info "To start Traefik later, run:"
    echo "docker-compose -f docker-compose.traefik.yml up -d"
fi

echo
echo "=================================="
print_success "Setup complete!"
echo "=================================="
echo
print_info "Next steps:"
echo "  1. Verify DNS records point to this server"
echo "  2. Wait for SSL certificates to be issued (check logs)"
echo "  3. Add your services using Docker labels (see README.traefik.md)"
echo
print_info "Documentation:"
echo "  - README.traefik.md - Complete guide"
echo "  - MIGRATION.md - Migration from original gateway"
echo "  - examples/ - Example configurations"
echo
