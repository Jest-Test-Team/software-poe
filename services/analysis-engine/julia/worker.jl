# Julia worker process: consumes analysis_jobs (Postgres-as-queue), computes
# gaps + assessments, writes audit entries. Runs beside the FastAPI process
# in the same container (see entrypoint.sh).

using LibPQ, Tables, Dates

include("metrics.jl")
using .Metrics

const RULE_VERSION = "v0.1.0"

function claim_job(conn)
    result = execute(conn, """
        UPDATE analysis_jobs SET status = 'running', updated_at = now()
        WHERE id = (SELECT id FROM analysis_jobs WHERE status = 'pending'
                    ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED)
        RETURNING id, event_id""")
    rows = Tables.rowtable(result)
    isempty(rows) ? nothing : rows[1]
end

function load_event(conn, event_id)
    rows = Tables.rowtable(execute(conn,
        """SELECT id, tenant_id, metric, value, evidence_ref,
                  extract(epoch from observed_at) AS observed_epoch
           FROM events WHERE id = \$1""", [event_id]))
    isempty(rows) ? nothing : rows[1]
end

function load_expectation(conn, tenant_id, metric)
    rows = Tables.rowtable(execute(conn,
        """SELECT id, expected_value, comparator, rule_version FROM expectations
           WHERE tenant_id = \$1 AND metric = \$2 AND rule_version = \$3""",
        [tenant_id, metric, RULE_VERSION]))
    isempty(rows) ? nothing : rows[1]
end

function process_job(conn, job)
    event = load_event(conn, job.event_id)
    event === nothing && error("event $(job.event_id) not found")

    expectation = load_expectation(conn, event.tenant_id, event.metric)
    has_expectation = expectation !== nothing
    expected = has_expectation ? Float64(expectation.expected_value) : nothing
    comparator = has_expectation ? expectation.comparator : ">="

    result = Metrics.evaluate(event.metric, Float64(event.value), expected, comparator)
    stale = Metrics.is_stale(Float64(event.observed_epoch), datetime2unix(now(UTC)))
    uncertainty = Metrics.uncertainty_score(has_expectation=has_expectation, stale=stale)

    summary = result.summary * (stale ? " Evidence is stale (>30d old)." : "")

    execute(conn, "BEGIN")
    try
        gap_id = missing  # LibPQ maps `missing` (not `nothing`) to SQL NULL
        if has_expectation
            rows = Tables.rowtable(execute(conn,
                """INSERT INTO gaps (tenant_id, event_id, expectation_id, metric,
                                     expected_value, actual_value, gap_value)
                   VALUES (\$1,\$2,\$3,\$4,\$5,\$6,\$7) RETURNING id""",
                [event.tenant_id, event.id, expectation.id, event.metric,
                 expected, event.value, result.gap_value]))
            gap_id = rows[1].id
        end
        execute(conn,
            """INSERT INTO assessments (tenant_id, gap_id, status, summary, uncertainty,
                                        gap_detected, missing_data, stale_evidence,
                                        rule_version, evidence_refs)
               VALUES (\$1,\$2,'review-required',\$3,\$4,\$5,\$6,\$7,\$8, ARRAY[\$9])""",
            [event.tenant_id, gap_id, summary, uncertainty, result.gap_detected,
             !has_expectation, stale, has_expectation ? expectation.rule_version : missing,
             event.evidence_ref])
        execute(conn,
            """INSERT INTO audit_entries (tenant_id, actor, action, object_type, object_id, payload_hash)
               VALUES (\$1,'analysis-engine','assess','event',\$2,\$3)""",
            [event.tenant_id, string(event.id), coalesce(event.evidence_ref, "sha256:unknown")])
        execute(conn, "UPDATE analysis_jobs SET status = 'done', updated_at = now() WHERE id = \$1", [job.id])
        execute(conn, "COMMIT")
    catch e
        execute(conn, "ROLLBACK")
        rethrow(e)
    end
end

function main()
    conn = LibPQ.Connection(ENV["DATABASE_URL"])
    poll_seconds = parse(Float64, get(ENV, "WORKER_POLL_SECONDS", "2"))
    @info "analysis worker started" poll_seconds
    while true
        job = claim_job(conn)
        if job === nothing
            sleep(poll_seconds)
            continue
        end
        try
            process_job(conn, job)
            @info "job done" job.id
        catch e
            @error "job failed" job.id exception=(e, catch_backtrace())
            execute(conn,
                "UPDATE analysis_jobs SET status = 'failed', error = \$2, updated_at = now() WHERE id = \$1",
                [job.id, sprint(showerror, e)])
        end
    end
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    main()
end
