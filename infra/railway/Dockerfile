# ALTER backend — single-container deploy of the whole FastAPI stack.
#
# All nine engine services run on their default localhost ports; the API gateway
# (the only externally-exposed service) runs on Railway's $PORT and reaches the
# others at http://localhost:80xx — which are exactly the gateway's config
# defaults, so no inter-service URL wiring is needed.
#
# Build context must be the repo root (so `services/` is available).
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Install every FastAPI service into one environment. Compatible deps
# (fastapi / pydantic / httpx / uvicorn) resolve once across all of them.
COPY services /app/services
RUN pip install --upgrade pip && \
    for d in api_gateway voice_gateway clone_council future_simulation \
             memory_system opportunity_engine social_graph alter_lens \
             reputation_engine officekit; do \
        echo "==> installing $d" && pip install "/app/services/$d" || exit 1; \
    done

COPY infra/railway/start.sh /app/start.sh
# Strip any CR (Windows checkout) so the Linux shell can run the script.
RUN sed -i 's/\r$//' /app/start.sh && chmod +x /app/start.sh

# Gateway listens here by default; Railway overrides with its own $PORT.
ENV PORT=8060
EXPOSE 8060

CMD ["/app/start.sh"]
