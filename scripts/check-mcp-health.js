#!/usr/bin/env node
const http = require('http');
const https = require('https');
const url = require('url');

const DEFAULT_URL = process.env.MCP_URL || 'http://localhost:54321/mcp';
const TIMEOUT_MS = Number(process.env.MCP_HEALTH_TIMEOUT_MS || 120000); // 2min default
const RETRY_INTERVAL_MS = Number(process.env.MCP_HEALTH_RETRY_MS || 2000);

function fetchOnce(mcpUrl) {
    return new Promise((resolve, reject) => {
        const parsed = url.parse(mcpUrl);
        const lib = parsed.protocol === 'https:' ? https : http;
        const opts = { method: 'GET', timeout: 10000, headers: { 'User-Agent': 'mcp-health-check' } };
        const req = lib.request(mcpUrl, opts, (res) => {
            resolve({ statusCode: res.statusCode, headers: res.headers });
        });
        req.on('error', (err) => reject(err));
        req.on('timeout', () => { req.destroy(new Error('timeout')); });
        req.end();
    });
}

async function waitForHealthy(mcpUrl) {
    const started = Date.now();
    while (Date.now() - started < TIMEOUT_MS) {
        try {
            const result = await fetchOnce(mcpUrl);
            console.log(`MCP responded: status=${result.statusCode}`);
            return true;
        } catch (err) {
            process.stdout.write('.');
            await new Promise((r) => setTimeout(r, RETRY_INTERVAL_MS));
        }
    }
    return false;
}

async function main() {
    const mcpUrl = process.argv[2] || DEFAULT_URL;
    console.log(`Checking MCP health at ${mcpUrl}. Timeout ${TIMEOUT_MS}ms`);
    const ok = await waitForHealthy(mcpUrl);
    if (!ok) {
        console.error('\nMCP did not become healthy before timeout.');
        process.exit(2);
    }
    console.log('\nMCP is healthy!');
    process.exit(0);
}

main().catch((err) => { console.error(err); process.exit(1); });
