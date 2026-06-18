#!/bin/sh
# Launch the whole ALTER backend in one container.
#
# The nine engine services run in the background on their default localhost
# ports. The gateway runs in the FOREGROUND on Railway's $PORT and keeps the
# container alive — if a DB-backed engine (memory_system / social_graph) can't
# reach its database it just exits in the background; the gateway degrades that
# one feature gracefully and everything else keeps working.
set -e

start() { echo "==> $1 on :$2"; uvicorn "$1" --host 0.0.0.0 --port "$2" & }

start alter_voice_gateway.api:app       8070
start alter_clone_council.api:app       8080
start alter_future_simulation.api:app   8090
start alter_memory_system.api:app       8100
start alter_opportunity_engine.api:app  8110
start alter_social_graph.api:app        8120
start alter_lens.api:app                8130
start alter_reputation_engine.api:app   8140
start alter_officekit.api:app           8150

echo "==> api_gateway (foreground) on :${PORT:-8060}"
exec uvicorn alter_api_gateway.api:app --host 0.0.0.0 --port "${PORT:-8060}"
