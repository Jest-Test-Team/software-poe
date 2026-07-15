*** Settings ***
Documentation     Contract enforcement at the ingestion edge (schemas/event.schema.json).
Resource          resources/common.resource
Suite Setup       Open POE Session

*** Test Cases ***
Valid Event Is Accepted
    ${event}=    Build Event
    ${result}=    Ingest Event    ${event}
    Should Not Be Empty    ${result['event_id']}
    Should Start With    ${result['evidence_ref']}    sha256:

Missing Tenant Is Rejected
    ${event}=    Build Event
    Remove From Dictionary    ${event}    tenant_id
    ${result}=    Ingest Event Expecting Failure    ${event}
    Should Contain Match    ${result['errors']}    *tenant_id*

Wrong Project Constant Is Rejected
    ${event}=    Build Event
    Set To Dictionary    ${event}    project=other-project
    ${result}=    Ingest Event Expecting Failure    ${event}
    Should Contain Match    ${result['errors']}    *project*

Unregistered Metric Is Rejected
    ${event}=    Build Event    metric=latency_p99
    ${result}=    Ingest Event Expecting Failure    ${event}
    Should Contain Match    ${result['errors']}    *metric*

Malformed Timestamp Is Rejected
    ${event}=    Build Event    observed_at=yesterday
    ${result}=    Ingest Event Expecting Failure    ${event}
    Should Contain Match    ${result['errors']}    *observed_at*

Request Without API Key Is Rejected
    Create Session    anon    ${BASE_URL}
    ${event}=    Build Event
    ${resp}=    POST On Session    anon    /v1/software-poe/events    json=${event}
    ...    expected_status=401
