"""Uncertainty scoring shared by orchestrator and surfaced to reviewers.

Kept as pure functions so the policy is unit-testable without a database.
The Julia worker mirrors this logic in julia/metrics.jl; the Robot suite
`stale_evidence.robot` guards the two implementations against drift.
"""

from datetime import datetime, timedelta, timezone

STALE_AFTER_DAYS = 30

BASE_UNCERTAINTY = 0.1
MISSING_EXPECTATION_PENALTY = 0.9
STALE_PENALTY = 0.3


def is_stale(observed_at: datetime, now: datetime | None = None) -> bool:
    now = now or datetime.now(timezone.utc)
    return now - observed_at > timedelta(days=STALE_AFTER_DAYS)


def uncertainty_score(*, has_expectation: bool, stale: bool) -> float:
    score = BASE_UNCERTAINTY
    if not has_expectation:
        score += MISSING_EXPECTATION_PENALTY
    if stale:
        score += STALE_PENALTY
    return min(score, 1.0)
