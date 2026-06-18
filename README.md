# ALTER



ALTER is a mobile-first Flutter application for a voice-first AI Future Operating System.



## Stack



- Flutter with Material 3

- Riverpod for application state

- go_router for route orchestration

- **SQLCipher** (`sqflite_sqlcipher`) — encrypted on-device database (`alter.db`)

- **Local PIN + optional biometrics** — primary gate; optional Supabase sign-in in Settings

- **On-device Gemma 4** (flutter_gemma) + **sherpa-onnx** offline STT/TTS

- **Optional cloud** — enable gateway URL + Supabase in Settings; proactive agent when `alter_online_assistant` is on

         

- Clean Architecture: domain, data/local DAOs, application, presentation

- **UI:** [`frontend/alter_flutter/`](frontend/alter_flutter/) is the design source; runtime screens live in [`lib/src/ui/`](lib/src/ui/)



## Local-first data & auth



| Concern | Implementation |

|---------|----------------|

| Database | `{documents}/alter.db` encrypted with PIN-derived key |

| Auth | PIN setup → PIN unlock; optional cloud account in Settings |

| Memories & RAG | `MemoryDao` + `EmbeddingDao` (hash embeddings in SQLCipher) |

| Profile & BYOK keys | `ProfileDao` — OpenAI/Sarvam keys stored locally |

| Legacy Supabase data | Optional JSON import or Supabase sign-in: Settings → Data management |

| Backend (optional) | `docker-compose.yml` for local dev; [`infra/railway/`](infra/railway/) for optional hosted deploy |



Fresh install flow: FTUE → Login → PIN setup → Permissions → Languages → About You → Home.



## Run



```bash

flutter pub get

flutter run

```



### Gateway URL (optional hybrid cloud)



The app is **offline-first**. Cloud paths are optional fallbacks in Settings → Performance.



- Default voice backend: **Cloud AI** (OpenAI BYOK) when online

- Default voice I/O: **Offline first** (sherpa-onnx when downloaded, else OS STT/TTS)

- Offline inference cascade: **Cloud/Gateway → on-device Gemma → memory-aware heuristic**

- OpenAI: direct BYOK API when Cloud AI is enabled

- Sarvam TTS: direct REST API when Cloud voice is enabled

- Gateway: `--dart-define=ALTER_API_GATEWAY_URL=...` or Settings override



## On-device models



| Model | Default | Settings |

|-------|---------|----------|

| Gemma 4 E4B/E2B (LiteRT-LM) | Optional (~3 GB) | Settings → Performance → On-device Gemma 4 |

| SenseVoice ASR + VAD | Mid+ phones | Settings → Performance → Offline voice models |

| Moonshine Tiny ASR | Low tier | Same screen |

| Piper TTS (en-IN / hi) | All tiers | Download per locale |



Release APK is **~80–120 MB** (no LLM bundled). Download Gemma 4 from Settings → EDGE.



**Resource governor:** never loads ASR + LLM + TTS simultaneously. Voice turn: listen (ASR) → infer (cascade) → speak (TTS).



## Screens



- FTUE & onboarding (local profile, no email auth)

- PIN setup / unlock

- Life Feed, ContextOS, Voice, Memory

- Settings → Performance, Offline voice models, Lock ALTER

- Data management → export + **Import from cloud export** (JSON)



## Architecture



```text

lib/src/

  core/database/     AlterDatabase, DatabaseKeyService, migrations, import

  core/performance/  Device tier, OnDeviceResourceGovernor

  data/local/        DAOs (never import sqflite in controllers)

  features/voice/data/offline/  sherpa-onnx ASR/TTS

  features/voice/application/   VoicePipeline, VoiceTurnOrchestrator, cascade runtime

```



## Acceptance checklist (manual)



**Auth / DB**

- [ ] Fresh install → PIN setup → `alter.db` not readable without PIN

- [ ] Lock from Settings → data inaccessible until re-unlock



**RAG**

- [ ] Voice turn stores memory; retrieve works in airplane mode

- [ ] Legacy `alter_memory_vectors.db` imported on upgrade (migration v2)



**Voice offline**

- [ ] Download ASR + TTS from Settings → Offline voice models

- [ ] Download/load Gemma 4 from Settings → EDGE (optional)

- [ ] Airplane mode: speak → Gemma or heuristic answer → offline TTS (not network error)

- [ ] Offline-only mode skips cloud voice and cloud inference



**Hybrid cloud**

- [ ] OpenAI BYOK works without Supabase when online

- [ ] Disable Cloud AI → falls to Gemma/heuristic without crash



## Backend services (optional)



Docker microservices under `services/` remain available for gateway/hybrid deployments. The phone app no longer requires Supabase.



```bash

docker compose up --build

```



## Data policy



ALTER does not seed demo data. Empty surfaces show **Still inferring…** until real user actions populate memories.



## Launch Blueprint



- [ALTER Unicorn Launch Blueprint](docs/alter_unicorn_launch_blueprint.md)

- [Mission Control Frontend Architecture](docs/mission_control_frontend.md)


