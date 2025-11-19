#!/usr/bin/env bash
set -euo pipefail
if ! command -v supabase >/dev/null 2>&1; then
  echo "Supabase CLI not found. Install it: https://supabase.com/docs/guides/cli"
  exit 1
fi
echo "Starting Supabase local development (this may require Docker)"
supabase start
echo "Supabase local started. MCP endpoint (if enabled by CLI): http://localhost:54321/mcp"
