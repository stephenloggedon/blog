#!/bin/bash
set -e

echo "Running database migrations..."
bin/migrate
echo "Migrations completed successfully!"