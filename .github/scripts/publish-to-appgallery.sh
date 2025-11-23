#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${AGC_CLIENT_ID:-}" || -z "${AGC_CLIENT_SECRET:-}" || -z "${AGC_APP_ID:-}" ]]; then
  echo "Missing required AGC env vars: AGC_CLIENT_ID, AGC_CLIENT_SECRET, AGC_APP_ID"
  exit 1
fi

echo "Fetching OAuth token from Huawei..."
TOKEN_RESPONSE=$(curl -s -X POST \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=client_credentials&client_id=${AGC_CLIENT_ID}&client_secret=${AGC_CLIENT_SECRET}" \
  https://oauth-login.cloud.huawei.com/oauth2/v3/token)

echo "Token response: $TOKEN_RESPONSE"

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "Failed to obtain access token — please verify AGC_CLIENT_ID / AGC_CLIENT_SECRET"
  exit 1
fi

echo "SUCCESS: Got access_token (first 32 chars): ${ACCESS_TOKEN:0:32}..."

ARTIFACT=build/app/outputs/bundle/release/app-release.aab

echo "Next: checking for built artifact and available upload method..."
if [[ ! -f "$ARTIFACT" ]]; then
  echo "No AAB artifact found at $ARTIFACT — build it first (flutter build appbundle --release)"
  exit 0
fi

echo "Artifact found: $ARTIFACT"

# Prefer using an installed AGC CLI if available (recommended for reliability)
if command -v agc >/dev/null 2>&1 || command -v appgallery >/dev/null 2>&1; then
  echo "AGC/AppGallery CLI detected — call it here to upload/publish the artifact (replace with your CLI args)."
  echo "Example (placeholder):"
  echo "  agc publish app --appId ${AGC_APP_ID} --file ${ARTIFACT} --token ${ACCESS_TOKEN}"
  echo "Please replace the above command with the specific CLI call you wish to use in your CI environment."
  exit 0
fi

echo "AGC CLI not detected — falling back to REST guidance."
cat <<'DOC'
Helpful options to finish app upload (REST sketch):

- AppGallery Connect REST API: Supports programmatic upload and publishing but requires multiple steps. This script only obtains an OAuth token; the exact upload endpoints are region/tenancy-dependent and need to be called carefully.

General flow (sketch):
1) Obtain OAuth token (already done above).
2) Call AppGallery Connect upload/init endpoint to register the upload and get upload target URLs and an uploadId.
3) Upload the AAB file to the provided URL(s) — often this is a multipart PUT or multipart/form-data POST depending on the region.
4) Call the finalize/commit endpoint so AppGallery Connect can process the uploaded artifact and create a new release.

Security note: Keep your AGC_CLIENT_ID / AGC_CLIENT_SECRET / AGC_APP_ID in CI secrets and avoid printing full tokens to logs in production.

If you'd like I can implement a full REST flow in this script for your project (I will need a sample successful API response or permission to run against a test AppGallery Connect project so I can verify exact endpoint variants for your region).

DOC

# Conservative REST-based upload attempt
# NOTE: AppGallery Connect API variants differ by region; this script tries the common v2 endpoints.
BASE=${AGC_API_BASE:-https://connect-api.cloud.huawei.com/api/publish/v2}

echo "Using API base: $BASE"

echo "1) Initiating upload registration..."
INIT_RESP=$(curl -s -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H 'Content-Type: application/json' \
  -d "{\"fileName\": \"$(basename "$ARTIFACT")\", \"fileType\": 1}" \
  "$BASE/app-file/upload-url/create?appId=${AGC_APP_ID}") || true

echo "Init response: $INIT_RESP"

# Try to parse common fields
UPLOAD_URL=$(echo "$INIT_RESP" | sed -n 's/.*"uploadUrl":"\([^"]*\)".*/\1/p' || true)
UPLOAD_URL_ALT=$(echo "$INIT_RESP" | sed -n 's/.*"uploadUrlList":\[\{.*"uploadUrl":"\([^"]*\)".*/\1/p' || true)
FILE_ID=$(echo "$INIT_RESP" | sed -n 's/.*"fileId":"\([^"]*\)".*/\1/p' || true)

if [[ -z "$UPLOAD_URL" && -n "$UPLOAD_URL_ALT" ]]; then
  UPLOAD_URL=$UPLOAD_URL_ALT
fi

if [[ -z "$UPLOAD_URL" ]]; then
  echo "Could not find upload URL in init response. The API might be different for your account/region."
  echo "You can set AGC_API_BASE to the correct base URL for publish API or use the AGC CLI instead."
  exit 0
fi

echo "Found upload URL. Uploading artifact (this may take a while)..."

curl --fail -X PUT \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"${ARTIFACT}" \
  "$UPLOAD_URL"

if [[ $? -ne 0 ]]; then
  echo "Upload failed. Check the upload URL and network access."
  exit 1
fi

echo "Upload finished. Committing upload..."

if [[ -n "$FILE_ID" ]]; then
  COMMIT_RESP=$(curl -s -X POST \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H 'Content-Type: application/json' \
    -d "{\"fileId\": \"${FILE_ID}\"}" \
    "$BASE/app-file/commit?appId=${AGC_APP_ID}") || true
  echo "Commit response: $COMMIT_RESP"
else
  echo "No fileId to commit — you may need to call a different finalize endpoint depending on API response." 
fi

echo "Done — uploaded $ARTIFACT. If commit was successful, check AppGallery Connect for new upload processing status and release creation."

exit 0
