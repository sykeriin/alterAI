param(
    [switch]$ApiGatewayOnly,
    [int]$ApiGatewayPort = 8060,
    [int]$FutureSimulationPort = 8092
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$RunDir = Join-Path $RepoRoot ".codex-run\backend"
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
$VenvPython = Join-Path $RepoRoot ".codex-run\api-gateway-venv\Scripts\python.exe"
$PythonExe = if (Test-Path $VenvPython) { $VenvPython } else { "python" }

$services = @(
    @{ Name = "voice_gateway"; Module = "alter_voice_gateway.api:app"; Port = 8070; Src = "services\voice_gateway\src" },
    @{ Name = "clone_council"; Module = "alter_clone_council.api:app"; Port = 8080; Src = "services\clone_council\src" },
    @{ Name = "future_simulation"; Module = "alter_future_simulation.api:app"; Port = $FutureSimulationPort; Src = "services\future_simulation\src" },
    @{ Name = "memory_system"; Module = "alter_memory_system.api:app"; Port = 8100; Src = "services\memory_system\src" },
    @{ Name = "opportunity_engine"; Module = "alter_opportunity_engine.api:app"; Port = 8110; Src = "services\opportunity_engine\src" },
    @{ Name = "social_graph"; Module = "alter_social_graph.api:app"; Port = 8120; Src = "services\social_graph\src" },
    @{ Name = "alter_lens"; Module = "alter_lens.api:app"; Port = 8130; Src = "services\alter_lens\src" },
    @{ Name = "reputation_engine"; Module = "alter_reputation_engine.api:app"; Port = 8140; Src = "services\reputation_engine\src" },
    @{ Name = "officekit"; Module = "alter_officekit.api:app"; Port = 8150; Src = "services\officekit\src" }
)

if ($ApiGatewayOnly) {
    $services = @()
}

$services += @{
    Name = "api_gateway";
    Module = "alter_api_gateway.api:app";
    Port = $ApiGatewayPort;
    Src = "services\api_gateway\src"
}

$pythonPathParts = @(
    "services\api_gateway\src",
    "services\voice_gateway\src",
    "services\clone_council\src",
    "services\future_simulation\src",
    "services\memory_system\src",
    "services\opportunity_engine\src",
    "services\social_graph\src",
    "services\alter_lens\src",
    "services\reputation_engine\src",
    "services\officekit\src"
) | ForEach-Object { Join-Path $RepoRoot $_ }

$pythonPath = ($pythonPathParts -join ";")

function Test-PortBusy {
    param([int]$Port)
    $connection = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    return $null -ne $connection
}

foreach ($service in $services) {
    if (Test-PortBusy -Port $service.Port) {
        Write-Host "$($service.Name) already has something listening on port $($service.Port); leaving it alone."
        continue
    }

    $env:PYTHONPATH = $pythonPath
    $env:ALTER_FUTURE_SIMULATION_URL = "http://localhost:$FutureSimulationPort"
    $env:ALTER_API_GATEWAY_URL = "http://localhost:$ApiGatewayPort"
    $outLog = Join-Path $RunDir "$($service.Name).out.log"
    $errLog = Join-Path $RunDir "$($service.Name).err.log"

    Start-Process -FilePath $PythonExe -WorkingDirectory $RepoRoot -WindowStyle Hidden -ArgumentList @(
        "-m",
        "uvicorn",
        $service.Module,
        "--host",
        "0.0.0.0",
        "--port",
        "$($service.Port)"
    ) -RedirectStandardOutput $outLog -RedirectStandardError $errLog | Out-Null
    Write-Host "Started $($service.Name) on port $($service.Port); logs: $outLog / $errLog"
}

Write-Host "Backend start requested. Gateway: http://localhost:$ApiGatewayPort"
Write-Host "Run scripts\test-backend-health.ps1 -BaseUrl http://localhost:$ApiGatewayPort to verify."
