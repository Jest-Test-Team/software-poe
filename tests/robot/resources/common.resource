*** Settings ***
Documentation     Shared keywords for Software POE black-box API tests.
...               Requires the docker-compose stack (gateway on ${BASE_URL}).
Library           RequestsLibrary
Library           Collections
Library           DateTime

*** Variables ***
${BASE_URL}       http://localhost:8081
${API_KEY}        local-dev-key
${TENANT}         synthetic-lab
${TENANT_B}       synthetic-lab-b
${SCHEMA_VERSION}    0.1.0
${ANALYSIS_WAIT}     15s

*** Keywords ***
Open POE Session
    ${headers}=    Create Dictionary    X-API-Key=${API_KEY}    Content-Type=application/json
    Create Session    poe    ${BASE_URL}    headers=${headers}

Build Event
    [Arguments]    ${metric}=intent_fulfillment_ratio    ${value}=${0.42}
    ...            ${tenant}=${TENANT}    ${observed_at}=${EMPTY}    ${schema_version}=${SCHEMA_VERSION}
    IF    '${observed_at}' == '${EMPTY}'
        ${observed_at}=    Get Current Date    UTC    result_format=%Y-%m-%dT%H:%M:%SZ
    END
    ${event}=    Create Dictionary
    ...    tenant_id=${tenant}
    ...    project=software-poe
    ...    source=robot-suite
    ...    observed_at=${observed_at}
    ...    metric=${metric}
    ...    value=${value}
    ...    schema_version=${schema_version}
    RETURN    ${event}

Ingest Event
    [Arguments]    ${event}
    ${resp}=    POST On Session    poe    /v1/software-poe/events    json=${event}
    ...    expected_status=202
    RETURN    ${resp.json()}

Ingest Event Expecting Failure
    [Arguments]    ${event}    ${status}=400
    ${resp}=    POST On Session    poe    /v1/software-poe/events    json=${event}
    ...    expected_status=${status}
    RETURN    ${resp.json()}

Get Assessments
    [Arguments]    ${tenant}=${TENANT}    ${status}=${EMPTY}
    ${params}=    Create Dictionary    tenant_id=${tenant}
    IF    '${status}' != '${EMPTY}'
        Set To Dictionary    ${params}    status=${status}
    END
    ${resp}=    GET On Session    poe    /v1/software-poe/assessments    params=${params}
    ...    expected_status=200
    RETURN    ${resp.json()}

Wait For Assessment Containing Evidence
    [Documentation]    Poll until an assessment referencing ${evidence_ref} appears.
    [Arguments]    ${evidence_ref}    ${tenant}=${TENANT}
    ${assessment}=    Wait Until Keyword Succeeds    ${ANALYSIS_WAIT}    1s
    ...    Assessment With Evidence Must Exist    ${evidence_ref}    ${tenant}
    RETURN    ${assessment}

Assessment With Evidence Must Exist
    [Arguments]    ${evidence_ref}    ${tenant}
    ${assessments}=    Get Assessments    tenant=${tenant}
    FOR    ${a}    IN    @{assessments}
        IF    $evidence_ref in $a['evidence_refs']    RETURN    ${a}
    END
    Fail    No assessment found for evidence ${evidence_ref}

Review Assessment
    [Arguments]    ${assessment_id}    ${decision}    ${tenant}=${TENANT}    ${reviewer}=robot-reviewer
    ${params}=    Create Dictionary    tenant_id=${tenant}
    ${body}=    Create Dictionary    reviewer=${reviewer}    decision=${decision}    annotation=robot run
    ${resp}=    POST On Session    poe    /v1/software-poe/assessments/${assessment_id}/review
    ...    params=${params}    json=${body}    expected_status=200
    RETURN    ${resp.json()}
