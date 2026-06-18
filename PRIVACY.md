# ALTER — Privacy & Data Handling

_Last updated: 2026-06-14. This document describes how ALTER handles your data.
It is written to be honest about what is and isn't implemented today._

ALTER is a mobile-first personal decision-intelligence app. Its design principle
is **local-first**: your private context lives on your phone, encrypted, and only
the minimum needed context — redacted — is sent to the cloud when a decision
genuinely needs deeper reasoning.

## What ALTER can access (only with your consent)

Each of these is **off until you grant it**, requested at the point of use, and
can be revoked in your system settings:

| Surface | Why | How it's used |
|---|---|---|
| Microphone | Voice input | Audio is sent to the speech service to transcribe, then discarded |
| Camera (Lens) | Scan documents/objects | The capture is analyzed; not stored or shared beyond the analysis call |
| Contacts | Warm intros, "call/message X" | Read on demand to resolve a name; not bulk-uploaded without an explicit "connect contacts" action |
| Calendar | "Am I free at 3?" | Today's events read on demand; never written to |
| Location | "Should I leave now?" | Approximate location read on demand |
| Notifications | Context capture | Read on-device, redacted on-device before any use |
| Accessibility (screen) | Agentic phone control | Reads the visible screen to perform actions you confirm |
| NFC | Profile exchange | Shares only the profile fields you choose |

ALTER does **not** read your SMS history, call logs, browsing history, or photo
library.

## Where your data lives

- **On your phone (local, encrypted):** your memory — decisions, goals,
  preferences, people, commitments, proof/outcomes, notes, and feedback — is
  stored encrypted at rest using **AES-256-GCM**, with the key held in the
  platform keystore. On-device semantic search (a local vector index) holds only
  embeddings and a non-reversible reference key, **never** your text.
- **In the cloud (only what's needed):** when a decision needs deep reasoning,
  ALTER sends the **minimum** context required, after **redacting** obvious
  personal identifiers (emails, phone numbers, long ID/card numbers) and
  applying a size budget. Cloud reasoning runs through:
  - **Supabase** (authentication, your account data, and an Edge Function that
    proxies AI calls so the AI provider key never lives in the app),
  - **OpenAI** (reasoning + embeddings, via that proxy),
  - **Sarvam** (speech-to-text, text-to-speech, translation), via the backend.
- Cloud sync of your local memory is **optional and consent-based**; the phone
  stays useful offline.

## How personalization works (no fine-tuning, no RL)

ALTER personalizes through **local/private memory + retrieval + preference
signals + outcome feedback** — not by training a per-user model. **No private
memory is ever stored in model weights.** Feedback you give (accepted / rejected
/ postponed / completed / regretted, ratings, outcomes) is logged as structured
events to *prepare* for future preference learning; ALTER does **not** run
reinforcement learning today and does not claim to.

## Your controls

- **Consent ledger** — every surface is opt-in and revocable.
- **Review / delete / export** — you can view, delete by scope, and export your
  local memory (Privacy screen).
- **Sensitive memories are private by default**; anything agent-visible or
  shareable is explicit.

## What ALTER does not do

- It does not sell your data.
- It does not bulk-collect or background-harvest personal data.
- It does not bypass Android's permission system; every sensitive action is
  permissioned and, for outward actions (send, pay, install, delete), confirmed
  by you.

## Contact

For privacy questions or data requests, contact the app owner listed in the app
store listing.

---

_This is a living document and will be updated as the architecture evolves
(e.g., on-device embeddings for fully-offline retrieval, consent-gated pgvector
cloud sync). See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)._
