import { fetchAssessments, type Assessment } from "@/lib/api";
import { ReviewCard } from "./review-card";

export const dynamic = "force-dynamic";

export default async function ReviewQueue() {
  let queue: Assessment[] = [];
  let error: string | null = null;
  try {
    queue = await fetchAssessments("review-required");
  } catch (e) {
    error = e instanceof Error ? e.message : "unknown error";
  }

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Review queue</h1>
      <p className="text-sm text-slate-600">
        Evidence, assumptions and missing-data flags are shown with each assessment. Decisions
        are recorded with your reviewer identity in the audit trail.
      </p>
      {error && (
        <div className="rounded-lg border border-amber-300 bg-amber-50 p-4 text-sm">
          Could not reach the gateway API: {error}
        </div>
      )}
      <div className="space-y-4">
        {queue.map((a) => (
          <ReviewCard key={a.assessment_id} assessment={a} />
        ))}
        {!error && queue.length === 0 && (
          <p className="text-sm text-slate-500">Nothing awaiting review.</p>
        )}
      </div>
    </div>
  );
}
