#!/bin/bash

echo "🚀 Starting Yapli Local Development Environment"

# Check if .env exists, if not create from example
if [ ! -f .env ]; then
    echo "📝 Creating .env file..."
    cat > .env << EOL
# Database
DATABASE_URL="postgresql://yapli_user:localpassword123@localhost:5432/yapli_local"

# NextAuth.js
NEXTAUTH_URL="http://localhost:3000"
NEXTAUTH_SECRET="local-dev-secret-change-in-production"

# CORS (not needed for local dev)
# ALLOWED_ORIGINS=""
EOL
fi

# Start only PostgreSQL
echo "🐘 Starting PostgreSQL..."
docker compose -f docker-compose.local.yml up -d

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 5

# Run migrations
echo "🔄 Running database migrations..."
npx prisma migrate deploy 2>/dev/null || npx prisma migrate dev

# Seed database if needed
if [ -f "prisma/seed.ts" ] || [ -f "prisma/seed.js" ]; then
    echo "🌱 Seeding database..."
    npx prisma db seed
fi

echo ""
echo "✅ Local environment ready!"
echo ""
echo "To start the app, run:"
echo "  npm run dev"
echo ""
echo "Database is available at:"
echo "  postgresql://yapli_user:localpassword123@localhost:5432/yapli_local"
echo ""
echo "To stop PostgreSQL later:"
echo "sudo docker compose -f docker-compose.local.yml down"