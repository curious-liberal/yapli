# Local Development Setup

## Quick Start (Recommended)

```bash
# 1. Install dependencies
npm install

# 2. Start local PostgreSQL and setup database
./start-local.sh

# 3. Start the development server
npm run dev
```

Visit http://localhost:3000

## Manual Setup

If the quick start doesn't work, here's what you need:

### Prerequisites
- Node.js 18+
- Docker (or Docker Desktop)
- npm or yarn

### Step 1: Environment Setup
Create a `.env` file:
```bash
# Database
DATABASE_URL="postgresql://yapli_user:localpassword123@localhost:5432/yapli_local"

# NextAuth.js
NEXTAUTH_URL="http://localhost:3000"
NEXTAUTH_SECRET="local-dev-secret-change-in-production"
```

### Step 2: Start PostgreSQL
```bash
docker compose -f docker-compose.local.yml up -d
```

### Step 3: Setup Database
```bash
# Run migrations
npx prisma migrate dev

# Generate Prisma client
npx prisma generate
```

### Step 4: Start Development Server
```bash
npm run dev
```

## Common Issues

### "Permission denied" with Docker
If you get permission errors:
1. Add your user to the docker group: `sudo usermod -aG docker $USER`
2. Log out and back in
3. Or use `sudo` before docker commands

### Port Already in Use
If port 5432 is taken:
1. Stop existing PostgreSQL: `sudo systemctl stop postgresql`
2. Or change the port in docker-compose.local.yml

### Database Connection Failed
1. Check PostgreSQL is running: `docker ps`
2. Check logs: `docker logs yapli_postgres_local`
3. Ensure DATABASE_URL in .env matches the container settings

## Available Commands

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run lint` - Run linting
- `npx prisma studio` - Open database GUI
- `docker compose -f docker-compose.local.yml down` - Stop PostgreSQL

## Production Deployment

For production deployment with Traefik, SSL, and security features, see:
- [DEPLOYMENT_SECURITY.md](./DEPLOYMENT_SECURITY.md)
- Use `docker-compose.production.yml` instead