# ALTER Life OS Digital Twin

The Digital Twin is a permissioned model of the user's context, personality, routines, relationships, and decision style. It is designed to make ALTER feel like a true Life OS while keeping phone access explicit and auditable.

## Core Model

- Data sources are scoped as `off`, `metadata`, `redacted`, or `local_full`.
- High-sensitivity data such as chats, photos, notes, files, and location is never treated as silently available.
- `local_full` means the raw index stays on-device. Cloud reasoning receives only redacted summaries.
- The twin's fidelity is computed from active sources and their access scope.
- Autonomy is expressed as a ring: `observe`, `recommend`, `draft`, `confirm_act`.

## Phone Control

OpenClaw is the action gateway. ALTER may prepare actions such as:

- Draft a WhatsApp or SMS reply.
- Open the dialer.
- Prefill a calendar event.
- Open a browser search or app link.
- Queue a permission/setup action.

ALTER must not silently send messages, make payments, install apps, delete data, change accounts, or post to social media. High-impact actions require explanation and explicit user confirmation.

## Source Policy

The current Flutter surface models these sources:

- Moments and share-sheet captures
- Notifications
- SMS
- WhatsApp
- Calls
- Email
- Social apps
- Notes
- Photos
- Contacts
- Calendar
- Files
- Browser
- Location

Some sources are implemented through existing notification/share intent surfaces. Others are modeled in the consent map so native connectors can be added without changing the product language.

## Persistence

The Supabase migration `20260613000004_digital_twin.sql` adds:

- `digital_twin_sources`: per-source access scope
- `digital_twin_settings`: autonomy ring

Both tables are row-level secured to the owning user.
