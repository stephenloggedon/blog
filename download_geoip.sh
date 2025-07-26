#!/bin/bash

# Download MaxMind GeoLite2 Country database (lightweight)
# Note: You'll need to register for a free MaxMind account and get a license key
# Register at: https://www.maxmind.com/en/geolite2/signup
# Set your license key as: export MAXMIND_LICENSE_KEY=your_key_here

set -e

GEOIP_DIR="priv/geoip"
MAXMIND_BASE_URL="https://download.maxmind.com/app/geoip_download"

if [ -z "$MAXMIND_LICENSE_KEY" ]; then
    echo "Error: MAXMIND_LICENSE_KEY environment variable is not set"
    echo ""
    echo "To get a free license key:"
    echo "1. Register at https://www.maxmind.com/en/geolite2/signup"
    echo "2. Generate a license key in your account"
    echo "3. Set it as: export MAXMIND_LICENSE_KEY=your_key_here"
    echo "4. Run this script again"
    exit 1
fi

echo "Creating GeoIP directory..."
mkdir -p "$GEOIP_DIR"

echo "Downloading MaxMind GeoLite2-Country database..."
curl -f -o "$GEOIP_DIR/GeoLite2-Country.tar.gz" \
    "$MAXMIND_BASE_URL?edition_id=GeoLite2-Country&license_key=$MAXMIND_LICENSE_KEY&suffix=tar.gz"

if [ $? -ne 0 ]; then
    echo "Error: Failed to download database. Check your license key."
    exit 1
fi

echo "Extracting database..."
cd "$GEOIP_DIR"

# Extract Country database
tar -xzf GeoLite2-Country.tar.gz
find . -name "GeoLite2-Country.mmdb" -exec mv {} . \;
rm -rf GeoLite2-Country_*
rm GeoLite2-Country.tar.gz

echo ""
echo "✅ GeoIP Country database downloaded successfully!"
echo "File size: $(du -h GeoLite2-Country.mmdb | cut -f1)"
echo "Location: $(pwd)/GeoLite2-Country.mmdb"
echo ""
echo "The database is now ready for use in production deployments."