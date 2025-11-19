#!/usr/bin/env bash
# Simple helper to run the official Supabase MCP server from the workspace.
# Usage examples:
#  ./scripts/run-official-mcp.sh           # run dev, loads env from default path
#  ./scripts/run-official-mcp.sh install   # install pnpm deps in the official repo
#  ./scripts/run-official-mcp.sh build     # build the official packages

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
MCP_DIR="$REPO_ROOT/supabase-mcp-official"
ENV_FILE="$REPO_ROOT/supabase-mcp-official/.env"

echo "Repo root: $REPO_ROOT"
echo "MCP dir: $MCP_DIR"

if [ ! -d "$MCP_DIR" ]; then
  echo "Official supabase-mcp directory not found at $MCP_DIR. Clone or extract it first." >&2
  exit 1
fi

function load_env_file() {
  local file=$1
  if [ ! -f "$file" ]; then return; fi
  echo "Loading env file: $file"
  set -a
  source "$file"
  set +a
}

if [ "${1:-}" = "install" ]; then
  if ! command -v pnpm >/dev/null 2>&1; then
    echo "pnpm not found; installing..."
    npm i -g pnpm
  fi
  echo "Installing workspace dependencies in $MCP_DIR"
  pnpm --prefix "$MCP_DIR" install
  exit 0
fi

if [ "${1:-}" = "build" ]; then
  echo "Building official MCP packages in $MCP_DIR"
  pnpm --prefix "$MCP_DIR" build
  exit 0
fi

if [ -f "$ENV_FILE" ]; then
  load_env_file "$ENV_FILE"
fi

echo "Starting official MCP dev server (workspace package: @supabase/mcp-server-supabase)"
pnpm --prefix "$MCP_DIR" --filter @supabase/mcp-server-supabase dev
