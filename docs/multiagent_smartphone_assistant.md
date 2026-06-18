# Multi-Agent Smartphone Assistant

ALTER now has a real observe-plan-act path:

1. Observe the current Android screen through the user-enabled Accessibility service.
2. Ask the backend planner for tool steps, with a local multi-agent fallback.
3. Execute one safe tool step.
4. Re-observe the phone.
5. Persist an audit and memory event.
6. Continue until the plan is complete or blocked.

## Agents

- Coordinator: decides whether a phone loop is needed.
- Planner: converts goals into tool steps.
- Phone Control: opens apps/settings, reads screen, taps, types, scrolls, presses Back/Home, opens SMS/call/search surfaces.
- Safety: blocks bypass/destructive/credential actions and routes risky final actions to OpenClaw.
- Memory: persists redacted observations, notifications, voice transcripts, and user goals locally.
- Language: routes live voice through backend Sarvam STT/TTS when configured.
- Task: handles browser search, calendar, drafts, and intent surfaces.
- Social/Opportunity: remains routed through existing backend services.

## Real Phone Tools

- `open_app`
- `open_settings`
- `read_screen`
- `tap` / visible node tap
- `click_text`
- `type_text`
- `scroll`
- `back`, `home`, `recents`, `notifications`, `quick_settings`
- `openSmsDraft`
- `openDialer`
- `openBrowserSearch`
- notification quick reply when Android exposes a replyable notification

Final send/pay/install/approve/delete actions remain confirmation-gated through
OpenClaw or the native app UI.

## Sarvam Live Voice

The APK can now record native Android audio, upload it to:

- `POST /v1/multilingual/speech-to-text`

Then it can synthesize the assistant reply through:

- `POST /v1/multilingual/text-to-speech`

The APK never stores the Sarvam key. Set `SARVAM_API_KEY` only on the backend.
If Sarvam is not configured, the app falls back to Android speech/TTS or local
text responses.

## Persistent Twin Memory

The local intelligence store persists:

- agent audit events
- screen observations
- redacted notification summaries
- voice transcripts
- user goals
- consent records
- export/delete privacy events

This is intentionally consent-based. ALTER does not silently scrape chats or
bypass Android app sandboxes.

## Phone Test

```powershell
scripts\start-backend.ps1 -ApiGatewayOnly
scripts\expose-backend-tunnel.ps1 -BaseUrl http://localhost:8060
scripts\install-and-smoke-test-android.ps1 -OpenPermissionSettings
```

Save the tunnel URL in the APK Settings screen before testing live voice or
agent planning.

## Release

Debug:

```powershell
scripts\release-debug-apk.ps1
```

Release AAB:

1. Add GitHub secrets:
   - `ANDROID_KEYSTORE_BASE64`
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_PASSWORD`
   - `ANDROID_KEY_ALIAS`
2. Run the `Android Release` GitHub workflow.

Play/device-policy review is still required for Accessibility, notification
access, foreground microphone, and any managed-device features.
