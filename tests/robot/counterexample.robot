*** Settings ***
Documentation     Counterexample guard: observations satisfying their
...               expectation must NOT be reported as gaps (false-positive check),
...               while violating observations must be.
Resource          resources/common.resource
Suite Setup       Open POE Session

*** Test Cases ***
Satisfying Observation Produces No Gap
    # expectation: intent_fulfillment_ratio >= 0.8
    ${event}=    Build Event    metric=intent_fulfillment_ratio    value=${0.95}
    ${result}=    Ingest Event    ${event}
    ${assessment}=    Wait For Assessment Containing Evidence    ${result['evidence_ref']}
    Should Not Be True    ${assessment['gap_detected']}
    Should Contain    ${assessment['summary']}    within expectation

Violating Observation Produces A Gap
    ${event}=    Build Event    metric=intent_fulfillment_ratio    value=${0.42}
    ${result}=    Ingest Event    ${event}
    ${assessment}=    Wait For Assessment Containing Evidence    ${result['evidence_ref']}
    Should Be True    ${assessment['gap_detected']}
    Should Contain    ${assessment['summary']}    Gap detected

Boundary Value Satisfies A GTE Expectation
    ${event}=    Build Event    metric=intent_fulfillment_ratio    value=${0.8}
    ${result}=    Ingest Event    ${event}
    ${assessment}=    Wait For Assessment Containing Evidence    ${result['evidence_ref']}
    Should Not Be True    ${assessment['gap_detected']}
