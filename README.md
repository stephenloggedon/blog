# stephenloggedon-blog

A Phoenix LiveView blog with advanced search and filtering capabilities.

## Features
- Real-time search with tag autocomplete
- Multi-tag filtering with OR logic  
- Responsive design with Catppuccin color scheme
- Markdown content rendering
- Infinite scroll pagination
- Single-user authentication with 2FA TOTP (optional)
- RESTful API with mTLS authentication
- OpenTelemetry observability (logs, traces, metrics)
- Geographic analytics with GeoIP lookup
- Comprehensive Grafana dashboards

## Tech Stack
- Phoenix LiveView + Turso (distributed SQLite)
- Tailwind CSS + Catppuccin theme
- OpenTelemetry with Grafana Cloud integration
- MaxMind GeoIP for geographic analytics
- Deployed on Fly.io with GitHub Actions CI/CD
- No authentication required for reading blog posts

## Development Setup

1. **Clone and install dependencies:**
   ```bash
   git clone <repository>
   cd blog
   mix setup
   ```

2. **Start the development server:**
   ```bash
   mix phx.server
   ```

3. **Visit** http://localhost:4000

The app includes seed data with sample blog posts for testing.

## Documentation

- [DEPLOYMENT.md](DEPLOYMENT.md) - Fly.io deployment with Turso database
- [API_DOCUMENTATION.md](API_DOCUMENTATION.md) - RESTful API with mTLS authentication
- [GEOIP_SETUP.md](GEOIP_SETUP.md) - Geographic analytics setup

## Observability

The blog includes comprehensive observability:
- **Structured logging** with OpenTelemetry
- **Grafana Cloud integration** for logs and traces
- **Geographic analytics** with MaxMind GeoIP
- **Performance monitoring** with separate UI/API dashboards
- **User behavior tracking** with browser and location analytics

Built with Phoenix LiveView for real-time interactivity.
