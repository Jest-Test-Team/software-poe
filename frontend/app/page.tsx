import { fetchAssessments, type Assessment } from "@/lib/api";

export const dynamic = "force-dynamic";

function Stat({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-lg border border-slate-200 bg-white p-4">
      <div className="text-sm text-slate-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold">{value}</div>
    </div>
  );
}

export default async function Dashboard() {
  let assessments: Assessment[] = [];
  let error: string | null = null;
  try {
    assessments = await fetchAssessments();
  } catch (e) {
    error = e instanceof Error ? e.message : "unknown error";
  }

  const pending = assessments.filter((a) => a.status === "review-required");
  const gaps = assessments.filter((a) => a.gap_detected);
  const missing = assessments.filter((a) => a.missing_data || a.stale_evidence);

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Architecture performance dashboard</h1>
      <p className="text-sm text-slate-600">
        Expected vs. actual across ADR assumptions. Every assessment requires human review —
        scores never replace professional judgement.
      </p>
      {error ? (
        <div className="rounded-lg border border-amber-300 bg-amber-50 p-4 text-sm">
          Could not reach the gateway API: {error}
        </div>
      ) : (
        <>
          <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
            <Stat label="Assessments" value={assessments.length} />
            <Stat label="Awaiting review" value={pending.length} />
            <Stat label="Gaps detected" value={gaps.length} />
            <Stat label="Missing / stale evidence" value={missing.length} />
          </div>
          <section>
            <h2 className="mb-3 text-lg font-semibold">Latest gap findings</h2>
            <ul className="space-y-2">
              {gaps.slice(0, 10).map((a) => (
                <li
                  key={a.assessment_id}
                  className="rounded-lg border border-slate-200 bg-white p-4 text-sm"
                >
                  <div>{a.summary}</div>
                  <div className="mt-1 text-xs text-slate-500">
                    uncertainty {a.uncertainty.toFixed(2)} · rule {a.rule_version ?? "n/a"} ·{" "}
                    {new Date(a.created_at).toLocaleString()}
                  </div>
                </li>
              ))}
              {gaps.length === 0 && (
                <li className="text-sm text-slate-500">No gaps detected yet.</li>
              )}
            </ul>
          </section>
        </>
      )}
    </div>
  );
}
