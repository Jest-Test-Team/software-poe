"""Typed event model mirroring schemas/event.schema.json (version 0.1.0)."""

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

SCHEMA_VERSION = "0.1.0"
PROJECT = "software-poe"
METRICS = frozenset(
    {
        "intent_fulfillment_ratio",
        "slo_gap",
        "cost_estimate_error",
        "unused_capability_ratio",
        "incident_delta",
    }
)


class ValidationError(ValueError):
    def __init__(self, errors: list[str]):
        super().__init__("; ".join(errors))
        self.errors = errors


@dataclass
class Event:
    tenant_id: str
    source: str
    observed_at: str
    metric: str
    value: float
    unit: str | None = None
    evidence_ref: str | None = None
    attributes: dict[str, Any] = field(default_factory=dict)
    project: str = PROJECT
    schema_version: str = SCHEMA_VERSION

    def validate(self) -> None:
        errors: list[str] = []
        if not self.tenant_id:
            errors.append("tenant_id is required")
        if self.project != PROJECT:
            errors.append(f"project must be '{PROJECT}'")
        if not self.source:
            errors.append("source is required")
        try:
            datetime.fromisoformat(self.observed_at.replace("Z", "+00:00"))
        except (ValueError, AttributeError):
            errors.append("observed_at must be an RFC3339 date-time")
        if self.metric not in METRICS:
            errors.append(f"metric must be one of {sorted(METRICS)}")
        if not isinstance(self.value, (int, float)) or isinstance(self.value, bool):
            errors.append("value must be a number")
        if self.schema_version != SCHEMA_VERSION:
            errors.append(f"schema_version must be '{SCHEMA_VERSION}'")
        for key, val in self.attributes.items():
            if not isinstance(val, (str, int, float, bool, type(None))):
                errors.append(f"attributes.{key} must be a scalar")
        if errors:
            raise ValidationError(errors)

    def to_dict(self) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "tenant_id": self.tenant_id,
            "project": self.project,
            "source": self.source,
            "observed_at": self.observed_at,
            "metric": self.metric,
            "value": self.value,
            "schema_version": self.schema_version,
        }
        if self.unit:
            payload["unit"] = self.unit
        if self.evidence_ref:
            payload["evidence_ref"] = self.evidence_ref
        if self.attributes:
            payload["attributes"] = self.attributes
        return payload
