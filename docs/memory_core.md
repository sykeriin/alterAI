# ALTER Memory Core

ALTER's Memory Core is the local-first identity and recall layer beneath the
voice assistant, phone actions, personas, and future simulations.

## Product Contract

- Default to forgetting.
- Classify before storing.
- Never store restricted secrets such as OTPs, passwords, PINs, or CVVs.
- Require confirmation before durable or sensitive facts become identity evidence.
- Preserve structured, inspectable memories; embeddings are retrieval indexes only.
- Retrieve the smallest relevant context package within a strict budget.
- Derive identity from repeated evidence, never from one interaction.
- Let the user inspect, correct, expire, export, and delete memory.

## End-to-End Flow

```text
phone signal or voice interaction
  -> local intent, relevance, sensitivity, and retention classification
  -> reject, keep for session, keep until expiry, or request durable confirmation
  -> abstract raw interaction into structured memory
  -> delete raw interaction
  -> retrieve a budgeted context package when relevant
  -> reason or act with user confirmation
  -> record outcomes and update evidence
```

## Lifecycle

1. **Encode**: extract the useful signal from a permitted interaction.
2. **Stabilize**: confirm, repeat, or validate a potential durable memory.
3. **Store**: save structured facts with provenance, confidence, sensitivity, and expiry.
4. **Retrieve**: rank only relevant memories into a bounded context package.
5. **Update**: supersede stale facts and strengthen or weaken evidence.
6. **Forget**: expire, reject, archive, or delete information.

## Reasoning Personas

The five personas share this one governed memory core. They are reasoning modes,
not continuously running models:

- Present Self
- Future Self
- Realist
- Strategist
- Values Self

Routine phone actions skip the council. Important decisions invoke the personas
sequentially and return disagreements, assumptions, experiments, and next actions.

## Current Vertical Slice

- Deterministic classifier-first ingestion
- Restricted-secret rejection
- Session and expiring short-term memory
- Confirmation-gated durable and sensitive memory
- Context-budgeted retrieval
- Evidence-linked identity snapshot
- Governance policy and portable shareable export APIs
- Flutter Memory Ledger with persisted retention, confirmation, portability,
  and recall-budget controls

## Next Production Stages

1. Replace deterministic classification fallback with a quantized on-device classifier.
2. Connect phone-source adapters to classified ingestion.
3. Store structured memory locally with encrypted indexes.
4. Add per-memory ledger rows, provenance, corrections, expiry, and deletion.
5. Record action outcomes and use them to update identity evidence.
6. Feed the governed context package into voice actions and the five-persona council.
