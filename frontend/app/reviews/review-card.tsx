"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { submitReview, type Assessment } from "@/lib/api";

function Flag({ show, label }: { show: boolean; label: string }) {
  if (!show) return null;
  return (
    <span className="rounded bg-amber-100 px-2 py-0.5 text-xs text-amber-800">{label}</span>
  );
}

export function ReviewCard({ assessment }: { assessment: Assessment }) {
  const router = useRouter();
  const [reviewer, setReviewer] = useState("");
  const [annotation, setAnnotation] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function decide(decision: "accepted" | "rejected") {
    if (!reviewer.trim()) {
      setError("Reviewer name is required — decisions are audited.");
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await submitReview(assessment.assessment_id, {
        reviewer,
        decision,
        annotation: annotation || undefined,
      });
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "review failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="rounded-lg border border-slate-200 bg-white p-5">
      <div className="flex flex-wrap items-center gap-2">
        <Flag show={assessment.gap_detected} label="gap" />
        <Flag show={assessment.missing_data} label="missing expectation" />
        <Flag show={assessment.stale_evidence} label="stale evidence" />
        <span className="text-xs text-slate-500">
          uncertainty {assessment.uncertainty.toFixed(2)}
        </span>
      </div>
      <p className="mt-2 text-sm">{assessment.summary}</p>
      <p className="mt-1 text-xs text-slate-500">
        evidence: {assessment.evidence_refs.join(", ") || "none"} · rule{" "}
        {assessment.rule_version ?? "n/a"}
      </p>
      <div className="mt-4 flex flex-wrap items-center gap-2">
        <input
          className="rounded border border-slate-300 px-2 py-1 text-sm"
          placeholder="Reviewer"
          value={reviewer}
          onChange={(e) => setReviewer(e.target.value)}
        />
        <input
          className="min-w-48 flex-1 rounded border border-slate-300 px-2 py-1 text-sm"
          placeholder="Annotation (optional)"
          value={annotation}
          onChange={(e) => setAnnotation(e.target.value)}
        />
        <button
          onClick={() => decide("accepted")}
          disabled={busy}
          className="rounded bg-emerald-600 px-3 py-1 text-sm text-white disabled:opacity-50"
        >
          Accept
        </button>
        <button
          onClick={() => decide("rejected")}
          disabled={busy}
          className="rounded bg-rose-600 px-3 py-1 text-sm text-white disabled:opacity-50"
        >
          Reject
        </button>
      </div>
      {error && <p className="mt-2 text-xs text-rose-600">{error}</p>}
    </div>
  );
}
