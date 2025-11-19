# Gavra MCP Supabase Server

MCP (Model Context Protocol) server za Gavra Android aplikaciju koji omogućava AI asistentima pristup Supabase bazi podataka.

## Instalacija

```bash
cd mcp-supabase-server
npm install
npm run build
```

## Konfiguracija

Postavite environment varijable:

```bash
# Obavezno
export SUPABASE_URL="https://gjtabtwudbrmfeyjiicu.supabase.co"
export SUPABASE_ANON_KEY="your-anon-key"

# Opciono za admin operacije
export SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
```

Ili kreirati `.env` fajl:

```
SUPABASE_URL=https://gjtabtwudbrmfeyjiicu.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

## Pokretanje

### Development
```bash
npm run dev
```

### Production
```bash
npm run build
npm start
```

### Korišćenje zvaničnog Supabase MCP servera (supabase-community/supabase-mcp)

Ako želite da koristite zvanični Supabase MCP server umesto lokalnog "gavra" servera, možete ga pokrenuti iz direktorijuma `supabase-mcp-official` koji je već uključen u workspace.

Na Windows PowerShell-u (iz root projekta):

```powershell
# Instalirajte zavisnosti za zvanični MCP repo
npm run official:install --prefix mcp-supabase-server

# Pokrenite dev server (radi unutar monorepo-a `supabase-mcp-official`)
npm run official:dev --prefix mcp-supabase-server

# Alternativno, koristite skriptu iz scripts/ (Windows PowerShell)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-official-mcp.ps1
```

Na macOS/Linux:

```bash
# Instalirajte zavisnosti
pnpm --prefix supabase-mcp-official install

# Build
pnpm --prefix supabase-mcp-official build

# Pokrenite dev server iz monorepo-a
pnpm --prefix supabase-mcp-official --filter @supabase/mcp-server-supabase dev

# Ili koristite bash skriptu
./scripts/run-official-mcp.sh
```

Napomena:
- Skripte u `mcp-supabase-server/package.json` omogućavaju komande `official:install`, `official:build` i `official:dev` koje pokreću pnpm komande nad `supabase-mcp-official` monorepom.
- Ako pokrećete MCP server iz monorepo-a, proverite `supabase-mcp-official/.env` i podesite neophodne varijable: `QUERY_API_KEY`, `SUPABASE_PROJECT_REF`, `SUPABASE_DB_PASSWORD`, `SUPABASE_REGION`, `SUPABASE_SERVICE_ROLE_KEY` i dr. (možete koristiti `.env` datoteku u `supabase-mcp-official` direktorijumu).

## Dostupni MCP Tools

### 1. `get_vozaci`
Dobija sve vozače iz baze podataka.

**Parametri:**
- `aktivan` (boolean, default: true) - Filter samo aktivne vozače

### 2. `get_mesecni_putnici`
Dobija mesečne putnike.

**Parametri:**
- `aktivan` (boolean, default: true) - Filter samo aktivne putnike
- `limit` (number, default: 50) - Maksimalan broj rezultata

### 3. `get_dnevni_putnici`
Dobija dnevne putnike za određeni datum.

**Parametri:**
- `datum` (string, default: danas) - Datum u YYYY-MM-DD formatu
- `limit` (number, default: 100) - Maksimalan broj rezultata

### 4. `get_putovanja_istorija`
Dobija istoriju putovanja.

**Parametri:**
- `vozac_id` (string, opciono) - UUID vozača za filtriranje
- `from_date` (string, opciono) - Početni datum (YYYY-MM-DD)
- `to_date` (string, opciono) - Završni datum (YYYY-MM-DD)
- `limit` (number, default: 100) - Maksimalan broj rezultata

### 5. `get_vozac_by_ime`
Pronalazi vozača po imenu.

**Parametri:**
- `ime` (string, obavezno) - Ime vozača

### 6. `get_vozac_kusur`
Dobija kusur vozača koristeći RPC funkciju.

**Parametri:**
- `vozac_ime` (string, obavezno) - Ime vozača

### 7. `update_vozac_kusur` (Admin)
Ažurira kusur vozača. Zahteva admin privilegije.

**Parametri:**
- `vozac_ime` (string, obavezno) - Ime vozača
- `novi_kusur` (number, obavezno) - Nova vrednost kusura

### 8. `get_statistike`
Dobija statistike za vozače.

**Parametri:**
- `vozac_ime` (string, obavezno) - Ime vozača

## Sigurnost

- Koristi se Supabase RLS (Row Level Security)
- Read operacije koriste anon key
- Admin operacije zahtevaju service role key
- Environment varijable se ne commituju u kod

## Integracija sa Claude Desktop

Dodaj u Claude Desktop config:

```json
{
  "mcpServers": {
    "gavra-supabase": {
      "command": "node",
      "args": ["C:/Users/Bojan/gavra_android/mcp-supabase-server/dist/index.js"],
      "env": {
        "SUPABASE_URL": "https://gjtabtwudbrmfeyjiicu.supabase.co",
        "SUPABASE_ANON_KEY": "your-anon-key",
        "SUPABASE_SERVICE_ROLE_KEY": "your-service-role-key"
      }
    }
  }
}
```

## Troubleshooting

### Problem: "No service role key"
Rešenje: Postaviti `SUPABASE_SERVICE_ROLE_KEY` environment varijablu za admin operacije.

### Problem: "Connection timeout"
Rešenje: Proveriti internet konekciju i Supabase URL.

### Problem: "RPC function not found"
Rešenje: Pokrenuti migrations u Supabase projektu:
```bash
supabase db push
```

---

## Running and integrating the official Supabase MCP server

Use the following quick commands from the project root or `mcp-supabase-server` directory.

Install/build/run the official repository via pnpm (workspace method):

```bash
# From project root
pnpm --prefix supabase-mcp-official install
pnpm --prefix supabase-mcp-official build
pnpm --prefix supabase-mcp-official --filter @supabase/mcp-server-supabase dev
```

Or use the repo-level npm scripts (cross-platform):

```bash
npm run mcp:install
npm run mcp:build
npm run mcp:dev
```

You can also use a cross-platform helper which runs the correct script for your system:

```bash
# From project root
npm run mcp:run
```

Start local Supabase CLI (if you want a local `http://localhost:54321/mcp` endpoint):

```bash
# Windows PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/start-supabase.ps1

# macOS/Linux
./scripts/start-supabase.sh
```

If you use Claude Desktop, add `claude-config.example.json` sample as starting config and set envs. Also `mcp_config.example.json` includes an HTTP transport sample for `http://localhost:54321/mcp`.

Also, copy the `.env.example` to `.env` inside `supabase-mcp-official` and update it with your real values:

```bash
cp supabase-mcp-official/.env.example supabase-mcp-official/.env
# Then fill the values (QUERY_API_KEY, SUPABASE_PROJECT_REF, etc.)
```

### Start everything (Supabase CLI, MCP server, health-check)

Use `mcp:dev:all` to orchestrate starting Supabase CLI (if available) and the official MCP server, then wait for the server health-check to pass:

```bash
# From project root
npm run mcp:install
npm run mcp:dev:all
```

To run a standalone health-check against the configured MCP URL (default `http://localhost:54321/mcp`):

```bash
npm run mcp:health
```

### Using `mcp_config.example.json` locally

1. Copy the example to a file your MCP client (e.g., Cursor or my custom client) can read. Name it `mcp_config.json` and edit the `project_ref`, `QUERY_API_KEY` and other secrets.
2. For `http://localhost:54321/mcp`, ensure you have started Supabase local dev via `supabase start`. If you also want the official MCP server running from this repo, run `npm run mcp:dev` from the project root.
3. If you use the `stdio` transport for the MCP server, set the command in the `claude-config.example.json` to the `dist/transports/stdio.js` and set `env` variables there.

### Safety and Security

Always use `read_only=true` query param for `http://localhost:54321/mcp` when you are using production-like data. Do not expose service role keys to third-party clients.

