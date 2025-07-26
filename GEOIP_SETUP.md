# GeoIP Setup Guide

This blog uses MaxMind's GeoLite2 Country database for lightweight geographic analytics.

## Quick Setup

### 1. Get a MaxMind License Key (Free)

1. Register at https://www.maxmind.com/en/geolite2/signup
2. Verify your email
3. Generate a license key in your account
4. Copy the license key

### 2. Download the Database

```bash
export MAXMIND_LICENSE_KEY=your_license_key_here
./download_geoip.sh
```

This downloads the GeoLite2-Country.mmdb file (~6MB) to `priv/geoip/`.

### 3. Deploy

The database is automatically included in production releases. No additional configuration needed.

## What You Get

### Log Data Enhancement
Each HTTP request now includes:
- `country`: Country name (e.g., "United States")
- `country_code`: ISO country code (e.g., "US") 
- `ip_type`: Classification (public/private/localhost)

### Dashboard Analytics
- Traffic by country
- Geographic user behavior patterns
- Network type analysis (public vs private IPs)

## Fallback Behavior

Without the database, the system gracefully falls back to:
- Private networks: `country="Private Network", country_code="PN"`
- Localhost: `country="Localhost", country_code="LH"`
- Unknown IPs: `country="Unknown", country_code="XX"`

## Database Updates

MaxMind updates GeoLite2 databases weekly. To update:

```bash
rm priv/geoip/GeoLite2-Country.mmdb
./download_geoip.sh
```

Then redeploy your application.

## Size Impact

- **Database size**: ~6MB
- **Release size increase**: ~11%
- **Memory usage**: +6MB RAM
- **Performance**: <0.1ms per lookup

This is a lightweight solution that provides 90% of the geographic analytics value with minimal overhead.