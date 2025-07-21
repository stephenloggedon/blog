#!/bin/bash

# Script to generate test certificates for CI/testing
# This script creates self-signed certificates for testing purposes only

set -e

echo "Generating test certificates for CI..."

# Create certificate directories
mkdir -p priv/cert/ca
mkdir -p priv/cert/server  
mkdir -p priv/cert/clients

# Generate CA private key
openssl genrsa -out priv/cert/ca/ca-key.pem 4096

# Generate CA certificate
openssl req -new -x509 -days 365 -key priv/cert/ca/ca-key.pem -out priv/cert/ca/ca.pem -subj "/C=US/ST=Test/L=Test/O=Test-CA/OU=Test/CN=Test-CA"

# Generate server private key
openssl genrsa -out priv/cert/server/server-key.pem 4096

# Generate server certificate signing request
openssl req -new -key priv/cert/server/server-key.pem -out priv/cert/server/server.csr -subj "/C=US/ST=Test/L=Test/O=Test-Server/OU=Test/CN=localhost"

# Generate server certificate signed by CA
openssl x509 -req -days 365 -in priv/cert/server/server.csr -CA priv/cert/ca/ca.pem -CAkey priv/cert/ca/ca-key.pem -CAcreateserial -out priv/cert/server/server-cert.pem

# Generate client private key
openssl genrsa -out priv/cert/clients/client-key.pem 4096

# Generate client certificate signing request
openssl req -new -key priv/cert/clients/client-key.pem -out priv/cert/clients/client.csr -subj "/C=US/ST=Test/L=Test/O=Test-Client/OU=Test/CN=test-client"

# Generate client certificate signed by CA
openssl x509 -req -days 365 -in priv/cert/clients/client.csr -CA priv/cert/ca/ca.pem -CAkey priv/cert/ca/ca-key.pem -CAcreateserial -out priv/cert/clients/client-cert.pem

# Copy client cert to test-auth-cert.pem for tests
cp priv/cert/clients/client-cert.pem priv/cert/clients/test-auth-cert.pem

# Generate invalid certificate (self-signed, not signed by CA)
openssl req -x509 -newkey rsa:2048 -keyout priv/cert/clients/invalid-key.pem -out priv/cert/clients/invalid-cert.pem -days 365 -nodes -subj "/C=US/ST=Test/L=Test/O=Invalid/OU=Test/CN=invalid-test"

# Clean up CSRs
rm -f priv/cert/server/server.csr priv/cert/clients/client.csr

echo "Test certificates generated successfully!"
echo "Generated files:"
echo "- CA: priv/cert/ca/ca.pem"
echo "- Server: priv/cert/server/server-cert.pem"
echo "- Client: priv/cert/clients/client-cert.pem"
echo "- Test client: priv/cert/clients/test-auth-cert.pem"
echo "- Invalid client: priv/cert/clients/invalid-cert.pem"