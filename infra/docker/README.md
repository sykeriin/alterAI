# ALTER Local Deployment

Run all backend services and local data stores:

```powershell
docker compose up --build
```

Gateway:

- `http://localhost:8060/healthz`
- `http://localhost:8060/v1/gateway/routes`
- `http://localhost:8060/v1/system/health`
- `POST http://localhost:8060/v1/mission/briefing`

Service ports:

| Service | Port |
| --- | --- |
| API Gateway | 8060 |
| Voice Gateway | 8070 |
| Clone Council | 8080 |
| Future Simulation | 8090 |
| Memory System | 8100 |
| Opportunity Engine | 8110 |
| Social Graph | 8120 |
| Alter Lens | 8130 |
| Reputation Engine | 8140 |
| OfficeKit | 8150 |
