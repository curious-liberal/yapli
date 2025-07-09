# Production Security Deployment Guide

## Security Architecture Overview

```
[Internet] → [Cloudflare] → [Server Firewall] → [Traefik] → [Docker Container] → [Application]
                ↓                    ↓                ↓              ↓                  ↓
            DDoS Protection    fail2ban/iptables  Rate Limit    App Isolation    App Security
```

## Layer 1: Cloudflare Configuration

### DNS Settings
```
Type  Name    Content         Proxy Status
A     @       YOUR_SERVER_IP  Proxied (Orange Cloud)
A     www     YOUR_SERVER_IP  Proxied (Orange Cloud)
```

### Cloudflare Security Settings

1. **SSL/TLS**
   - Mode: Full (strict)
   - Minimum TLS: 1.2
   - Enable HSTS

2. **Security Level**
   - Set to: High
   - Challenge Passage: 30 minutes

3. **Rate Limiting Rules** (Page Rules)
   ```
   Rule 1: /api/auth/* - 10 requests per minute
   Rule 2: /api/rooms/*/messages - 60 requests per minute
   Rule 3: /* - 100 requests per minute
   ```

4. **WAF Rules**
   - Enable OWASP Core Ruleset
   - Block countries (if applicable)
   - Custom rule for SQL injection patterns

5. **DDoS Protection**
   - Sensitivity: High
   - Enable "I'm Under Attack" mode if needed

## Layer 2: Server Firewall & fail2ban

### UFW Configuration
```bash
# Basic firewall rules
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp          # SSH (consider changing port)
sudo ufw allow 80/tcp          # HTTP (Traefik)
sudo ufw allow 443/tcp         # HTTPS (Traefik)
sudo ufw enable
```

### fail2ban Configuration

1. **Install fail2ban**
```bash
sudo apt-get update
sudo apt-get install fail2ban
```

2. **Create jail.local**
```ini
# /etc/fail2ban/jail.local
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = 22
logpath = %(sshd_log)s
maxretry = 3

[traefik-auth]
enabled = true
port = http,https
filter = traefik-auth
logpath = /var/log/traefik/access.log
maxretry = 5
bantime = 900

[docker-yapli]
enabled = true
filter = docker-yapli
logpath = /var/lib/docker/containers/*/*-json.log
maxretry = 10
findtime = 60
bantime = 600
```

3. **Create filter for Traefik**
```ini
# /etc/fail2ban/filter.d/traefik-auth.conf
[Definition]
failregex = ^<HOST> .* "(GET|POST) /(api/auth|api/login).* HTTP/.*" 401 .*$
ignoreregex =
```

4. **Create filter for Yapli app**
```ini
# /etc/fail2ban/filter.d/docker-yapli.conf
[Definition]
failregex = ^.*CORS blocked request from:.*<HOST>.*$
            ^.*Failed login attempt.*<HOST>.*$
            ^.*Rate limit exceeded.*<HOST>.*$
ignoreregex =
```

## Layer 3: Traefik Configuration

### docker-compose.yml
```yaml
version: '3.8'

services:
  traefik:
    image: traefik:v3.0
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik/traefik.yml:/traefik.yml:ro
      - ./traefik/acme.json:/acme.json
      - ./traefik/logs:/logs
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.entrypoints=http"
      - "traefik.http.routers.traefik.rule=Host(`traefik.yourdomain.com`)"
      - "traefik.http.middlewares.traefik-auth.basicauth.users=admin:$$2y$$10$$..." 
      - "traefik.http.middlewares.traefik-https-redirect.redirectscheme.scheme=https"
      - "traefik.http.routers.traefik.middlewares=traefik-https-redirect"
      - "traefik.http.routers.traefik-secure.entrypoints=https"
      - "traefik.http.routers.traefik-secure.rule=Host(`traefik.yourdomain.com`)"
      - "traefik.http.routers.traefik-secure.middlewares=traefik-auth"
      - "traefik.http.routers.traefik-secure.tls=true"
      - "traefik.http.routers.traefik-secure.tls.certresolver=cloudflare"
      - "traefik.http.routers.traefik-secure.service=api@internal"

  zest_app:
    build: .
    restart: unless-stopped
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - NEXTAUTH_URL=${NEXTAUTH_URL}
      - NEXTAUTH_SECRET=${NEXTAUTH_SECRET}
      - ALLOWED_ORIGINS=${ALLOWED_ORIGINS}
    depends_on:
      zest_postgres:
        condition: service_healthy
    labels:
      - "traefik.enable=true"
      
      # HTTP to HTTPS redirect
      - "traefik.http.routers.zest.entrypoints=http"
      - "traefik.http.routers.zest.rule=Host(`yourdomain.com`, `www.yourdomain.com`)"
      - "traefik.http.routers.zest.middlewares=https-redirect"
      
      # HTTPS router
      - "traefik.http.routers.zest-secure.entrypoints=https"
      - "traefik.http.routers.zest-secure.rule=Host(`yourdomain.com`, `www.yourdomain.com`)"
      - "traefik.http.routers.zest-secure.tls=true"
      - "traefik.http.routers.zest-secure.tls.certresolver=cloudflare"
      
      # Middlewares
      - "traefik.http.routers.zest-secure.middlewares=zest-headers,zest-ratelimit,zest-auth-ratelimit"
      
      # Security headers
      - "traefik.http.middlewares.zest-headers.headers.frameDeny=true"
      - "traefik.http.middlewares.zest-headers.headers.sslRedirect=true"
      - "traefik.http.middlewares.zest-headers.headers.browserXssFilter=true"
      - "traefik.http.middlewares.zest-headers.headers.contentTypeNosniff=true"
      - "traefik.http.middlewares.zest-headers.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.zest-headers.headers.stsPreload=true"
      - "traefik.http.middlewares.zest-headers.headers.stsSeconds=31536000"
      - "traefik.http.middlewares.zest-headers.headers.customResponseHeaders.X-Robots-Tag=noindex,nofollow"
      
      # General rate limiting
      - "traefik.http.middlewares.zest-ratelimit.ratelimit.average=100"
      - "traefik.http.middlewares.zest-ratelimit.ratelimit.period=1m"
      - "traefik.http.middlewares.zest-ratelimit.ratelimit.burst=50"
      
      # Auth endpoint rate limiting (stricter)
      - "traefik.http.middlewares.zest-auth-ratelimit.ratelimit.average=10"
      - "traefik.http.middlewares.zest-auth-ratelimit.ratelimit.period=1m"
      - "traefik.http.middlewares.zest-auth-ratelimit.ratelimit.burst=5"
      
      # Service
      - "traefik.http.services.zest.loadbalancer.server.port=3000"

  zest_postgres:
    image: postgres:17-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
```

### traefik.yml
```yaml
api:
  dashboard: true
  debug: false

entryPoints:
  http:
    address: ":80"
    http:
      redirections:
        entrypoint:
          to: https
          scheme: https
  https:
    address: ":443"

certificatesResolvers:
  cloudflare:
    acme:
      email: your-email@example.com
      storage: acme.json
      dnsChallenge:
        provider: cloudflare
        resolvers:
          - "1.1.1.1:53"
          - "1.0.0.1:53"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false

log:
  level: INFO
  filePath: /logs/traefik.log

accessLog:
  filePath: /logs/access.log
  bufferingSize: 100
  filters:
    statusCodes:
      - "400-499"
      - "500-599"
```

## Layer 4: Application Security

### 1. Install Rate Limiting
```bash
npm install express-rate-limit redis @redis/client
```

### 2. Create Rate Limit Middleware
```typescript
// src/lib/rateLimiter.ts
import rateLimit from 'express-rate-limit';
import { createClient } from '@redis/client';
import RedisStore from 'rate-limit-redis';

const redisClient = createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379',
});

redisClient.connect().catch(console.error);

// General API rate limit
export const apiLimiter = rateLimit({
  store: new RedisStore({
    client: redisClient,
    prefix: 'rl:api:',
  }),
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 100,
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});

// Strict auth rate limit
export const authLimiter = rateLimit({
  store: new RedisStore({
    client: redisClient,
    prefix: 'rl:auth:',
  }),
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5,
  message: 'Too many authentication attempts, please try again later.',
  skipSuccessfulRequests: true,
});

// Message rate limit per user
export const messageLimiter = rateLimit({
  store: new RedisStore({
    client: redisClient,
    prefix: 'rl:msg:',
  }),
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 30,
  keyGenerator: (req) => req.session?.user?.id || req.ip,
  message: 'Slow down! Too many messages.',
});
```

### 3. Apply to API Routes
```typescript
// src/app/api/auth/[...nextauth]/route.ts
import { authLimiter } from '@/lib/rateLimiter';

export async function POST(req: Request) {
  // Apply rate limiting
  await authLimiter.check(req);
  // ... rest of auth logic
}
```

## Layer 5: Monitoring & Alerts

### 1. Prometheus + Grafana Setup
```yaml
# Add to docker-compose.yml
prometheus:
  image: prom/prometheus
  volumes:
    - ./prometheus.yml:/etc/prometheus/prometheus.yml
    - prometheus_data:/prometheus
  command:
    - '--config.file=/etc/prometheus/prometheus.yml'
    - '--storage.tsdb.path=/prometheus'

grafana:
  image: grafana/grafana
  environment:
    - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
  volumes:
    - grafana_data:/var/lib/grafana
```

### 2. Alert Configuration
```yaml
# prometheus/alerts.yml
groups:
  - name: security
    rules:
      - alert: HighFailedLoginRate
        expr: rate(failed_login_total[5m]) > 10
        annotations:
          summary: "High failed login rate detected"
          
      - alert: RateLimitTriggered
        expr: rate(rate_limit_triggered_total[5m]) > 50
        annotations:
          summary: "High rate limit triggers"
          
      - alert: SuspiciousTraffic
        expr: rate(cors_blocked_total[5m]) > 20
        annotations:
          summary: "High CORS block rate"
```

## Security Checklist

### Pre-Deployment
- [ ] Cloudflare DNS configured and proxied
- [ ] SSL certificates working
- [ ] Environment variables set
- [ ] Redis running for rate limiting
- [ ] Logs directories created with proper permissions

### Post-Deployment
- [ ] Verify rate limiting at each layer
- [ ] Test fail2ban rules
- [ ] Check security headers (securityheaders.com)
- [ ] Run SSL test (ssllabs.com)
- [ ] Monitor logs for first 24 hours
- [ ] Set up alerts for security events

### Maintenance
- [ ] Weekly: Review fail2ban logs
- [ ] Monthly: Update dependencies
- [ ] Quarterly: Security audit
- [ ] Annually: Penetration testing

## Emergency Procedures

### Under Attack
1. Enable Cloudflare "Under Attack" mode
2. Tighten rate limits temporarily
3. Review logs for attack patterns
4. Block specific IPs/ranges if needed
5. Scale infrastructure if legitimate traffic

### Incident Response
1. Isolate affected systems
2. Preserve logs
3. Identify attack vector
4. Patch vulnerability
5. Document lessons learned