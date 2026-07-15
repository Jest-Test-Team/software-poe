"""FastAPI orchestrator process. The Julia worker (julia/worker.jl) runs as a
sibling process in the same container and consumes the analysis_jobs table."""

import os
from contextlib import contextmanager

import psycopg
from fastapi import FastAPI, HTTPException

app = FastAPI(title="Software POE Analysis Engine", version="0.1.0")


@contextmanager
def connection():
    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        yield conn


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.get("/internal/analysis/jobs")
def job_stats() -> dict:
    with connection() as conn:
        rows = conn.execute(
            "SELECT status, count(*) FROM analysis_jobs GROUP BY status"
        ).fetchall()
    return {"jobs": {status: count for status, count in rows}}


@app.post("/internal/analysis/requeue-stuck")
def requeue_stuck() -> dict:
    """Return jobs stuck in 'running' (e.g. worker crash) to the queue."""
    with connection() as conn:
        cur = conn.execute(
            """UPDATE analysis_jobs SET status = 'pending', updated_at = now()
               WHERE status = 'running' AND updated_at < now() - interval '10 minutes'"""
        )
        conn.commit()
    return {"requeued": cur.rowcount}


@app.get("/internal/analysis/jobs/{job_id}")
def job_detail(job_id: int) -> dict:
    with connection() as conn:
        row = conn.execute(
            "SELECT id, event_id, status, error FROM analysis_jobs WHERE id = %s",
            (job_id,),
        ).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="job not found")
    return {"id": row[0], "event_id": str(row[1]), "status": row[2], "error": row[3]}
