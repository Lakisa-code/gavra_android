#!/usr/bin/env node
const { spawn } = require('child_process');
const path = require('path');
const process = require('process');

const repoRoot = path.resolve(__dirname, '..');
const nodeCmd = process.platform === 'win32' ? 'node' : 'node';
const mcpDevArgs = ['--prefix', 'supabase-mcp-official', '--filter', '@supabase/mcp-server-supabase', 'dev'];

function spawnProcess(cmd, args, options = {}) {
    console.log(`Spawning: ${cmd} ${args.join(' ')}`);
    const p = spawn(cmd, args, { stdio: 'inherit', shell: true, ...options });
    p.on('exit', (code, signal) => {
        if (signal) {
            console.log(`${cmd} killed with signal ${signal}`);
        } else {
            console.log(`${cmd} exited with code ${code}`);
        }
    });
    return p;
}

async function waitForHealth(mcpUrl, timeout = 120000) {
    // reuse the health-check script
    return new Promise((resolve) => {
        const script = path.join(repoRoot, 'scripts', 'check-mcp-health.js');
        const checker = spawn(nodeCmd, [script, mcpUrl], { stdio: 'inherit', shell: true });
        checker.on('exit', (code) => resolve(code === 0));
    });
}

async function run() {
    // Start Supabase CLI
    let supabaseProcess = null;
    try {
        supabaseProcess = spawnProcess('supabase', ['start']);
    } catch (err) {
        console.warn('Could not start Supabase CLI (not found on PATH). Continue and assume a remote or already running instance is available.');
    }

    // Start MCP server dev
    const mcpProcess = spawnProcess('pnpm', mcpDevArgs);

    // Wait for health
    const mcpUrl = process.env.MCP_URL || 'http://localhost:54321/mcp';
    const healthy = await waitForHealth(mcpUrl);
    if (!healthy) {
        console.error('MCP did not become healthy. Exiting.');
        process.exit(3);
    }
    console.log('All services healthy. Press Ctrl+C to stop.');

    // forward signals
    process.on('SIGINT', () => { console.log('SIGINT received, shutting down child processes...'); mcpProcess.kill('SIGINT'); if (supabaseProcess) supabaseProcess.kill('SIGINT'); process.exit(0); });
    process.on('SIGTERM', () => { console.log('SIGTERM received, shutting down child processes...'); mcpProcess.kill(); if (supabaseProcess) supabaseProcess.kill(); process.exit(0); });
}

run();
