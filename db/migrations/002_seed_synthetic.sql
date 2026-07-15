-- Synthetic single-tenant seed (blueprint constraint: no production data).

INSERT INTO tenants (id, name)
VALUES ('synthetic-lab', 'Synthetic Lab'), ('synthetic-lab-b', 'Synthetic Lab B')
ON CONFLICT (id) DO NOTHING;

INSERT INTO architecture_decisions (tenant_id, adr_key, title, source, observed_at)
VALUES ('synthetic-lab', 'ADR-001', 'Adopt event-driven ingestion', 'synthetic-fixture', '2026-01-01T00:00:00Z')
ON CONFLICT (tenant_id, adr_key) DO NOTHING;

INSERT INTO expectations (tenant_id, adr_id, metric, comparator, expected_value, unit, rule_version, source, observed_at)
SELECT 'synthetic-lab', ad.id, m.metric, m.comparator, m.expected_value, m.unit, 'v0.1.0', 'synthetic-fixture', '2026-01-01T00:00:00Z'
FROM architecture_decisions ad,
     (VALUES
        ('intent_fulfillment_ratio', '>=', 0.8::float8, 'ratio'),
        ('slo_gap',                  '<=', 0.05::float8, 'ratio'),
        ('cost_estimate_error',      '<=', 0.15::float8, 'ratio'),
        ('unused_capability_ratio',  '<=', 0.25::float8, 'ratio'),
        ('incident_delta',           '<=', 0.0::float8,  'count')
     ) AS m(metric, comparator, expected_value, unit)
WHERE ad.tenant_id = 'synthetic-lab' AND ad.adr_key = 'ADR-001'
ON CONFLICT (tenant_id, metric, rule_version) DO NOTHING;
