#!/bin/bash

# iOS Certificate Generation Script
# Run this to generate CSR for Apple Developer Console

echo "🔐 Generating iOS Certificate Signing Request (CSR)..."

# Create directory for certificates
mkdir -p ios_certificates
cd ios_certificates

# Generate private key and CSR
openssl req -new -newkey rsa:2048 -nodes \
    -keyout gavra_ios_private.key \
    -out gavra_ios.csr \
    -subj "/C=RS/ST=Serbia/L=Belgrade/O=Gavra013/OU=Development/CN=Gavra Android App/emailAddress=your.email@example.com"

echo "✅ Files generated:"
echo "📄 gavra_ios.csr - Upload this to Apple Developer Console"
echo "🔑 gavra_ios_private.key - Keep this safe, needed for certificate conversion"

echo ""
echo "📋 Next steps:"
echo "1. Upload gavra_ios.csr to Apple Developer Console"
echo "2. Download the certificate (.cer file)" 
echo "3. Run the certificate conversion script"

ls -la
