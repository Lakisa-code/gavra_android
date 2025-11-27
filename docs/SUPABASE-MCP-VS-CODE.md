# Supabase MCP + VS Code — Setup, viewing DB, and safe schema changes

This document explains how to connect the hosted Supabase MCP server and how to safely view and edit database tables, columns, and policies from VS Code.

---

## Pre-requisites
- Supabase hosted project or a Supabase account with the project ID (we're using project ref `gjtabtwudbrmfeyjiicu` from this repo).
- VS Code installed.
- MCP extension or similar client that supports MCP HTTP transport (the MCP extension that displays “MCP Servers - Installed”).
- Optional: Docker + Supabase CLI if you want a local HTTP endpoint.

---

## Step 0 — Where we already added config
- I added `mcp.json` in the repo root and a user `~/.mcp/mcp.json` entry that points to your Hosted Supabase MCP server with write access (READ_ONLY=false):
  - `https://mcp.supabase.com/mcp?project_ref=gjtabtwudbrmfeyjiicu&read_only=false&features=database,docs,development,functions`

These are the two locations clients look for MCP server config:
- Workspace `mcp.json` (`<repo-root>/mcp.json`) — the workspace config.
- Home `~/.mcp/mcp.json` — global user config that clients use.

---

## Step 1 — Install the MCP client/extension in VS Code
- Open VS Code Extensions (Ctrl+Shift+X).
- Search for "MCP" or "MCP Servers" or the specific client extension you use (e.g. Copilot or an MCP extension).
- Install/enable the extension. The MCP extension should show a sidebar: "MCP Servers - Installed".

---

## Step 2 — Add this hosted MCP server in VS Code (UI method)
- Open Command Palette (Ctrl+Shift+P) → `MCP: Install Server` or `MCP: Add Server`.
- Select "Add custom server" or "Add from JSON".
- Give it a friendly name: `supabase-hosted`.
- Type: `http`
- URL: paste:
  ```text
  https://mcp.supabase.com/mcp?project_ref=gjtabtwudbrmfeyjiicu&read_only=false&features=database,docs,development,functions
  ```
- Save and confirm.

After adding, the UI will open an OAuth or login flow. Authorize the MCP for your Supabase account and organization.

---

## Step 3 — Starting & Testing the server in VS Code
- In the MCP Servers sidebar, find `supabase-hosted` in "Installed".
- Right-click the server → `Start Server`.
- `Show Output` to view logs (useful for errors or if the extension asks to connect).

When a server is connected, browse resources:
- Right-click `supabase-hosted` → `Browse Resources` → `Database`.
- Use the `list_tables` operation to view tables in a schema (for example 'public').

---

## Step 4 — How to make schema changes safely (recommended flow)
**Important**: `read_only=false` allows write operations. Only use write operations in development projects or after confirming backups.

Preferred approach: use `apply_migration` tool to make tracked schema changes.

1. Create your SQL for the schema change (example add column):
```sql
ALTER TABLE public.my_table ADD COLUMN new_column TEXT;
```

2. Use the `apply_migration` tool via MCP client (it wraps and stores a migration):
- Set `name` of the migration: `add_new_column_my_table`.
- Set `query` to the SQL above.

This will create a migration in the management API (like creating a migration file) — it's a safe, auditable change.

Alternative: `execute_sql` — runs SQL directly without creating migration. Use it for quick tests, but prefer migration for schema changes.

**Policy creation example:**
```sql
ALTER TABLE public.my_table ENABLE ROW LEVEL SECURITY;
CREATE POLICY "allow_owner" ON public.my_table
  USING (auth.uid() = owner);
```
Use `apply_migration` to execute this SQL and track it.

---

## Step 5 — Branching / Previews / Production safety
- If you use Supabase branching, create a dev branch, apply migrations there and test. Only merge to production after validations.
- When using the hosted MCP server, prefer `project_ref` scoping to ensure the server is scoped to a dev project.

---

## Step 6 — Troubleshooting & tips
- If you do not see your server in VS Code, ensure `mcp.json` is present and the extension is installed. Try `Reload Window` in VS Code (Ctrl+Shift+P -> "Developer: Reload Window").
- If the server status shows "Unauthorized" or HTTP 401/403, run the `Connect` flow again or create a PAT and configure it in the client if OAuth flow is not working.
- If you get `list_tables` errors, ensure the project ID `project_ref` matches an existing project (In Supabase dashboard → Settings -> General → Project ID).

---

## Running test commands with the stdio dev server using `mcpcurl`
We have a `mcpcurl` CLI in the repo: `github-mcp-server/cmd/mcpcurl/mcpcurl.exe`. Use it to run commands against a running `stdio` server implemented in `supabase-mcp-official`.

**List tables example (stdio dev server)**
```powershell
cd github-mcp-server\cmd\mcpcurl
# run 'run_stdio.bat' to start the stdio command inside mcpcurl process
.\mcpcurl.exe --stdio-server-cmd 'cmd /c run_stdio.bat' tools list_tables --schemas public
```
This command lists public schema tables via the dev server (stdio transport), but it does not use the hosted server.

---

## Want me to continue?
I can do one of these right away:
- A) Guide you through adding the hosted MCP server in VS Code and log in (manual step required for OAuth) — I'll provide short commands and questions to continue.
- B) Demonstrate `list_tables` in `mcpcurl` with the stdio server and show the output here.
- C) Prepare an `apply_migration` SQL and a safe test plan; I will not execute it without explicit `Da/Yes` confirmation.

Choose which one you want me to do next.
