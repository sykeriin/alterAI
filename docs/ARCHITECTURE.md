# ALTER — Architecture (current vs target)

ALTER is a **mobile-first personal AI decision-intelligence platform** for
general users. It helps people make high-impact life and work decisions by
combining personal memory, future simulation, multi-agent reasoning, opportunity
discovery, relationship/context intelligence, and outcome tracking.

> Personalization in ALTER is **retrieval-based**: local/private memory +
> retrieval + preference signals + outcome feedback. ALTER does **not**
> fine-tune per-user models and does **not** run reinforcement learning today.
> Private user memory is **never** stored in model weights.

---

## 1. Current architecture (as built)

```
┌──────────────────────────── Phone (Flutter) ────────────────────────────┐
│  Voice agent (STT/TTS) · Lens (camera) · Notifications · Contacts ·       │
│  Calendar/Location (native) · NFC · Floating bubble (summon)              │
│                                                                          │
│  Local memory: PersistentIntelligenceStore  ── now ENCRYPTED at rest      │
│    (AES-256-GCM, key in platform keystore)                                │
│  Semantic recall: cloud embeddings + on-device cosine (keyword fallback)  │
│  On-device AI: flutter_gemma (redaction + triage in LifeShield)           │
└──────────────┬───────────────────────────────────────────┬──────────────┘
               │ Supabase (auth, Postgres, Edge Functions)  │ API Gateway
               │   - openai-chat edge fn (chat + embeddings) │ (FastAPI, multi-
               │   - per-user daily quota, BYOK              │  service)
               ▼                                             ▼
   Cloud reasoning / data:  Clone Council · Future Simulation · Opportunity
   Engine · Voice Gateway · Social Graph · Reputation · Lens · OfficeKit ·
   Mission/Proof/Intelligence (all via the gateway + OpenAI)
```

**Honest current-state notes**
- The **API Gateway runs on a developer PC behind a Cloudflare quick-tunnel**;
  the URL is overridable but defaults to a tunnel. *Not production-grade hosting
  yet.*
- **No pgvector / cloud vector store.** Durable memory lives in Supabase tables;
  cloud semantic memory is not yet implemented.
- **Semantic retrieval needs the network** (embeddings are computed in the cloud
  and cached locally). Offline, recall falls back to keyword search.
- On-device AI (Gemma) is integrated but used narrowly (redaction/triage).

---

## 2. Target architecture (mobile-first hybrid)

The phone owns **private, fast, local context**. The cloud handles **deep
reasoning, multi-agent debate, long-context decisions, live opportunity
discovery, and heavy model calls**. Only the minimum needed context leaves the
device.

### Layers
1. **Mobile Local Memory Layer** — encrypted local store for recent decisions,
   goals, preferences, people, commitments, proof/outcomes, private notes; a
   retrieval interface that can back onto a local vector DB (e.g. ObjectBox).
   *Cloud sync is optional and consent-based.*
2. **Hybrid Retrieval Layer** — the app retrieves relevant **local** memory; the
   backend retrieves durable **cloud** memory; the gateway merges both into one
   decision-context pack with source labels (`local`, `cloud`, `user-entered`,
   `inferred`, `imported`).
3. **On-Device AI Adapter Layer** — an interface for lightweight on-device tasks
   (intent classification, memory extraction, summarization, privacy redaction,
   short offline drafts, local context compression) with **stub/fallback** impls
   so builds never depend on a specific platform model (Gemini Nano, LiteRT,
   Apple Foundation Models, etc.).
4. **Cloud Reasoning Layer** — Clone Council and heavy reasoning stay in the
   backend with structured outputs; the cloud receives only the minimum context
   under a **context budget + privacy filter**.
5. **Decision Intelligence Pipeline** — capture → infer intent → retrieve memory
   → build decision context → simulate futures → run council → rank
   opportunities → produce recommendation/tradeoffs/risks/confidence/next
   actions → write outcome/proof back to memory on consent.
6. **Feedback & Learning** — explicit capture of accepted / rejected / postponed
   / completed / regretted / outcome±/ rating / follow-through, stored as memory
   + structured events; **data models prepared** for future preference learning
   / contextual bandits (not active RL).
7. **Privacy-Respecting Design** — consent boundaries per surface (memory,
   camera, voice, OfficeKit, NFC, social graph, cloud reasoning); review / delete
   / archive flows; sensitive memories **private by default**; agent-visible or
   shareable memories must be explicit.

---

## 3. Current → target, by area

| Area | Current | Target |
|---|---|---|
| Local memory at rest | **Encrypted (AES-256-GCM)** ✅ (this increment) | same + structured 7-category schema |
| Local retrieval | cloud embeddings + local cosine; keyword fallback | **on-device vector DB (ObjectBox) + on-device embeddings**, offline |
| Cloud memory | Supabase tables | + **pgvector**, consent-gated sync |
| On-device AI | Gemma redaction/triage | adapter for intent/extraction/summarize/redact/draft + fallbacks |
| Context to cloud | full prompt context | **minimised** via context budget + privacy filter |
| Decision output | engines return structured results | unified **decision context pack** with source labels |
| Feedback | Decision DNA outcomes | full feedback taxonomy + preference-ready event models |
| Backend hosting | PC + Cloudflare tunnel | stable hosted service |
| Personalization | retrieval + outcomes | same — **no fine-tuning, no RL** (by design) |

---

## 4. What changed in this increment

- **Encrypted local memory.** `PersistentIntelligenceStore` no longer writes
  plaintext to `SharedPreferences`. It persists through a new
  [`SecureBlobStore`](../lib/src/core/storage/secure_blob_store.dart) abstraction
  whose default implementation (`EncryptedBlobStore`) seals data with
  **AES-256-GCM** using a key held in the platform keystore
  (`flutter_secure_storage`). Legacy plaintext is **re-encrypted on first read**.
  Any failure degrades gracefully to plaintext so persistence never breaks.
- **Abstraction seam** for a future local vector DB (ObjectBox) — callers use
  `SecureBlobStore`, not `SharedPreferences`.
- **Tests** for the encryption codec (`test/secure_blob_store_test.dart`).
- Public memory API (`addMemory` / `searchMemory` / `recordAudit` / `exportData`
  / `deleteScopes` …) is **unchanged** — fully backwards compatible.

## 5. Remaining future work (prioritised)

1. **Backend hosting** off the developer PC (stable domain).
2. **ObjectBox** local vector DB + on-device embeddings → offline retrieval.
3. **7-category typed memory schema** (decisions/goals/preferences/people/
   commitments/proof/notes).
4. **Consent-gated cloud sync** (Supabase + pgvector).
5. **On-device AI adapter** doing more of the small/private tasks.
6. **Graceful offline mode** (capture + local recall + summaries with cloud off).
7. **Privacy/consent UX + policy**, APK slimming (AAB + optional Gemma download),
   Play-policy review for accessibility/overlay/notification access.
8. **Tests + observability + cloud cost controls.**

> Demo explanation: *ALTER is mobile-first because decisions happen in the
> moment. The phone is the capture layer for voice, camera, context,
> relationships, goals and proof. Private memory stays local (and encrypted)
> when possible; lightweight AI runs on-device for redaction, extraction and
> retrieval. When a decision needs deeper reasoning, only the needed context
> goes to the cloud, where the Clone Council, future simulator and opportunity
> engine produce a personalized decision card with tradeoffs, next actions and
> follow-through tracking.*
