param(
    [string]$BaseUrl = "http://localhost:8060"
)

$ErrorActionPreference = "Stop"
$base = $BaseUrl.TrimEnd("/")
$userId = "11111111-1111-4111-8111-111111111111"

function Invoke-JsonPost {
    param(
        [string]$Path,
        [hashtable]$Body
    )
    $json = $Body | ConvertTo-Json -Depth 12
    return Invoke-RestMethod -Method Post -Uri "$base$Path" -ContentType "application/json" -Body $json
}

Write-Host "Checking $base/healthz"
$health = Invoke-RestMethod -Method Get -Uri "$base/healthz"
Write-Host "Gateway: $($health.status) / $($health.service)"

Write-Host "Checking system health"
$system = Invoke-RestMethod -Method Get -Uri "$base/v1/system/health"
Write-Host "System health: $($system.status)"

Write-Host "Checking Sarvam language list"
$languages = Invoke-RestMethod -Method Get -Uri "$base/v1/multilingual/languages"
Write-Host "Sarvam enabled: $($languages.sarvam_enabled); Indian languages: $($languages.indian_languages.Count)"

Write-Host "Checking language detection fallback/live path"
$detect = Invoke-JsonPost -Path "/v1/multilingual/detect-language" -Body @{ text = "Namaste, plan my day" }
Write-Host "Detected language: $($detect.language_code); provider: $($detect.provider)"

Write-Host "Checking TTS fallback/live path"
$tts = Invoke-JsonPost -Path "/v1/multilingual/text-to-speech" -Body @{
    text = "Namaste, ALTER is ready."
    target_language_code = "hi-IN"
}
Write-Host "TTS provider: $($tts.provider); audio count: $($tts.audio_count)"

Write-Host "Checking consent ledger"
$ledger = Invoke-RestMethod -Method Get -Uri "$base/v1/security/consent-ledger?user_id=$userId"
Write-Host "Consent grants: $($ledger.grants.Count)"

Write-Host "Checking safe ingestion"
$ingestion = Invoke-JsonPost -Path "/v1/data-ingestion/import" -Body @{
    user_id = $userId
    source = "notes"
    items = @(@{ title = "Launch note"; summary = "Build ALTER end to end" })
}
Write-Host "Ingestion accepted: $($ingestion.accepted); candidates: $($ingestion.memory_candidates.Count)"

Write-Host "Checking agent planner"
$plan = Invoke-JsonPost -Path "/v1/agent/plan" -Body @{
    user_id = $userId
    goal = "Open WhatsApp and draft a reply"
}
Write-Host "Planner ready: $($plan.ready_to_execute); steps: $($plan.steps.Count)"

Write-Host "Checking privacy export"
$export = Invoke-RestMethod -Method Get -Uri "$base/v1/privacy/export?user_id=$userId"
Write-Host "Privacy export ready: $($export.download_ready)"

Write-Host "Backend smoke checks completed for $base"
