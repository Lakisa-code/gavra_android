#!/usr/bin/env node

import { config } from "dotenv";
import { dirname, resolve } from "path";
import { fileURLToPath, pathToFileURL } from "url";

const currentDir = dirname(fileURLToPath(import.meta.url));

config({ path: resolve(currentDir, ".env") });
config({ path: resolve(currentDir, "env.local") });

const stdioEntrypoint = resolve(
  currentDir,
  "node_modules",
  "@supabase",
  "mcp-server-supabase",
  "dist",
  "transports",
  "stdio.js"
);

await import(pathToFileURL(stdioEntrypoint).href);
