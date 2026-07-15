from datetime import datetime, timezone

from app.uncertainty import is_stale, uncertainty_score


def test_fresh_evidence_with_expectation_has_low_uncertainty():
    assert uncertainty_score(has_expectation=True, stale=False) == 0.1


def test_missing_expectation_dominates():
    assert uncertainty_score(has_expectation=False, stale=False) == 1.0


def test_stale_evidence_raises_uncertainty():
    assert uncertainty_score(has_expectation=True, stale=True) == 0.4


def test_score_is_capped_at_one():
    assert uncertainty_score(has_expectation=False, stale=True) == 1.0


def test_staleness_threshold():
    now = datetime(2026, 7, 15, tzinfo=timezone.utc)
    assert is_stale(datetime(2026, 5, 1, tzinfo=timezone.utc), now)
    assert not is_stale(datetime(2026, 7, 1, tzinfo=timezone.utc), now)
