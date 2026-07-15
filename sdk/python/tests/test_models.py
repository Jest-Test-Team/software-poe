import pytest

from software_poe import Event, ValidationError


def make_event(**overrides):
    base = dict(
        tenant_id="synthetic-lab",
        source="synthetic-fixture",
        observed_at="2026-07-11T08:00:00Z",
        metric="intent_fulfillment_ratio",
        value=0.42,
    )
    base.update(overrides)
    return Event(**base)


def test_valid_event_passes():
    make_event().validate()


def test_unknown_metric_rejected():
    with pytest.raises(ValidationError, match="metric"):
        make_event(metric="latency_p99").validate()


def test_bad_timestamp_rejected():
    with pytest.raises(ValidationError, match="observed_at"):
        make_event(observed_at="yesterday").validate()


def test_non_scalar_attribute_rejected():
    with pytest.raises(ValidationError, match="attributes.nested"):
        make_event(attributes={"nested": {"a": 1}}).validate()


def test_to_dict_omits_empty_optionals():
    payload = make_event().to_dict()
    assert "unit" not in payload
    assert payload["schema_version"] == "0.1.0"
    assert payload["project"] == "software-poe"
