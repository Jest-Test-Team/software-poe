*** Settings ***
Documentation     Evidence older than 30 days must be flagged stale and raise
...               uncertainty — stale topology must not present as current truth.
Resource          resources/common.resource
Suite Setup       Open POE Session

*** Test Cases ***
Old Observation Is Flagged Stale
    ${old}=    Get Current Date    UTC    increment=-45 days    result_format=%Y-%m-%dT%H:%M:%SZ
    ${event}=    Build Event    metric=slo_gap    value=${0.01}    observed_at=${old}
    ${result}=    Ingest Event    ${event}
    ${assessment}=    Wait For Assessment Containing Evidence    ${result['evidence_ref']}
    Should Be True    ${assessment['stale_evidence']}
    Should Be True    ${assessment['uncertainty']} >= 0.4
    Should Contain    ${assessment['summary']}    stale

Fresh Observation Is Not Flagged Stale
    ${event}=    Build Event    metric=slo_gap    value=${0.01}
    ${result}=    Ingest Event    ${event}
    ${assessment}=    Wait For Assessment Containing Evidence    ${result['evidence_ref']}
    Should Not Be True    ${assessment['stale_evidence']}
