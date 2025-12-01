#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 🚀 Huawei AppGallery Connect - Full Upload Script
# 
# This script uploads an AAB/APK to AppGallery Connect and optionally submits
# for review. Based on the MCP client implementation.
#
# Required environment variables:
#   AGC_CLIENT_ID     - API Client ID from AppGallery Connect Console
#   AGC_CLIENT_SECRET - API Client Secret
#   AGC_APP_ID        - Your app's ID in AppGallery Connect
#
# Optional:
#   AGC_SUBMIT_FOR_REVIEW - Set to "true" to auto-submit after upload
###############################################################################

# Validate required environment variables
if [[ -z "${AGC_CLIENT_ID:-}" || -z "${AGC_CLIENT_SECRET:-}" || -z "${AGC_APP_ID:-}" ]]; then
  echo "❌ Missing required AGC env vars: AGC_CLIENT_ID, AGC_CLIENT_SECRET, AGC_APP_ID"
  exit 1
fi

# API endpoints
AUTH_URL="https://connect-api.cloud.huawei.com/api/oauth2/v1/token"
API_BASE="https://connect-api.cloud.huawei.com/api/publish/v2"

# Artifact path
ARTIFACT="${ARTIFACT_PATH:-build/app/outputs/bundle/release/app-release.aab}"
SUFFIX="aab"

# Check if APK instead
if [[ "$ARTIFACT" == *.apk ]]; then
  SUFFIX="apk"
fi

echo "=============================================="
echo "🚀 Huawei AppGallery Connect Upload Script"
echo "=============================================="
echo "📱 App ID: ${AGC_APP_ID}"
echo "📦 Artifact: ${ARTIFACT}"
echo "=============================================="

###############################################################################
# Step 1: Get OAuth Token
###############################################################################
echo ""
echo "🔐 Step 1: Fetching OAuth token..."

TOKEN_RESPONSE=$(curl -s -X POST \
  -H 'Content-Type: application/json' \
  -d "{\"grant_type\":\"client_credentials\",\"client_id\":\"${AGC_CLIENT_ID}\",\"client_secret\":\"${AGC_CLIENT_SECRET}\"}" \
  "$AUTH_URL")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "❌ Failed to obtain access token"
  echo "Response: $TOKEN_RESPONSE"
  exit 1
fi

echo "✅ Got access token (expires in $(echo "$TOKEN_RESPONSE" | sed -n 's/.*"expires_in":\([0-9]*\).*/\1/p') seconds)"

###############################################################################
# Step 2: Check artifact exists
###############################################################################
echo ""
echo "📦 Step 2: Checking artifact..."

if [[ ! -f "$ARTIFACT" ]]; then
  echo "❌ Artifact not found: $ARTIFACT"
  echo "Run 'flutter build appbundle --release' first"
  exit 1
fi

FILE_SIZE=$(stat -c%s "$ARTIFACT" 2>/dev/null || stat -f%z "$ARTIFACT" 2>/dev/null || echo "unknown")
echo "✅ Found artifact: $ARTIFACT ($FILE_SIZE bytes)"

###############################################################################
# Step 3: Get Upload URL
###############################################################################
echo ""
echo "🔗 Step 3: Getting upload URL..."

UPLOAD_URL_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "client_id: ${AGC_CLIENT_ID}" \
  "${API_BASE}/upload-url?appId=${AGC_APP_ID}&suffix=${SUFFIX}")

# Get HTTP status code (last line)
HTTP_STATUS=$(echo "$UPLOAD_URL_RESPONSE" | tail -n1)
UPLOAD_URL_BODY=$(echo "$UPLOAD_URL_RESPONSE" | sed '$d')

echo "HTTP Status: $HTTP_STATUS"
echo "Upload URL response body: $UPLOAD_URL_BODY"

# Parse response using grep/sed
UPLOAD_URL=$(echo "$UPLOAD_URL_BODY" | grep -oP '"uploadUrl"\s*:\s*"\K[^"]+' || true)
AUTH_CODE=$(echo "$UPLOAD_URL_BODY" | grep -oP '"authCode"\s*:\s*"\K[^"]+' || true)
RET_CODE=$(echo "$UPLOAD_URL_BODY" | grep -oP '"code"\s*:\s*\K[0-9]+' || true)

echo "Parsed uploadUrl: ${UPLOAD_URL:-<empty>}"
echo "Parsed authCode: ${AUTH_CODE:-<empty>}"
echo "Parsed ret code: ${RET_CODE:-<empty>}"

if [[ -z "$UPLOAD_URL" || -z "$AUTH_CODE" ]]; then
  echo "❌ Failed to get upload URL"
  echo "Full response: $UPLOAD_URL_BODY"
  
  # Check for common errors
  if echo "$UPLOAD_URL_BODY" | grep -q "permission"; then
    echo "⚠️ Possible permission issue - check API client permissions in AppGallery Connect"
  fi
  if echo "$UPLOAD_URL_BODY" | grep -q "appId"; then
    echo "⚠️ Possible appId issue - verify AGC_APP_ID is correct"
  fi
  
  exit 1
fi

echo "✅ Got upload URL"

###############################################################################
# Step 4: Upload the file
###############################################################################
echo ""
echo "📤 Step 4: Uploading file to AppGallery..."

UPLOAD_RESPONSE=$(curl -s -X POST \
  -F "file=@${ARTIFACT}" \
  -F "authCode=${AUTH_CODE}" \
  -F "fileCount=1" \
  "$UPLOAD_URL")

echo "Upload response: $UPLOAD_RESPONSE"

# Parse file URL from response
FILE_DEST_URL=$(echo "$UPLOAD_RESPONSE" | sed -n 's/.*"fileDestUlr":"\([^"]*\)".*/\1/p')

if [[ -z "$FILE_DEST_URL" ]]; then
  echo "❌ Upload failed or couldn't parse fileDestUlr"
  exit 1
fi

echo "✅ File uploaded successfully!"
echo "   File URL: ${FILE_DEST_URL:0:80}..."

###############################################################################
# Step 5: Update app file info
###############################################################################
echo ""
echo "📝 Step 5: Updating app file info..."

FILENAME=$(basename "$ARTIFACT")

UPDATE_RESPONSE=$(curl -s -X PUT \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "client_id: ${AGC_CLIENT_ID}" \
  -H "Content-Type: application/json" \
  -d "{\"appId\":\"${AGC_APP_ID}\",\"files\":[{\"fileName\":\"${FILENAME}\",\"fileDestUrl\":\"${FILE_DEST_URL}\"}]}" \
  "${API_BASE}/app-file-info")

echo "Update response: $UPDATE_RESPONSE"

UPDATE_CODE=$(echo "$UPDATE_RESPONSE" | sed -n 's/.*"code":\([0-9]*\).*/\1/p')

if [[ "$UPDATE_CODE" != "0" ]]; then
  echo "⚠️ Warning: Update file info returned code $UPDATE_CODE"
  echo "This might be okay - the file may still be processing"
fi

echo "✅ App file info updated!"

###############################################################################
# Step 6: Submit for review (optional)
###############################################################################
if [[ "${AGC_SUBMIT_FOR_REVIEW:-false}" == "true" ]]; then
  echo ""
  echo "🚀 Step 6: Submitting for review..."
  
  SUBMIT_RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "client_id: ${AGC_CLIENT_ID}" \
    -H "Content-Type: application/json" \
    -d "{\"appId\":\"${AGC_APP_ID}\"}" \
    "${API_BASE}/app-submit")
  
  echo "Submit response: $SUBMIT_RESPONSE"
  
  SUBMIT_CODE=$(echo "$SUBMIT_RESPONSE" | sed -n 's/.*"code":\([0-9]*\).*/\1/p')
  
  if [[ "$SUBMIT_CODE" == "0" ]]; then
    echo "✅ App submitted for review!"
  else
    echo "⚠️ Submit returned code $SUBMIT_CODE - check AppGallery Connect console"
  fi
else
  echo ""
  echo "ℹ️ Step 6: Skipping review submission (set AGC_SUBMIT_FOR_REVIEW=true to enable)"
fi

###############################################################################
# Done!
###############################################################################
echo ""
echo "=============================================="
echo "🎉 Upload complete!"
echo "=============================================="
echo ""
echo "Next steps:"
echo "  1. Go to AppGallery Connect Console"
echo "  2. Check your app's 'Version Information'"
echo "  3. Complete any missing metadata"
echo "  4. Submit for review when ready"
echo ""
echo "Console: https://developer.huawei.com/consumer/en/service/josp/agc/index.html"
echo "=============================================="
