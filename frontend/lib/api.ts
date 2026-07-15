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
  human_review_required: boolean;
  created_at: string;
}

const BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8081";
const API_KEY = process.env.NEXT_PUBLIC_API_KEY ?? "";
export const TENANT_ID = process.env.NEXT_PUBLIC_TENANT_ID ?? "synthetic-lab";

function headers(): Record<string, string> {
  const h: Record<string, string> = { "Content-Type": "application/json" };
  if (API_KEY) h["X-API-Key"] = API_KEY;
  return h;
}

export async function fetchAssessments(status?: string): Promise<Assessment[]> {
  const params = new URLSearchParams({ tenant_id: TENANT_ID });
  if (status) params.set("status", status);
  const resp = await fetch(`${BASE_URL}/v1/software-poe/assessments?${params}`, {
    headers: headers(),
    cache: "no-store",
  });
  if (!resp.ok) throw new Error(`Failed to load assessments (HTTP ${resp.status})`);
  return resp.json();
}

export async function submitReview(
  assessmentId: string,
  review: { reviewer: string; decision: "accepted" | "rejected"; annotation?: string },
): Promise<void> {
  const params = new URLSearchParams({ tenant_id: TENANT_ID });
  const resp = await fetch(
    `${BASE_URL}/v1/software-poe/assessments/${assessmentId}/review?${params}`,
    { method: "POST", headers: headers(), body: JSON.stringify(review) },
  );
  if (!resp.ok) throw new Error(`Review failed (HTTP ${resp.status})`);
}
