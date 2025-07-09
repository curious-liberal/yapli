#!/bin/bash

# Create docker-data directories
echo "Creating docker-data directories..."
mkdir -p docker-data/traefik/logs
mkdir -p docker-data/postgres
mkdir -p docker-data/backup

# Create acme.json with correct permissions
echo "Setting up acme.json for SSL certificates..."
touch docker-data/traefik/acme.json
chmod 600 docker-data/traefik/acme.json

# Create external network for Traefik
echo "Creating Docker network..."
docker network create proxy 2>/dev/null || echo "Network 'proxy' already exists"

# Copy environment file
if [ ! -f .env.production ]; then
    echo "Creating .env.production from template..."
    cp .env.example .env.production
    echo ""
    echo "⚠️  Please edit .env.production with your actual values:"
    echo "   - Database credentials"
    echo "   - NEXTAUTH_SECRET (generate with: openssl rand -base64 64)"
    echo "   - ALLOWED_ORIGINS"
    echo "   - DOMAIN"
    echo "   - Cloudflare API credentials"
fi

echo ""
echo "✅ Setup complete! Next steps:"
echo "1. Edit .env.production with your configuration"
echo "2. Run: docker compose -f docker-compose.production.yml up -d"
echo "3. Check logs: docker compose -f docker-compose.production.yml logs -f"