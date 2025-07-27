# Blog Deployment Guide

This guide covers deploying the Phoenix LiveView blog to Fly.io with Turso (distributed SQLite) database and OpenTelemetry observability.

## Prerequisites

1. **Fly.io Account**: Sign up at [fly.io](https://fly.io)
2. **GitHub Account**: Repository hosted on GitHub
3. **Grafana Cloud Account**: For observability (optional but recommended)
4. **MaxMind Account**: For GeoIP analytics (optional)
5. **Local Development**: Blog working locally

## Fly.io Setup

### 1. Install Fly.io CLI

```bash
# macOS
brew install flyctl

# Linux
curl -L https://fly.io/install.sh | sh

# Windows
curl -fsSL https://fly.io/install.ps1 | iex
```

### 2. Login and Create App

```bash
# Login
fly auth login

# Launch app (generates fly.toml)
fly launch

# Follow prompts:
# - Choose app name
# - Select region
# - Decline PostgreSQL (we use SQLite)
# - Decline Redis
```

### 3. Configure Environment Variables

```bash
# Generate secret key base
mix phx.gen.secret

# Set required environment variables
fly secrets set SECRET_KEY_BASE=your_secret_key_here
fly secrets set PHX_HOST=your-app-name.fly.dev

# Turso database configuration (required for production)
fly secrets set LIBSQL_URI=libsql://your-database-name-your-org.turso.io
fly secrets set LIBSQL_TOKEN=your_turso_auth_token

# OpenTelemetry configuration (optional)
fly secrets set OTEL_EXPORTER_OTLP_ENDPOINT=https://otlp-gateway-prod-us-central-0.grafana.net/otlp
fly secrets set OTEL_EXPORTER_OTLP_HEADERS_AUTHORIZATION=your_base64_encoded_credentials
```

### 4. Deploy

```bash
# Deploy the application
fly deploy
```

## Database Configuration

This blog uses **Turso** (distributed SQLite) for scalability and reliability:

- **Distributed SQLite**: Global edge database with local replicas
- **Cost-effective**: Pay-per-request pricing model
- **High availability**: Built-in replication and failover
- **Perfect for blogs**: Handles read-heavy workloads with low latency
- **Automatic backups**: Turso provides built-in backup and point-in-time recovery

### Turso Configuration

The production environment uses Turso with the following configuration:
- **Database URI**: Set via `LIBSQL_URI` environment variable
- **Auth Token**: Set via `LIBSQL_TOKEN` environment variable
- **Sync Mode**: Enabled for consistency across edge locations

## GitHub Actions Setup

### Repository Secrets

Add these secrets in GitHub repository settings (Settings → Secrets and variables → Actions):

- `FLY_API_TOKEN`: Generate at https://fly.io/user/personal_access_tokens

### CI/CD Pipeline

The pipeline automatically:
- Runs tests on every push/PR
- Deploys to Fly.io on main branch pushes
- Runs code quality checks (Credo, formatting)

## Manual Deployment

If you need to deploy manually:

```bash
# Deploy current branch
fly deploy

# Deploy specific image
fly deploy --image your-image

# Check deployment status
fly status

# View logs
fly logs
```

## Environment Configuration

### Production Environment Variables

Required:
- `SECRET_KEY_BASE`: Generated with `mix phx.gen.secret`
- `PHX_HOST`: Your app's domain (your-app.fly.dev)
- `PHX_SERVER`: Set to `true` (auto-set by Fly.io)
- `LIBSQL_URI`: Turso database URI (libsql://your-db.turso.io)
- `LIBSQL_TOKEN`: Turso authentication token

Optional:
- `PORT`: HTTP port (auto-set by Fly.io to 8080)
- `MTLS_PORT`: mTLS API port (default: 8443)
- `SSL_KEYFILE`: Path to SSL private key
- `SSL_CERTFILE`: Path to SSL certificate
- `SSL_CACERTFILE`: Path to CA certificate
- `OTEL_EXPORTER_OTLP_ENDPOINT`: Grafana Cloud OTLP endpoint
- `OTEL_EXPORTER_OTLP_HEADERS_AUTHORIZATION`: Base64 encoded credentials

### Fly.io Configuration

The app uses Elixir releases without Docker:
- **Elixir**: 1.17.3
- **Erlang**: 27.2
- **Node.js**: 22.x

Key `fly.toml` settings:
```toml
[build]
# No dockerfile - uses Elixir buildpack

[deploy]
release_command = '/app/bin/migrate'

[env]
PHX_HOST = 'your-app.fly.dev'
PORT = '8080'
MTLS_PORT = '8443'
PHX_SERVER = 'true'

# Multiple port configuration for HTTP and mTLS
[[services]]
internal_port = 8080
protocol = "tcp"

[[services.ports]]
handlers = ["http"]
port = 80

[[services.ports]]
handlers = ["tls", "http"]
port = 443

# Separate service for mTLS API
[[services]]
internal_port = 8443
protocol = "tcp"

[[services.ports]]
handlers = ["tls"]
port = 8443
```

## Database Operations

### Migrations

Migrations run automatically on deployment via the release command against Turso database.

To run manually:
```bash
# Run migrations on Turso
fly ssh console -C "/app/bin/blog eval 'Blog.Release.migrate'"

# Seed Turso database
fly ssh console -C "/app/bin/blog eval 'Blog.Release.seed'"
```

### Turso Database Management

```bash
# Check Turso connection
fly ssh console -C "/app/bin/blog eval 'Blog.TursoRepo.query(\"SELECT 1\", [])'"

# List posts via Turso
fly ssh console -C "/app/bin/blog eval 'Blog.Content.list_posts() |> length()'"
```

### Console Access

```bash
# SSH into running instance
fly ssh console

# Run Elixir console
fly ssh console -C "/app/bin/blog remote"

# Run one-off commands
fly ssh console -C "/app/bin/blog eval 'Blog.Content.list_posts() |> length()'"
```

## Monitoring

### Logs
```bash
# View live logs
fly logs

# View historical logs
fly logs --app your-app-name
```

### App Status
```bash
# Check app health
fly status

# Check resource usage
fly vm status

# Check machine info
fly machine list
```

### Performance
- **Free Tier**: Limited monthly usage
- **Paid Tiers**: $1.94/month minimum for always-on apps
- **Resources**: 256MB RAM, shared CPU (configurable)

## SSL Certificates (Required for mTLS)

For mTLS API authentication, SSL certificates must be deployed:

```bash
# Copy certificates to deployment
fly deploy --build-arg SSL_CERTS=true

# Or mount certificates via secrets
fly secrets set SSL_KEYFILE_CONTENT="$(cat priv/cert/server/server-key.pem)"
fly secrets set SSL_CERTFILE_CONTENT="$(cat priv/cert/server/server-cert.pem)"
fly secrets set SSL_CACERTFILE_CONTENT="$(cat priv/cert/ca/ca.pem)"
```

**Certificate Structure Required:**
```
priv/cert/
├── ca/
│   ├── ca.pem              # Certificate Authority
│   └── ca-key.pem          # CA Private Key (keep secure)
├── server/
│   ├── server-cert.pem     # Server Certificate
│   └── server-key.pem      # Server Private Key
└── clients/
    ├── client-cert.pem     # Client Certificate Template
    └── client-key.pem      # Client Private Key Template
```

## Custom Domain (Optional)

```bash
# Add custom domain
fly certs add yourdomain.com

# Configure DNS
# Add CNAME record: yourdomain.com → your-app.fly.dev

# Update PHX_HOST
fly secrets set PHX_HOST=yourdomain.com
```

## SSL/TLS

Fly.io provides automatic SSL certificates for:
- `*.fly.dev` domains (included)
- Custom domains (free certificates)

## Troubleshooting

### Common Issues

1. **Build Failures**
   ```bash
   # Check build logs
   fly logs
   
   # Test build locally
   mix release --overwrite
   ```

2. **SQLite Permission Issues**
   ```bash
   # Ensure proper file permissions
   fly ssh console -C "ls -la /app/priv/repo/"
   ```

3. **Asset Compilation Issues**
   ```bash
   # Test assets locally
   mix assets.deploy
   ```

### Debug Commands

```bash
# Remote shell access
fly ssh console -C "/app/bin/blog remote"

# Check file system
fly ssh console -C "df -h"
fly ssh console -C "ls -la /app/priv/repo/"

# Scale app
fly scale count 2
fly scale memory 512
```

## Security Considerations

1. **Environment Variables**: Never commit secrets to version control
2. **SSL**: Enforced automatically on Fly.io
3. **Dependencies**: Keep dependencies updated
4. **SQLite**: File permissions handled by Fly.io

## Cost Management

- **Fly.io**: ~$2-5/month for small blogs
- **Turso**: Pay-per-request pricing
  - Free tier: 1M requests/month
  - Paid: $0.25 per million requests
  - Storage: $1 per GB/month
- **SSL Certificates**: Free (Let's Encrypt via Fly.io)
- **Total**: ~$3-8/month for typical blog workloads

## Backup Strategy

### Turso Database Backup

Turso provides automatic backups and point-in-time recovery:

```bash
# List database backups (via Turso CLI)
turso db backup list your-database-name

# Create manual backup
turso db backup create your-database-name

# Restore from backup
turso db backup restore your-database-name backup-id
```

### Data Export/Import

```bash
# Export data via API
fly ssh console -C "/app/bin/blog eval 'Blog.Content.export_all_posts()'"

# Import data (if needed)
fly ssh console -C "/app/bin/blog eval 'Blog.Content.import_posts(data)'"
```

## Observability Setup

### Grafana Cloud Integration

The blog includes comprehensive observability with Grafana Cloud:

1. **Create Grafana Cloud account** at https://grafana.com/auth/sign-up/create-user
2. **Get OTLP credentials** from Grafana Cloud → OpenTelemetry → Configuration
3. **Set environment variables** (shown above in step 3)
4. **Import dashboards** from `grafana-dashboards/` directory

### Available Dashboards

- **Performance Dashboard**: UI/API latency, error rates, traffic patterns
- **User Behavior Dashboard**: Geographic analytics, browser patterns, user activity

### GeoIP Analytics

For geographic user analytics:

1. **Register at MaxMind**: https://www.maxmind.com/en/geolite2/signup
2. **Download GeoIP database**: See [GEOIP_SETUP.md](GEOIP_SETUP.md)
3. **Deploy with database included** (automatic)

## Next Steps

1. Deploy your blog following this guide
2. Set up observability with Grafana Cloud (recommended)
3. Configure GeoIP analytics (optional)
4. Set up custom domain (optional)
5. Import Grafana dashboards for monitoring

For more information, visit the [Fly.io documentation](https://fly.io/docs/).