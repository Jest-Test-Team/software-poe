using Test, SoftwarePOE

valid() = Event(
    tenant_id="synthetic-lab",
    source="synthetic-fixture",
    observed_at="2026-07-11T08:00:00Z",
    metric="intent_fulfillment_ratio",
    value=0.42,
)

@testset "event validation" begin
    @test isempty(validate_event(valid()))

    bad_metric = Event(
        tenant_id="synthetic-lab", source="s",
        observed_at="2026-07-11T08:00:00Z", metric="latency_p99", value=1.0)
    @test any(contains("metric"), validate_event(bad_metric))

    bad_ts = Event(
        tenant_id="synthetic-lab", source="s",
        observed_at="yesterday", metric="slo_gap", value=1.0)
    @test any(contains("observed_at"), validate_event(bad_ts))

    non_scalar = Event(
        tenant_id="synthetic-lab", source="s",
        observed_at="2026-07-11T08:00:00Z", metric="slo_gap", value=1.0,
        attributes=Dict{String,Any}("nested" => Dict("a" => 1)))
    @test any(contains("attributes.nested"), validate_event(non_scalar))
end
