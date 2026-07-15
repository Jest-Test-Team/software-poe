*** Settings ***
Documentation     Events without a registered expectation must surface as
...               missing-data assessments with maximal uncertainty — never
...               silently dropped, never auto-judged.
Resource          resources/common.resource
Suite Setup       Open POE Session

*** Test Cases ***
Event Without Expectation Yields Missing-Data Assessment
    # tenant B has no expectations seeded
    ${event}=    Build Event    tenant=${TENANT_B}    metric=incident_delta    value=${3}
    ${result}=    Ingest Event    ${event}
    ${assessment}=    Wait For Assessment Containing Evidence    ${result['evidence_ref']}    tenant=${TENANT_B}
    Should Be True    ${assessment['missing_data']}
    Should Be Equal As Numbers    ${assessment['uncertainty']}    1.0
    Should Be Equal    ${assessment['status']}    review-required
    Should Contain    ${assessment['summary']}    No expectation registered
