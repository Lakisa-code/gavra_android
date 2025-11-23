#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 /path/to/agc-apiclient.json"
  exit 1
fi

JSON_PATH="$1"
if [ ! -f "$JSON_PATH" ]; then
  echo "File not found: $JSON_PATH"
  exit 1
fi

CLIENT_ID=$(jq -r '.client_id // .clientId' "$JSON_PATH")
CLIENT_SECRET=$(jq -r '.client_secret // .clientSecret' "$JSON_PATH")
PROJECT_ID=$(jq -r '.project_id // .projectId' "$JSON_PATH")

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ] || [ -z "$PROJECT_ID" ]; then
  echo "Warning: missing one of client_id / client_secret / project_id in JSON"
fi

echo "Setting GitHub secrets (AGC_CLIENT_ID / AGC_CLIENT_SECRET / AGC_APP_ID)"
gh secret set AGC_CLIENT_ID --body "$CLIENT_ID" || echo "gh set AGC_CLIENT_ID failed"
gh secret set AGC_CLIENT_SECRET --body "$CLIENT_SECRET" || echo "gh set AGC_CLIENT_SECRET failed"
gh secret set AGC_APP_ID --body "$PROJECT_ID" || echo "gh set AGC_APP_ID failed"

if command -v supabase >/dev/null 2>&1; then
  echo "Setting Supabase secrets (AGC_APICLIENT_JSON / AGC_APP_ID)"
  supabase secrets set AGC_APICLIENT_JSON --value "$(cat "$JSON_PATH")" || echo "supabase set AGC_APICLIENT_JSON failed"
  supabase secrets set AGC_APP_ID --value "$PROJECT_ID" || echo "supabase set AGC_APP_ID failed"
else
  echo "Supabase CLI not installed — skipping Supabase secrets"
fi

echo "Done. Trigger CI publish by running scripts/trigger-publish.sh or create a release/tag."
