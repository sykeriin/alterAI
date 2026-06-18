# Push all Supabase migrations to the linked remote project.
# Prerequisites:
#   1. supabase login   (once - opens browser)
#   2. Set DB password:  $env:SUPABASE_DB_PASSWORD = "your-db-password"
#      (Supabase Dashboard -> Project Settings -> Database -> Database password)
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/supabase_db_push.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$SupabaseExe = $null
if (Get-Command supabase -ErrorAction SilentlyContinue) {
    $SupabaseExe = "supabase"
} elseif (Test-Path "$env:USERPROFILE\scoop\shims\supabase.exe") {
    $SupabaseExe = "$env:USERPROFILE\scoop\shims\supabase.exe"
}

$ProjectRef = $env:SUPABASE_PROJECT_REF
if (-not $ProjectRef) {
    Write-Error "Set SUPABASE_PROJECT_REF to your Supabase project ref (Dashboard -> Project Settings -> General)."
    exit 1
}

function Invoke-Supabase {
    param([string[]]$CliArgs)
    if ($SupabaseExe) {
        & $SupabaseExe @CliArgs
    } else {
        & npx supabase @CliArgs
    }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "ALTER Supabase - linking project $ProjectRef ..." -ForegroundColor Cyan

$linkArgs = @("link", "--project-ref", $ProjectRef, "--yes")
if ($env:SUPABASE_DB_PASSWORD) {
    $linkArgs += @("-p", $env:SUPABASE_DB_PASSWORD)
}

Invoke-Supabase $linkArgs

Write-Host "Pushing migrations from supabase/migrations ..." -ForegroundColor Cyan

$pushArgs = @("db", "push", "--linked", "--yes")
if ($env:SUPABASE_DB_PASSWORD) {
    $pushArgs += @("-p", $env:SUPABASE_DB_PASSWORD)
}

Invoke-Supabase $pushArgs

Write-Host "Done. All migrations applied." -ForegroundColor Green
