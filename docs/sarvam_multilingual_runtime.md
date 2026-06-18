# Sarvam Multilingual Runtime

ALTER uses Sarvam AI from the backend gateway, never from the Android APK.

## Configure

Set these on the backend host:

```powershell
$env:SARVAM_API_KEY = "replace-with-rotated-key"
$env:ALTER_SARVAM_CHAT_MODEL = "sarvam-m"
$env:ALTER_SARVAM_TRANSLATE_MODEL = "sarvam-translate:v1"
$env:ALTER_SARVAM_STT_MODEL = "saaras:v3"
$env:ALTER_SARVAM_TTS_MODEL = "bulbul:v3"
$env:ALTER_SARVAM_TTS_SPEAKER = "shubh"
```

Do not commit real keys. If a key was pasted into chat or logs, rotate it.

## Endpoints

- `GET /v1/multilingual/languages`
- `POST /v1/multilingual/chat`
- `POST /v1/multilingual/translate`
- `POST /v1/multilingual/detect-language`
- `POST /v1/multilingual/text-to-speech`
- `POST /v1/multilingual/speech-to-text`
- `POST /v1/voice/action-runtime`

The Android voice screen continues to use `/v1/voice/action-runtime`. When
`SARVAM_API_KEY` is available, the gateway asks Sarvam to produce the localized
assistant response. If Sarvam is unavailable, the gateway returns a local
fallback and marks the response as `ai_provider: alter-local`.

Speech-to-text accepts multipart audio uploads and forwards them to Sarvam
server-side. Text-to-speech returns Sarvam's base64 audio payload so the Android
client can play or cache it without ever storing the Sarvam key in the APK.
Language detection uses Sarvam `text-lid` when configured and a small local
script heuristic otherwise.

## Language Coverage

The app exposes all 22 official Indian languages plus English for Sarvam-backed
Indian language work, and major foreign language options for the assistant UI.
Sarvam Translate is used only for language codes supported by Sarvam Translate.

## Consent Boundary

Sarvam voice and language endpoints do not grant phone data access by
themselves. Phone data enters ALTER through Android-approved surfaces such as
Notification Listener, Accessibility, share intents, file pickers, and manual
exports. The gateway exposes separate consent, ingestion, privacy export, and
delete endpoints so those abilities remain explicit and reversible.
