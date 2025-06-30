# stephenloggedon-blog

A Phoenix LiveView blog with advanced search and filtering capabilities.

## Features
- Real-time search with tag autocomplete
- Multi-tag filtering with OR logic  
- Responsive design with Catppuccin color scheme
- Markdown content rendering
- Infinite scroll pagination
- Single-user authentication with 2FA TOTP (optional)

## Tech Stack
- Phoenix LiveView + SQLite
- Tailwind CSS + Catppuccin theme
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

## Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for Fly.io deployment instructions.

Built with Phoenix LiveView for real-time interactivity.
