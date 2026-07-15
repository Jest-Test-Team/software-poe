/** Client SDK for Software POE — mirrors schemas/event.schema.json (0.1.0). */

export const SCHEMA_VERSION = "0.1.0";
export const PROJECT = "software-poe";

export const METRICS = [
  "intent_fulfillment_ratio",
  "slo_gap",
  "cost_estimate_error",
  "unused_capability_ratio",
  "incident_delta",
] as const;

export type Metric = (typeof METRICS)[number];

export type Scalar = string | number | boolean | null;

export interface Event {
  tenant_id: string;
  project?: typeof PROJECT;
  source: string;
  observed_at: string;
  metric: Metric;
  value: number;
  unit?: string;
  evidence_ref?: string;
  schema_version?: typeof SCHEMA_VERSION;
  attributes?: Record<string, Scalar>;
}

export interface Assessment {
  assessment_id: string;
  tenant_id: string;
  status: "draft" | "review-required" | "accepted" | "rejected";
  summary: string;
  uncertainty: number;
  gap_detected: boolean;
  missing_data: boolean;
  stale_evidence: boolean;
  rule_version: string | null;
  evidence_refs: string[];
  human_review_required: true;
  created_at: string;
}

export function validateEvent(event: Event): string[] {
  const errors: string[] = [];
  if (!event.tenant_id) errors.push("tenant_id is required");
  if ((event.project ?? PROJECT) !== PROJECT) errors.push(`project must be '${PROJECT}'`);
  if (!event.source) errors.push("source is required");
  if (Number.isNaN(Date.parse(event.observed_at ?? "")))
    errors.push("observed_at must be an RFC3339 date-time");
  if (!METRICS.includes(event.metric)) errors.push("metric must be a registered metric ID");
  if (typeof event.value !== "number") errors.push("value must be a number");
  if ((event.schema_version ?? SCHEMA_VERSION) !== SCHEMA_VERSION)
    errors.push(`schema_version must be '${SCHEMA_VERSION}'`);
  for (const [key, value] of Object.entries(event.attributes ?? {})) {
    if (value !== null && !["string", "number", "boolean"].includes(typeof value))
      errors.push(`attributes.${key} must be a scalar`);
  }
  return errors;
}

export class ValidationError extends Error {
  errors: string[];

  constructor(errors: string[]) {
    super(errors.join("; "));
    this.name = "ValidationError";
    this.errors = errors;
  }
}

export interface ClientOptions {
  apiKey?: string;
  fetch?: typeof fetch;
}

export class Client {
  private baseUrl: string;
  private headers: Record<string, string>;
  private fetchImpl: typeof fetch;

  constructor(baseUrl: string, options: ClientOptions = {}) {
    this.baseUrl = baseUrl.replace(/\/$/, "");
    this.headers = options.apiKey ? { "X-API-Key": options.apiKey } : {};
    this.fetchImpl = options.fetch ?? fetch;
  }

  private async request<T>(path: string, init: RequestInit = {}): Promise<T> {
    const resp = await this.fetchImpl(`${this.baseUrl}${path}`, {
      ...init,
      headers: { "Content-Type": "application/json", ...this.headers, ...init.headers },
    });
    if (!resp.ok) throw new Error(`HTTP ${resp.status}: ${await resp.text()}`);
    return (await resp.json()) as T;
  }

  async ingest(event: Event): Promise<{ event_id: string; evidence_ref: string }> {
    const errors = validateEvent(event);
    if (errors.length > 0) throw new ValidationError(errors);
    const payload = { project: PROJECT, schema_version: SCHEMA_VERSION, ...event };
    return this.request("/v1/software-poe/events", {
      method: "POST",
      body: JSON.stringify(payload),
    });
  }

  async assessments(tenantId: string, status?: string): Promise<Assessment[]> {
    const params = new URLSearchParams({ tenant_id: tenantId });
    if (status) params.set("status", status);
    return this.request(`/v1/software-poe/assessments?${params}`);
  }

  async review(
    assessmentId: string,
    tenantId: string,
    review: { reviewer: string; decision: "accepted" | "rejected"; annotation?: string },
  ): Promise<{ review_id: string; assessment_id: string; status: string }> {
    const params = new URLSearchParams({ tenant_id: tenantId });
    return this.request(`/v1/software-poe/assessments/${assessmentId}/review?${params}`, {
      method: "POST",
      body: JSON.stringify(review),
    });
  }
}
