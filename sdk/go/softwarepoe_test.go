package softwarepoe

import "testing"

func validEvent() *Event {
	return &Event{
		TenantID:   "synthetic-lab",
		Source:     "synthetic-fixture",
		ObservedAt: "2026-07-11T08:00:00Z",
		Metric:     "intent_fulfillment_ratio",
		Value:      0.42,
	}
}

func TestValidEventPasses(t *testing.T) {
	if errs := validEvent().Validate(); len(errs) != 0 {
		t.Fatalf("expected no errors, got %v", errs)
	}
}

func TestValidateFillsConstants(t *testing.T) {
	e := validEvent()
	e.Validate()
	if e.Project != Project || e.SchemaVersion != SchemaVersion {
		t.Fatalf("constants not filled: %+v", e)
	}
}

func TestUnknownMetricRejected(t *testing.T) {
	e := validEvent()
	e.Metric = "latency_p99"
	if errs := e.Validate(); len(errs) == 0 {
		t.Fatal("expected metric error")
	}
}

func TestBadTimestampRejected(t *testing.T) {
	e := validEvent()
	e.ObservedAt = "yesterday"
	if errs := e.Validate(); len(errs) == 0 {
		t.Fatal("expected observed_at error")
	}
}

func TestNonScalarAttributeRejected(t *testing.T) {
	e := validEvent()
	e.Attributes = map[string]any{"nested": map[string]any{"a": 1}}
	if errs := e.Validate(); len(errs) == 0 {
		t.Fatal("expected attributes error")
	}
}
