# Blog Deployment Guide

This guide covers deploying the Phoenix LiveView blog to Gigalixir with automated CI/CD.

## Prerequisites

1. **Gigalixir Account**: Sign up at [gigalixir.com](https://gigalixir.com)
2. **GitHub Account**: Repository hosted on GitHub
3. **Local Development**: Blog working locally

## Gigalixir Setup

### 1. Install Gigalixir CLI

```bash
# macOS
brew install gigalixir/brew/gigalixir

# Linux
curl -fsSL https://github.com/gigalixir/gigalixir-cli/releases/download/v1.4.0/gigalixir_linux -o gigalixir
chmod +x gigalixir
sudo mv gigalixir /usr/local/bin/
```

### 2. Login and Create App

```bash
# Login
gigalixir login

# Create app (replace 'my-blog' with your app name)
gigalixir create my-blog

# Get app info
gigalixir apps
```

### 3. Configure Database

```bash
# Create database (Free tier includes 1 database)
gigalixir pg:create --free

# Get database URL
gigalixir config
```

### 4. Set Environment Variables

```bash
# Generate secret key base
mix phx.gen.secret

# Set required environment variables
gigalixir config:set SECRET_KEY_BASE=your_secret_key_here
gigalixir config:set PHX_HOST=your-app-name.gigalixirapp.com
gigalixir config:set DATABASE_URL=your_database_url_here
gigalixir config:set POOL_SIZE=2
```

## GitHub Actions Setup

### 1. Repository Secrets

Add these secrets in GitHub repository settings (Settings → Secrets and variables → Actions):

- `GIGALIXIR_EMAIL`: Your Gigalixir account email
- `GIGALIXIR_PASSWORD`: Your Gigalixir account password  
- `GIGALIXIR_APP_NAME`: Your Gigalixir app name

### 2. CI/CD Pipeline

The pipeline automatically:
- Runs tests on every push/PR
- Deploys to Gigalixir on main branch pushes
- Runs code quality checks (Credo, formatting)

## Manual Deployment

If you need to deploy manually:

```bash
# Add Gigalixir remote
gigalixir git:remote your-app-name

# Deploy
git push gigalixir main

# Check logs
gigalixir logs

# Check app status
gigalixir ps
```

## Environment Configuration

### Production Environment Variables

Required:
- `SECRET_KEY_BASE`: Generated with `mix phx.gen.secret`
- `DATABASE_URL`: PostgreSQL connection string (auto-set by Gigalixir)
- `PHX_HOST`: Your app's domain (your-app.gigalixirapp.com)
- `PHX_SERVER`: Set to `true` (auto-set by Gigalixir)

Optional:
- `POOL_SIZE`: Database connection pool size (default: 10, recommend 2 for free tier)
- `PORT`: HTTP port (auto-set by Gigalixir)

### Build Configuration

The app uses these buildpacks (defined in `.buildpacks`):
1. Clean cache buildpack
2. Elixir buildpack  
3. Phoenix static buildpack
4. Mix buildpack

Build settings:
- **Elixir**: 1.17.2
- **Erlang**: 27.0
- **Node.js**: 20.11.0
- **NPM**: 10.2.4

## Database Migrations

Migrations run automatically on deployment. To run manually:

```bash
# Run migrations
gigalixir run mix ecto.migrate

# Seed database (if needed)
gigalixir run mix run priv/repo/seeds.exs

# Access remote console
gigalixir run iex -S mix
```

## Monitoring

### Logs
```bash
# View live logs
gigalixir logs

# View logs with filters
gigalixir logs --num=100
gigalixir logs --app=your-app-name
```

### App Status
```bash
# Check app health
gigalixir ps

# Check config
gigalixir config

# Check database status
gigalixir pg:info
```

### Performance
- **Free Tier**: 0.5 CPU, 512MB RAM
- **Paid Tiers**: Scalable resources available
- **Database**: 10,000 rows max on free tier

## Custom Domain (Optional)

```bash
# Add custom domain
gigalixir domains:add yourdomain.com

# Configure DNS
# Add CNAME record: yourdomain.com → your-app.gigalixirapp.com

# Set PHX_HOST to your domain
gigalixir config:set PHX_HOST=yourdomain.com
```

## SSL/TLS

Gigalixir provides automatic SSL certificates for:
- `*.gigalixirapp.com` domains (included)
- Custom domains (free Let's Encrypt certificates)

## Troubleshooting

### Common Issues

1. **Build Failures**
   ```bash
   # Check build logs
   gigalixir logs --num=200
   
   # Verify buildpack configuration
   cat .buildpacks
   ```

2. **Database Connection Issues**
   ```bash
   # Check database status
   gigalixir pg:info
   
   # Verify DATABASE_URL
   gigalixir config | grep DATABASE_URL
   ```

3. **Asset Compilation Issues**
   ```bash
   # Test assets locally
   mix assets.deploy
   
   # Check Node.js/NPM versions in phoenix_static_buildpack.config
   ```

### Debug Commands

```bash
# Remote shell access
gigalixir run iex -S mix

# Run specific commands
gigalixir run mix ecto.migrate
gigalixir run mix test

# Scale app (paid tiers)
gigalixir scale --replicas=2
```

## Security Considerations

1. **Environment Variables**: Never commit secrets to version control
2. **Database**: Use connection pooling (POOL_SIZE=2 for free tier)
3. **SSL**: Enforced automatically on Gigalixir
4. **Dependencies**: Keep dependencies updated

## Cost Management

- **Free Tier**: $0/month, includes:
  - 1 app instance
  - PostgreSQL database (10k rows)
  - SSL certificate
  - Custom domains

- **Paid Tiers**: Start at $10/month for production workloads

## Next Steps

1. Deploy your blog following this guide
2. Set up monitoring and alerting
3. Configure backup strategies
4. Consider CDN for static assets (if needed)
5. Set up error tracking (Sentry, etc.)

For more information, visit the [Gigalixir documentation](https://gigalixir.readthedocs.io/).