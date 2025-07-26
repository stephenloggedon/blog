# OpenTelemetry Observability Setup Guide

This guide will help you set up comprehensive observability for the Phoenix blog application using OpenTelemetry and Grafana Cloud.

## Overview

The application includes:
- **Automatic instrumentation** for HTTP requests, database queries, and LiveView events
- **Custom business metrics** for post views, search analytics, and API usage
- **User behavior tracking** including browser/device detection and referrer analysis
- **Error tracking** and performance monitoring

## 1. Grafana Cloud Setup

### Create Account
1. Go to [grafana.com](https://grafana.com) and create a free account
2. You'll get access to:
   - 50 GB traces per month
   - 50 GB logs per month  
   - 10k metrics series per month
   - 14-day retention
   - Forever free tier

### Get OpenTelemetry Credentials
1. In your Grafana Cloud dashboard, navigate to **"Connections"**
2. Click **"Add new connection"** 
3. Select **"OpenTelemetry"**
4. Copy the following information:
   - **OTLP Endpoint URL** (e.g., `https://otlp-gateway-prod-us-central-0.grafana.net/otlp`)
   - **Instance ID** (usually a number like `12345`)
   - **API Token** (create one with "MetricsPublisher" role)

## 2. Environment Variables

Create these environment variables in your deployment environment:

```bash
# Grafana Cloud OpenTelemetry Configuration
export OTEL_EXPORTER_OTLP_ENDPOINT="https://otlp-gateway-prod-us-central-0.grafana.net/otlp"
export OTEL_EXPORTER_OTLP_HEADERS_AUTHORIZATION="your-instance-id:your-api-token-base64-encoded"
```

### Creating the Authorization Header
The authorization header needs to be base64 encoded in the format `instance_id:api_token`:

```bash
# Example (replace with your actual credentials)
echo -n "12345:glc_eyJvIjoiNzA3..." | base64
# Result: MTIzNDU6Z2xjX2V5Sm5JaU9qRTJOekE...
```

## 3. Development Environment

For local development, you can set these in your `.env` file:

```bash
# .env file (do not commit this to version control)
OTEL_EXPORTER_OTLP_ENDPOINT=https://otlp-gateway-prod-us-central-0.grafana.net/otlp
OTEL_EXPORTER_OTLP_HEADERS_AUTHORIZATION=MTIzNDU6Z2xjX2V5Sm5JaU9qRTJOekE...
```

Then load them before starting your application:
```bash
source .env
mix phx.server
```

## 4. Production Deployment

Set the environment variables in your production environment:

### Fly.io
```bash
fly secrets set OTEL_EXPORTER_OTLP_ENDPOINT="https://otlp-gateway-prod-us-central-0.grafana.net/otlp"
fly secrets set OTEL_EXPORTER_OTLP_HEADERS_AUTHORIZATION="your-base64-encoded-auth"
```

### Heroku
```bash
heroku config:set OTEL_EXPORTER_OTLP_ENDPOINT="https://otlp-gateway-prod-us-central-0.grafana.net/otlp"
heroku config:set OTEL_EXPORTER_OTLP_HEADERS_AUTHORIZATION="your-base64-encoded-auth"
```

### Docker
```dockerfile
ENV OTEL_EXPORTER_OTLP_ENDPOINT=https://otlp-gateway-prod-us-central-0.grafana.net/otlp
ENV OTEL_EXPORTER_OTLP_HEADERS_AUTHORIZATION=your-base64-encoded-auth
```

## 5. Metrics Being Collected

### Automatic Metrics
- **HTTP requests**: Response times, status codes, route information
- **Database queries**: Execution time, connection pool usage, query details
- **LiveView events**: Mount/unmount times, event handling performance
- **System metrics**: Memory usage, process information, garbage collection

### Custom Business Metrics
- **Post views**: Track which posts are viewed, by whom, and from where
- **Search analytics**: Search queries, result counts, tag selections
- **API usage**: Endpoint access patterns, authentication success/failure
- **User behavior**: Browser/device breakdown, referrer sources, navigation patterns

### User Information Tracked
- **Browser**: Chrome, Firefox, Safari, Edge with version numbers
- **Device type**: Desktop, Mobile, Tablet detection
- **Referrer**: Where users came from (Google, direct, social media, etc.)
- **User agent**: Full user agent string for detailed analysis
- **IP address**: For geographic analysis (respecting privacy)

## 6. Grafana Dashboard Setup

Once data starts flowing to Grafana Cloud (usually within 1-2 minutes), you can:

### Import Pre-built Dashboards
1. Go to **Dashboards** → **Browse**
2. Click **"New"** → **"Import"**
3. Search for "Phoenix" or "Elixir" community dashboards
4. Import relevant dashboards for your metrics

### Create Custom Dashboards
Key metrics to visualize:
- **Traffic Overview**: Requests per minute, response times, error rates
- **Content Analytics**: Most viewed posts, popular tags, search queries
- **User Analytics**: Browser breakdown, device types, referrer sources
- **Performance**: Database query times, LiveView performance, memory usage

### Example Queries
```promql
# Requests per minute
rate(http_request_duration_seconds_count[5m])

# Average response time
rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])

# Most viewed posts
topk(10, sum by (post_title) (blog_post_view_total))

# Error rate
rate(http_request_duration_seconds_count{status_code=~"5.."}[5m]) / rate(http_request_duration_seconds_count[5m])
```

## 7. Alerting Setup

Set up basic alerts for:
- **High error rate**: >5% 4xx/5xx responses
- **Slow responses**: Average response time >2 seconds
- **Database issues**: Query time >1 second
- **High traffic**: Unusual spike in requests

## 8. Privacy Considerations

The analytics system respects privacy by:
- **No personal data**: Only tracking anonymous usage patterns
- **IP anonymization**: Can be configured to mask IP addresses
- **GDPR compliance**: Data stored in Grafana Cloud follows GDPR guidelines
- **Configurable**: Easy to disable or modify tracking as needed

## 9. Troubleshooting

### No Data Appearing in Grafana
1. Check environment variables are set correctly
2. Verify base64 encoding of authorization header
3. Check application logs for OpenTelemetry errors
4. Ensure OTLP endpoint URL is correct (include `/otlp` path)

### Testing Locally
You can test the setup by running:
```bash
# Check if instrumentation is working
curl -v http://localhost:4000/api/posts

# Check logs for telemetry information
mix phx.server
```

Look for OpenTelemetry traces in your application output and verify they appear in Grafana Cloud within 1-2 minutes.

## 10. Next Steps

Once basic observability is working:
1. **Create custom dashboards** for your specific use cases
2. **Set up alerting** for critical metrics
3. **Add more custom metrics** as your application grows
4. **Explore distributed tracing** for complex request flows
5. **Consider upgrading** to paid Grafana Cloud tier if you need more retention or data volume

The current setup provides comprehensive observability that will scale with your blog's growth while remaining free for typical blog traffic levels.