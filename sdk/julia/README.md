# SoftwarePOE.jl

Julia client SDK for Software POE. Registered in the General registry via JuliaRegistrator (`subdir=sdk/julia`).

```julia
using SoftwarePOE

client = Client("https://<choreo-gateway>"; api_key="...")
ingest(client, Event(
    tenant_id="synthetic-lab",
    source="synthetic-fixture",
    observed_at="2026-07-11T08:00:00Z",
    metric="intent_fulfillment_ratio",
    value=0.42,
))
assessments(client, "synthetic-lab")
```
