# Android Phone Control

ALTER now has a native Android phone-control layer with three parts:

1. Foreground wake service for `Hey Alter`.
2. Accessibility service for visible screen reading, taps, scrolling, typing, and global navigation.
3. Device-control bridge for app/settings/dialer/SMS intents and Accessibility actions.

## Native Channels

- `alter.ai/device_control`
  - `isAccessibilityEnabled`
  - `openAccessibilitySettings`
  - `openApp`
  - `openSettings`
  - `openDialer`
  - `openSmsDraft`
  - `readScreen`
  - `executeAccessibilityAction`

## Consent Model

ALTER cannot use Accessibility until the user enables `ALTER phone control` in Android Settings. When enabled, the app can read visible screen text and perform UI actions only through Android's Accessibility APIs. Every Flutter-side phone-control attempt is recorded in the local Phone Control audit panel in OpenClaw.

## Agent Tools

The agent planner can now call tools for:

- Opening apps and settings.
- Reading visible screen text and converting it into a structured screen model.
- Clicking visible text.
- Typing into focused fields.
- Scrolling.
- Pressing Back, Home, Recents, Notifications, and Quick Settings.
- Queuing confirmation-required actions into OpenClaw.

Direct clicks on high-impact labels such as Send, Pay, Confirm, Install, Approve, Delete, Allow, and Transfer are blocked in the direct agent path. These actions are classified by the action policy engine and must stay behind OpenClaw confirmation.

## OpenClaw Bridge

OpenClaw actions now carry a structured command payload:

- `kind`
- `args`
- `policy_tier`
- `policy_reason`
- `requires_accessibility`

OpenClaw execution routes confirmed actions into native device actions where there is a safe mapping. Unknown action types are still marked and audited, but ALTER does not pretend that unmapped actions were automated.

## Policy Engine

The phone action policy classifies actions into:

- `safe`: reversible, local, or Android-confirmed surface actions.
- `confirm`: actions that can send, pay, install, approve, delete, submit, or otherwise commit something.
- `blocked`: destructive, security-bypass, credential-harvesting, or device-wiping actions.

The agent direct path can execute only `safe` actions. OpenClaw can execute `confirm` actions only after explicit UI confirmation.

## Screen Understanding

`readScreen` returns a structured screen with:

- current package/class
- visible elements
- inferred roles: button, input, list, toggle, link, text
- center coordinates
- per-element policy classification

This lets ALTER inspect the UI before choosing the next action instead of guessing.

## Wake Handoff

The foreground wake service keeps the last wake event if Flutter is not actively listening and replays it when the app attaches to `alter.ai/wake_events`. The notification also changes to a tap-to-speak handoff when `Hey Alter` is heard.
