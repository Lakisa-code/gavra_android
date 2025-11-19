#!/usr/bin/env node
const { spawn } = require('child_process');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..');
const scriptPathPs = path.join(repoRoot, 'scripts', 'run-official-mcp.ps1');
const scriptPathSh = path.join(repoRoot, 'scripts', 'run-official-mcp.sh');

function run(command, args, options = {}) {
    const p = spawn(command, args, { stdio: 'inherit', shell: true, ...options });
    p.on('close', (code) => process.exit(code));
}

if (process.platform === 'win32') {
    console.log('Running PowerShell script...');
    run('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', scriptPathPs]);
} else {
    console.log('Running Bash script...');
    run('bash', [scriptPathSh]);
}
