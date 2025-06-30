# Blog Deployment Guide

This guide covers deploying the Phoenix LiveView blog to Fly.io with SQLite database.

## Prerequisites

1. **Fly.io Account**: Sign up at [fly.io](https://fly.io)
2. **GitHub Account**: Repository hosted on GitHub
3. **Local Development**: Blog working locally

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
```

### 4. Deploy

```bash
# Deploy the application
fly deploy
```

## Database Configuration

This blog uses **SQLite** for simplicity and cost-effectiveness:

- **No external database required**: SQLite file is stored with the app
- **Zero cost**: No database service fees
- **Perfect for blogs**: Handles typical blog workloads efficiently
- **Automatic backups**: Include SQLite file in volume snapshots

### SQLite File Location

The SQLite database is stored at `/app/priv/repo/blog_prod.db` in production.

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

Optional:
- `DATABASE_URL`: Override default SQLite path
- `POOL_SIZE`: Database connection pool size (default: 5)
- `PORT`: HTTP port (auto-set by Fly.io to 8080)

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
PHX_SERVER = 'true'
```

## Database Operations

### Migrations

Migrations run automatically on deployment via the release command.

To run manually:
```bash
# Run migrations
fly ssh console -C "/app/bin/blog eval 'Blog.Release.migrate'"

# Seed database
fly ssh console -C "/app/bin/blog eval 'Blog.Release.seed'"
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

## Volumes (Optional)

For persistent SQLite storage across deployments:

```bash
# Create volume
fly volume create blog_data --region lax --size 1

# Update fly.toml
[mounts]
source = "blog_data"
destination = "/data"
```

Then update `config/runtime.exs`:
```elixir
database: "/data/blog_prod.db"
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

- **Free Tier**: Limited monthly allowance
- **Paid Plans**: ~$2-5/month for small blogs
- **No Database Costs**: SQLite eliminates database service fees

## Backup Strategy

### SQLite Backup
```bash
# Download SQLite database
fly ssh console -C "cat /app/priv/repo/blog_prod.db" > backup.db

# Upload SQLite database
cat backup.db | fly ssh console -C "cat > /app/priv/repo/blog_prod.db"
```

### Volume Snapshots (if using volumes)
```bash
# Create snapshot
fly volume snapshot create blog_data

# List snapshots
fly volume snapshot list
```

## Next Steps

1. Deploy your blog following this guide
2. Set up custom domain (optional)
3. Configure monitoring and logging
4. Set up backup automation
5. Consider error tracking (Sentry, etc.)

For more information, visit the [Fly.io documentation](https://fly.io/docs/).