*** Settings ***
Documentation     No consequential state change without a human decision:
...               assessments are born review-required, always flagged
...               human_review_required, and only transition via the review API.
Resource          resources/common.resource
Suite Setup       Open POE Session

*** Test Cases ***
Assessment Requires Human Review By Construction
    ${event}=    Build Event    metric=incident_delta    value=${5}
    ${result}=    Ingest Event    ${event}
    ${assessment}=    Wait For Assessment Containing Evidence    ${result['evidence_ref']}
    Should Be True    ${assessment['human_review_required']}
    Should Be Equal    ${assessment['status']}    review-required

Human Decision Transitions The Assessment
    ${event}=    Build Event    metric=incident_delta    value=${7}
    ${result}=    Ingest Event    ${event}
    ${assessment}=    Wait For Assessment Containing Evidence    ${result['evidence_ref']}
    ${review}=    Review Assessment    ${assessment['assessment_id']}    rejected
    Should Be Equal    ${review['status']}    rejected

Decided Assessment Cannot Be Re-Decided
    ${event}=    Build Event    metric=incident_delta    value=${9}
    ${result}=    Ingest Event    ${event}
    ${assessment}=    Wait For Assessment Containing Evidence    ${result['evidence_ref']}
    Review Assessment    ${assessment['assessment_id']}    accepted
    ${params}=    Create Dictionary    tenant_id=${TENANT}
    ${body}=    Create Dictionary    reviewer=robot-reviewer    decision=rejected
    POST On Session    poe    /v1/software-poe/assessments/${assessment['assessment_id']}/review
    ...    params=${params}    json=${body}    expected_status=409

Review Without Reviewer Identity Is Rejected
    ${event}=    Build Event    metric=incident_delta    value=${11}
    ${result}=    Ingest Event    ${event}
    ${assessment}=    Wait For Assessment Containing Evidence    ${result['evidence_ref']}
    ${params}=    Create Dictionary    tenant_id=${TENANT}
    ${body}=    Create Dictionary    reviewer=${EMPTY}    decision=accepted
    POST On Session    poe    /v1/software-poe/assessments/${assessment['assessment_id']}/review
    ...    params=${params}    json=${body}    expected_status=400
