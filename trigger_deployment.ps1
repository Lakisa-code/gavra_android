#!/usr/bin/env powershell
<#
.SYNOPSIS
    Pokreni GitHub Actions workflow - UNIFIED DEPLOY ALL
    Deploy version 6.0.50+420 na sve 3 platforme
#>

param(
    [string]$Owner = "kadpitamkurac-hash",
    [string]$Repo = "gavra_android",
    [string]$Workflow = "unified-deploy-all.yml",
    [bool]$BumpVersion = $false,
    [string]$ReleaseNotes = "Version 6.0.50+420 - Production Release",
    [bool]$SubmitReviewHuawei = $true,
    [bool]$SubmitReviewIOS = $true,
    [bool]$DryRun = $false,
    [bool]$RunGooglePlay = $true,
    [bool]$RunHuaweiAppGallery = $true,
    [bool]$RunIOSAppStore = $true
)

function Test-GitHubCLI {
    try {
        $version = gh --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ GitHub CLI pronađen: $version" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Host "❌ GitHub CLI nije pronađen" -ForegroundColor Red
        return $false
    }
}

function Test-GitHubAuth {
    try {
        $auth = gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ GitHub autentifikacija OK" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Host "❌ GitHub autentifikacija failed" -ForegroundColor Red
        return $false
    }
}

function Trigger-Workflow {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$Workflow,
        [hashtable]$Inputs
    )
    
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "🚀 POKRETANJE GITHUB ACTIONS WORKFLOW" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    
    Write-Host ""
    Write-Host "Repository: $Owner/$Repo" -ForegroundColor Yellow
    Write-Host "Workflow: $Workflow" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Parametri:" -ForegroundColor Yellow
    foreach ($key in $Inputs.Keys) {
        $value = $Inputs[$key]
        Write-Host "  • $key = $value"
    }
    Write-Host ""
    
    # Pripremi inputs kao JSON
    $inputsJson = @{}
    foreach ($key in $Inputs.Keys) {
        $inputsJson[$key] = [string]$Inputs[$key]
    }
    
    # Pokreni workflow
    Write-Host "⏳ Slanje zahteva GitHub Actions API..." -ForegroundColor Cyan
    
    $cmd = @(
        "workflow", "run",
        $Workflow,
        "--repo", "$Owner/$Repo",
        "--ref", "main"
    )
    
    # Dodaj inputs
    foreach ($key in $Inputs.Keys) {
        $cmd += "-f"
        $cmd += "$key=$($Inputs[$key])"
    }
    
    Write-Host "Komanda: gh $($cmd -join ' ')" -ForegroundColor Gray
    Write-Host ""
    
    & gh $cmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ WORKFLOW POKRENUTA USPJEŠNO!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Prati progress na:" -ForegroundColor Green
        Write-Host "  https://github.com/$Owner/$Repo/actions" -ForegroundColor Cyan
        Write-Host ""
        return $true
    } else {
        Write-Host ""
        Write-Host "❌ GREŠKA pri pokretanju workflow-a" -ForegroundColor Red
        return $false
    }
}

function Show-Monitoring {
    param(
        [string]$Owner,
        [string]$Repo
    )
    
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "📊 MONITORING DEPLOYMENT" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    
    Write-Host ""
    Write-Host "Build Time: ~20-30 minuta (paralelno)" -ForegroundColor Yellow
    Write-Host "  • Google Play (AAB):   5-10 min" -ForegroundColor Gray
    Write-Host "  • Huawei (APK):       5-10 min" -ForegroundColor Gray
    Write-Host "  • iOS (IPA):          10-15 min" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Upload + Review:" -ForegroundColor Yellow
    Write-Host "  • Google Play: 1-4 sata (obično instant)" -ForegroundColor Gray
    Write-Host "  • Huawei:      2-6 sati" -ForegroundColor Gray
    Write-Host "  • iOS:         24-48 sati" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "Komande za monitoring:" -ForegroundColor Yellow
    Write-Host "  # Prikaži sve run-ove (zadnjih 10)"
    Write-Host "  gh workflow view unified-deploy-all.yml --repo $Owner/$Repo"
    Write-Host ""
    Write-Host "  # Prikaži log zadnjeeg run-a"
    Write-Host "  gh run list --repo $Owner/$Repo --workflow unified-deploy-all.yml --limit 1"
    Write-Host ""
    Write-Host "  # Prati live log"
    Write-Host "  gh run watch --repo $Owner/$Repo"
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║  🚀 GITHUB ACTIONS WORKFLOW TRIGGER                      ║" -ForegroundColor Magenta
Write-Host "║     Version 6.0.50+420 - All Platforms                    ║" -ForegroundColor Magenta
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

# Provjeri preduslove
Write-Host ""
Write-Host "📋 Provera preduslova..." -ForegroundColor Cyan

if (-not (Test-GitHubCLI)) {
    Write-Host ""
    Write-Host "❌ Trebam GitHub CLI (gh)" -ForegroundColor Red
    Write-Host "   Instaliraj sa: https://cli.github.com/" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-GitHubAuth)) {
    Write-Host ""
    Write-Host "❌ Trebam GitHub autentifikaciju" -ForegroundColor Red
    Write-Host "   Pokreni: gh auth login" -ForegroundColor Yellow
    exit 1
}

# Pripremi inputs
$inputs = @{
    bump_version = if ($BumpVersion) { "true" } else { "false" }
    release_notes = $ReleaseNotes
    submit_for_review_huawei = if ($SubmitReviewHuawei) { "true" } else { "false" }
    submit_for_review_ios = if ($SubmitReviewIOS) { "true" } else { "false" }
    dry_run = if ($DryRun) { "true" } else { "false" }
    run_google_play = if ($RunGooglePlay) { "true" } else { "false" }
    run_huawei_appgallery = if ($RunHuaweiAppGallery) { "true" } else { "false" }
    run_ios_app_store = if ($RunIOSAppStore) { "true" } else { "false" }
}

# Pokreni workflow
$success = Trigger-Workflow -Owner $Owner -Repo $Repo -Workflow $Workflow -Inputs $inputs

if ($success) {
    Show-Monitoring -Owner $Owner -Repo $Repo
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "✨ Deployment je pokrenuta! ✨" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
}
