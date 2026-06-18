# ALTER Mission Control Frontend Architecture

```mermaid
flowchart TD
  A["MissionControlScreen"] --> B["missionControlProvider"]
  B --> C["MissionControlSnapshot"]
  C --> D["Phone Field Layer"]
  C --> E["Laptop Strategy Layer"]
  D --> D1["Voice"]
  D --> D2["Camera"]
  D --> D3["NFC"]
  E --> E1["Future Timelines"]
  E --> E2["Clone Council"]
  E --> E3["Opportunity Radar"]
  E --> E4["Social Graph"]
  E --> E5["Reputation Engine"]
  A --> F["Mission Map Painter"]
  A --> G["Command Feed"]
  A --> H["Future Timeline Strip"]
```

## Screen Model

```mermaid
classDiagram
  class MissionControlSnapshot {
    operatorName
    activeObjective
    readiness
    phoneModules
    laptopModules
    metrics
    events
  }
  class MissionModule {
    id
    title
    route
    surface
    signal
    health
    status
    cadence
    capabilities
  }
  class MissionMetric {
    label
    value
    detail
    moduleId
  }
  class MissionEvent {
    time
    title
    source
    impact
  }
  MissionControlSnapshot --> MissionModule
  MissionControlSnapshot --> MissionMetric
  MissionControlSnapshot --> MissionEvent
```

## Navigation

```mermaid
flowchart LR
  M["/mission"] --> V["/voice"]
  M --> L["/lens"]
  M --> N["/nfc"]
  M --> F["/simulator"]
  M --> C["/council"]
  M --> R["/radar"]
  M --> S["/social"]
  M --> P["/reputation"]
```

## Layout Strategy

- Compact: mission map first, then phone layer, laptop layer, timeline, feed.
- Expanded: phone layer, central mission map, laptop layer in one command row.
- Reusable data model: `MissionControlSnapshot` can be replaced by live backend telemetry.
- Visual language: glass panels, dense telemetry, constrained command map, Linear-style rows.
