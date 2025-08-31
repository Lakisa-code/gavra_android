#!/bin/bash

# Convert Apple certificate to P12 and Base64 for GitHub Secrets
# Run this after downloading certificate from Apple Developer Console

if [ ! -f "ios_distribution.cer" ]; then
    echo "❌ Error: ios_distribution.cer not found!"
    echo "Please download the certificate from Apple Developer Console and save it as 'ios_distribution.cer'"
    exit 1
fi

if [ ! -f "gavra_ios_private.key" ]; then
    echo "❌ Error: gavra_ios_private.key not found!"
    echo "Please run generate_csr.sh first"
    exit 1
fi

echo "🔄 Converting certificate to P12 format..."

# Convert certificate to P12
openssl x509 -in ios_distribution.cer -inform DER -out ios_distribution.pem -outform PEM
openssl pkcs12 -export -out ios_distribution.p12 -inkey gavra_ios_private.key -in ios_distribution.pem -password pass:GavraApp2025

echo "🔄 Converting to Base64 for GitHub Secrets..."

# Convert to base64
base64 -i ios_distribution.p12 -o certificate_base64.txt

echo "✅ Files generated:"
echo "📄 ios_distribution.p12 - Certificate file"
echo "📄 certificate_base64.txt - For GitHub Secret: IOS_CERTIFICATE_BASE64"

echo ""
echo "🔐 GitHub Secrets to add:"
echo "IOS_CERTIFICATE_BASE64 = $(cat certificate_base64.txt)"
echo "IOS_CERTIFICATE_PASSWORD = GavraApp2025"

echo ""
echo "📋 Next step: Create Provisioning Profile in Apple Developer Console"
