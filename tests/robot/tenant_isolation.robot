*** Settings ***
Documentation     Tenant boundaries: one tenant must never see or decide on
...               another tenant's assessments.
Resource          resources/common.resource
Suite Setup       Open POE Session

*** Test Cases ***
Assessments Are Scoped To Their Tenant
    ${event}=    Build Event    metric=cost_estimate_error    value=${0.5}
    ${result}=    Ingest Event    ${event}
    ${assessment}=    Wait For Assessment Containing Evidence    ${result['evidence_ref']}
    # The same evidence must not be visible from tenant B
    ${others}=    Get Assessments    tenant=${TENANT_B}
    FOR    ${a}    IN    @{others}
        Should Not Contain    ${a['evidence_refs']}    ${result['evidence_ref']}
        Should Be Equal    ${a['tenant_id']}    ${TENANT_B}
    END

Unknown Tenant Cannot Ingest
    ${event}=    Build Event    tenant=intruder-tenant
    Ingest Event Expecting Failure    ${event}    status=403

Cross-Tenant Review Is Rejected
    ${event}=    Build Event    metric=unused_capability_ratio    value=${0.9}
    ${result}=    Ingest Event    ${event}
    ${assessment}=    Wait For Assessment Containing Evidence    ${result['evidence_ref']}
    ${params}=    Create Dictionary    tenant_id=${TENANT_B}
    ${body}=    Create Dictionary    reviewer=intruder    decision=accepted
    POST On Session    poe    /v1/software-poe/assessments/${assessment['assessment_id']}/review
    ...    params=${params}    json=${body}    expected_status=409
