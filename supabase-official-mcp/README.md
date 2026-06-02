# Supabase Official MCP Server

Official Model Context Protocol (MCP) server for Supabase.

## Installation

1. Install dependencies:
```bash
npm install
```

2. Set up environment variables:
```bash
cp .env.example .env
```

Edit `.env` and add your Supabase credentials:
```
SUPABASE_ACCESS_TOKEN=your_supabase_personal_access_token
# Optional: lock to one project
# SUPABASE_PROJECT_REF=your_project_ref
```

## Usage

### Running the server directly

```bash
npm start
```

### MCP Configuration

Add the following to your MCP client configuration (e.g., Claude Desktop config):

```json
{
  "mcpServers": {
    "supabase": {
      "command": "node",
      "args": [
        "c:\\Users\\Bojan\\gavra_android\\supabase-official-mcp\\index.js"
      ],
      "env": {
        "SUPABASE_ACCESS_TOKEN": "your_supabase_personal_access_token",
        "SUPABASE_PROJECT_REF": "optional_project_ref"
      }
    }
  }
}
```

## Available Tools

The official Supabase MCP server provides the following tools:

- **Database operations**: Query, insert, update, delete data
- **Schema management**: List tables, view table schemas
- **Authentication**: User management and auth operations
- **Storage**: File upload/download operations
- **Edge Functions**: Invoke and manage edge functions
- **Realtime**: Subscribe to database changes

## Requirements

- Node.js >= 18
- Supabase account with Personal Access Token (PAT)

## Getting Supabase Credentials

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to Settings > API
4. Create/copy a Personal Access Token (Account Settings)

## License

MIT
