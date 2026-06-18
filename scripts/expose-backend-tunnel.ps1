param(
    [string]$BaseUrl = "http://localhost:8060"
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$RunDir = Join-Path $RepoRoot ".codex-run\backend"
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null

$cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue
$ngrok = Get-Command ngrok -ErrorAction SilentlyContinue

if ($cloudflared) {
    $log = Join-Path $RunDir "cloudflared.log"
    $command = "cloudflared tunnel --url $BaseUrl *>> '$log'"
    Start-Process -FilePath "powershell" -WindowStyle Hidden -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        $command
    ) | Out-Null
    Start-Sleep -Seconds 8
    $content = if (Test-Path $log) { Get-Content $log -Raw } else { "" }
    $match = [regex]::Match($content, "https://[a-zA-Z0-9-]+\.trycloudflare\.com")
    if ($match.Success) {
        Write-Host "Tunnel URL: $($match.Value)"
        Write-Host "Save this URL in ALTER Settings > Backend Gateway on the phone."
    } else {
        Write-Host "cloudflared started, but the URL was not parsed yet. Log: $log"
    }
    exit 0
}

if ($ngrok) {
    $log = Join-Path $RunDir "ngrok.log"
    $command = "ngrok http $BaseUrl --log stdout *>> '$log'"
    Start-Process -FilePath "powershell" -WindowStyle Hidden -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        $command
    ) | Out-Null
    Start-Sleep -Seconds 8
    $api = $null
    try {
        $api = Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:4040/api/tunnels"
    } catch {
        $api = $null
    }
    $url = $api.tunnels | Where-Object { $_.public_url -like "https://*" } | Select-Object -First 1 -ExpandProperty public_url
    if ($url) {
        Write-Host "Tunnel URL: $url"
        Write-Host "Save this URL in ALTER Settings > Backend Gateway on the phone."
    } else {
        Write-Host "ngrok started, but no HTTPS tunnel was detected yet. Log: $log"
    }
    exit 0
}

Write-Host "No tunnel tool found. Install cloudflared or ngrok, or use your computer LAN URL if the phone is on the same Wi-Fi."
exit 1
