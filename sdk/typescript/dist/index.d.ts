/** Client SDK for Software POE — mirrors schemas/event.schema.json (0.1.0). */
export declare const SCHEMA_VERSION = "0.1.0";
export declare const PROJECT = "software-poe";
export declare const METRICS: readonly ["intent_fulfillment_ratio", "slo_gap", "cost_estimate_error", "unused_capability_ratio", "incident_delta"];
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
export declare function validateEvent(event: Event): string[];
export declare class ValidationError extends Error {
    errors: string[];
    constructor(errors: string[]);
}
export interface ClientOptions {
    apiKey?: string;
    fetch?: typeof fetch;
}
export declare class Client {
    private baseUrl;
    private headers;
    private fetchImpl;
    constructor(baseUrl: string, options?: ClientOptions);
    private request;
    ingest(event: Event): Promise<{
        event_id: string;
        evidence_ref: string;
    }>;
    assessments(tenantId: string, status?: string): Promise<Assessment[]>;
    review(assessmentId: string, tenantId: string, review: {
        reviewer: string;
        decision: "accepted" | "rejected";
        annotation?: string;
    }): Promise<{
        review_id: string;
        assessment_id: string;
        status: string;
    }>;
}
