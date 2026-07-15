*** Settings ***
Documentation     Every automated judgement must be traceable to a pinned
...               rule version (threat model: rule/model/version pinning).
Resource          resources/common.resource
Suite Setup       Open POE Session

*** Test Cases ***
Assessment Pins The Rule Version Used
    ${event}=    Build Event    metric=slo_gap    value=${0.5}
    ${result}=    Ingest Event    ${event}
    ${assessment}=    Wait For Assessment Containing Evidence    ${result['evidence_ref']}
    Should Be Equal    ${assessment['rule_version']}    v0.1.0

Wrong Schema Version Is Rejected At The Edge
    ${event}=    Build Event    schema_version=9.9.9
    ${res}=    Ingest Event Expecting Failure    ${event}
    Should Contain Match    ${res['errors']}    *schema_version*
