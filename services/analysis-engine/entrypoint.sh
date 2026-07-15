#!/bin/bash
# Two processes, one image (implementation plan §2.1): FastAPI orchestrator +
# Julia metric worker. If either dies, the container exits so Choreo restarts it.
set -e

julia --project=/app/julia /app/julia/worker.jl &
JULIA_PID=$!

uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8082}" &
UVICORN_PID=$!

trap 'kill $JULIA_PID $UVICORN_PID 2>/dev/null' TERM INT

# Exit when the first process exits.
wait -n $JULIA_PID $UVICORN_PID 2>/dev/null || wait $JULIA_PID
