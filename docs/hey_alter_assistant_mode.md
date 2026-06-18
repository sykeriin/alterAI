# Hey Alter Assistant Mode

ALTER should behave like an assistant layer, not only a dashboard. The app now has an in-app wake loop:

1. User taps `Arm Hey Alter`.
2. The microphone listens for `Hey Alter`, `Ok Alter`, `Hi Alter`, or direct `Alter`.
3. When a command follows the wake phrase, ALTER runs the voice runtime.
4. ALTER speaks the response.
5. If assistant mode is still armed, it listens for the next wake phrase.

Examples:

- `Hey Alter, what should I do today?`
- `Ok Alter, is this message safe?`
- `Alter, remind me to call Mom`

## Current Capability

ALTER now has two wake paths:

- In-app assistant mode, powered by the Flutter `speech_to_text` stack.
- Android native foreground wake service, powered by `HeyAlterWakeService`.

The native path starts from the voice screen's `Native Hey Alter` panel. Android keeps a persistent foreground notification while the microphone service is active. Wake detections are emitted over the `alter.ai/wake_events` event channel and handed into the same ALTER voice runtime.

## Native Background Path

The native Android layer includes:

- `HeyAlterWakeService`: foreground microphone service with `foregroundServiceType="microphone"`.
- `alter.ai/wake_service`: method channel for start, stop, and capability checks.
- `alter.ai/wake_events`: event channel for detected wake phrases.
- On-device recognizer preference on Android 12+ when `SpeechRecognizer.isOnDeviceRecognitionAvailable` returns true.
- Offline-preferred fallback using Android `SpeechRecognizer` with `EXTRA_PREFER_OFFLINE`.

This is a native foreground service, not a hidden background recorder. Android shows the microphone privacy indicator and foreground notification while it runs. The current detector uses Android's speech recognizer as the local wake layer; a production-grade custom hotword model such as Porcupine, openWakeWord, or a small TFLite keyword model can replace the phrase matcher behind the same service/channel contract later. The event handoff now keeps the last wake event and replays it when Flutter attaches, so background wake detection can hand control back to the app more reliably.

## Android Limits

- The service must be started by the user from the app.
- `RECORD_AUDIO` is required before the service can listen.
- Android 13+ may ask for `POST_NOTIFICATIONS`.
- Full Siri-style background activity launch is restricted by Android; the service emits wake events to Flutter when the app process is active and keeps a notification entry point available.
