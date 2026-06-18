# ALTER Lens

ALTER Lens turns phone camera captures into structured career and opportunity
intelligence with OpenAI vision models.

## Flow

```mermaid
flowchart TD
  A["Flutter camera preview"] --> B["Capture image"]
  B --> C["POST /v1/alter-lens/analyze"]
  C --> D["FastAPI upload validation"]
  D --> E{"Environment"}
  E -->|local| F["Deterministic analyzer"]
  E -->|production| G["OpenAI structured vision output"]
  G --> H["Summary"]
  G --> I["Insights"]
  G --> J["Opportunities"]
  G --> K["Recommendations"]
  F --> H
  F --> I
  F --> J
  F --> K
  H --> L["Flutter result dashboard"]
  I --> L
  J --> L
  K --> L
```

## Scan Types

- Resume
- Startup deck
- Event poster
- Research paper
- Product

## API

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/healthz` | Service health |
| `GET` | `/v1/alter-lens/architecture` | Flow and schema description |
| `POST` | `/v1/alter-lens/analyze` | Analyze an uploaded camera image |

`POST /v1/alter-lens/analyze` expects multipart form data:

- `scan_type`: `resume`, `startup_deck`, `event_poster`, `research_paper`, or `product`
- `image`: camera image upload
- `user_context`: optional short context

## Run

```powershell
cd services\alter_lens
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -e ".[dev]"
.\.venv\Scripts\python.exe -m uvicorn alter_lens.api:app --reload --port 8130
```

Production OpenAI mode:

```powershell
$env:ALTER_LENS_ENV="production"
$env:OPENAI_API_KEY="..."
$env:ALTER_LENS_OPENAI_MODEL="gpt-4.1-mini"
```

## Response Contract

```mermaid
classDiagram
  class LensScanResponse {
    scan_id
    scan_type
    summary
    confidence
    insights
    opportunities
    recommendations
    memory_candidates
  }
  class LensInsight {
    title
    detail
    confidence
    tags
  }
  class LensOpportunity {
    title
    why_now
    next_step
    score
  }
  class LensRecommendation {
    action
    priority
    rationale
  }
  LensScanResponse --> LensInsight
  LensScanResponse --> LensOpportunity
  LensScanResponse --> LensRecommendation
```
