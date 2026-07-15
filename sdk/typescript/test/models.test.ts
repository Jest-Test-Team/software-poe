import { test } from "node:test";
import assert from "node:assert/strict";
import { validateEvent, type Event } from "../src/index.ts";

const valid: Event = {
  tenant_id: "synthetic-lab",
  source: "synthetic-fixture",
  observed_at: "2026-07-11T08:00:00Z",
  metric: "intent_fulfillment_ratio",
  value: 0.42,
};

test("valid event has no errors", () => {
  assert.deepEqual(validateEvent(valid), []);
});

test("unknown metric rejected", () => {
  const errors = validateEvent({ ...valid, metric: "latency_p99" as Event["metric"] });
  assert.ok(errors.some((e) => e.includes("metric")));
});

test("bad timestamp rejected", () => {
  const errors = validateEvent({ ...valid, observed_at: "yesterday" });
  assert.ok(errors.some((e) => e.includes("observed_at")));
});

test("non-scalar attribute rejected", () => {
  const errors = validateEvent({
    ...valid,
    attributes: { nested: { a: 1 } as unknown as string },
  });
  assert.ok(errors.some((e) => e.includes("attributes.nested")));
});
