"""
    SoftwarePOE

Client SDK for Software POE (post-occupancy evaluation for software
architecture). Mirrors `schemas/event.schema.json` version 0.1.0.
"""
module SoftwarePOE

using Dates, HTTP, JSON3, StructTypes

export Client, Event, validate_event, ingest, assessments, review

const SCHEMA_VERSION = "0.1.0"
const PROJECT = "software-poe"
const METRICS = Set([
    "intent_fulfillment_ratio",
    "slo_gap",
    "cost_estimate_error",
    "unused_capability_ratio",
    "incident_delta",
])

Base.@kwdef struct Event
    tenant_id::String
    source::String
    observed_at::String
    metric::String
    value::Float64
    unit::Union{String,Nothing} = nothing
    evidence_ref::Union{String,Nothing} = nothing
    attributes::Union{Dict{String,Any},Nothing} = nothing
    project::String = PROJECT
    schema_version::String = SCHEMA_VERSION
end

StructTypes.StructType(::Type{Event}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Event}) = (:unit, :evidence_ref, :attributes)

"""Return a vector of validation error strings (empty when valid)."""
function validate_event(e::Event)
    errors = String[]
    isempty(e.tenant_id) && push!(errors, "tenant_id is required")
    e.project == PROJECT || push!(errors, "project must be '$(PROJECT)'")
    isempty(e.source) && push!(errors, "source is required")
    try
        DateTime(replace(e.observed_at, r"Z$" => ""), dateformat"yyyy-mm-dd\THH:MM:SS")
    catch
        push!(errors, "observed_at must be an RFC3339 date-time")
    end
    e.metric in METRICS || push!(errors, "metric must be a registered metric ID")
    e.schema_version == SCHEMA_VERSION ||
        push!(errors, "schema_version must be '$(SCHEMA_VERSION)'")
    if e.attributes !== nothing
        for (k, v) in e.attributes
            v isa Union{AbstractString,Real,Bool,Nothing} ||
                push!(errors, "attributes.$k must be a scalar")
        end
    end
    return errors
end

struct Client
    base_url::String
    headers::Vector{Pair{String,String}}
end

function Client(base_url::AbstractString; api_key::Union{AbstractString,Nothing}=nothing)
    headers = ["Content-Type" => "application/json"]
    api_key !== nothing && push!(headers, "X-API-Key" => String(api_key))
    Client(rstrip(String(base_url), '/'), headers)
end

function ingest(c::Client, e::Event)
    errors = validate_event(e)
    isempty(errors) || throw(ArgumentError("invalid event: " * join(errors, "; ")))
    resp = HTTP.post(c.base_url * "/v1/software-poe/events", c.headers, JSON3.write(e))
    return JSON3.read(resp.body)
end

function assessments(c::Client, tenant_id::AbstractString; status=nothing)
    query = Dict("tenant_id" => tenant_id)
    status !== nothing && (query["status"] = status)
    resp = HTTP.get(c.base_url * "/v1/software-poe/assessments", c.headers; query=query)
    return JSON3.read(resp.body)
end

function review(c::Client, assessment_id::AbstractString, tenant_id::AbstractString;
                reviewer::AbstractString, decision::AbstractString, annotation=nothing)
    body = JSON3.write(Dict(
        "reviewer" => reviewer, "decision" => decision, "annotation" => annotation))
    url = c.base_url * "/v1/software-poe/assessments/$(assessment_id)/review"
    resp = HTTP.post(url, c.headers, body; query=Dict("tenant_id" => tenant_id))
    return JSON3.read(resp.body)
end

end # module
