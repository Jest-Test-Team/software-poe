# Test Plan — Software POE

至少涵蓋：schema validation、missing data、stale evidence、counterexample、tenant isolation、rule versioning、human-review gate。

## Robot Framework suites (`tests/robot/`)

| Suite | Covers |
|---|---|
| `schema_validation.robot` | contract enforcement at the ingestion edge + API-key auth |
| `missing_data.robot` | events without expectations → missing-data assessment, uncertainty 1.0 |
| `stale_evidence.robot` | >30-day-old evidence flagged stale, uncertainty raised |
| `counterexample.robot` | satisfying observations produce **no** gap (false-positive guard) |
| `tenant_isolation.robot` | tenant scoping on list/review, unknown tenant refused |
| `rule_versioning.robot` | assessments pin rule_version; wrong schema_version refused |
| `human_review_gate.robot` | review-required by construction; transitions only via human decision |

## Running

```bash
docker compose up -d --build          # postgres + gateway + analysis + review
pip install robotframework robotframework-requests
robot --outputdir tests/results tests/robot
```

CI runs the same flow in `.github/workflows/robot-tests.yml`.
