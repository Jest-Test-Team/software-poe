-- Software POE — initial schema (Neon / Postgres 16)
-- Every evidence object carries tenant_id, source, observed_at, ingested_at, schema_version.

CREATE TABLE IF NOT EXISTS tenants (
    id          text PRIMARY KEY,
    name        text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS architecture_decisions (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id      text NOT NULL REFERENCES tenants(id),
    adr_key        text NOT NULL,
    title          text NOT NULL,
    status         text NOT NULL DEFAULT 'accepted',
    source         text NOT NULL,
    observed_at    timestamptz NOT NULL,
    ingested_at    timestamptz NOT NULL DEFAULT now(),
    schema_version text NOT NULL DEFAULT '0.1.0',
    UNIQUE (tenant_id, adr_key)
);

CREATE TABLE IF NOT EXISTS expectations (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id      text NOT NULL REFERENCES tenants(id),
    adr_id         uuid REFERENCES architecture_decisions(id),
    metric         text NOT NULL,
    comparator     text NOT NULL DEFAULT '>=',        -- >=, <=, ==
    expected_value double precision NOT NULL,
    unit           text,
    rule_version   text NOT NULL DEFAULT 'v0.1.0',
    source         text NOT NULL,
    observed_at    timestamptz NOT NULL,
    ingested_at    timestamptz NOT NULL DEFAULT now(),
    schema_version text NOT NULL DEFAULT '0.1.0',
    UNIQUE (tenant_id, metric, rule_version)
);

-- Observations (evidence events)
CREATE TABLE IF NOT EXISTS events (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id      text NOT NULL REFERENCES tenants(id),
    project        text NOT NULL CHECK (project = 'software-poe'),
    source         text NOT NULL,
    observed_at    timestamptz NOT NULL,
    ingested_at    timestamptz NOT NULL DEFAULT now(),
    metric         text NOT NULL,
    value          double precision NOT NULL,
    unit           text,
    evidence_ref   text,
    schema_version text NOT NULL,
    attributes     jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS idx_events_tenant_metric ON events (tenant_id, metric, observed_at DESC);

-- DB-as-queue for the analysis engine (MVP simplicity, see implementation plan §7)
CREATE TABLE IF NOT EXISTS analysis_jobs (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_id   uuid NOT NULL REFERENCES events(id),
    status     text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','running','done','failed')),
    error      text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON analysis_jobs (status, id);

CREATE TABLE IF NOT EXISTS gaps (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id      text NOT NULL REFERENCES tenants(id),
    event_id       uuid NOT NULL REFERENCES events(id),
    expectation_id uuid REFERENCES expectations(id),
    metric         text NOT NULL,
    expected_value double precision,
    actual_value   double precision NOT NULL,
    gap_value      double precision,
    created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS assessments (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id             text NOT NULL REFERENCES tenants(id),
    gap_id                uuid REFERENCES gaps(id),
    status                text NOT NULL DEFAULT 'review-required'
                          CHECK (status IN ('draft','review-required','accepted','rejected')),
    summary               text NOT NULL,
    uncertainty           double precision NOT NULL DEFAULT 0 CHECK (uncertainty BETWEEN 0 AND 1),
    gap_detected          boolean NOT NULL DEFAULT false,
    missing_data          boolean NOT NULL DEFAULT false,
    stale_evidence        boolean NOT NULL DEFAULT false,
    rule_version          text,
    evidence_refs         text[] NOT NULL DEFAULT '{}',
    human_review_required boolean NOT NULL DEFAULT true CHECK (human_review_required),
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_assessments_tenant ON assessments (tenant_id, created_at DESC);

CREATE TABLE IF NOT EXISTS reviews (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    assessment_id uuid NOT NULL REFERENCES assessments(id),
    reviewer      text NOT NULL,
    decision      text NOT NULL CHECK (decision IN ('accepted','rejected')),
    annotation    text,
    created_at    timestamptz NOT NULL DEFAULT now()
);

-- Append-only audit trail: no UPDATE/DELETE grants; hash chains provenance.
CREATE TABLE IF NOT EXISTS audit_entries (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id    text NOT NULL,
    actor        text NOT NULL,
    action       text NOT NULL,
    object_type  text NOT NULL,
    object_id    text NOT NULL,
    payload_hash text NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now()
);
